import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/note_repository.dart';
import '../models/study_task.dart';

const _validStudyStatuses = {'new', 'learning', 'mastered'};

/// Loads checklist tasks and coordinates independent Study Kanban status writes.
class StudyKanbanController extends ChangeNotifier {
  StudyKanbanController({
    required NoteRepository repository,
    required Future<Map<String, String>> Function(String noteId) loadStatuses,
    required Future<void> Function(
      String noteId,
      String taskId,
      String status,
    ) persistStatus,
  })  : _repository = repository,
        _loadStatuses = loadStatuses,
        _persistStatus = persistStatus;

  final NoteRepository _repository;
  final Future<Map<String, String>> Function(String noteId) _loadStatuses;
  final Future<void> Function(String noteId, String taskId, String status)
      _persistStatus;

  List<StudyTask> _tasks = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  Object? _error;

  int _operationCounter = 0;
  final Map<String, int> _latestOperationByTask = {};
  final Map<String, Future<void>> _writeTailByTask = {};
  final Map<String, String> _confirmedStatusByTask = {};

  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get hasError => _error != null;
  bool get hasLoaded => _hasLoaded;
  bool get isEmpty =>
      _hasLoaded && !_isLoading && _error == null && _tasks.isEmpty;

  static String _key(String noteId, String taskId) =>
      '${noteId.length}:$noteId$taskId';

  void _replaceTaskStatus(String key, String status) {
    final separator = key.indexOf(':');
    final noteIdLength = int.parse(key.substring(0, separator));
    final noteIdStart = separator + 1;
    final noteId = key.substring(noteIdStart, noteIdStart + noteIdLength);
    final taskId = key.substring(noteIdStart + noteIdLength);

    _tasks = List.unmodifiable(_tasks.map((task) {
      if (task.noteId != noteId || task.taskId != taskId) return task;
      return StudyTask(
        noteId: task.noteId,
        taskId: task.taskId,
        taskText: task.taskText,
        studyStatus: status,
        noteTitle: task.noteTitle,
        isChecked: task.isChecked,
      );
    }));
  }

  /// Reloads notes and maps valid checklist entries to immutable view models.
  /// Invalid individual tasks are skipped; storage errors are exposed to callers.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final notes = await _repository.getNotes();
      final statusByNote = <String, Map<String, String>>{};
      for (final note in notes) {
        if (note.id.trim().isEmpty || note.checklistItems.isEmpty) continue;
        statusByNote[note.id] = await _loadStatuses(note.id);
      }

      final loaded = <StudyTask>[];
      final confirmed = <String, String>{};
      for (final note in notes) {
        if (note.id.trim().isEmpty) continue;
        final statuses = statusByNote[note.id] ?? const <String, String>{};
        for (final item in note.checklistItems) {
          try {
            final taskId = item.id.trim();
            final taskText = item.text.trim();
            if (taskId.isEmpty || taskText.isEmpty) continue;

            final storedStatus = statuses[item.id];
            final status = _validStudyStatuses.contains(storedStatus)
                ? storedStatus!
                : 'new';
            final key = _key(note.id, item.id);
            confirmed[key] = status;

            loaded.add(StudyTask(
              noteId: note.id,
              taskId: item.id,
              taskText: taskText,
              studyStatus: status,
              noteTitle: note.title.trim().isEmpty ? null : note.title,
              isChecked: item.isDone,
            ));
          } catch (_) {
            // One malformed task must not prevent other tasks from loading.
          }
        }
      }
      _tasks = List.unmodifiable(loaded);
      _confirmedStatusByTask
        ..clear()
        ..addAll(confirmed);
    } catch (error) {
      _error = error;
      _tasks = const [];
      _confirmedStatusByTask.clear();
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      notifyListeners();
    }
  }

  /// Optimistically moves a task, serializing writes for that task only.
  ///
  /// The note/task is revalidated through the repository before changing local
  /// state. A failed latest operation rolls back to the last persisted status.
  /// Older failures cannot undo a newer move, and database writes execute in
  /// invocation order so an older write cannot finish after a newer write.
  Future<void> moveTask(
    String noteId,
    String taskId,
    String newStatus,
  ) async {
    if (!_validStudyStatuses.contains(newStatus)) {
      throw FormatException('Unsupported study status: $newStatus');
    }

    final index = _tasks.indexWhere(
      (task) => task.noteId == noteId && task.taskId == taskId,
    );
    if (index < 0) {
      throw StateError('Task $taskId not found in note $noteId');
    }

    final note = await _repository.getNote(noteId);
    if (note == null ||
        !note.checklistItems.any((item) => item.id == taskId)) {
      throw StateError('Task $taskId not found in note $noteId');
    }

    final currentIndex = _tasks.indexWhere(
      (task) => task.noteId == noteId && task.taskId == taskId,
    );
    if (currentIndex < 0) {
      throw StateError('Task $taskId is no longer available in note $noteId');
    }
    final currentTask = _tasks[currentIndex];
    if (currentTask.studyStatus == newStatus) return;

    final key = _key(noteId, taskId);
    final operationId = ++_operationCounter;
    _latestOperationByTask[key] = operationId;

    _replaceTaskStatus(key, newStatus);
    notifyListeners();

    final previousWrite = _writeTailByTask[key] ?? Future<void>.value();
    final write = previousWrite
        .then<void>((_) => _persistStatus(noteId, taskId, newStatus),
            onError: (Object _, StackTrace __) =>
                _persistStatus(noteId, taskId, newStatus));
    _writeTailByTask[key] = write;

    try {
      await write;
      _confirmedStatusByTask[key] = newStatus;
    } catch (_) {
      if (_latestOperationByTask[key] == operationId) {
        final confirmed = _confirmedStatusByTask[key] ?? currentTask.studyStatus;
        _replaceTaskStatus(key, confirmed);
        notifyListeners();
      }
      rethrow;
    } finally {
      if (identical(_writeTailByTask[key], write)) {
        _writeTailByTask.remove(key);
      }
      if (_latestOperationByTask[key] == operationId) {
        _latestOperationByTask.remove(key);
      }
    }
  }
}
