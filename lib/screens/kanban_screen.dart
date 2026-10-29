import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/kanban/kanban_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import '../l10n/app_localizations.dart';
import '../services/orah_feature_gate.dart';
import '../services/orah_premium_gate.dart';
import 'kanban_goals_screen.dart';

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key, this.repository, this.initialGoalId});
  final KanbanRepository? repository;
  final String? initialGoalId;

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  KanbanRepository? _repo;
  Stream<List<KanbanCard>>? _cards;
  Stream<List<KanbanGoal>>? _goals;
  String? _goalId;
  bool _byGoal = false;
  bool _allowMultipleTimers = false;
  bool _ownsRepo = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _goalId = widget.initialGoalId;
    _byGoal = widget.initialGoalId != null;
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
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _repo = repo;
        _ownsRepo = widget.repository == null;
        _allowMultipleTimers = prefs.getBool('orah_kanban_allow_multiple_timers') ?? false;
        _cards = repo.watchCards(goalId: _goalId);
        _goals = repo.watchGoals();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<bool> _pro(OrahFeature feature) => OrahPremiumGate.check(context, feature);

  void _refresh() {
    if (!mounted || _repo == null) return;
    setState(() => _cards = _repo!.watchCards(goalId: _byGoal ? _goalId : null));
  }

  Future<void> _addCard() async {
    final l = AppLocalizations.of(context)!;
    final draft = await showDialog<_KanbanCardDraft>(context: context, builder: (_) => _KanbanCardEditor(
      title: l.kanbanNewCard,
      saveLabel: l.kanbanSave,
    ));
    if (draft == null || !mounted) return;
    await _repo!.createCard(
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
      dueDate: draft.dueDate,
      colorLabel: draft.colorLabel,
      checklist: draft.checklist,
      goalId: _byGoal ? _goalId : null,
    );
    _refresh();
  }

  Future<void> _addGoal() async {
    if (!await _pro(OrahFeature.kanbanGoals) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final draft = await showDialog<_KanbanGoalDraft>(context: context, builder: (_) => _KanbanGoalEditor());
    if (draft == null || !mounted) return;
    await _repo!.createGoal(title: draft.title, description: draft.description, targetDate: draft.targetDate);
    setState(() => _goals = _repo!.watchGoals());
  }

  Future<void> _showCardLinks(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final links = await _repo!.getLinks('card', card.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, builder: (ctx) => SafeArea(child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(title: Text(l.kanbanLinks), leading: const Icon(Icons.link)),
        if (links.isEmpty) ListTile(title: Text(l.kanbanNoNotesToLink)),
        for (final link in links)
          ActionChip(
            avatar: Icon(link['target_type'] == 'note' ? Icons.note_outlined : link['target_type'] == 'goal' ? Icons.flag_outlined : Icons.view_kanban_outlined),
            label: Text(link['target_type'] == 'note' ? l.kanbanNoteLink : link['target_type'] == 'goal' ? l.kanbanGoalLink : l.kanbanCardLink),
            onPressed: () {
              Navigator.pop(ctx);
              _openLinkedTarget(link['target_type'] as String, link['target_id'] as String);
            },
          ),
        ListTile(leading: const Icon(Icons.add_link), title: Text(l.kanbanLinkNote), onTap: () { Navigator.pop(ctx); _linkNote(card); }),
        ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l.kanbanLinkGoal), onTap: () { Navigator.pop(ctx); _linkGoal(card); }),
        ListTile(leading: const Icon(Icons.view_kanban_outlined), title: Text(l.kanbanLinkCard), onTap: () { Navigator.pop(ctx); _linkCard(card); }),
      ],
    )));
  }

  Future<void> _linkGoal(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanLinks) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final goals = await _repo!.getGoals();
    if (!mounted) return;
    final selected = await showDialog<KanbanGoal>(context: context, builder: (ctx) => SimpleDialog(
      title: Text(l.kanbanLinkGoal),
      children: goals.map((goal) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, goal), child: Text(goal.title))).toList(),
    ));
    if (selected == null || !mounted) return;
    await _repo!.updateCard(card, goalId: selected.id);
    await _repo!.addLink(sourceType: 'card', sourceId: card.id, targetType: 'goal', targetId: selected.id, linkKind: 'goal');
    _refresh();
  }

  Future<void> _linkCard(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanLinks) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final cards = (await _repo!.getCards()).where((candidate) => candidate.id != card.id).toList();
    if (!mounted) return;
    final selected = await showDialog<KanbanCard>(context: context, builder: (ctx) => SimpleDialog(
      title: Text(l.kanbanLinkCard),
      children: cards.map((candidate) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, candidate), child: Text(candidate.title))).toList(),
    ));
    if (selected == null || !mounted) return;
    await _repo!.addLink(sourceType: 'card', sourceId: card.id, targetType: 'card', targetId: selected.id);
    _refresh();
  }

  Future<void> _openLinkedTarget(String type, String id) async {
    if (type == 'note') {
      await _openLinkedNote(id);
      return;
    }
    final l = AppLocalizations.of(context)!;
    final rows = type == 'goal'
      ? await _repo!.database.query('goals', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1)
      : await _repo!.database.query('kanban_cards', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1);
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable)));
      return;
    }
    if (type == 'card') {
      final row = rows.single;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(row['title'] as String? ?? l.kanbanUnavailable),
        content: Text((row['description'] as String? ?? '') + '\n' + l.kanbanPriority + ': ' + (row['priority'] as String? ?? l.kanbanMedium)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.kanbanCancel))],
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => KanbanScreen(repository: _repo, initialGoalId: type == 'goal' ? id : null)));
  }

  Future<void> _linkNote(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanLinks) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final notesRepository = await NoteRepositoryProvider.instance();
    final notes = (await notesRepository.getNotes()).where((note) => !note.isLocked && !note.isTrashed && !note.isArchived).toList();
    if (!mounted) return;
    final search = TextEditingController();
    final selected = await showModalBottomSheet<Note>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
        final query = search.text.toLowerCase();
        final filtered = notes.where((note) => note.title.toLowerCase().contains(query) || note.content.toLowerCase().contains(query)).toList();
        return SafeArea(child: SizedBox(height: MediaQuery.of(sheetContext).size.height * 0.72, child: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(l.kanbanLinkNote, style: Theme.of(sheetContext).textTheme.titleLarge)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(
            controller: search, decoration: InputDecoration(hintText: l.searchHint, prefixIcon: const Icon(Icons.search)),
            onChanged: (_) => setSheetState(() {}),
          )),
          Expanded(child: filtered.isEmpty ? Center(child: Text(l.kanbanNoNotesToLink)) : ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final note = filtered[index];
              return ListTile(
                leading: const Icon(Icons.note_outlined),
                title: Text(note.title.trim().isEmpty ? l.notes : note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(sheetContext, note),
              );
            },
          )),
        ])));
      }),
    );
    search.dispose();
    if (selected != null && mounted) {
      await _repo!.addLink(sourceType: 'card', sourceId: card.id, targetType: 'note', targetId: selected.id);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanLinkAdded)));
    }
  }

  Future<void> _openLinkedNote(String noteId) async {
    final l = AppLocalizations.of(context)!;
    final notesRepository = await NoteRepositoryProvider.instance();
    final notes = await notesRepository.getNotes();
    final matches = notes.where((note) => note.id == noteId && !note.isTrashed && !note.isArchived && !note.isLocked);
    if (!mounted) return;
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable)));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: notesRepository, note: matches.first)));
  }

  Future<void> _timer(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanTimers) || !mounted) return;
    final rows = await _repo!.database.query('time_entries', where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL', whereArgs: [card.id], limit: 1);
    if (rows.isEmpty) {
      await _repo!.startTimer(card.id, allowMultiple: _allowMultipleTimers);
    } else {
      await _repo!.stopTimer(card.id);
    }
    _refresh();
  }

  Future<void> _editCard(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final draft = await showDialog<_KanbanCardDraft>(context: context, builder: (_) => _KanbanCardEditor(
      title: l.kanbanEditCard,
      saveLabel: l.kanbanSave,
      initialTitle: card.title,
      initialDescription: card.description,
      initialPriority: card.priority,
      initialDueDate: card.dueDate,
      initialColorLabel: card.colorLabel,
      initialChecklist: card.checklist,
    ));
    if (draft == null || !mounted) return;
    await _repo!.updateCard(
      card,
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
      dueDate: draft.dueDate,
      clearDueDate: draft.clearDueDate,
      colorLabel: draft.colorLabel,
      clearColorLabel: draft.colorLabel == null,
      checklist: draft.checklist,
    );
    _refresh();
  }

  Future<void> _moveCardWithUndo(KanbanCard card, KanbanStatus status) async {
    final previous = card.status;
    await _repo!.moveCard(card, status);
    if (!mounted) return;
    _refresh();
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.kanbanCardMoved),
      action: SnackBarAction(label: l.kanbanUndo, onPressed: () async {
        await _repo!.moveCard(card, previous);
        _refresh();
      }),
    ));
  }

  Future<void> _archive(KanbanCard card) async {
    await _repo!.archiveCard(card.id);
    _refresh();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.kanbanArchived),
      action: SnackBarAction(label: l.kanbanUndo, onPressed: () async {
        await _repo!.restoreCard(card.id);
        _refresh();
      }),
    ));
  }

  Future<void> _showArchived() async {
    final l = AppLocalizations.of(context)!;
    final cards = (await _repo!.getCards(includeArchived: true)).where((card) => card.archivedAt != null).toList();
    final goals = (await _repo!.getGoals(includeArchived: true)).where((goal) => goal.archivedAt != null).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(title: Text(l.kanbanArchived), leading: const Icon(Icons.archive_outlined)),
        if (cards.isEmpty && goals.isEmpty) ListTile(title: Text(l.kanbanNoCards)),
        for (final card in cards)
          ListTile(
            leading: const Icon(Icons.view_kanban_outlined),
            title: Text(card.title),
            subtitle: Text(l.kanbanArchived),
            trailing: IconButton(icon: const Icon(Icons.unarchive_outlined), tooltip: l.kanbanRestore, onPressed: () async {
              await _repo!.restoreCard(card.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            }),
          ),
        for (final goal in goals)
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(goal.title),
            subtitle: Text(l.kanbanArchived),
            trailing: IconButton(icon: const Icon(Icons.unarchive_outlined), tooltip: l.kanbanRestore, onPressed: () async {
              await _repo!.restoreGoal(goal.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            }),
          ),
      ],
    )));
  }

  Future<void> _delete(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      content: Text(l.kanbanDeleteConfirm),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.kanbanCancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.kanbanDeletePermanently))],
    ));
    if (ok == true) { await _repo!.deleteCardPermanently(card.id); _refresh(); }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: Text(l.kanban)), body: Center(child: Text(_error!)));
    return Scaffold(
      appBar: AppBar(title: Text(l.kanbanBoard), actions: [
        PopupMenuButton<String>(
          tooltip: l.kanbanAllowMultipleTimers,
          onSelected: (value) async {
            if (value == 'multiple') {
              final next = !_allowMultipleTimers;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('orah_kanban_allow_multiple_timers', next);
              if (mounted) setState(() => _allowMultipleTimers = next);
            }
          },
          itemBuilder: (_) => [CheckedPopupMenuItem(value: 'multiple', checked: _allowMultipleTimers, child: Text(l.kanbanAllowMultipleTimers))],
        ),
        IconButton(tooltip: l.kanbanArchived, onPressed: _showArchived, icon: const Icon(Icons.archive_outlined)),
        IconButton(tooltip: l.kanbanGoals, onPressed: () async {
          if (!await _pro(OrahFeature.kanbanGoals) || !mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => KanbanGoalsScreen(repository: _repo)));
        }, icon: const Icon(Icons.flag_outlined)),
        IconButton(tooltip: l.kanbanCreateGoal, onPressed: _addGoal, icon: const Icon(Icons.add_task_outlined)),
        IconButton(tooltip: l.kanbanAddCard, onPressed: _byGoal && _goalId == null ? null : _addCard, icon: const Icon(Icons.add_rounded)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(8), child: SegmentedButton<bool>(
          segments: [ButtonSegment(value: false, label: Text(l.kanbanAllCards)), ButtonSegment(value: true, label: Text(l.kanbanByGoal))],
          selected: {_byGoal},
          onSelectionChanged: (v) async {
            if (v.first && !await _pro(OrahFeature.kanbanGoals)) return;
            if (!mounted) return;
            setState(() { _byGoal = v.first; _goalId = null; _cards = _repo!.watchCards(); });
          },
        )),
        FutureBuilder<int>(future: _repo!.totalSecondsToday(), builder: (context, snap) {
          final seconds = snap.data ?? 0;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Align(alignment: Alignment.centerLeft, child: Text(l.kanbanTodayTime + ': ' + (seconds ~/ 3600).toString() + 'h ' + ((seconds % 3600) ~/ 60).toString() + 'm', style: Theme.of(context).textTheme.labelMedium)));
        }),
        if (_byGoal) SizedBox(height: 56, child: StreamBuilder<List<KanbanGoal>>(stream: _goals, builder: (context, snap) {
          final goals = snap.data ?? const <KanbanGoal>[];
          if (goals.isEmpty) return Center(child: Text(l.kanbanNoGoals));
          return ListView(
            scrollDirection: Axis.horizontal,
            children: goals.map((g) => Padding(
              padding: const EdgeInsets.all(4),
              child: ChoiceChip(
                label: Text(g.title),
                selected: _goalId == g.id,
                onSelected: (_) => setState(() {
                  _goalId = g.id;
                  _cards = _repo!.watchCards(goalId: g.id);
                }),
              ),
            )).toList(),
          );
        })),
        Expanded(child: StreamBuilder<List<KanbanCard>>(stream: _cards, builder: (context, snap) {
          if (_byGoal && _goalId == null) return Center(child: Text(l.kanbanChooseGoal));
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final cards = snap.data!;
          final statuses = KanbanStatus.values;
          return LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth >= 840) return Row(children: statuses.map((s) => Expanded(child: _column(s, cards))).toList());
            return DefaultTabController(length: 3, child: Column(children: [
              TabBar(tabs: [Tab(text: l.kanbanTodo + ' (' + _count(cards, KanbanStatus.todo).toString() + ')'),
                Tab(text: l.kanbanInProgress + ' (' + _count(cards, KanbanStatus.inProgress).toString() + ')'),
                Tab(text: l.kanbanDone + ' (' + _count(cards, KanbanStatus.done).toString() + ')')]),
              Expanded(child: TabBarView(children: statuses.map((s) => _column(s, cards)).toList())),
            ]));
          });
        })),
      ]),
    );
  }

  int _count(List<KanbanCard> cards, KanbanStatus s) => cards.where((c) => c.status == s).length;

  Widget _column(KanbanStatus status, List<KanbanCard> all) {
    final l = AppLocalizations.of(context)!;
    final cards = all.where((c) => c.status == status).toList();
    final title = status == KanbanStatus.todo ? l.kanbanTodo : status == KanbanStatus.inProgress ? l.kanbanInProgress : l.kanbanDone;
    return DragTarget<KanbanCard>(
      onAcceptWithDetails: (details) => _moveCardWithUndo(details.data, status),
      builder: (context, candidates, rejected) => Container(
        margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text(title + ' (' + cards.length.toString() + ')', style: Theme.of(context).textTheme.titleMedium),
          Expanded(child: cards.isEmpty ? Center(child: Text(l.kanbanNoCards)) : ReorderableListView(
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex--;
              final card = cards.removeAt(oldIndex);
              cards.insert(newIndex, card);
              for (var i = 0; i < cards.length; i++) { await _repo!.reorderCard(cards[i], i); }
              _refresh();
            },
            children: cards.map((card) => LongPressDraggable<KanbanCard>(
              key: ValueKey(card.id), data: card,
              feedback: Material(child: SizedBox(width: 230, child: ListTile(title: Text(card.title)))),
              child: Card(child: ListTile(
                title: Text(card.title),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (card.description.isNotEmpty) Text(card.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (card.colorLabel != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Chip(
                    label: Text(card.colorLabel!), visualDensity: VisualDensity.compact,
                  )),
                  if (card.dueDate != null) Text(l.kanbanDueDate + ': ' + card.dueDate!.toLocal().toIso8601String().substring(0, 10)),
                  if (card.checklist.isNotEmpty) Text(l.kanbanChecklistHint + ': ' + card.checklist.length.toString()),
                  Text(l.kanbanPriority + ': ' + (card.priority == KanbanPriority.low ? l.kanbanLow : card.priority == KanbanPriority.medium ? l.kanbanMedium : l.kanbanHigh)),
                  FutureBuilder<List<Map<String, Object?>>>(
                    future: _repo!.getLinks('card', card.id),
                    builder: (context, snapshot) {
                      final links = snapshot.data ?? const <Map<String, Object?>>[];
                      if (links.isEmpty) return const SizedBox.shrink();
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 4, runSpacing: 2, children: links.map((link) => ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(link['target_type'] == 'note' ? l.kanbanNoteLink : link['target_type'] == 'goal' ? l.kanbanGoalLink : l.kanbanCardLink),
                        onPressed: () => _openLinkedTarget(link['target_type'] as String, link['target_id'] as String),
                      )).toList()));
                    },
                  ),
                  FutureBuilder<int>(future: _repo!.totalSecondsForCard(card.id), builder: (context, snapshot) {
                    final seconds = snapshot.data ?? 0;
                    if (seconds <= 0) return const SizedBox.shrink();
                    return Text(l.kanbanTotalTime + ': ' + (seconds ~/ 3600).toString() + 'h ' + ((seconds % 3600) ~/ 60).toString() + 'm');
                  }),
                ]),
                isThreeLine: true,
                onTap: () => _showCardLinks(card),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  FutureBuilder<bool>(
                    future: _repo!.database.query('time_entries', where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL', whereArgs: [card.id], limit: 1).then((rows) => rows.isNotEmpty),
                    builder: (context, snapshot) => snapshot.data == true
                      ? const Icon(Icons.timer, color: Colors.green)
                      : const SizedBox.shrink(),
                  ),
                  PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await _editCard(card);
                    if (v == 'link_note') await _linkNote(card);
                    if (v == 'todo') await _moveCardWithUndo(card, KanbanStatus.todo);
                    if (v == 'progress') await _moveCardWithUndo(card, KanbanStatus.inProgress);
                    if (v == 'done') await _moveCardWithUndo(card, KanbanStatus.done);
                    if (v == 'timer') await _timer(card);
                    if (v == 'stop_timer') await _repo!.stopTimer(card.id);
                    if (v == 'archive') await _archive(card);
                    if (v == 'delete') await _delete(card);
                    _refresh();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l.kanbanEditCard)),
                    PopupMenuItem(value: 'link_note', child: Text(l.kanbanLinkNote)),
                    PopupMenuItem(value: 'todo', child: Text(l.kanbanTodo)),
                    PopupMenuItem(value: 'progress', child: Text(l.kanbanInProgress)),
                    PopupMenuItem(value: 'done', child: Text(l.kanbanDone)),
                    PopupMenuItem(value: 'timer', child: Text(l.kanbanStartPauseTimer)),
                    PopupMenuItem(value: 'stop_timer', child: Text(l.kanbanStopTimerNow)),
                    PopupMenuItem(value: 'archive', child: Text(l.kanbanArchive)),
                    PopupMenuItem(value: 'delete', child: Text(l.kanbanDeletePermanently)),
                  ],
                  ),
                ]),
              )),
            )).toList(),
          )),
        ]),
      ),
    );
  }
}

