import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  late LocalNoteRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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

    // The stream may seed from storage or deliver the live write first. Wait
    // for the event that proves persistence instead of assuming a fixed event
    // count and accidentally skipping the update.
    final event = repository.watchNotes().firstWhere(
      (notes) => notes.length == 1 && notes.single.id == note.id,
    );

    await repository.saveNote(note);
    final notes = await event;
    expect(notes.single.title, note.title);
    expect(notes.single.isTrashed, isFalse);
  });

  test('deleteNote publishes the updated list to watchNotes immediately', () async {
    repository = await createRepository();
    final note = makeNote('delete-stream-test');
    await repository.saveNote(note);

    final event = repository.watchNotes().firstWhere((notes) => notes.isEmpty);
    await repository.deleteNote(note.id);
    expect(await event, isEmpty);
  });

  test('saveNote publishes trash/restore state changes immediately', () async {
    repository = await createRepository();
    final note = makeNote('trash-restore-stream-test');
    await repository.saveNote(note);

    final trashEvent = repository.watchNotes().firstWhere(
      (notes) => notes.length == 1 && notes.single.isTrashed,
    );
    await repository.saveNote(
      note.copyWith(isTrashed: true, updatedAt: DateTime.now()),
    );
    expect((await trashEvent).single.isTrashed, isTrue);

    final restoreEvent = repository.watchNotes().firstWhere(
      (notes) => notes.length == 1 && !notes.single.isTrashed,
    );
    await repository.saveNote(
      note.copyWith(isTrashed: false, updatedAt: DateTime.now()),
    );
    expect((await restoreEvent).single.isTrashed, isFalse);
  });
}
