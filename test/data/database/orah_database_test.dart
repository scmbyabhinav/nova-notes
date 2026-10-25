import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/database/note_dao.dart';

void main() {
  late Directory databaseDirectory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseDirectory = await Directory.systemTemp.createTemp('orah_sqlite_test_');
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory.path);
    await OrahDatabase.closeForTesting();
  });

  tearDown(() async {
    await OrahDatabase.closeForTesting();
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  Map<String, dynamic> note({
    String id = 'note-1',
    String title = 'Migration note',
    bool locked = false,
  }) => {
        'id': id,
        'title': title,
        'content': locked ? 'vault:v1:encrypted-payload' : 'Original body',
        'type': 'text',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-02T00:00:00.000',
        'tags': ['work', 'study'],
        'isPinned': true,
        'isLocked': locked,
        'isFavorite': true,
        'isArchived': false,
        'isTrashed': false,
        'dueAt': '2026-02-01T00:00:00.000',
        'attachments': ['image.jpg'],
        'checklistItems': [
          {'id': 'check-1', 'text': 'Keep me', 'isDone': true}
        ],
      };

  test('migrates JSON notes once and preserves source JSON and metadata', () async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = jsonEncode([note(), note(id: 'locked-1', locked: true)]);
    await prefs.setString(OrahDatabase.legacyNotesKey, legacy);
    await prefs.setString(OrahDatabase.vaultNotesKey, jsonEncode([
      {'id': 'pre-existing-vault', 'isLocked': true, 'content': 'vault:v1:old'}
    ]));

    final db = await OrahDatabase.open(prefs);
    final rows = await db.query('notes');
    expect(rows, hasLength(1));
    final migrated = OrahDatabase.mapFromRow(rows.single);
    expect(migrated['id'], 'note-1');
    expect(migrated['title'], 'Migration note');
    expect(migrated['content'], 'Original body');
    expect(migrated['tags'], ['work', 'study']);
    expect(migrated['isPinned'], isTrue);
    expect(migrated['dueAt'], '2026-02-01T00:00:00.000');
    expect(migrated['checklistItems'], hasLength(1));

    expect(prefs.getString(OrahDatabase.legacyNotesKey), legacy);
    expect(prefs.getString(OrahDatabase.legacyBackupKey), legacy);
    expect(await db.getVersion(), OrahDatabase.schemaVersion);
    final migrationState = await db.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: ['legacy_json_v1']);
    expect(migrationState.single['value'], 'complete');
    final vault = jsonDecode(prefs.getString(OrahDatabase.vaultNotesKey)!) as List;
    expect(vault.map((item) => item['id']), containsAll(['locked-1', 'pre-existing-vault']));

    await db.insert('notes', OrahDatabase.rowFor(note(id: 'new-note')));
    await OrahDatabase.closeForTesting();
    final reopened = await OrahDatabase.open(prefs);
    expect(await reopened.query('notes'), hasLength(2));
    expect(prefs.getString(OrahDatabase.legacyNotesKey), legacy);
  });

  test('creates versioned schema and required future-feature tables', () async {
    final prefs = await SharedPreferences.getInstance();
    final db = await OrahDatabase.open(prefs);
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((row) => row['name']).toSet();

    expect(tables, containsAll(['notes', 'note_versions', 'habits']));
    final columns = (await db.rawQuery('PRAGMA table_info(notes)'))
        .map((row) => row['name'])
        .toSet();
    expect(columns, containsAll([
      'tags',
      'is_pinned',
      'deadline',
      'focus_minutes',
      'font_family',
      'payload',
    ]));
    expect(db.getVersion(), completion(OrahDatabase.schemaVersion));
  });

  test('NoteDao upserts, lists, counts, and deletes by stable ID', () async {
    final prefs = await SharedPreferences.getInstance();
    final db = await OrahDatabase.open(prefs);
    final dao = NoteDao(db);

    await dao.upsert(note());
    expect(await dao.count(), 1);
    expect((await dao.getAllRows()).single['id'], 'note-1');

    await dao.upsert(note(title: 'Updated title'));
    expect(await dao.count(), 1);
    expect((await dao.getAllRows()).single['title'], 'Updated title');

    await dao.delete('note-1');
    expect(await dao.count(), 0);
  });

  test('recovers a committed pending Vault migration on next initialization', () async {
    final prefs = await SharedPreferences.getInstance();
    final seed = await databaseFactoryFfi.openDatabase('${databaseDirectory.path}/orah_notes.db');
    await seed.execute('CREATE TABLE migration_state (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
    await seed.insert('migration_state', {'key': 'legacy_json_v1', 'value': 'vault_pending'});
    await seed.insert('migration_state', {'key': 'legacy_vault_pending_v1', 'value': jsonEncode([note(id: 'vault-recovery', locked: true)])});
    await seed.execute('PRAGMA user_version = 2');
    await seed.close();
    final recovered = await OrahDatabase.open(prefs);
    expect(prefs.getString(OrahDatabase.vaultNotesKey), contains('vault-recovery'));
    final state = await recovered.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: ['legacy_json_v1']);
    expect(state.single['value'], 'complete');
    expect(await recovered.query('migration_state', where: 'key = ?', whereArgs: ['legacy_vault_pending_v1']), isEmpty);
  });

  test('concurrent initialization shares one database and migrates once', () async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = jsonEncode([note(), note(id: 'note-2', title: 'Second')]);
    await prefs.setString(OrahDatabase.legacyNotesKey, legacy);
    final databases = await Future.wait(List.generate(8, (_) => OrahDatabase.open(prefs)));
    expect(databases.every((db) => identical(db, databases.first)), isTrue);
    expect(await databases.first.query('notes'), hasLength(2));
    expect(await databases.first.getVersion(), OrahDatabase.schemaVersion);
    final state = await databases.first.query('migration_state', columns: ['value'], where: 'key = ?', whereArgs: ['legacy_json_v1']);
    expect(state.single['value'], 'complete');
    expect(prefs.getString(OrahDatabase.legacyNotesKey), legacy);
  });

  test('repeated initialization preserves stable IDs and trash metadata', () async {
    final prefs = await SharedPreferences.getInstance();
    final trashed = note(id: 'trash-1')..['isTrashed'] = true;
    final legacy = jsonEncode([trashed]);
    await prefs.setString(OrahDatabase.legacyNotesKey, legacy);
    final first = await OrahDatabase.open(prefs);
    expect(await first.query('notes'), hasLength(1));
    await OrahDatabase.closeForTesting();
    final second = await OrahDatabase.open(prefs);
    final stored = OrahDatabase.mapFromRow((await second.query('notes')).single);
    expect(stored['id'], 'trash-1');
    expect(stored['isTrashed'], isTrue);
    expect(prefs.getString(OrahDatabase.legacyNotesKey), legacy);
  });


  test('SQLite import failure rolls back schema and version while preserving source', () async {
    final prefs = await SharedPreferences.getInstance();
    final invalid = note()..['createdAt'] = 123;
    final legacy = jsonEncode([invalid]);
    await prefs.setString(OrahDatabase.legacyNotesKey, legacy);

    await expectLater(OrahDatabase.open(prefs), throwsA(anything));
    expect(prefs.getString(OrahDatabase.legacyNotesKey), legacy);

    final db = await databaseFactoryFfi.openDatabase('${databaseDirectory.path}/orah_notes.db');
    expect(await db.getVersion(), 0);
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('notes', 'migration_state')");
    expect(tables, isEmpty);
    await db.close();
  });

  test('malformed legacy JSON fails without overwriting source data', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(OrahDatabase.legacyNotesKey, '{not-json');

    await expectLater(OrahDatabase.open(prefs), throwsA(anything));
    expect(prefs.getString(OrahDatabase.legacyNotesKey), '{not-json');
    final db = await databaseFactoryFfi.openDatabase('${databaseDirectory.path}/orah_notes.db');
    expect(await db.getVersion(), 0);
    await db.close();
  });
}
