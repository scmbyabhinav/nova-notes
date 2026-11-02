import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'support/isolated_sqlite_test_setup.dart';

void main() {
  setUpIsolatedSqliteTestDatabase();

  late LocalNoteRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalNoteRepository(await SharedPreferences.getInstance());
  });

  Note makeNote(String id) {
    final now = DateTime.utc(2026, 1, 1);
    return Note(
      id: id,
      title: 'Title $id',
      content: 'Content $id',
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('concurrent saves of different notes do not overwrite each other', () async {
    final notes = List.generate(12, (index) => makeNote('concurrent-$index'));

    await Future.wait(notes.map(repository.saveNote));

    final persisted = await repository.getNotes();
    expect(persisted, hasLength(notes.length));
    expect(persisted.map((note) => note.id).toSet(),
        equals(notes.map((note) => note.id).toSet()));

    for (final note in notes) {
      final stored = await repository.getNote(note.id);
      expect(stored, isNotNull);
      expect(stored!.title, note.title);
      expect(stored.content, note.content);
    }
  });

  test('concurrent save and delete operations leave a consistent snapshot', () async {
    final existing = makeNote('delete-me');
    await repository.saveNote(existing);

    await Future.wait([
      repository.saveNote(makeNote('keep-a')),
      repository.deleteNote(existing.id),
      repository.saveNote(makeNote('keep-b')),
    ]);

    final persisted = await repository.getNotes();
    expect(persisted.map((note) => note.id).toSet(), {'keep-a', 'keep-b'});
    expect(await repository.getNote(existing.id), isNull);
  });
  test('backup import and live save do not lose either set of notes', () async {
    final imported = makeNote('imported-note');
    final backup = {
      'format': 'nova_notes_backup',
      'version': 1,
      'exportedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'notes': [imported.toMap()],
    };

    await Future.wait([
      repository.importJson(jsonEncode(backup)),
      repository.saveNote(makeNote('live-note')),
    ]);

    final persisted = await repository.getNotes();
    expect(persisted.map((note) => note.id).toSet(),
        {'imported-note', 'live-note'});
  });

}
