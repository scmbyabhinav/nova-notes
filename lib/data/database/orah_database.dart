import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class _LegacyMigrationPlan {
  const _LegacyMigrationPlan({required this.ordinaryNotes, required this.vaultNotes});
  final List<Map<String, dynamic>> ordinaryNotes;
  final List<Map<String, dynamic>> vaultNotes;
}

/// Versioned local database. The legacy JSON is retained as a recovery backup
/// and is never deleted by the migration.
class OrahDatabase {
  OrahDatabase._();

  static const schemaVersion = 3;
  static const legacyNotesKey = 'nova_notes_v1';
  static const legacyBackupKey = 'orah_legacy_notes_backup_v1';
  static const vaultNotesKey = 'orah_vault_notes_v1';
  static Database? _instance;
  static Future<Database>? _opening;
  static int _activeOperations = 0;
  static int _nextOperationId = 0;
  static final Map<int, Map<String, Object?>> _activeOperationDetails = {};
  static Completer<void>? _operationsDrained;
  static int _activeTransactions = 0;
  static void _diag(String phase, String message) => print('[ORAH-DIAG][utc=${DateTime.now().toUtc().toIso8601String()}][run=${Platform.environment['GITHUB_RUN_ID'] ?? 'local'}][phase=$phase] $message');

  static Future<Database> open(SharedPreferences preferences) async {
    _diag('database-open', 'OrahDatabase.open ENTER openingPending=${_opening != null} instanceOpen=${_instance?.isOpen ?? false}');
    final existing = _instance;
    if (existing != null && existing.isOpen) {
      _diag('database-open', 'OrahDatabase.open EXIT using existing database');
      return existing;
    }
    final pending = _opening;
    if (pending != null) { _diag('database-open', 'joining in-flight SQLite initialization'); return pending; }
    final future = _openAndMigrate(preferences);
    _opening = future;
    try {
      final db = await future;
      _instance = db;
      _diag('database-open', 'OrahDatabase.open EXIT initialized isOpen=${db.isOpen}');
      return db;
    } catch (error) {
      _diag('database-open', 'OrahDatabase.open FAILED error=$error');
      rethrow;
    } finally {
      _opening = null;
      _diag('database-open', 'opening future cleared');
    }
  }

  static const _legacyMigrationKey = 'legacy_json_v1';
  static const _legacyVaultPendingKey = 'legacy_vault_pending_v1';

