import 'package:flutter_test/flutter_test.dart';
import 'package:nova_notes/models/note.dart';

void main() {
  group('linked notes', () {
    final now = DateTime.utc(2026, 11, 1, 12);

    test('round-trips linked note IDs through serialization', () {
      final note = Note(
        id: 'note-a',
        title: 'Planning',
        content: 'Project plan',
        type: NoteType.text,
        createdAt: now,
        updatedAt: now,
        linkedNoteIds: const ['note-b', 'note-c'],
      );

      final restored = Note.fromMap(note.toMap());

      expect(restored.linkedNoteIds, ['note-b', 'note-c']);
      expect(restored.id, note.id);
      expect(restored.content, note.content);
    });

    test('older records without linkedNoteIds remain compatible', () {
      final note = Note.fromMap({
        'id': 'legacy-note',
        'title': 'Legacy',
        'content': 'Existing note',
        'type': 'text',
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });

      expect(note.linkedNoteIds, isEmpty);
    });

    test('copyWith preserves links unless replaced', () {
      final note = Note(
        id: 'note-a',
        title: 'Planning',
        content: '',
        type: NoteType.text,
        createdAt: now,
        updatedAt: now,
        linkedNoteIds: const ['note-b'],
      );

      expect(note.copyWith(title: 'Renamed').linkedNoteIds, ['note-b']);
      expect(note.copyWith(linkedNoteIds: const ['note-c']).linkedNoteIds, ['note-c']);
    });
  });
}
