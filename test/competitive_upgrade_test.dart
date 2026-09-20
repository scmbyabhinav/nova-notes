import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  test('local search ranks title matches ahead of content matches', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalNoteRepository(preferences);

    final olderContentMatch = Note(
      id: '1',
      title: 'Weekly notes',
      content: 'Project NOVA meeting details',
      type: NoteType.text,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
    );

    final newerTitleMatch = Note(
      id: '2',
      title: 'NOVA project',
      content: 'General notes',
      type: NoteType.text,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await repository.saveNote(olderContentMatch);
    await repository.saveNote(newerTitleMatch);

    final results = await repository.search('NOVA');

    expect(results.map((note) => note.id).toList(), ['2', '1']);
  });
}
