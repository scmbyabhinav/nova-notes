import 'package:flutter_test/flutter_test.dart';

import 'package:orah_notes/app.dart';

void main() {
  testWidgets('Orah launches', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    expect(find.text('Orah'), findsOneWidget);
    expect(find.byTooltip('New note'), findsNothing);
  });

  testWidgets('quick capture opens a note immediately', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    await tester.tap(find.text('Quick capture'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Start writing...'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('long-press quick capture opens checklist options', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    await tester.longPress(find.text('Quick capture'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Quick checklist'), findsOneWidget);
    await tester.tap(find.text('Quick checklist'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Your checklist is empty'), findsOneWidget);
  });
}
