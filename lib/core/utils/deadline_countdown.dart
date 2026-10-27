/// Local-calendar countdown values for note and checklist deadlines.
///
/// This utility deliberately has no Flutter, database, or serialization
/// dependency. UI code can map [DeadlineCountdownState] to theme colors.
enum DeadlineCountdownState { overdue, dueSoon, upcoming }

class DeadlineCountdownResult {
  const DeadlineCountdownResult({
    required this.label,
    required this.semanticLabel,
    required this.state,
    required this.daysUntilDue,
  });

  final String label;
  final String semanticLabel;
  final DeadlineCountdownState state;

  /// Negative values are overdue; zero means due today.
  final int daysUntilDue;
}

class DeadlineCountdown {
  const DeadlineCountdown._();

  /// Computes a deadline label using local calendar dates.
  ///
  /// Returns null when no deadline is present. [now] can be supplied for
  /// deterministic tests. Date-only arithmetic is performed in UTC after
  /// extracting local year/month/day, so daylight-saving transitions cannot
  /// turn a calendar day into a 23- or 25-hour countdown.
  static DeadlineCountdownResult? compute(
    DateTime? dueAt, {
    DateTime? now,
  }) {
    if (dueAt == null) return null;

    final localNow = (now ?? DateTime.now()).toLocal();
    final localDueAt = dueAt.toLocal();

    final today = DateTime.utc(localNow.year, localNow.month, localNow.day);
    final dueDay = DateTime.utc(
      localDueAt.year,
      localDueAt.month,
      localDueAt.day,
    );
    final days = dueDay.difference(today).inDays;

    final DeadlineCountdownState state;
    final String label;
    final String semanticLabel;

    if (days < 0) {
      state = DeadlineCountdownState.overdue;
      final overdueDays = -days;
      label = overdueDays == 1
          ? 'Overdue by 1 day'
          : 'Overdue by $overdueDays days';
      semanticLabel = 'Deadline missed: $label';
    } else if (days == 0) {
      state = DeadlineCountdownState.dueSoon;
      label = 'Due today';
      semanticLabel = 'Deadline: today';
    } else if (days == 1) {
      state = DeadlineCountdownState.dueSoon;
      label = 'Due tomorrow';
      semanticLabel = 'Deadline: tomorrow';
    } else if (days <= 3) {
      state = DeadlineCountdownState.dueSoon;
      label = 'Due in $days days';
      semanticLabel = 'Deadline: in $days days';
    } else {
      state = DeadlineCountdownState.upcoming;
      label = 'Due in $days days';
      semanticLabel = 'Deadline: in $days days';
    }

    return DeadlineCountdownResult(
      label: label,
      semanticLabel: semanticLabel,
      state: state,
      daysUntilDue: days,
    );
  }
}
