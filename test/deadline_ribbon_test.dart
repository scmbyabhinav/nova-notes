import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/core/widgets/deadline_ribbon.dart';

void main() {
  group('DeadlineRibbon', () {
    final now = DateTime(2026, 10, 27, 12);

    testWidgets('renders nothing when no deadline exists', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DeadlineRibbon(dueAt: null)),
        ),
      );

      expect(find.byType(DeadlineRibbon), findsOneWidget);
      expect(find.text('Due today'), findsNothing);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders overdue label and accessible semantic label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeadlineRibbon(
              dueAt: DateTime(2026, 10, 26),
              now: now,
            ),
          ),
        ),
      );

      expect(find.text('Overdue by 1 day'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Deadline missed: Overdue by 1 day'),
        findsOneWidget,
      );
    });

    testWidgets('renders due-tomorrow urgency label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeadlineRibbon(
              dueAt: DateTime(2026, 10, 28),
              now: now,
            ),
          ),
        ),
      );

      expect(find.text('Due tomorrow'), findsOneWidget);
      expect(find.bySemanticsLabel('Deadline: tomorrow'), findsOneWidget);
    });

    testWidgets('renders calm label for distant deadlines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeadlineRibbon(
              dueAt: DateTime(2026, 11, 26),
              now: now,
            ),
          ),
        ),
      );

      expect(find.text('Due in 30 days'), findsOneWidget);
      expect(find.bySemanticsLabel('Deadline: in 30 days'), findsOneWidget);
    });
  });
}
