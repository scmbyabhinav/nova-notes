import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  late LocalNoteRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await OrahDatabase.closeForTesting();
  });

  Future<LocalNoteRepository> createRepository() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalNoteRepository(preferences);
  }

  Note makeNote(String id, {bool isTrashed = false}) {
    final now = DateTime.now();
    return Note(
      id: id,
      title: 'Stream regression',
      content: 'Persisted note',
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      isTrashed: isTrashed,
    );
  }

  test('saveNote publishes the persisted note to watchNotes immediately', () async {
    repository = await createRepository();
    final note = makeNote('save-stream-test');
    final iterator = StreamIterator<List<Note>>(repository.watchNotes());
    addTearDown(iterator.cancel);

    // Keep one subscription for both the initial snapshot and the live update.
    // Re-subscribing can race a new initial read against the write under test.
    expect(await iterator.moveNext(), isTrue);
    await repository.saveNote(note);

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    expect(iterator.current.single.id, note.id);
    expect(iterator.current.single.title, note.title);
    expect(iterator.current.single.isTrashed, isFalse);
  });

  test('deleteNote publishes the updated list to watchNotes immediately', () async {
    repository = await createRepository();
    final note = makeNote('delete-stream-test');
    await repository.saveNote(note);

    final iterator = StreamIterator<List<Note>>(repository.watchNotes());
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.map((item) => item.id), contains(note.id));

    await repository.deleteNote(note.id);

    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, isEmpty);
  });

  test('saveNote publishes trash/restore state changes immediately', () async {
    repository = await createRepository();
    final note = makeNote('trash-restore-stream-test');
    await repository.saveNote(note);

    final iterator = StreamIterator<List<Note>>(repository.watchNotes());
    addTearDown(iterator.cancel);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.single.isTrashed, isFalse);

    await repository.saveNote(note.copyWith(
      isTrashed: true,
      updatedAt: DateTime.now(),
    ));
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    expect(iterator.current.single.isTrashed, isTrue);

    await repository.saveNote(note.copyWith(
      isTrashed: false,
      updatedAt: DateTime.now(),
    ));
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    expect(iterator.current.single.isTrashed, isFalse);
  });
}
