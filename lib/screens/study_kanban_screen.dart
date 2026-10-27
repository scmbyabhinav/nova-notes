import 'package:flutter/material.dart';

import '../controllers/study_kanban_controller.dart';
import '../models/study_task.dart';

const studyKanbanStatuses = <String>['new', 'learning', 'mastered'];

String studyKanbanLabel(String status) => switch (status) {
  'new' => 'New',
  'learning' => 'Learning',
  'mastered' => 'Mastered',
  _ => 'New',
};

/// Three-column Study Kanban board backed by [StudyKanbanController].
class StudyKanbanScreen extends StatefulWidget {
  const StudyKanbanScreen({super.key, required this.controller, this.noteId});

  final StudyKanbanController controller;
  final String? noteId;

  @override
  State<StudyKanbanScreen> createState() => _StudyKanbanScreenState();
}

class _StudyKanbanScreenState extends State<StudyKanbanScreen> {
  late final StudyKanbanController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  List<StudyTask> _tasksFor(String status) => _controller.tasks.where((task) =>
      task.studyStatus == status &&
      (widget.noteId == null || task.noteId == widget.noteId)).toList();

  Future<void> _move(StudyTask task, String status) async {
    if (task.studyStatus == status) return;
    try {
      await _controller.moveTask(task.noteId, task.taskId, status);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move task: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_controller.isLoading && !_controller.hasLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Kanban')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_controller.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Study Kanban')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 44),
              const SizedBox(height: 12),
              const Text('Could not load your study tasks.', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('${_controller.error}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _controller.load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ]),
          ),
        ),
      );
    }
    final allTasks = _controller.tasks.where((task) => widget.noteId == null || task.noteId == widget.noteId).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Kanban'),
        actions: [IconButton(tooltip: 'Refresh tasks', onPressed: _controller.load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: allTasks.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No checklist tasks yet. Add checklist items to start tracking your study progress.', textAlign: TextAlign.center)))
          : LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 840;
              final columns = studyKanbanStatuses.map((status) => _buildColumn(context, status)).toList();
              if (wide) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: columns[i]),
                    ],
                  ]),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: columns.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, index) => SizedBox(height: 340, child: columns[index]),
              );
            }),
    );
  }

  Widget _buildColumn(BuildContext context, String status) {
    final theme = Theme.of(context);
    final tasks = _tasksFor(status);
    return DragTarget<StudyTask>(
      key: ValueKey('kanban-target-$status'),
      onWillAcceptWithDetails: (details) => details.data.studyStatus != status,
      onAcceptWithDetails: (details) => _move(details.data, status),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: candidates.isNotEmpty ? theme.colorScheme.primary : theme.colorScheme.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(studyKanbanLabel(status), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            CircleAvatar(radius: 13, child: Text('${tasks.length}', style: theme.textTheme.labelSmall)),
          ]),
          const SizedBox(height: 10),
          Expanded(child: tasks.isEmpty
              ? Center(child: Text('No ${studyKanbanLabel(status).toLowerCase()} tasks', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
              : ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _taskCard(context, tasks[index]),
                )),
        ]),
      ),
    );
  }

  Widget _taskCard(BuildContext context, StudyTask task) {
    final theme = Theme.of(context);
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(task.taskText, style: theme.textTheme.bodyMedium)),
            PopupMenuButton<String>(
              tooltip: 'Move to…',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (status) => _move(task, status),
              itemBuilder: (_) => [for (final status in studyKanbanStatuses.where((value) => value != task.studyStatus)) PopupMenuItem(value: status, child: Text('Move to ${studyKanbanLabel(status)}'))],
            ),
          ]),
          if (task.noteTitle != null && task.noteTitle!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(task.noteTitle!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          if (task.isChecked)
            Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.check_circle_outline, size: 14, color: theme.colorScheme.tertiary), const SizedBox(width: 4), Text('Checklist completed', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary))])),
        ]),
      ),
    );
    return LongPressDraggable<StudyTask>(
      data: task,
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 260, child: Opacity(opacity: 0.92, child: card))),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
      ignoringFeedbackSemantics: true,
      dragAnchorStrategy: pointerDragAnchorStrategy,
    );
  }
}
