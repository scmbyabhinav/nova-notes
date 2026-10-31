import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/core/utils/note_tag_filter.dart';
import 'package:orah_notes/models/note.dart';

Note _note(String id, List<String> tags) => Note(
      id: id,
      title: id,
      content: '',
      type: NoteType.text,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      tags: tags,
    );

void main() {
  group('collectNoteTags', () {
    test('trims whitespace, removes blanks, deduplicates case-insensitively, and sorts', () {
      final tags = collectNoteTags([
        _note('1', [' Work ', 'home', 'work', '']),
        _note('2', ['Personal', ' HOME ']),
      ]);

      expect(tags, ['home', 'Personal', 'Work']);
    });

    test('returns no tags when notes have no non-empty tags', () {
      expect(collectNoteTags([_note('1', [' ', ''])]), isEmpty);
    });
  });

  group('filterNotesByTag', () {
    final notes = [
      _note('1', [' Work ']),
      _note('2', ['home']),
      _note('3', ['WORK', 'Personal']),
    ];

    test('returns every note when no tag is selected', () {
      expect(filterNotesByTag(notes, null).map((note) => note.id), ['1', '2', '3']);
    });

    test('matches tags case-insensitively and ignores stored whitespace', () {
      expect(filterNotesByTag(notes, 'work').map((note) => note.id), ['1', '3']);
    });

    test('returns no notes for an unknown tag', () {
      expect(filterNotesByTag(notes, 'missing'), isEmpty);
    });
  });
}
