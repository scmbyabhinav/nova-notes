import 'package:flutter_test/flutter_test.dart';

import 'package:orah_notes/app.dart';

void main() {
  testWidgets('Orah launches', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Orah'), findsOneWidget);
    expect(find.text('Recent Notes'), findsOneWidget);
    expect(find.byTooltip('New note'), findsNothing);
  });
}