class _KanbanGoalDraft {
  const _KanbanGoalDraft({required this.title, required this.description, this.targetDate});
  final String title;
  final String description;
  final DateTime? targetDate;
}

class _KanbanGoalEditor extends StatefulWidget {
  @override
  State<_KanbanGoalEditor> createState() => _KanbanGoalEditorState();
}

class _KanbanGoalEditorState extends State<_KanbanGoalEditor> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  DateTime? _targetDate;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.kanbanCreateGoal),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l.kanbanGoalTitle)),
        TextField(controller: _description, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: l.kanbanGoalDescription)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.kanbanDueDate),
          subtitle: Text(_targetDate == null ? l.kanbanDueDate : _targetDate!.toLocal().toIso8601String().substring(0, 10)),
          trailing: IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: () async {
            final date = await showDatePicker(context: context, initialDate: _targetDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
            if (date != null) setState(() => _targetDate = date);
          }),
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.kanbanCancel)),
        FilledButton(onPressed: () {
          final title = _title.text.trim();
          if (title.isEmpty) return;
          Navigator.pop(context, _KanbanGoalDraft(title: title, description: _description.text.trim(), targetDate: _targetDate));
        }, child: Text(l.kanbanSave)),
      ],
    );
  }
}

class _KanbanCardDraft {
  const _KanbanCardDraft({
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.clearDueDate,
    required this.colorLabel,
    required this.checklist,
  });
  final String title;
  final String description;
  final KanbanPriority priority;
  final DateTime? dueDate;
  final bool clearDueDate;
  final String? colorLabel;
  final List<String> checklist;
}

