import 'package:flutter_test/flutter_test.dart';

import 'package:orah_notes/app.dart';

void main() {
  testWidgets('Orah launches', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    expect(find.text('Orah'), findsOneWidget);
    expect(find.byType(OrahApp), findsOneWidget);
  });
}
