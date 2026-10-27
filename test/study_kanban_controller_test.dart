import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/controllers/study_kanban_controller.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/models/search_filter.dart';
import 'package:orah_notes/data/repositories/note_repository.dart';

class _NoNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Study Kanban controller tests must not use the network.');
  }
}

class _FakeNoteRepository implements NoteRepository {
  _FakeNoteRepository(this.notes);
  final List<Note> notes;
  Object? error;

  @override
  Future<List<Note>> getNotes() async {
    if (error != null) throw error!;
    return notes;
  }

  @override
  Stream<List<Note>> watchNotes() => Stream.value(notes);
  @override
  Future<Note?> getNote(String id) async =>
      notes.where((note) => note.id == id).firstOrNull;
  @override
  Future<void> saveNote(Note note) async {}
  @override
  Future<void> deleteNote(String id) async {}
  @override
  Future<List<Note>> searchNotes(String query) async => notes;
  @override
  Future<List<Note>> search(String query, {SearchFilter filter = const SearchFilter()}) async => notes;
}

Note _note({
  String id = 'note-1',
  String title = 'Biology',
  List<ChecklistItem> items = const [],
}) => Note(
      id: id,
      title: title,
      content: 'Unchanged note body',
      type: NoteType.checklist,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      checklistItems: items,
    );

void main() {
  late HttpOverrides? previousOverrides;

  setUp(() {
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _NoNetworkHttpOverrides();
  });

  tearDown(() {
    HttpOverrides.global = previousOverrides;
  });

  test('maps checklist items and preserves checked state independently', () async {
    final repository = _FakeNoteRepository([
      _note(items: const [
        ChecklistItem(id: 'task-1', text: ' Revise cells ', isDone: true),
        ChecklistItem(id: 'task-2', text: 'Study genetics'),
      ]),
    ]);
    final controller = StudyKanbanController(
      repository: repository,
      loadStatuses: (noteId) async => {'task-1': 'mastered'},
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.hasError, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.tasks, hasLength(2));
    expect(controller.tasks[0].noteId, 'note-1');
    expect(controller.tasks[0].taskId, 'task-1');
    expect(controller.tasks[0].taskText, 'Revise cells');
    expect(controller.tasks[0].noteTitle, 'Biology');
    expect(controller.tasks[0].studyStatus, 'mastered');
    expect(controller.tasks[0].isChecked, isTrue);
    expect(controller.tasks[1].studyStatus, 'new');
    expect(controller.tasks[1].isChecked, isFalse);
  });

  test('defaults missing or invalid sidecar statuses to new', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [
          ChecklistItem(id: 'task-1', text: 'Read chapter'),
          ChecklistItem(id: 'task-2', text: 'Practice questions'),
        ]),
      ]),
      loadStatuses: (noteId) async => {
        'task-2': 'unknown-status',
      },
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.tasks.map((task) => task.studyStatus), ['new', 'new']);
  });

  test('skips malformed checklist entries without losing valid tasks', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [
          ChecklistItem(id: '', text: 'No ID'),
          ChecklistItem(id: 'blank-text', text: '   '),
          ChecklistItem(id: 'valid', text: 'Valid task'),
        ]),
      ]),
      loadStatuses: (noteId) async => const {},
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.tasks, hasLength(1));
    expect(controller.tasks.single.taskId, 'valid');
  });

  test('exposes repository errors and clears stale tasks', () async {
    final repository = _FakeNoteRepository([
      _note(items: const [ChecklistItem(id: 'task-1', text: 'Task')]),
    ]);
    final controller = StudyKanbanController(
      repository: repository,
      loadStatuses: (noteId) async => const {},
    );
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.tasks, hasLength(1));

    repository.error = StateError('local repository unavailable');
    await controller.load();

    expect(controller.hasError, isTrue);
    expect(controller.error.toString(), contains('local repository unavailable'));
    expect(controller.tasks, isEmpty);
    expect(controller.isLoading, isFalse);
    expect(controller.isEmpty, isFalse);
  });

  test('exposes status-store errors instead of showing stale data', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Task')]),
      ]),
      loadStatuses: (noteId) async => throw StateError('SQLite read failed'),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.hasError, isTrue);
    expect(controller.error.toString(), contains('SQLite read failed'));
    expect(controller.tasks, isEmpty);
  });

  test('empty state is distinct from loading and errors', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([_note()]),
      loadStatuses: (noteId) async => const {},
    );
    addTearDown(controller.dispose);

    expect(controller.isEmpty, isFalse);
    await controller.load();
    expect(controller.isEmpty, isTrue);
  });
}