  static Future<Database> _openAndMigrate(SharedPreferences preferences) async {
    _diag('sqlite-initialize', 'SQLite initialization ENTER');
    final root = await getDatabasesPath();
    _diag('sqlite-initialize', 'before openDatabase root resolved');
    final db = await openDatabase(p.join(root, 'orah_notes.db'));
    _diag('sqlite-initialize', 'openDatabase returned isOpen=${db.isOpen}');
    try {
      _diag('sqlite-initialize', 'checking migration_state table');
      final table = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='migration_state'");
      String? existingState;
      if (table.isNotEmpty) {
        final rows = await db.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: [_legacyMigrationKey], limit: 1);
        if (rows.isNotEmpty) existingState = rows.single['value'] as String;
      }
      final legacy = preferences.getString(legacyNotesKey);
      _diag('sqlite-initialize', 'state preflight complete state=$existingState legacy=${legacy != null && legacy.isNotEmpty}');
      final plan = existingState == null && legacy != null && legacy.isNotEmpty
          ? await _prepareLegacyMigration(preferences, legacy) : null;
      _diag('sqlite-initialize', 'migration plan prepared=${plan != null}');
      _activeTransactions++;
      _diag('sqlite-transaction', 'migration transaction ENTER activeTransactions=$_activeTransactions');
      try {
      await db.transaction((txn) async {
        _diag('sqlite-transaction', 'transaction callback entered');
        final versionRows = await txn.rawQuery('PRAGMA user_version');
        final currentVersion = (versionRows.single['user_version'] as int?) ?? 0;
        await _createSchema(txn);
        _diag('sqlite-transaction', 'schema created');
        await txn.execute('CREATE TABLE IF NOT EXISTS migration_state (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
        final stateRows = await txn.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: [_legacyMigrationKey], limit: 1);
        final state = stateRows.isEmpty ? null : stateRows.single['value'] as String;
        if (state == null) {
          if (plan == null) {
            await txn.insert('migration_state', {'key': _legacyMigrationKey, 'value': 'complete'});
          } else {
            for (final map in plan.ordinaryNotes) {
              await txn.insert('notes', rowFor(map), conflictAlgorithm: ConflictAlgorithm.ignore);
            }
            for (final map in plan.ordinaryNotes) {
              final rows = await txn.query('notes', columns: ['id', 'payload'], where: 'id = ?', whereArgs: [map['id']], limit: 1);
              if (rows.length != 1) throw StateError('Legacy note ${map['id']} was not persisted.');
              final stored = jsonDecode(rows.single['payload'] as String);
              if (stored is! Map || stored['id'] != map['id']) throw StateError('Legacy note ${map['id']} failed verification.');
            }
            await txn.insert('migration_state', {'key': _legacyMigrationKey, 'value': 'vault_pending'});
            await txn.insert('migration_state', {'key': _legacyVaultPendingKey, 'value': jsonEncode(plan.vaultNotes)});
          }
        } else if (state != 'complete' && state != 'vault_pending') {
          throw StateError('Unknown legacy migration state: $state');
        }
        _diag('sqlite-transaction', 'migration state staged currentVersion=$currentVersion');
        if (currentVersion < schemaVersion) await txn.execute('PRAGMA user_version = $schemaVersion');
        _diag('sqlite-transaction', 'user_version write complete');
      });
      _diag('sqlite-transaction', 'transaction commit returned activeTransactions=$_activeTransactions');
      } finally {
        _activeTransactions--;
        _diag('sqlite-transaction', 'migration transaction EXIT activeTransactions=$_activeTransactions');
      }
      await _finishPendingVaultMigration(db, preferences);
      _diag('sqlite-initialize', 'pending Vault migration finalized');
      final version = await db.getVersion();
      _diag('sqlite-initialize', 'final version=$version');
      if (version < schemaVersion) throw StateError('Database schema version $version is below $schemaVersion.');
      _diag('sqlite-initialize', 'SQLite initialization EXIT schemaVersion=$version isOpen=${db.isOpen}');
      return db;
    } catch (error, stackTrace) {
      _diag('sqlite-initialize', 'SQLite initialization FAILED error=$error activeTransactions=$_activeTransactions');
      if (db.isOpen) await db.close();
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<_LegacyMigrationPlan> _prepareLegacyMigration(SharedPreferences preferences, String legacy) async {
    final decoded = jsonDecode(legacy);
    if (decoded is! List) throw const FormatException('Legacy notes storage is not a JSON list; original data was preserved.');
    final ordinary = <String, Map<String, dynamic>>{};
    final locked = <String, Map<String, dynamic>>{};
    for (final entry in decoded) {
      if (entry is! Map) throw const FormatException('Legacy notes contain a malformed record; original data was preserved.');
      final map = Map<String, dynamic>.from(entry);
      final id = map['id'];
      if (id is! String || id.trim().isEmpty) throw const FormatException('A legacy note has no stable ID; original data was preserved.');
      if (map['isLocked'] == true) { locked.putIfAbsent(id, () => map); } else { ordinary.putIfAbsent(id, () => map); }
    }
    if (preferences.getString(legacyBackupKey) == null) {
      final saved = await preferences.setString(legacyBackupKey, legacy);
      if (!saved || preferences.getString(legacyBackupKey) != legacy) throw StateError('Could not verify the legacy notes recovery backup.');
    }
    final vaultRaw = preferences.getString(vaultNotesKey);
    final vault = <String, Map<String, dynamic>>{};
    if (vaultRaw != null && vaultRaw.isNotEmpty) {
      final decodedVault = jsonDecode(vaultRaw);
      if (decodedVault is! List) throw const FormatException('Vault storage is malformed; SQLite migration stopped without replacing it.');
      for (final entry in decodedVault) {
        if (entry is! Map || entry['id'] is! String) throw const FormatException('Vault storage contains a malformed record; it was not replaced.');
        final map = Map<String, dynamic>.from(entry);
        vault[map['id'] as String] = map;
      }
    }
    for (final entry in locked.entries) { vault.putIfAbsent(entry.key, () => entry.value); }
    return _LegacyMigrationPlan(ordinaryNotes: ordinary.values.toList(growable: false), vaultNotes: vault.values.toList(growable: false));
  }

  static Future<void> _finishPendingVaultMigration(Database db, SharedPreferences preferences) async {
    final stateRows = await db.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: [_legacyMigrationKey], limit: 1);
    if (stateRows.isEmpty || stateRows.single['value'] == 'complete') return;
    if (stateRows.single['value'] != 'vault_pending') throw StateError('Unexpected legacy migration state: ${stateRows.single['value']}');
    final pendingRows = await db.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: [_legacyVaultPendingKey], limit: 1);
    if (pendingRows.length != 1) throw StateError('Pending Vault migration payload is missing.');
    final decoded = jsonDecode(pendingRows.single['value'] as String);
    if (decoded is! List || decoded.any((item) => item is! Map || item['id'] is! String)) throw const FormatException('Pending Vault migration payload is malformed.');
    final pendingVault = decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final encoded = jsonEncode(pendingVault);
    final saved = await preferences.setString(vaultNotesKey, encoded);
    if (!saved || preferences.getString(vaultNotesKey) != encoded) throw StateError('Could not verify migrated Vault data; startup is retryable.');
    _activeTransactions++;
    _diag('sqlite-transaction', 'vault-finalization transaction ENTER activeTransactions=$_activeTransactions');
    try {
    await db.transaction((txn) async {
      await txn.update('migration_state', {'value': 'complete'}, where: 'key = ?', whereArgs: [_legacyMigrationKey]);
      await txn.delete('migration_state', where: 'key = ?', whereArgs: [_legacyVaultPendingKey]);
    });
    _diag('sqlite-transaction', 'vault-finalization transaction commit returned');
    } finally {
      _activeTransactions--;
      _diag('sqlite-transaction', 'vault-finalization transaction EXIT activeTransactions=$_activeTransactions');
    }
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'text',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        tags TEXT NOT NULL DEFAULT '[]',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        deadline TEXT,
        focus_minutes INTEGER NOT NULL DEFAULT 0,
        font_family TEXT,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        content TEXT NOT NULL,
        saved_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_note_versions_note_saved ON note_versions(note_id, saved_at)');

