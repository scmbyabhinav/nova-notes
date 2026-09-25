import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/app.dart';
import 'package:orah_notes/services/speech_to_text_service.dart';
import 'package:orah_notes/screens/orah_templates_screen.dart';

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

    await tester.tap(find.byTooltip('Quick capture. Long-press for checklist and quick options.'));
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

    await tester.tap(find.byTooltip('Quick capture. Long-press for checklist and quick options.'));
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

  testWidgets('voice FAB invokes speech service and shows one-time hint', (tester) async {
    final speech = _FakeSpeechService();
    await tester.pumpWidget(OrahApp(speechService: speech));
    await tester.pump();

    await tester.tap(find.byTooltip('Quick capture. Long-press for checklist and quick options.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tap the mic to speak your note'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

    expect(speech.startCount, 1);
    expect(find.text('Hello from voice'), findsOneWidget);

    await tester.pageBack();
    await tester.pump();

    await tester.tap(find.byTooltip('Quick capture. Long-press for checklist and quick options.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tap the mic to speak your note'), findsNothing);
  });

  testWidgets('templates list all starter templates and inserts selected content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrahTemplatesScreen()));
    await tester.pumpAndSettle();

    for (final title in [
      'Meeting Notes', 'Daily Plan', 'Shopping List', 'Project Brief',
      'Travel Plan', 'Travel Diary', 'Journal', 'Recipe', 'Book Notes',
      'Expense Tracker', 'Workout Log',
    ]) {
      expect(find.text(title), findsOneWidget);
    }

    await tester.tap(find.text('Recipe'));
    await tester.pumpAndSettle();

    expect(find.text('Ingredients'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });


}


class _FakeSpeechService implements VoiceSpeechService {
  int startCount = 0;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) async => true;

  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
  }) async {
    startCount++;
    _isListening = true;
    onResult('Hello from voice', true);
    _isListening = false;
  }

  @override
  Future<void> stopListening() async => _isListening = false;

  @override
  Future<void> cancel() async => _isListening = false;

  @override
  void dispose() {}
}
