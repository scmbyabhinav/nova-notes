import 'package:flutter/foundation.dart';

import '../data/repositories/note_repository.dart';
import '../models/note.dart';
import '../models/study_task.dart';

/// Loads checklist tasks and their independent Study Kanban statuses.
///
/// The status loader is injected so the controller can be tested without a
/// real database and production can provide NoteDao.getStudyTaskStatuses.
class StudyKanbanController extends ChangeNotifier {
  StudyKanbanController({
    required NoteRepository repository,
    required Future<Map<String, String>> Function(String noteId) loadStatuses,
  })  : _repository = repository,
        _loadStatuses = loadStatuses;

  final NoteRepository _repository;
  final Future<Map<String, String>> Function(String noteId) _loadStatuses;

  List<StudyTask> _tasks = const [];
  bool _isLoading = false;
  Object? _error;

  List<StudyTask> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get hasError => _error != null;
  bool get isEmpty => !_isLoading && _error == null && _tasks.isEmpty;

  /// Reloads notes and maps valid checklist entries to immutable view models.
  ///
  /// Invalid individual tasks are skipped. A repository/status-store failure
  /// is exposed through [error] rather than silently presenting stale data.
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
      for (final note in notes) {
        if (note.id.trim().isEmpty) continue;
        final statuses = statusByNote[note.id] ?? const <String, String>{};
        for (final item in note.checklistItems) {
          try {
            final taskId = item.id.trim();
            final taskText = item.text.trim();
            if (taskId.isEmpty || taskText.isEmpty) continue;

            final storedStatus = statuses[item.id];
            final status = const {'new', 'learning', 'mastered'}
                    .contains(storedStatus)
                ? storedStatus!
                : 'new';

            loaded.add(StudyTask(
              noteId: note.id,
              taskId: item.id,
              taskText: taskText,
              studyStatus: status,
              noteTitle: note.title.trim().isEmpty ? null : note.title,
              isChecked: item.isDone,
            ));
          } catch (_) {
            // A malformed task must not prevent other tasks from loading.
          }
        }
      }
      _tasks = List.unmodifiable(loaded);
    } catch (error) {
      _error = error;
      _tasks = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
