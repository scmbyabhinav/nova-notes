// ORAH-F04 persistence regression tests; kept independent of note payload serialization.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:orah_notes/data/database/note_dao.dart';
import 'package:orah_notes/data/database/orah_database.dart';

void main() {
  late Directory databaseDirectory;
  late SharedPreferences preferences;
  late NoteDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    databaseDirectory = await Directory.systemTemp.createTemp('orah_study_status_');
    await databaseFactoryFfi.setDatabasesPath(databaseDirectory.path);
    await OrahDatabase.closeForTesting();
    dao = NoteDao(await OrahDatabase.open(preferences));
  });

  tearDown(() async {
    await OrahDatabase.closeForTesting();
    if (await databaseDirectory.exists()) {
      await databaseDirectory.delete(recursive: true);
    }
  });

  Map<String, dynamic> note({
    String id = 'note-1',
    String content = 'Keep note content unchanged',
    List<Map<String, dynamic>>? checklistItems,
  }) => {
        'id': id,
        'title': 'Study note',
        'content': content,
        'type': 'checklist',
        'createdAt': '2026-01-01T00:00:00.000',
        'updatedAt': '2026-01-02T00:00:00.000',
        'tags': <String>[],
        'attachments': <String>[],
        'checklistItems': checklistItems ??
            [
              {'id': 'task-1', 'text': 'Revise algebra', 'isDone': false},
            ],
      };

  test('status persists across database close and reopen', () async {
    await dao.upsert(note());
    await dao.updateStudyTaskStatus('note-1', 'task-1', 'learning');
    expect(await dao.getStudyTaskStatuses('note-1'), {'task-1': 'learning'});

    await OrahDatabase.closeForTesting();
    final reopened = await OrahDatabase.open(preferences);
    dao = NoteDao(reopened);

    expect(await dao.getStudyTaskStatuses('note-1'), {'task-1': 'learning'});
    final stored = (await dao.getAllRows()).single;
    expect(stored['content'], 'Keep note content unchanged');
    expect(stored['checklistItems'], [
      {'id': 'task-1', 'text': 'Revise algebra', 'isDone': false},
    ]);
  });

  test('saving a note after task deletion cleans its orphaned status', () async {
    await dao.upsert(note());
    await dao.updateStudyTaskStatus('note-1', 'task-1', 'mastered');
    expect(await dao.getStudyTaskStatuses('note-1'), {'task-1': 'mastered'});

    await dao.upsert(note(checklistItems: const []));

    expect(await dao.getStudyTaskStatuses('note-1'), isEmpty);
  });

  test('concurrent note save does not overwrite independent study status', () async {
    await dao.upsert(note());

    await Future.wait([
      dao.updateStudyTaskStatus('note-1', 'task-1', 'learning'),
      dao.upsert(note(content: 'Autosaved updated note content')),
    ]);

    expect(await dao.getStudyTaskStatuses('note-1'), {'task-1': 'learning'});
    final stored = (await dao.getAllRows()).single;
    expect(stored['content'], 'Autosaved updated note content');
    expect(stored['checklistItems'], [
      {'id': 'task-1', 'text': 'Revise algebra', 'isDone': false},
    ]);
  });

  test('upgrades a schema-v2 database by creating the sidecar table', () async {
    final existing = await OrahDatabase.open(preferences);
    await existing.execute('DROP TABLE study_task_status');
    await existing.setVersion(2);
    await OrahDatabase.closeForTesting();

    final upgraded = await OrahDatabase.open(preferences);
    expect(await upgraded.getVersion(), 3);
    final table = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      ['study_task_status'],
    );
    expect(table, hasLength(1));
  });

  test('status updates reject missing tasks and invalid status values', () async {
    await dao.upsert(note());

    await expectLater(
      dao.updateStudyTaskStatus('note-1', 'missing-task', 'learning'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      dao.updateStudyTaskStatus('note-1', 'task-1', 'done'),
      throwsA(isA<FormatException>()),
    );
    expect(await dao.getStudyTaskStatuses('note-1'), isEmpty);
  });
}