class _KanbanCardEditor extends StatefulWidget {
  const _KanbanCardEditor({
    required this.title,
    required this.saveLabel,
    this.initialTitle = '',
    this.initialDescription = '',
    this.initialPriority = KanbanPriority.medium,
    this.initialDueDate,
    this.initialColorLabel,
    this.initialChecklist = const [],
  });
  final String title;
  final String saveLabel;
  final String initialTitle;
  final String initialDescription;
  final KanbanPriority initialPriority;
  final DateTime? initialDueDate;
  final String? initialColorLabel;
  final List<String> initialChecklist;

  @override
  State<_KanbanCardEditor> createState() => _KanbanCardEditorState();
}

class _KanbanCardEditorState extends State<_KanbanCardEditor> {
  late final TextEditingController _title = TextEditingController(text: widget.initialTitle);
  late final TextEditingController _description = TextEditingController(text: widget.initialDescription);
  late final TextEditingController _color = TextEditingController(text: widget.initialColorLabel ?? '');
  late final TextEditingController _checklist = TextEditingController(text: widget.initialChecklist.join('\n'));
  late KanbanPriority _priority = widget.initialPriority;
  DateTime? _dueDate;
  bool _clearDueDate = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _color.dispose();
    _checklist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dueLabel = _dueDate == null ? l.kanbanDueDate : _dueDate!.toLocal().toIso8601String().substring(0, 10);
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l.kanbanCardTitle)),
        TextField(controller: _description, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: l.kanbanDescription)),
        DropdownButtonFormField<KanbanPriority>(
          value: _priority,
          decoration: InputDecoration(labelText: l.kanbanPriority),
          items: [
            DropdownMenuItem(value: KanbanPriority.low, child: Text(l.kanbanLow)),
            DropdownMenuItem(value: KanbanPriority.medium, child: Text(l.kanbanMedium)),
            DropdownMenuItem(value: KanbanPriority.high, child: Text(l.kanbanHigh)),
          ],
          onChanged: (value) { if (value != null) setState(() => _priority = value); },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.kanbanDueDate),
          subtitle: Text(dueLabel),
          trailing: Wrap(children: [
            IconButton(tooltip: l.kanbanDueDate, icon: const Icon(Icons.calendar_month_outlined), onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() { _dueDate = picked; _clearDueDate = false; });
            }),
            if (_dueDate != null) IconButton(icon: const Icon(Icons.clear), tooltip: l.kanbanCancel, onPressed: () => setState(() { _dueDate = null; _clearDueDate = true; })),
          ]),
        ),
        TextField(controller: _color, decoration: InputDecoration(labelText: l.kanbanColorLabel)),
        TextField(controller: _checklist, minLines: 2, maxLines: 5, decoration: InputDecoration(labelText: l.kanbanChecklistHint)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.kanbanCancel)),
        FilledButton(onPressed: () {
          final title = _title.text.trim();
          if (title.isEmpty) return;
          Navigator.pop(context, _KanbanCardDraft(
            title: title,
            description: _description.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
            clearDueDate: _clearDueDate,
            colorLabel: _color.text.trim().isEmpty ? null : _color.text.trim(),
            checklist: _checklist.text.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
          ));
        }, child: Text(widget.saveLabel)),
      ],
    );
  }
}
