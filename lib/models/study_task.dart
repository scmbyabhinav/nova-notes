/// A checklist item projected into the Study Kanban board.
///
/// Study status is deliberately separate from [ChecklistItem.isDone]. It is
/// persisted in the SQLite study-status sidecar, not in the note payload.
class StudyTask {
  const StudyTask({
    required this.noteId,
    required this.taskId,
    required this.taskText,
    required this.studyStatus,
    this.noteTitle,
    this.isChecked = false,
  });

  final String noteId;
  final String taskId;
  final String taskText;
  final String studyStatus;
  final String? noteTitle;
  final bool isChecked;

  bool get isNew => studyStatus == 'new';
  bool get isLearning => studyStatus == 'learning';
  bool get isMastered => studyStatus == 'mastered';
}
