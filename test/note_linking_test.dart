import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  group('Note serialization', () {
    test('persists linked note IDs and per-note font selection', () {
      final createdAt = DateTime(2026, 10, 24, 10);
      final note = Note(
        id: 'note-a',
        title: 'Meeting notes',
        content: 'Discuss launch',
        type: NoteType.text,
        createdAt: createdAt,
        updatedAt: createdAt,
        linkedNoteIds: const ['note-b', 'note-c'],
        fontFamily: 'Lora',
      );

      final restored = Note.fromMap(note.toMap());

      expect(restored.linkedNoteIds, ['note-b', 'note-c']);
      expect(restored.fontFamily, 'Lora');
    });

    test('loads older notes without linked note IDs', () {
      final createdAt = DateTime(2026, 10, 24, 10);
      final legacy = Note(
        id: 'legacy-note',
        title: 'Older note',
        content: 'No link metadata yet',
        type: NoteType.text,
        createdAt: createdAt,
        updatedAt: createdAt,
      ).toMap()
        ..remove('linkedNoteIds');

      final restored = Note.fromMap(legacy);

      expect(restored.linkedNoteIds, isEmpty);
    });
  });
}
