import '../models/note.dart';

/// Calculates the user's current consecutive-day note creation streak.
///
/// A streak is active only when at least one non-trashed note was created
/// today. Multiple notes on the same local calendar day count as one day.
class StreakService {
  const StreakService();

  int calculateCurrentStreak(List<Note> notes, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    final createdDays = notes
        .where((note) => !note.isTrashed)
        .map((note) {
          final local = note.createdAt.toLocal();
          return DateTime(local.year, local.month, local.day);
        })
        .toSet();

    if (!createdDays.contains(todayKey)) return 0;

    var streak = 0;
    var day = todayKey;
    while (createdDays.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
