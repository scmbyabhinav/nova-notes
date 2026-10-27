import 'dart:async';
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
      persistStatus: (noteId, taskId, status) async {},
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
      persistStatus: (noteId, taskId, status) async {},
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
      persistStatus: (noteId, taskId, status) async {},
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
      persistStatus: (noteId, taskId, status) async {},
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
      persistStatus: (noteId, taskId, status) async {},
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.hasError, isTrue);
    expect(controller.error.toString(), contains('SQLite read failed'));
    expect(controller.tasks, isEmpty);
  });


  test('moves a task optimistically and persists the exact status', () async {
    final persisted = <List<String>>[];
    final completer = Completer<void>();
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Read chapter')]),
      ]),
      loadStatuses: (noteId) async => const {},
      persistStatus: (noteId, taskId, status) {
        persisted.add([noteId, taskId, status]);
        return completer.future;
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    final moving = controller.moveTask('note-1', 'task-1', 'learning');
    await Future<void>.delayed(Duration.zero);
    expect(controller.tasks.single.studyStatus, 'learning');
    expect(persisted, [['note-1', 'task-1', 'learning']]);

    completer.complete();
    await moving;
    expect(controller.tasks.single.studyStatus, 'learning');
  });

  test('rejects a missing task without writing status', () async {
    var writes = 0;
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Read chapter')]),
      ]),
      loadStatuses: (noteId) async => const {},
      persistStatus: (noteId, taskId, status) async { writes++; },
    );
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.moveTask('note-1', 'missing-task', 'learning'),
      throwsA(isA<StateError>()),
    );
    expect(writes, 0);
    expect(controller.tasks.single.studyStatus, 'new');
  });

  test('rolls back optimistic status when persistence fails', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Read chapter')]),
      ]),
      loadStatuses: (noteId) async => {'task-1': 'learning'},
      persistStatus: (noteId, taskId, status) async {
        throw StateError('SQLite write failed');
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.moveTask('note-1', 'task-1', 'mastered'),
      throwsA(isA<StateError>()),
    );
    expect(controller.tasks.single.studyStatus, 'learning');
  });

  test('serializes rapid moves and leaves the latest status persisted', () async {
    final firstWrite = Completer<void>();
    final writes = <String>[];
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Read chapter')]),
      ]),
      loadStatuses: (noteId) async => const {},
      persistStatus: (noteId, taskId, status) {
        writes.add(status);
        if (status == 'learning') return firstWrite.future;
        return Future<void>.value();
      },
    );
    addTearDown(controller.dispose);
    await controller.load();

    final first = controller.moveTask('note-1', 'task-1', 'learning');
    await Future<void>.delayed(Duration.zero);
    final second = controller.moveTask('note-1', 'task-1', 'mastered');
    await Future<void>.delayed(Duration.zero);

    expect(controller.tasks.single.studyStatus, 'mastered');
    expect(writes, ['learning']);

    firstWrite.complete();
    await Future.wait([first, second]);

    expect(writes, ['learning', 'mastered']);
    expect(controller.tasks.single.studyStatus, 'mastered');
  });

  test('rejects unsupported statuses before any state or database change', () async {
    var writes = 0;
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([
        _note(items: const [ChecklistItem(id: 'task-1', text: 'Read chapter')]),
      ]),
      loadStatuses: (noteId) async => const {},
      persistStatus: (noteId, taskId, status) async { writes++; },
    );
    addTearDown(controller.dispose);
    await controller.load();

    await expectLater(
      controller.moveTask('note-1', 'task-1', 'done'),
      throwsA(isA<FormatException>()),
    );
    expect(writes, 0);
    expect(controller.tasks.single.studyStatus, 'new');
  });

  test('empty state is distinct from loading and errors', () async {
    final controller = StudyKanbanController(
      repository: _FakeNoteRepository([_note()]),
      loadStatuses: (noteId) async => const {},
      persistStatus: (noteId, taskId, status) async {},
    );
    addTearDown(controller.dispose);

    expect(controller.isEmpty, isFalse);
    await controller.load();
    expect(controller.isEmpty, isTrue);
  });
}
