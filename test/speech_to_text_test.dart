import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/orah_test_diagnostics.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:orah_notes/data/repositories/note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/models/search_filter.dart';
import 'package:orah_notes/screens/note_editor_screen.dart';
import 'package:orah_notes/services/speech_to_text_service.dart';

class _MemoryNoteRepository implements NoteRepository {
  final List<Note> _notes = [];
  final StreamController<List<Note>> _controller =
      StreamController<List<Note>>.broadcast();

  @override
  Stream<List<Note>> watchNotes() => _controller.stream;

  @override
  Future<List<Note>> getNotes() async => List<Note>.unmodifiable(_notes);

  @override
  Future<Note?> getNote(String id) async {
    for (final note in _notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<void> saveNote(Note note) async {
    final index = _notes.indexWhere((item) => item.id == note.id);
    if (index == -1) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _controller.add(List<Note>.unmodifiable(_notes));
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((note) => note.id == id);
    _controller.add(List<Note>.unmodifiable(_notes));
  }

  @override
  Future<List<Note>> searchNotes(String query) => search(query);

  @override
  Future<List<Note>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
  }) async {
    final normalized = query.trim().toLowerCase();
    return _notes.where((note) {
      if (filter.favoritesOnly && !note.isFavorite) return false;
      if (filter.pinnedOnly && !note.isPinned) return false;
      if (filter.archivedOnly && !note.isArchived) return false;
      if (!filter.archivedOnly && note.isArchived) return false;
      if (filter.folderId != null && note.folderId != filter.folderId) return false;
      if (filter.noteType != null && note.type != filter.noteType) return false;
      if (normalized.isEmpty) return true;
      return '${note.title} ${note.content}'.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<void> dispose() => _controller.close();
}

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

Future<({WidgetTester tester, _FakeVoiceSpeechService speech, _MemoryNoteRepository repository})>
    _pumpEditor(WidgetTester tester) async {
  final repository = _MemoryNoteRepository();
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

void main() {
  testWidgets('voice input starts from the editor microphone control', (tester) async {
    final state = await _pumpEditor(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    expect(find.byTooltip('Stop voice input'), findsOneWidget);

    state.speech.emitPartial('remember the supplier');
    await tester.pump();

    expect(find.text('remember the supplier'), findsOneWidget);
  });

  testWidgets('final voice transcript is inserted and autosaved', (tester) async {
    OrahTestDiagnostics.setPhase('body');
    OrahTestDiagnostics.log('VOICE_TEST body ENTER');
    try {
    OrahTestDiagnostics.log('VOICE checkpoint ENTER: _pumpEditor');
    final state = await _pumpEditor(tester);
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: _pumpEditor');

    OrahTestDiagnostics.log('VOICE checkpoint ENTER: enterText');
    await tester.enterText(
      find.byWidgetPredicate((widget) => widget is TextField && widget.decoration?.hintText == 'Start writing...'),
      'Existing note',
    );
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: enterText');
    OrahTestDiagnostics.log('VOICE checkpoint ENTER: microphone tap');
    await tester.tap(find.byType(FloatingActionButton));
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: microphone tap');
    await tester.pump();
    // The FAB handler first awaits SharedPreferences before it starts the
    // speech service. Do not emit a fake transcript until the editor has
    // actually subscribed to the service result callback.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Stop voice input'), findsOneWidget);
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: speech listener ready');
    OrahTestDiagnostics.log('VOICE checkpoint ENTER: emit final transcript');
    state.speech.emitFinal('remember the supplier tomorrow');
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: emit final transcript');
    await tester.pump();
    final editorField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField &&
            widget.decoration?.hintText == 'Start writing...',
      ),
    );
    expect(
      editorField.controller!.text,
      'Existing note\\nremember the supplier tomorrow',
      reason: 'The final transcript must reach the editor before autosave.',
    );
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: transcript visible in editor');
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: pump after final transcript');
    await tester.pump(const Duration(milliseconds: 700));
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: 700ms autosave pump');
    OrahTestDiagnostics.log('VOICE checkpoint ENTER: wait for repository operations to drain');
    await tester.pump();
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: repository operations drained');
    OrahTestDiagnostics.log('VOICE checkpoint ENTER: repository.getNotes');
    final notes = await state.repository.getNotes();
    OrahTestDiagnostics.log('VOICE checkpoint EXIT: repository.getNotes count=${notes.length}');
    expect(notes, hasLength(1));
    expect(
      notes.single.content,
      'Existing note\nremember the supplier tomorrow',
    );
    } finally {
      OrahTestDiagnostics.log('VOICE_TEST body EXIT from finally');
    }
  });

  testWidgets('voice input does not change the note type', (tester) async {
    final state = await _pumpEditor(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    state.speech.emitFinal('a text note');
    await tester.pump();

    final notes = await state.repository.getNotes();
    expect(notes, isNotEmpty);
    expect(notes.single.type.name, 'text');
  });
}
