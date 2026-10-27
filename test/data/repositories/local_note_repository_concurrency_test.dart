import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('concurrent note saves preserve both notes', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalNoteRepository(preferences);
    final now = DateTime.now();

    Note makeNote(String id, String title) => Note(
          id: id,
          title: title,
          content: 'content for $title',
          type: NoteType.text,
          createdAt: now,
          updatedAt: now,
        );

    await Future.wait([
      repository.saveNote(makeNote('concurrent-a', 'First note')),
      repository.saveNote(makeNote('concurrent-b', 'Second note')),
    ]);

    final saved = await repository.getNotes();
    expect(saved.map((note) => note.id).toSet(),
        containsAll({'concurrent-a', 'concurrent-b'}));
  });
}
