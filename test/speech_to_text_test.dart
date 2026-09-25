import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
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

Future<({WidgetTester tester, _FakeVoiceSpeechService speech, LocalNoteRepository repository})>
    _pumpEditor(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final repository = LocalNoteRepository(preferences);
  final speech = _FakeVoiceSpeechService();

  await tester.pumpWidget(
    MaterialApp(
      home: NoteEditorScreen(
        repository: repository,
        speechService: speech,
      ),
    ),
  );
  await tester.pump();

  return (tester: tester, speech: speech, repository: repository);
}

void main() {
  testWidgets('voice input starts from the editor microphone control', (tester) async {
    final state = await _pumpEditor(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

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
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

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

    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    state.speech.emitFinal('a text note');
    await tester.pump();

    final notes = await state.repository.getNotes();
    expect(notes, isNotEmpty);
    expect(notes.single.type.name, 'text');
  });
}
