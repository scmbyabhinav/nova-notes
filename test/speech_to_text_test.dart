import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:orah_notes/data/repositories/in_memory_note_repository.dart';
import 'package:orah_notes/screens/note_editor_screen.dart';
import 'package:orah_notes/services/speech_to_text_service.dart';

class _FakeVoiceSpeechService implements VoiceSpeechService {
  SpeechResultCallback? _onResult;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    required SpeechStatusCallback onStatus,
    required SpeechErrorCallback onError,
  }) async {
    return true;
  }

  @override
  Future<void> startListening({
    required SpeechResultCallback onResult,
  }) async {
    _onResult = onResult;
    _listening = true;
  }

  void emitPartial(String text) {
    _onResult?.call(text, false);
  }

  void emitFinal(String text) {
    _onResult?.call(text, true);
    _listening = false;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  @override
  void dispose() {
    _onResult = null;
    _listening = false;
  }
}

Future<({WidgetTester tester, _FakeVoiceSpeechService speech, InMemoryNoteRepository repository})>
    _pumpEditor(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final repository = InMemoryNoteRepository(preferences);
  final speech = _FakeVoiceSpeechService();

  await tester.pumpWidget(
    MaterialApp(
      home: NoteEditorScreen(
        repository: repository,
        speechService: speech,
        requestMicrophonePermission: () async => PermissionStatus.granted,
      ),
    ),
  );
  await tester.pump();

  return (tester: tester, speech: speech, repository: repository);
}

Future<void> _tapMicrophone(WidgetTester tester) async {
  final micButton = find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == 'Voice input',
  );
  if (micButton.evaluate().isEmpty) debugDumpApp();
  expect(micButton, findsOneWidget);
  final button = tester.widget<IconButton>(micButton);
  expect(button.onPressed, isNotNull, reason: 'Voice input must be enabled in the editor test.');
  // The toolbar is horizontally scrollable. Finish the scroll/layout update
  // before tapping so the hit-test coordinates match the button's new position.
  await tester.ensureVisible(micButton);
  // Finish the known 300 ms editor/toolbar entrance animation before the tap.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(micButton);
  await tester.pump();
}

void main() {
  setUpAll(() {
    // Treat missed taps as real test failures instead of allowing false greens.
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  testWidgets('voice input starts from the editor microphone control', (tester) async {
    final state = await _pumpEditor(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await _tapMicrophone(tester);

    expect(find.byTooltip('Stop voice input'), findsOneWidget);

    state.speech.emitPartial('remember the supplier');
    await tester.pump();

    expect(find.text('remember the supplier'), findsOneWidget);
  });

  testWidgets('final voice transcript is inserted and autosaved', (tester) async {
    final state = await _pumpEditor(tester);

    await tester.enterText(
      find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...'),
      'Existing note',
    );
    await _tapMicrophone(tester);

    state.speech.emitFinal('remember the supplier tomorrow');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final notes = await state.repository.getNotes();
    expect(notes, hasLength(1));
    expect(
      notes.single.content,
      'Existing note\nremember the supplier tomorrow',
    );
  });

  testWidgets('voice input does not change the note type', (tester) async {
    final state = await _pumpEditor(tester);

    await _tapMicrophone(tester);
    state.speech.emitFinal('a text note');
    await tester.pump();

    final notes = await state.repository.getNotes();
    expect(notes, isNotEmpty);
    expect(notes.single.type.name, 'text');
  });
}
