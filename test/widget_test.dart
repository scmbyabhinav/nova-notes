import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/orah_test_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:orah_notes/app.dart';
import 'package:orah_notes/core/widgets/orah_wordmark.dart';
import 'package:orah_notes/services/speech_to_text_service.dart';
import 'package:orah_notes/screens/orah_templates_screen.dart';
import 'package:orah_notes/screens/orah_registration_screen.dart' as registration;

Future<void> _closeEditor(WidgetTester tester) async {
  final backButton = find.byTooltip('Back');
  if (backButton.evaluate().isEmpty) return;

  // Exercise the same awaited close path users take, rather than forcing a
  // Navigator pop that can dispose the editor while autosave is still active.
  await tester.tap(backButton);
  for (var attempt = 0; attempt < 50; attempt++) {
    // Database/plugin futures use real asynchronous I/O. Advancing only fake
    // widget time can exhaust this loop before SQLite has finished opening.
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    if (backButton.evaluate().isEmpty) return;
  }
  fail('Editor did not finish saving and close within five seconds of real time.');
}

void main() {
  // SQLite FFI initialization and per-test database isolation are provided by
  // test/flutter_test_config.dart. Keep only this file's preference mock here.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('registration form requires name and email fields', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: registration.OrahRegistrationScreen(onRegistered: (_) {}),
    ));

    expect(find.text('Welcome to Orah'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Register & continue'), findsOneWidget);
  });

  testWidgets('registration rejects malformed email addresses', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: registration.OrahRegistrationScreen(onRegistered: (_) {}),
    ));

    await tester.enterText(find.byType(TextFormField).at(0), 'Ravi Kumar');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.tap(find.text('Register & continue'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('Orah launches', (tester) async {
    await tester.pumpWidget(const OrahApp(
      skipRegistrationForTesting: true,
      skipHomeRepositoryLoadForTesting: true,
    ));
    await tester.pump();

    // The brand is rendered as a gradient OrahWordmark, not a plain Text('Orah').
    expect(find.byType(OrahWordmark), findsOneWidget);
    expect(find.byTooltip('New note'), findsNothing);
  });

  testWidgets('quick capture opens a note immediately', (tester) async {
    // Keep the hint tooltip/auto-hide timer out of this navigation-only test.
    SharedPreferences.setMockInitialValues({
      'orah_quick_capture_hint_dismissed': true,
      'orah_voice_hint_shown': true,
    });
    OrahTestDiagnostics.setPhase('body');
    OrahTestDiagnostics.log('testWidgets callback ENTER: quick capture opens a note immediately');
    try {
    // Isolate capture/navigation from Home startup and post-editor repository I/O.
    await tester.pumpWidget(const OrahApp(
      skipRegistrationForTesting: true,
      skipHomeRepositoryLoadForTesting: true,
    ));
    print('[ORAH-DIAG] TEST: pumpWidget returned');
    await tester.pump();
    print('[ORAH-DIAG] TEST: initial pump returned');

    final quickCaptureFab = find.byTooltip(
      'Quick capture. Long-press for checklist and quick options.',
    );
    print('[ORAH-DIAG] TEST: tapping quick capture');
    await tester.tap(quickCaptureFab);
    OrahTestDiagnostics.log('Quick Capture interaction completion: tester.tap returned');
    await tester.pump();
    print('[ORAH-DIAG] TEST: post-tap pump returned');
    await tester.pump(const Duration(milliseconds: 300));
    print('[ORAH-DIAG] TEST: 300ms pump returned');
    await tester.pump();
    print('[ORAH-DIAG] TEST: final pump returned');

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Start writing...'), findsOneWidget);
    OrahTestDiagnostics.log('Quick Capture interaction completion: editor assertions passed');

    await _closeEditor(tester);
    print('[ORAH-DIAG] TEST: awaited editor close returned');
    OrahTestDiagnostics.log('test body final pump returned');
    } finally {
      OrahTestDiagnostics.log('testWidgets callback EXIT from finally: quick capture opens a note immediately');
    }
  });

  testWidgets('long-press quick capture opens checklist options', (tester) async {
    OrahTestDiagnostics.setPhase('body');
    OrahTestDiagnostics.log('LONG_PRESS_TEST body ENTER');
    try {
    OrahTestDiagnostics.log('LONG_PRESS checkpoint ENTER: pumpWidget');
    await tester.pumpWidget(const OrahApp(skipRegistrationForTesting: true));
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: pumpWidget');
    await tester.pump();
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: initial pump');

    final quickCaptureFab = find.byTooltip(
      'Quick capture. Long-press for checklist and quick options.',
    );
    final quickCaptureCenter = tester.getCenter(quickCaptureFab);
    OrahTestDiagnostics.log('LONG_PRESS checkpoint ENTER: longPressAt');
    await tester.longPressAt(quickCaptureCenter);
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: longPressAt');
    await tester.pump();
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: pump after longPressAt');
    await tester.pump(const Duration(milliseconds: 300));
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: 300ms pump after longPressAt');
    await tester.pump();
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: second pump after longPressAt');

    expect(find.text('Quick checklist'), findsOneWidget);
    OrahTestDiagnostics.log('LONG_PRESS checkpoint ENTER: tap Quick checklist');
    await tester.tap(find.text('Quick checklist'));
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: tap Quick checklist');
    await tester.pump();
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: pump after checklist tap');
    await tester.pump(const Duration(milliseconds: 300));
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: 300ms pump after checklist tap');
    await tester.pump();
    OrahTestDiagnostics.log('LONG_PRESS checkpoint EXIT: second pump after checklist tap');

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Your checklist is empty'), findsOneWidget);
    await _closeEditor(tester);
    } finally {
      OrahTestDiagnostics.log('LONG_PRESS_TEST body EXIT from finally');
    }
  });

  testWidgets('new note appears in home list immediately after editor closes', (tester) async {
    await tester.pumpWidget(const OrahApp(skipRegistrationForTesting: true));
    await tester.pump();

    final quickCaptureFab = find.byTooltip(
      'Quick capture. Long-press for checklist and quick options.',
    );
    await tester.tap(quickCaptureFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final titleField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Title',
    );
    await tester.enterText(titleField, 'Reactive note test');
    await tester.pump(const Duration(milliseconds: 700));

    await _closeEditor(tester);

    expect(find.text('Reactive note test'), findsAtLeastNWidgets(1));
  });

  testWidgets('voice FAB invokes speech service and shows one-time hint', (tester) async {
    final speech = _FakeSpeechService();
    await tester.pumpWidget(OrahApp(speechService: speech, requestMicrophonePermission: () async => PermissionStatus.granted, skipRegistrationForTesting: true));
    await tester.pump();

    final quickCaptureFab = find.byTooltip(
      'Quick capture. Long-press for checklist and quick options.',
    );
    await tester.tap(quickCaptureFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    final voiceHint = find.byWidgetPredicate(
      (widget) => widget is Tooltip && widget.message == 'Tap the mic to speak your note',
    );
    expect(voiceHint, findsOneWidget);
    tester.state<TooltipState>(voiceHint).ensureTooltipVisible();
    await tester.pump();
    expect(find.text('Tap the mic to speak your note'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(speech.startCount, 1);
    expect(find.text('Hello from voice'), findsAtLeastNWidgets(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('orah_voice_hint_shown'), isTrue);
    await _closeEditor(tester);
  });

  testWidgets('templates list all starter templates and inserts selected content', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OrahTemplatesScreen()));
    await tester.pumpAndSettle();

    for (final title in [
      'Meeting Notes', 'Daily Plan', 'Shopping List', 'Project Brief',
      'Travel Plan', 'Travel Diary', 'Journal', 'Recipe', 'Book Notes',
      'Expense Tracker', 'Workout Log',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }

    await tester.scrollUntilVisible(
      find.text('Recipe'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Recipe'));
    await tester.pumpAndSettle();

    final contentField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...',
    );
    expect(contentField, findsOneWidget);
    final content = tester.widget<TextField>(contentField).controller?.text ?? '';
    expect(content, contains('Ingredients'));
    expect(content, contains('Steps'));
    expect(content, contains('Notes'));
    await _closeEditor(tester);
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
