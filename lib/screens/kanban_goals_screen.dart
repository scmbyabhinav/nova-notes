import 'dart:async';
import 'package:flutter/material.dart';

import '../data/kanban/kanban_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import '../l10n/app_localizations.dart';
import 'kanban_screen.dart';

class KanbanGoalsScreen extends StatefulWidget {
  const KanbanGoalsScreen({super.key, this.repository});
  final KanbanRepository? repository;

  @override
  State<KanbanGoalsScreen> createState() => _KanbanGoalsScreenState();
}

class _KanbanGoalsScreenState extends State<KanbanGoalsScreen> {
  KanbanRepository? _repo;
  Stream<List<KanbanGoal>>? _goals;
  bool _ownsRepo = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    if (_ownsRepo && _repo != null) unawaited(_repo!.dispose());
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final repo = widget.repository ?? await openKanbanRepository();
      if (!mounted) return;
      setState(() { _repo = repo; _ownsRepo = widget.repository == null; _goals = repo.watchGoals(); _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _linkNote(KanbanGoal goal) async {
    final l = AppLocalizations.of(context)!;
    final notesRepository = await NoteRepositoryProvider.instance();
    final notes = (await notesRepository.getNotes()).where((note) => !note.isLocked && !note.isTrashed && !note.isArchived).toList();
    if (!mounted) return;
    final selected = await showDialog<Note>(context: context, builder: (ctx) => SimpleDialog(
      title: Text(l.kanbanLinkNote),
      children: notes.map((note) => SimpleDialogOption(
        onPressed: () => Navigator.pop(ctx, note),
        child: Text(note.title.trim().isEmpty ? l.notes : note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      )).toList(),
    ));
    if (selected != null && mounted) {
      await _repo!.addLink(sourceType: 'goal', sourceId: goal.id, targetType: 'note', targetId: selected.id);
      setState(() => _goals = _repo!.watchGoals());
    }
  }

  Future<void> _openLinkedNote(String noteId) async {
    final l = AppLocalizations.of(context)!;
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    final matches = notes.where((note) => note.id == noteId && !note.isLocked && !note.isTrashed && !note.isArchived);
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable)));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: repository, note: matches.first)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.kanbanGoals)),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
        _error != null ? Center(child: Text(_error!)) :
        StreamBuilder<List<KanbanGoal>>(stream: _goals, builder: (context, snapshot) {
          final goals = snapshot.data ?? const <KanbanGoal>[];
          if (goals.isEmpty) return Center(child: Text(l.kanbanNoGoals));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return FutureBuilder<List<KanbanCard>>(
                future: _repo!.getCards(goalId: goal.id),
                builder: (context, cardSnapshot) {
                  final cards = cardSnapshot.data ?? const <KanbanCard>[];
                  final done = cards.where((card) => card.status == KanbanStatus.done).length;
                  final progress = cards.isEmpty ? 0.0 : done / cards.length;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(goal.title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 4),
                          Text(l.kanbanGoalProgress + ': ' + (progress * 100).round().toString() + '%  (' + done.toString() + '/' + cards.length.toString() + ')'),
                          FutureBuilder<int>(future: _repo!.totalSecondsForGoal(goal.id), builder: (context, timeSnapshot) {
                            final seconds = timeSnapshot.data ?? 0;
                            return Text(l.kanbanGoalTime + ': ' + (seconds ~/ 3600).toString() + 'h ' + ((seconds % 3600) ~/ 60).toString() + 'm');
                          }),
                          FutureBuilder<List<Map<String, Object?>>>(future: _repo!.getLinks('goal', goal.id), builder: (context, linkSnapshot) {
                            final links = linkSnapshot.data ?? const <Map<String, Object?>>[];
                            if (links.isEmpty) return const SizedBox.shrink();
                            return Wrap(spacing: 4, children: links.map((link) => ActionChip(
                              visualDensity: VisualDensity.compact,
                              label: Text(l.kanbanNoteLink),
                              onPressed: () => _openLinkedNote(link['target_id'] as String),
                            )).toList());
                          }),
                        ]),
                      ),
                      isThreeLine: true,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => KanbanScreen(repository: _repo, initialGoalId: goal.id))),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'archive') await _repo!.archiveGoal(goal.id);
                          if (value == 'link_note') await _linkNote(goal);
                          if (value == 'delete') {
                            final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
                              content: Text(l.kanbanDeleteConfirm),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l.kanbanCancel)),
                                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l.kanbanDeletePermanently)),
                              ],
                            ));
                            if (confirmed == true) await _repo!.deleteGoalPermanently(goal.id);
                          }
                          if (mounted) setState(() => _goals = _repo!.watchGoals());
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'link_note', child: Text(l.kanbanLinkNote)),
                          PopupMenuItem(value: 'archive', child: Text(l.kanbanArchive)),
                          PopupMenuItem(value: 'delete', child: Text(l.kanbanDeletePermanently)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }),
    );
  }
}
