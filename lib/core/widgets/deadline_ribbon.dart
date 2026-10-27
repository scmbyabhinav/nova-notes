import 'package:flutter/material.dart';

import '../utils/deadline_countdown.dart';

/// A compact, accessible, read-only deadline label for a note card.
class DeadlineRibbon extends StatelessWidget {
  const DeadlineRibbon({
    super.key,
    required this.dueAt,
    this.now,
  });

  final DateTime? dueAt;

  /// Optional reference time for deterministic widget tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final result = DeadlineCountdown.compute(dueAt, now: now);
    if (result == null) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final Color background;
    final Color foreground;

    switch (result.state) {
      case DeadlineCountdownState.overdue:
        background = colors.error;
        foreground = colors.onError;
      case DeadlineCountdownState.dueSoon:
        background = Colors.amber.shade700;
        foreground = Colors.black;
      case DeadlineCountdownState.upcoming:
        background = colors.primaryContainer.withValues(alpha: 0.72);
        foreground = colors.onPrimaryContainer;
    }

    return Semantics(
      label: result.semanticLabel,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: double.infinity),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              result.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
