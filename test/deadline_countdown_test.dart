import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/core/utils/deadline_countdown.dart';
import 'package:orah_notes/models/note.dart';

void main() {
  group('DeadlineCountdown.compute', () {
    final now = DateTime(2026, 10, 27, 14, 30);

    test('returns null when no deadline exists', () {
      expect(DeadlineCountdown.compute(null, now: now), isNull);
    });

    test('labels a deadline earlier today as due today', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 27, 8),
        now: now,
      );

      expect(result?.label, 'Due today');
      expect(result?.semanticLabel, 'Deadline: today');
      expect(result?.state, DeadlineCountdownState.dueSoon);
      expect(result?.daysUntilDue, 0);
    });

    test('labels tomorrow distinctly', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 28, 23, 59),
        now: now,
      );

      expect(result?.label, 'Due tomorrow');
      expect(result?.semanticLabel, 'Deadline: tomorrow');
      expect(result?.state, DeadlineCountdownState.dueSoon);
    });

    test('labels an overdue deadline by one day', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 26, 23, 59),
        now: now,
      );

      expect(result?.label, 'Overdue by 1 day');
      expect(result?.semanticLabel, 'Deadline missed: Overdue by 1 day');
      expect(result?.state, DeadlineCountdownState.overdue);
      expect(result?.daysUntilDue, -1);
    });

    test('uses plural wording for multiple overdue days', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 24),
        now: now,
      );

      expect(result?.label, 'Overdue by 3 days');
      expect(result?.daysUntilDue, -3);
    });

    test('three-day boundary remains due soon', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 30),
        now: now,
      );

      expect(result?.label, 'Due in 3 days');
      expect(result?.state, DeadlineCountdownState.dueSoon);
    });

    test('four-day boundary uses upcoming state', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 10, 31),
        now: now,
      );

      expect(result?.label, 'Due in 4 days');
      expect(result?.state, DeadlineCountdownState.upcoming);
    });

    test('seven-day boundary is upcoming', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 11, 3),
        now: now,
      );

      expect(result?.label, 'Due in 7 days');
      expect(result?.state, DeadlineCountdownState.upcoming);
    });

    test('distant deadlines remain visible with a calm state', () {
      final result = DeadlineCountdown.compute(
        DateTime(2026, 11, 26),
        now: now,
      );

      expect(result?.label, 'Due in 30 days');
      expect(result?.state, DeadlineCountdownState.upcoming);
    });

    test('calendar-day arithmetic handles leap day', () {
      final result = DeadlineCountdown.compute(
        DateTime(2024, 2, 28),
        now: DateTime(2024, 2, 26, 22),
      );

      expect(result?.label, 'Due in 2 days');
      expect(result?.daysUntilDue, 2);
    });

    test('calendar-day arithmetic handles year boundaries', () {
      final result = DeadlineCountdown.compute(
        DateTime(2025, 1, 1),
        now: DateTime(2024, 12, 31, 23, 59),
      );

      expect(result?.label, 'Due tomorrow');
    });

    test('invalid serialized deadline safely deserializes to null', () {
      final note = Note.fromMap({
        'id': 'note-1',
        'title': 'Test',
        'content': '',
        'type': 'text',
        'createdAt': '2026-10-01T10:00:00',
        'updatedAt': '2026-10-01T10:00:00',
        'dueAt': 'not-a-date',
      });

      expect(note.dueAt, isNull);
      expect(DeadlineCountdown.compute(note.dueAt, now: now), isNull);
    });
  });
}
