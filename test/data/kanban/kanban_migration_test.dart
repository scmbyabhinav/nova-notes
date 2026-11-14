import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/orah_database.dart';

void main() {
  Directory? directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await OrahDatabase.closeForTesting();
    directory = await Directory.systemTemp.createTemp('orah_kanban_migration_');
    await databaseFactoryFfi.setDatabasesPath(directory!.path);
  });

  tearDown(() async {
    await OrahDatabase.closeForTesting();
    final current = directory;
    if (current != null && await current.exists()) await current.delete(recursive: true);
    directory = null;
  });

  test('upgrades an existing schema-v2 database without changing notes', () async {
    final path = p.join(directory!.path, 'orah_notes.db');
    final oldDb = await databaseFactoryFfi.openDatabase(path, options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE notes (
          id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL DEFAULT '', content TEXT NOT NULL DEFAULT '',
          type TEXT NOT NULL DEFAULT 'text', created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          tags TEXT NOT NULL DEFAULT '[]', is_pinned INTEGER NOT NULL DEFAULT 0, deadline TEXT,
          focus_minutes INTEGER NOT NULL DEFAULT 0, font_family TEXT, payload TEXT NOT NULL
        )''');
        await db.insert('notes', {
          'id': 'note-before-kanban', 'title': 'Keep existing note', 'content': 'Do not alter me',
          'type': 'text', 'created_at': '2026-01-01T00:00:00.000Z', 'updated_at': '2026-01-02T00:00:00.000Z',
          'tags': '[]', 'is_pinned': 0, 'deadline': null, 'focus_minutes': 0, 'font_family': null,
          'payload': '{"id":"note-before-kanban","title":"Keep existing note","content":"Do not alter me"}',
        });
      },
    ));
    await oldDb.close();

    final preferences = await SharedPreferences.getInstance();
    final upgraded = await OrahDatabase.open(preferences);
    expect(await upgraded.getVersion(), OrahDatabase.schemaVersion);
    final note = await upgraded.query('notes', where: 'id = ?', whereArgs: ['note-before-kanban']);
    expect(note, hasLength(1));
    expect(note.single['title'], 'Keep existing note');
    expect(note.single['content'], 'Do not alter me');

    final tables = await upgraded.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    expect(tables.map((row) => row['name']), containsAll(['kanban_cards', 'goals', 'links', 'time_entries']));
  });
}
