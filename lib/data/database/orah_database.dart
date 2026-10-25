import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Versioned local database. The legacy JSON is retained as a recovery backup
/// and is never deleted by the migration.
class OrahDatabase {
  OrahDatabase._();

  static const schemaVersion = 2;
  static const legacyNotesKey = 'nova_notes_v1';
  static const legacyBackupKey = 'orah_legacy_notes_backup_v1';
  static const vaultNotesKey = 'orah_vault_notes_v1';
  static const migrationMarkerKey = 'orah_sqlite_migration_v2_complete';
  static Database? _instance;
  static Future<Database>? _opening;

  static Future<Database> open(SharedPreferences preferences) async {
    print('[ORAH-DIAG] sqlite.open entered');
    final existing = _instance;
    if (existing != null && existing.isOpen) {
      print('[ORAH-DIAG] sqlite.open using cached database');
      return existing;
    }
    final pending = _opening;
    if (pending != null) return pending;
    print('[ORAH-DIAG] sqlite.open starting open/migration');
    final future = _openAndMigrate(preferences);
    _opening = future;
    try {
      final db = await future;
      print('[ORAH-DIAG] sqlite.open completed');
      _instance = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  static Future<Database> _openAndMigrate(SharedPreferences preferences) async {
    print('[ORAH-DIAG] sqlite: resolving database directory');
    final root = await getDatabasesPath();
    print('[ORAH-DIAG] sqlite: database directory resolved to $root');
    print('[ORAH-DIAG] sqlite: calling openDatabase');
    final db = await openDatabase(
      p.join(root, 'orah_notes.db'),
      version: schemaVersion,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSchema(db);
      },
    );
    print('[ORAH-DIAG] sqlite: openDatabase returned; checking migration marker');

    // Migration is idempotent and transactional. Do not mark completion until
    // every valid record has been inserted and the Vault split has succeeded.
    final done = preferences.getBool(migrationMarkerKey) == true;
    print('[ORAH-DIAG] sqlite: migration marker read done=$done');
    if (!done) {
      final legacy = preferences.getString(legacyNotesKey);
      print('[ORAH-DIAG] sqlite: legacy payload present=${legacy != null && legacy.isNotEmpty}');
      if (legacy != null && legacy.isNotEmpty) {
        print('[ORAH-DIAG] sqlite: legacy migration starting length=${legacy.length}');
        await _migrateLegacyJson(db, preferences, legacy);
        print('[ORAH-DIAG] sqlite: legacy migration completed');
      }
      // The marker is an idempotency optimization, not part of the SQLite
      // transaction. Do not let a stalled preferences-store write keep the
      // database unavailable after schema creation and migration have succeeded.
      // If it does not persist, the next launch safely retries the idempotent
      // migration (ordinary note inserts use ConflictAlgorithm.ignore).
      print('[ORAH-DIAG] sqlite: scheduling migration marker write');
      unawaited(preferences.setBool(migrationMarkerKey, true).then<void>(
        (saved) {
          print('[ORAH-DIAG] sqlite: migration marker write completed result=$saved');
        },
        onError: (Object error, StackTrace stackTrace) {
          print('[ORAH-DIAG] sqlite: migration marker write failed: $error');
        },
      ));
    }
    print('[ORAH-DIAG] sqlite: database initialization finished');
    return db;
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habits (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        last_done TEXT,
        streak INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static Future<void> _migrateLegacyJson(
    Database db,
    SharedPreferences preferences,
    String legacy,
  ) async {
    final decoded = jsonDecode(legacy);
    if (decoded is! List) {
      throw const FormatException('Legacy notes storage is not a JSON list; original data was preserved.');
    }

    final ordinary = <Map<String, dynamic>>[];
    final locked = <Map<String, dynamic>>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      if (map['isLocked'] == true) {
        locked.add(map);
      } else {
        ordinary.add(map);
      }
    }

    // Keep an explicit immutable copy in addition to the untouched legacy key.
    if (preferences.getString(legacyBackupKey) == null) {
      await preferences.setString(legacyBackupKey, legacy);
    }

    final existingVaultRaw = preferences.getString(vaultNotesKey);
    final vaultById = <String, Map<String, dynamic>>{};
    if (existingVaultRaw != null && existingVaultRaw.isNotEmpty) {
      final vaultDecoded = jsonDecode(existingVaultRaw);
      if (vaultDecoded is! List) {
        throw const FormatException('Vault storage is malformed; SQLite migration stopped without replacing it.');
      }
      for (final entry in vaultDecoded) {
        if (entry is Map && entry['id'] is String) {
          vaultById[entry['id'] as String] = Map<String, dynamic>.from(entry);
        }
      }
    }
    for (final entry in locked) {
      if (entry['id'] is String) vaultById[entry['id'] as String] = entry;
    }

    await db.transaction((txn) async {
      for (final map in ordinary) {
        final id = map['id'];
        if (id is! String || id.trim().isEmpty) continue;
        await txn.insert('notes', rowFor(map), conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    // Only update Vault after SQLite's transaction commits. The original JSON
    // is retained for recovery if this write or the completion marker fails.
    await preferences.setString(vaultNotesKey, jsonEncode(vaultById.values.toList()));
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

  /// Test-only reset. Production callers should never close/delete the database.
  static Future<void> closeForTesting() async {
    // A widget can start opening SQLite and then be disposed before the
    // future completes. Never clear _opening while that open is still in
    // flight: doing so permits a second connection to race the first one.
    final pendingOpen = _opening;
    if (pendingOpen != null) {
      try {
        await pendingOpen;
      } catch (_) {
        // Preserve the original open error; cleanup should still reset state.
      }
    }

    final db = _instance;
    _instance = null;
    _opening = null;
    if (db != null && db.isOpen) await db.close();
  }
}