    // v3: Keep study progress separate from the serialized note payload.
    // This avoids competing read-modify-write operations with editor autosave.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS study_task_status (
        note_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        study_status TEXT NOT NULL DEFAULT 'new'
          CHECK (study_status IN ('new', 'learning', 'mastered')),
        updated_at TEXT NOT NULL,
        PRIMARY KEY (note_id, task_id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        last_done TEXT,
        streak INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Map<String, Object?> rowFor(Map<String, dynamic> map) => {
    'id': map['id'] as String,
    'title': map['title'] as String? ?? '',
    'content': map['content'] as String? ?? '',
    'type': map['type'] as String? ?? 'text',
    'created_at': map['createdAt'] as String? ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
    'updated_at': map['updatedAt'] as String? ?? DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
    'tags': jsonEncode(map['tags'] is List ? map['tags'] : const []),
    'is_pinned': map['isPinned'] == true ? 1 : 0,
    'deadline': map['dueAt'] as String?,
    'focus_minutes': map['focusMinutes'] is int ? map['focusMinutes'] as int : 0,
    'font_family': map['fontFamily'] as String?,
    'payload': jsonEncode(map),
  };

  static Map<String, dynamic> mapFromRow(Map<String, Object?> row) {
    final payload = jsonDecode(row['payload'] as String);
    if (payload is! Map) throw const FormatException('Stored note payload is malformed.');
    final map = Map<String, dynamic>.from(payload);
    map['tags'] = _decodeList(row['tags']);
    map['isPinned'] = (row['is_pinned'] as int? ?? 0) == 1;
    map['dueAt'] = row['deadline'];
    map['focusMinutes'] = row['focus_minutes'] as int? ?? 0;
    map['fontFamily'] = row['font_family'];
    return map;
  }

  static List<String> _decodeList(Object? value) {
    try {
      final decoded = jsonDecode(value as String);
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) {}
    return const [];
  }

  /// Tracks in-flight repository work for deterministic test teardown.
  static Future<T> trackOperation<T>(
    Future<T> Function() operation, {
    String name = 'unnamed',
  }) async {
    if (_activeOperations == 0) _operationsDrained = Completer<void>();
    final id = ++_nextOperationId;
    final startedAt = DateTime.now();
    final clock = Stopwatch()..start();
    final callSite = StackTrace.current.toString().split('\n').skip(1).take(5).join(' | ');
    _activeOperations++;
    _activeOperationDetails[id] = {
      'id': id,
      'name': name,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'elapsedMs': 0,
      'status': 'active',
      'callSite': callSite,
      'finallyEntered': false,
    };
    _diag('repository-operations', 'START id=$id name=$name activeOperations=$_activeOperations callSite=$callSite');
    try {
      final result = await operation();
      _diag('repository-operations', 'FUTURE_COMPLETE id=$id name=$name outcome=success elapsedMs=${clock.elapsedMilliseconds}');
      return result;
    } catch (error, stackTrace) {
      _diag('repository-operations', 'FUTURE_COMPLETE id=$id name=$name outcome=failure elapsedMs=${clock.elapsedMilliseconds} error=$error stack=$stackTrace');
      rethrow;
    } finally {
      final details = _activeOperationDetails[id];
      if (details != null) {
        details['finallyEntered'] = true;
        details['elapsedMs'] = clock.elapsedMilliseconds;
        details['status'] = 'finally';
      }
      _activeOperationDetails.remove(id);
      _activeOperations--;
      _diag('repository-operations', 'FINALLY_EXIT id=$id name=$name elapsedMs=${clock.elapsedMilliseconds} activeOperations=$_activeOperations');
      if (_activeOperations == 0 && !(_operationsDrained?.isCompleted ?? true)) {
        _operationsDrained!.complete();
        _diag('repository-operations', 'drain completer completed');
      }
    }
  }

  static Future<void> waitForOperationsForTesting() async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    _diag('repository-drain', 'ENTER activeOperations=$_activeOperations hasDrainCompleter=${_operationsDrained != null}');
    try {
      // The counter is authoritative. A waiter can capture a completed drain
      // completer just as another operation starts, so always re-check the
      // live count after each wake-up rather than trusting one Future forever.
      while (_activeOperations > 0) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining <= Duration.zero) {
          throw TimeoutException(
            'Repository operations did not drain; activeOperations=$_activeOperations',
            const Duration(seconds: 12),
          );
        }
        final pending = _operationsDrained;
        if (pending != null && !pending.isCompleted) {
          await Zone.root.run(() => Future.any<void>([
                pending.future,
                Future<void>.delayed(const Duration(milliseconds: 1)),
              ]).timeout(remaining));
        } else {
          await Zone.root.run(() => Future<void>.delayed(const Duration(milliseconds: 1)).timeout(remaining));
        }
      }
      _diag('repository-drain', 'EXIT activeOperations=$_activeOperations');
    } catch (error, stackTrace) {
      _diag('repository-drain', 'FAILED activeOperations=$_activeOperations error=$error');
      for (final entry in _activeOperationDetails.entries) {
        final details = entry.value;
        _diag('repository-drain-active', 'id=${details['id']} name=${details['name']} startedAt=${details['startedAt']} elapsedMs=${DateTime.now().difference(DateTime.parse(details['startedAt'] as String)).inMilliseconds} status=${details['status']} finallyEntered=${details['finallyEntered']} callSite=${details['callSite']}');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Test-only reset. Production callers should never close/delete the database.
  static Future<void> closeForTesting() async {
    _diag('database-close', 'closeForTesting ENTER activeOperations=$_activeOperations activeTransactions=$_activeTransactions openingPending=${_opening != null} instanceOpen=${_instance?.isOpen ?? false}');
    try {
      await waitForOperationsForTesting();
      _diag('database-close', 'repository operations drained');
      final pendingOpen = _opening;
      if (pendingOpen != null) {
        _diag('database-close', 'awaiting in-flight SQLite initialization');
        await Zone.root.run(() => pendingOpen.timeout(const Duration(seconds: 12)));
        _diag('database-close', 'in-flight SQLite initialization completed');
      }
      final db = _instance;
      _instance = null;
      _opening = null;
      if (db != null && db.isOpen) {
        _diag('database-close', 'Database.close ENTER activeTransactions=$_activeTransactions');
        await Zone.root.run(() => db.close().timeout(const Duration(seconds: 12)));
        _diag('database-close', 'Database.close EXIT');
      }
      _diag('database-close', 'closeForTesting EXIT activeOperations=$_activeOperations activeTransactions=$_activeTransactions');
    } catch (error, stackTrace) {
      _diag('database-close', 'closeForTesting FAILED error=$error activeOperations=$_activeOperations activeTransactions=$_activeTransactions');
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
