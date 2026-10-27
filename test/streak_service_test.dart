import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/services/streak_service.dart';

void main() {
  Note noteAt(String id, DateTime createdAt, {bool isTrashed = false, String? mood}) {
    return Note(
      id: id,
      title: 'Test $id',
      content: 'Content',
      type: NoteType.text,
      createdAt: createdAt,
      updatedAt: createdAt,
      isTrashed: isTrashed,
      mood: mood,
    );
  }

  group('Note mood persistence', () {
    test('legacy note maps without mood remain valid', () {
      final createdAt = DateTime(2026, 1, 1);
      final legacy = <String, dynamic>{
        'id': 'legacy',
        'title': 'Legacy note',
        'content': 'Still works',
        'type': 'text',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': createdAt.toIso8601String(),
      };

      final note = Note.fromMap(legacy);
      expect(note.mood, isNull);
      expect(Note.fromMap(note.toMap()).mood, isNull);
    });

    test('selected mood round-trips and can be cleared', () {
      final note = noteAt('mood', DateTime(2026, 1, 1), mood: 'happy');
      expect(Note.fromMap(note.toMap()).mood, 'happy');
      expect(note.copyWith(mood: 'sad').mood, 'sad');
      expect(note.copyWith(clearMood: true).mood, isNull);
    });
  });

  group('StreakService', () {
    const service = StreakService();

    test('counts consecutive local calendar days ending today', () {
      final today = DateTime(2026, 10, 3, 12);
      final notes = [
        noteAt('today', DateTime(2026, 10, 3, 9)),
        noteAt('today-duplicate', DateTime(2026, 10, 3, 10)),
        noteAt('yesterday', DateTime(2026, 10, 2, 22)),
        noteAt('two-days-ago', DateTime(2026, 10, 1, 8)),
        noteAt('gap', DateTime(2026, 9, 29, 8)),
      ];

      expect(service.calculateCurrentStreak(notes, now: today), 3);
    });

    test('returns zero if no note was created today', () {
      final notes = [noteAt('yesterday', DateTime(2026, 10, 2, 8))];
      expect(
        service.calculateCurrentStreak(notes, now: DateTime(2026, 10, 3, 12)),
        0,
      );
    });

    test('ignores trashed notes when counting a streak', () {
      final notes = [
        noteAt('today', DateTime(2026, 10, 3, 8)),
        noteAt('trashed-yesterday', DateTime(2026, 10, 2, 8), isTrashed: true),
      ];
      expect(
        service.calculateCurrentStreak(notes, now: DateTime(2026, 10, 3, 12)),
        1,
      );
    });
  });
}
