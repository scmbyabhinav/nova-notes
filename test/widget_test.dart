import 'package:flutter_test/flutter_test.dart';

import 'package:nova_notes/app.dart';

void main() {
  testWidgets('NOVA Notes launches', (tester) async {
    await tester.pumpWidget(const NovaNotesApp());
    await tester.pump();

    expect(find.text('NOVA'), findsOneWidget);
    expect(find.text('Recent Notes'), findsOneWidget);
    expect(find.byTooltip('New note'), findsNothing);
  });
}
