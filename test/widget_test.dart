import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Start writing...'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('long-press quick capture opens checklist options', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    final quickCaptureCenter = tester.getCenter(find.byType(FloatingActionButton));
    await tester.longPressAt(quickCaptureCenter);
    debugPrint('LONG PRESS AFTER GESTURE: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');
    await tester.pump();
    debugPrint('LONG PRESS AFTER PUMP 1: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint('LONG PRESS AFTER PUMP 300MS: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');
    await tester.pump();
    debugPrint('LONG PRESS AFTER PUMP 2: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');

    expect(find.text('Quick checklist'), findsOneWidget);
    await tester.tap(find.text('Quick checklist'));
    await tester.pump();
    debugPrint('CHECKLIST TAP AFTER PUMP 1: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');
    await tester.pump(const Duration(milliseconds: 300));
    debugPrint('CHECKLIST TAP AFTER PUMP 300MS: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');
    await tester.pump();
    debugPrint('CHECKLIST TAP AFTER PUMP 2: ${tester.allWidgets.map((w) => w.runtimeType).toList()}');

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Your checklist is empty'), findsOneWidget);
  });

  testWidgets('new note appears in home list immediately after editor closes', (tester) async {
    await tester.pumpWidget(const OrahApp());
    await tester.pump();

    await tester.tap(find.text('Quick capture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final titleField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Title',
    );
    await tester.enterText(titleField, 'Reactive note test');
    await tester.pump(const Duration(milliseconds: 700));

    await tester.pageBack();
    await tester.pump();

    expect(find.text('Reactive note test'), findsOneWidget);
  });
}
