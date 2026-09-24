import 'package:flutter_test/flutter_test.dart';

import 'package:orah_notes/app.dart';

void main() {
  testWidgets('Orah launches', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    expect(find.text('Orah'), findsOneWidget);
    expect(find.byTooltip('New note'), findsNothing);
  });

  testWidgets('quick checklist opens after the capture sheet closes', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick capture'));
    await tester.pumpAndSettle();

    expect(find.text('Quick checklist'), findsOneWidget);
    await tester.tap(find.text('Quick checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Your checklist is empty'), findsOneWidget);
  });
}
