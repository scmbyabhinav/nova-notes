import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/controllers/study_kanban_controller.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/models/search_filter.dart';
import 'package:orah_notes/data/repositories/note_repository.dart';
import 'package:orah_notes/screens/study_kanban_screen.dart';

class _NoNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => throw StateError('Unexpected network access in Study Kanban test.');
}

class _FakeRepo implements NoteRepository {
  _FakeRepo(this.notes);
  final List<Note> notes;
  @override Future<List<Note>> getNotes() async => notes;
  @override Stream<List<Note>> watchNotes() => Stream.value(notes);
  @override Future<Note?> getNote(String id) async { for (final note in notes) { if (note.id == id) return note; } return null; }
  @override Future<void> saveNote(Note note) async {}
  @override Future<void> deleteNote(String id) async {}
  @override Future<List<Note>> searchNotes(String query) async => notes;
  @override Future<List<Note>> search(String query, {SearchFilter filter = const SearchFilter()}) async => notes;
}

Note _note({List<ChecklistItem> items = const []}) => Note(
  id: 'note-1', title: 'Biology revision', content: 'Do not change this body',
  type: NoteType.checklist, createdAt: DateTime(2026), updatedAt: DateTime(2026),
  checklistItems: items,
);

void main() {
  late HttpOverrides? previous;
  setUp(() { previous = HttpOverrides.current; HttpOverrides.global = _NoNetworkOverrides(); });
  tearDown(() { HttpOverrides.global = previous; });

  testWidgets('renders three columns, task counts and empty column messages', (tester) async {
    // Use a wide viewport so all three responsive columns are mounted together.
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    final controller = StudyKanbanController(
      repository: _FakeRepo([_note(items: const [ChecklistItem(id: 'a', text: 'Read cell biology'), ChecklistItem(id: 'b', text: 'Practice genetics')])]),
      loadStatuses: (_) async => {'a': 'new', 'b': 'mastered'},
      persistStatus: (_, __, ___) async {},
    );
    await tester.pumpWidget(MaterialApp(home: StudyKanbanScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('Mastered'), findsOneWidget);
    expect(find.text('Read cell biology'), findsOneWidget);
    expect(find.text('Practice genetics'), findsOneWidget);
    expect(find.text('No learning tasks'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('Move to menu persists status and preserves checklist state', (tester) async {
    final note = _note(items: const [ChecklistItem(id: 'a', text: 'Revise chapter', isDone: true)]);
    final writes = <String>[];
    final controller = StudyKanbanController(
      repository: _FakeRepo([note]),
      loadStatuses: (_) async => const {},
      persistStatus: (_, taskId, status) async { writes.add('$taskId:$status'); },
    );
    await tester.pumpWidget(MaterialApp(home: StudyKanbanScreen(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to Learning'));
    await tester.pumpAndSettle();
    expect(writes, ['a:learning']);
    expect(controller.tasks.single.studyStatus, 'learning');
    expect(controller.tasks.single.isChecked, isTrue);
    expect(note.content, 'Do not change this body');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('shows board-level empty state when no checklist tasks exist', (tester) async {
    final controller = StudyKanbanController(repository: _FakeRepo([_note()]), loadStatuses: (_) async => const {}, persistStatus: (_, __, ___) async {});
    await tester.pumpWidget(MaterialApp(home: StudyKanbanScreen(controller: controller)));
    await tester.pumpAndSettle();
    expect(find.textContaining('No checklist tasks yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('drag-and-drop moves a task to Learning', (tester) async {
    final writes = <String>[];
    final controller = StudyKanbanController(
      repository: _FakeRepo([_note(items: const [ChecklistItem(id: 'a', text: 'Drag me')])]),
      loadStatuses: (_) async => const {},
      persistStatus: (_, taskId, status) async { writes.add('$taskId:$status'); },
    );
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(home: StudyKanbanScreen(controller: controller)));
    await tester.pumpAndSettle();
    final task = find.text('Drag me');
    final target = find.byKey(const ValueKey('kanban-target-learning'));
    final gesture = await tester.startGesture(tester.getCenter(task));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(writes, ['a:learning']);
    expect(controller.tasks.single.studyStatus, 'learning');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
