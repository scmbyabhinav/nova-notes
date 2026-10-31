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
  const KanbanScreen({super.key, this.repository, this.initialGoalId, this.skipInitializationForTest = false, this.skipTodaySummaryForTest = false});
  final KanbanRepository? repository;
  final String? initialGoalId;
  @visibleForTesting
  final bool skipInitializationForTest;
  @visibleForTesting
  final bool skipTodaySummaryForTest;

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
  Future<int>? _todaySecondsFuture;
  final Map<String, Future<List<Map<String, Object?>>>> _cardLinksFutures = {};
  final Map<String, Future<int>> _cardSecondsFutures = {};
  final Map<String, Future<bool>> _cardRunningFutures = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _goalId = widget.initialGoalId;
    _byGoal = widget.initialGoalId != null;
    if (widget.repository != null) {
      if (!widget.skipInitializationForTest) {
        _configureRepository(widget.repository!, allowMultipleTimers: false, ownsRepo: false);
      }
      return;
    }
    if (widget.skipInitializationForTest) return;
    unawaited(_init());
  }

  void _configureRepository(KanbanRepository repo, {required bool allowMultipleTimers, required bool ownsRepo}) {
    _repo = repo;
    _ownsRepo = ownsRepo;
    _allowMultipleTimers = allowMultipleTimers;
    _cards = repo.watchCards(goalId: _goalId);
    _goals = repo.watchGoals();
    _todaySecondsFuture = widget.skipTodaySummaryForTest ? Future<int>.value(0) : repo.totalSecondsToday();
    _loading = false;
    _error = null;
  }

  @override
  void dispose() {
    if (_ownsRepo && _repo != null) unawaited(_repo!.dispose());
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final repo = await openKanbanRepository();
      final preferences = await SharedPreferences.getInstance();
      final allowMultipleTimers = preferences.getBool('orah_kanban_allow_multiple_timers') ?? false;
      if (!mounted) { await repo.dispose(); return; }
      setState(() => _configureRepository(repo, allowMultipleTimers: allowMultipleTimers, ownsRepo: true));
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<List<Map<String, Object?>>> _linksForCard(String id) =>
      _cardLinksFutures.putIfAbsent(id, () => _repo!.getLinks('card', id));

  Future<int> _secondsForCard(String id) =>
      _cardSecondsFutures.putIfAbsent(id, () => _repo!.totalSecondsForCard(id));

  Future<bool> _isCardTimerRunning(String id) =>
      _cardRunningFutures.putIfAbsent(id, () => _repo!.database
          .query('time_entries', where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL', whereArgs: [id], limit: 1)
          .then((rows) => rows.isNotEmpty));

  Future<bool> _pro(OrahFeature feature) => OrahPremiumGate.check(context, feature);

  void _refresh() {
    if (!mounted || _repo == null) return;
    setState(() => _cards = _repo!.watchCards(goalId: _byGoal ? _goalId : null));
  }

  Future<void> _addCard() async {
    final l = AppLocalizations.of(context)!;
    final draft = await showDialog<_KanbanCardDraft>(context: context, builder: (_) => _KanbanCardEditor(title: l.kanbanNewCard, saveLabel: l.kanbanSave));
    if (draft == null || !mounted) return;
    await _repo!.createCard(title: draft.title, description: draft.description, priority: draft.priority, dueDate: draft.dueDate, colorLabel: draft.colorLabel, checklist: draft.checklist, goalId: _byGoal ? _goalId : null);
    _refresh();
  }

  Future<void> _addGoal() async {
    if (!await _pro(OrahFeature.kanbanGoals) || !mounted) return;
    final draft = await showDialog<_KanbanGoalDraft>(context: context, builder: (_) => _KanbanGoalEditor());
    if (draft == null || !mounted) return;
    await _repo!.createGoal(title: draft.title, description: draft.description, targetDate: draft.targetDate);
    setState(() => _goals = _repo!.watchGoals());
  }

  Future<void> _showCardLinks(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final links = await _repo!.getLinks('card', card.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
      ListTile(title: Text(l.kanbanLinks), leading: const Icon(Icons.link)),
      if (links.isEmpty) ListTile(title: Text(l.kanbanNoNotesToLink)),
      for (final link in links)
        ActionChip(
          avatar: Icon(link['target_type'] == 'note' ? Icons.note_outlined : link['target_type'] == 'goal' ? Icons.flag_outlined : Icons.view_kanban_outlined),
          label: Text(link['target_type'] == 'note' ? l.kanbanNoteLink : link['target_type'] == 'goal' ? l.kanbanGoalLink : l.kanbanCardLink),
          onPressed: () { Navigator.pop(ctx); _openLinkedTarget(link['target_type'] as String, link['target_id'] as String); },
        ),
      ListTile(leading: const Icon(Icons.add_link), title: Text(l.kanbanLinkNote), onTap: () { Navigator.pop(ctx); _linkNote(card); }),
      ListTile(leading: const Icon(Icons.flag_outlined), title: Text(l.kanbanLinkGoal), onTap: () { Navigator.pop(ctx); _linkGoal(card); }),
      ListTile(leading: const Icon(Icons.view_kanban_outlined), title: Text(l.kanbanLinkCard), onTap: () { Navigator.pop(ctx); _linkCard(card); }),
    ])));
  }

  Future<void> _linkGoal(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanLinks) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final goals = await _repo!.getGoals();
    if (!mounted) return;
    final selected = await showDialog<KanbanGoal>(context: context, builder: (ctx) => SimpleDialog(title: Text(l.kanbanLinkGoal), children: goals.map((goal) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, goal), child: Text(goal.title))).toList()));
    if (selected == null || !mounted) return;
    await _repo!.updateCard(card, goalId: selected.id);
    await _repo!.addLink(sourceType: 'card', sourceId: card.id, targetType: 'goal', targetId: selected.id, linkKind: 'goal');
    _refresh();
  }

  Future<void> _linkCard(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanLinks) || !mounted) return;
    final l = AppLocalizations.of(context)!;
    final cards = (await _repo!.getCards()).where((c) => c.id != card.id).toList();
    if (!mounted) return;
    final selected = await showDialog<KanbanCard>(context: context, builder: (ctx) => SimpleDialog(title: Text(l.kanbanLinkCard), children: cards.map((c) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c.title))).toList()));
    if (selected == null || !mounted) return;
    await _repo!.addLink(sourceType: 'card', sourceId: card.id, targetType: 'card', targetId: selected.id);
    _refresh();
  }

  Future<void> _openLinkedTarget(String type, String id) async {
    if (type == 'note') { await _openLinkedNote(id); return; }
    final l = AppLocalizations.of(context)!;
    final rows = type == 'goal'
      ? await _repo!.database.query('goals', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1)
      : await _repo!.database.query('kanban_cards', where: 'id = ? AND deleted_at IS NULL AND archived_at IS NULL', whereArgs: [id], limit: 1);
    if (!mounted) return;
    if (rows.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable))); return; }
    if (type == 'card') {
      final row = rows.single;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: Text(row['title'] as String? ?? l.kanbanUnavailable),
        content: Text('${row['description'] as String? ?? ''}\n${l.kanbanPriority}: ${row['priority'] as String? ?? l.kanbanMedium}'),
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
    final notes = (await notesRepository.getNotes()).where((n) => !n.isLocked && !n.isTrashed && !n.isArchived).toList();
    if (!mounted) return;
    final search = TextEditingController();
    final selected = await showModalBottomSheet<Note>(context: context, isScrollControlled: true, builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) {
      final query = search.text.toLowerCase();
      final filtered = notes.where((n) => n.title.toLowerCase().contains(query) || n.content.toLowerCase().contains(query)).toList();
      return SafeArea(child: SizedBox(height: MediaQuery.of(sheetContext).size.height * 0.72, child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(l.kanbanLinkNote, style: Theme.of(sheetContext).textTheme.titleLarge)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: TextField(controller: search, decoration: InputDecoration(hintText: l.searchHint, prefixIcon: const Icon(Icons.search)), onChanged: (_) => setSheetState(() {}))),
        Expanded(child: filtered.isEmpty ? Center(child: Text(l.kanbanNoNotesToLink)) : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
          final note = filtered[i];
          return ListTile(leading: const Icon(Icons.note_outlined), title: Text(note.title.trim().isEmpty ? l.notes : note.title, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => Navigator.pop(sheetContext, note));
        })),
      ])));
    }));
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
    final matches = notes.where((n) => n.id == noteId && !n.isTrashed && !n.isArchived && !n.isLocked);
    if (!mounted) return;
    if (matches.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanUnavailable))); return; }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: notesRepository, note: matches.first)));
  }

  Future<void> _timer(KanbanCard card) async {
    if (!await _pro(OrahFeature.kanbanTimers) || !mounted) return;
    final rows = await _repo!.database.query('time_entries', where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL', whereArgs: [card.id], limit: 1);
    if (rows.isEmpty) { await _repo!.startTimer(card.id, allowMultiple: _allowMultipleTimers); } else { await _repo!.stopTimer(card.id); }
    _refresh();
  }

  Future<void> _editCard(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final draft = await showDialog<_KanbanCardDraft>(context: context, builder: (_) => _KanbanCardEditor(title: l.kanbanEditCard, saveLabel: l.kanbanSave, initialTitle: card.title, initialDescription: card.description, initialPriority: card.priority, initialDueDate: card.dueDate, initialColorLabel: card.colorLabel, initialChecklist: card.checklist));
    if (draft == null || !mounted) return;
    await _repo!.updateCard(card, title: draft.title, description: draft.description, priority: draft.priority, dueDate: draft.dueDate, clearDueDate: draft.clearDueDate, colorLabel: draft.colorLabel, clearColorLabel: draft.colorLabel == null, checklist: draft.checklist);
    _refresh();
  }

  Future<void> _moveCardWithUndo(KanbanCard card, KanbanStatus status) async {
    final previous = card.status;
    await _repo!.moveCard(card, status);
    if (!mounted) return;
    _refresh();
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanCardMoved), action: SnackBarAction(label: l.kanbanUndo, onPressed: () async { await _repo!.moveCard(card, previous); _refresh(); })));
  }

  Future<void> _archive(KanbanCard card) async {
    await _repo!.archiveCard(card.id);
    _refresh();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.kanbanArchived), action: SnackBarAction(label: l.kanbanUndo, onPressed: () async { await _repo!.restoreCard(card.id); _refresh(); })));
  }

  Future<void> _showArchived() async {
    final l = AppLocalizations.of(context)!;
    final cards = (await _repo!.getCards(includeArchived: true)).where((c) => c.archivedAt != null).toList();
    final goals = (await _repo!.getGoals(includeArchived: true)).where((g) => g.archivedAt != null).toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (ctx) => SafeArea(child: ListView(shrinkWrap: true, children: [
      ListTile(title: Text(l.kanbanArchived), leading: const Icon(Icons.archive_outlined)),
      if (cards.isEmpty && goals.isEmpty) ListTile(title: Text(l.kanbanNoCards)),
      for (final card in cards)
        ListTile(leading: const Icon(Icons.view_kanban_outlined), title: Text(card.title), subtitle: Text(l.kanbanArchived), trailing: IconButton(icon: const Icon(Icons.unarchive_outlined), tooltip: l.kanbanRestore, onPressed: () async { await _repo!.restoreCard(card.id); if (ctx.mounted) Navigator.pop(ctx); _refresh(); })),
      for (final goal in goals)
        ListTile(leading: const Icon(Icons.flag_outlined), title: Text(goal.title), subtitle: Text(l.kanbanArchived), trailing: IconButton(icon: const Icon(Icons.unarchive_outlined), tooltip: l.kanbanRestore, onPressed: () async { await _repo!.restoreGoal(goal.id); if (ctx.mounted) Navigator.pop(ctx); _refresh(); })),
    ])));
  }

  Future<void> _delete(KanbanCard card) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(content: Text(l.kanbanDeleteConfirm), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.kanbanCancel)), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.kanbanDeletePermanently))]));
    if (ok == true) { await _repo!.deleteCardPermanently(card.id); _refresh(); }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(appBar: AppBar(title: Text(l.kanban)), body: Center(child: Text(_error!)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.kanbanBoard),
        actions: [
          IconButton(tooltip: l.kanbanAddCard, onPressed: _byGoal && _goalId == null ? null : _addCard, icon: const Icon(Icons.add_rounded)),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'goals':
                  if (!await _pro(OrahFeature.kanbanGoals) || !mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => KanbanGoalsScreen(repository: _repo)));
                case 'create_goal':
                  await _addGoal();
                case 'archived':
                  await _showArchived();
                case 'multiple_timers':
                  final next = !_allowMultipleTimers;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('orah_kanban_allow_multiple_timers', next);
                  if (mounted) setState(() => _allowMultipleTimers = next);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'goals', child: Text(l.kanbanGoals)),
              PopupMenuItem(value: 'create_goal', child: Text(l.kanbanCreateGoal)),
              PopupMenuItem(value: 'archived', child: Text(l.kanbanArchived)),
              CheckedPopupMenuItem(value: 'multiple_timers', checked: _allowMultipleTimers, child: Text(l.kanbanAllowMultipleTimers)),
            ],
          ),
        ],
      ),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            Expanded(child: SegmentedButton<bool>(
              segments: [ButtonSegment(value: false, label: Text(l.kanbanAllCards)), ButtonSegment(value: true, label: Text(l.kanbanByGoal))],
              selected: {_byGoal},
              onSelectionChanged: (v) async {
                if (v.first && !await _pro(OrahFeature.kanbanGoals)) return;
                if (!mounted) return;
                setState(() { _byGoal = v.first; _goalId = null; _cards = _repo!.watchCards(); });
              },
            )),
            const SizedBox(width: 8),
            FutureBuilder<int>(future: _todaySecondsFuture, builder: (context, snap) {
              final s = snap.data ?? 0;
              return Text('${s ~/ 3600}h ${(s % 3600) ~/ 60}m', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
            }),
          ]),
        ),
        if (_byGoal)
          SizedBox(height: 48, child: StreamBuilder<List<KanbanGoal>>(stream: _goals, builder: (context, snap) {
            final goals = snap.data ?? const <KanbanGoal>[];
            if (goals.isEmpty) return Center(child: Text(l.kanbanNoGoals));
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: goals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final g = goals[i];
                return ChoiceChip(label: Text(g.title), selected: _goalId == g.id, onSelected: (_) => setState(() { _goalId = g.id; _cards = _repo!.watchCards(goalId: g.id); }));
              },
            );
          })),
        Expanded(child: StreamBuilder<List<KanbanCard>>(stream: _cards, initialData: const <KanbanCard>[], builder: (context, snap) {
          if (_byGoal && _goalId == null) return Center(child: Text(l.kanbanNoGoals));
          final cards = snap.data ?? const <KanbanCard>[];
          const statuses = [KanbanStatus.todo, KanbanStatus.inProgress, KanbanStatus.done];
          final wide = MediaQuery.sizeOf(context).width >= 840;
          if (wide) {
            return Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final s in statuses) Expanded(child: _column(s, cards, l))]));
          }
          return DefaultTabController(length: 3, child: Column(children: [
            TabBar(tabs: [
              Tab(text: '${l.kanbanTodo} (${_count(cards, KanbanStatus.todo)})'),
              Tab(text: '${l.kanbanInProgress} (${_count(cards, KanbanStatus.inProgress)})'),
              Tab(text: '${l.kanbanDone} (${_count(cards, KanbanStatus.done)})'),
            ]),
            Expanded(child: TabBarView(children: [for (final s in statuses) _column(s, cards, l)])),
          ]));
        })),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _byGoal && _goalId == null ? null : _addCard, tooltip: l.kanbanAddCard, child: const Icon(Icons.add)),
    );
  }

  int _count(List<KanbanCard> cards, KanbanStatus s) => cards.where((c) => c.status == s).length;

  String _statusTitle(KanbanStatus status, AppLocalizations l) => switch (status) {
    KanbanStatus.todo => l.kanbanTodo,
    KanbanStatus.inProgress => l.kanbanInProgress,
    KanbanStatus.done => l.kanbanDone,
  };

  Color _priorityColor(KanbanPriority p, ColorScheme cs) => switch (p) {
    KanbanPriority.high => cs.error,
    KanbanPriority.medium => cs.tertiary,
    KanbanPriority.low => cs.outline,
  };

  Widget _column(KanbanStatus status, List<KanbanCard> all, AppLocalizations l) {
    final theme = Theme.of(context);
    final cards = all.where((c) => c.status == status).toList();
    final title = _statusTitle(status, l);
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: Row(children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)), child: Text('${cards.length}', style: theme.textTheme.labelSmall)),
        ])),
        Expanded(child: DragTarget<KanbanCard>(
          onWillAcceptWithDetails: (d) => d.data.status != status,
          onAcceptWithDetails: (d) async => _moveCardWithUndo(d.data, status),
          builder: (context, candidate, rejected) {
            final highlight = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(color: highlight ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25) : null, borderRadius: BorderRadius.circular(12)),
              child: cards.isEmpty
                ? Center(child: Text(l.kanbanNoCards, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    itemCount: cards.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;
                      await _repo!.reorderCard(cards[oldIndex], newIndex);
                      _refresh();
                    },
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return LongPressDraggable<KanbanCard>(
                        key: ValueKey(card.id),
                        data: card,
                        feedback: Material(elevation: 6, borderRadius: BorderRadius.circular(12), child: SizedBox(width: 260, child: Opacity(opacity: 0.9, child: _cardTile(card, l)))),
                        childWhenDragging: Opacity(opacity: 0.35, child: _cardTile(card, l)),
                        child: _cardTile(card, l),
                      );
                    },
                  ),
            );
          },
        )),
      ]),
    );
  }

  Widget _cardTile(KanbanCard card, AppLocalizations l) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editCard(card),
        onLongPress: () => _showCardLinks(card),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 8, height: 8, decoration: BoxDecoration(color: _priorityColor(card.priority, theme.colorScheme), shape: BoxShape.circle))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (card.description.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(card.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                if (card.dueDate != null) _metaChip(Icons.event_outlined, '${card.dueDate!.day}/${card.dueDate!.month}'),
                if (card.colorLabel != null && card.colorLabel!.isNotEmpty) _metaChip(Icons.label_outline, card.colorLabel!),
                FutureBuilder<int>(future: _secondsForCard(card.id), builder: (context, snap) {
                  final s = snap.data ?? 0;
                  if (s <= 0) return const SizedBox.shrink();
                  return _metaChip(Icons.timer_outlined, '${s ~/ 3600}h ${(s % 3600) ~/ 60}m');
                }),
                FutureBuilder<bool>(future: _isCardTimerRunning(card.id), builder: (context, snap) {
                  if (snap.data != true) return const SizedBox.shrink();
                  return Icon(Icons.circle, size: 8, color: theme.colorScheme.primary);
                }),
              ]),
            ])),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) async {
                switch (v) {
                  case 'edit': await _editCard(card);
                  case 'links': await _showCardLinks(card);
                  case 'todo': await _moveCardWithUndo(card, KanbanStatus.todo);
                  case 'progress': await _moveCardWithUndo(card, KanbanStatus.inProgress);
                  case 'done': await _moveCardWithUndo(card, KanbanStatus.done);
                  case 'timer': await _timer(card);
                  case 'archive': await _archive(card);
                  case 'delete': await _delete(card);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.kanbanEditCard)),
                PopupMenuItem(value: 'links', child: Text(l.kanbanLinks)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'todo', child: Text(l.kanbanTodo)),
                PopupMenuItem(value: 'progress', child: Text(l.kanbanInProgress)),
                PopupMenuItem(value: 'done', child: Text(l.kanbanDone)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'timer', child: Text(l.kanbanStartPauseTimer)),
                PopupMenuItem(value: 'archive', child: Text(l.kanbanArchive)),
                PopupMenuItem(value: 'delete', child: Text(l.kanbanDeletePermanently)),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
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
  void dispose() { _title.dispose(); _description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.kanbanCreateGoal),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l.kanbanCardTitle)),
        TextField(controller: _description, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: l.kanbanDescription)),
        ListTile(contentPadding: EdgeInsets.zero, title: Text(l.kanbanDueDate), subtitle: Text(_targetDate == null ? '—' : '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'), trailing: IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: _targetDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setState(() => _targetDate = picked);
        })),
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
  const _KanbanCardDraft({required this.title, required this.description, required this.priority, this.dueDate, this.clearDueDate = false, this.colorLabel, this.checklist = const []});
  final String title;
  final String description;
  final KanbanPriority priority;
  final DateTime? dueDate;
  final bool clearDueDate;
  final String? colorLabel;
  final List<String> checklist;
}

class _KanbanCardEditor extends StatefulWidget {
  const _KanbanCardEditor({required this.title, required this.saveLabel, this.initialTitle, this.initialDescription, this.initialPriority, this.initialDueDate, this.initialColorLabel, this.initialChecklist});
  final String title;
  final String saveLabel;
  final String? initialTitle;
  final String? initialDescription;
  final KanbanPriority? initialPriority;
  final DateTime? initialDueDate;
  final String? initialColorLabel;
  final List<String>? initialChecklist;
  @override
  State<_KanbanCardEditor> createState() => _KanbanCardEditorState();
}

class _KanbanCardEditorState extends State<_KanbanCardEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _color;
  late final TextEditingController _checklist;
  late KanbanPriority _priority;
  DateTime? _dueDate;
  bool _clearDueDate = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle ?? '');
    _description = TextEditingController(text: widget.initialDescription ?? '');
    _color = TextEditingController(text: widget.initialColorLabel ?? '');
    _checklist = TextEditingController(text: (widget.initialChecklist ?? const []).join('\n'));
    _priority = widget.initialPriority ?? KanbanPriority.medium;
    _dueDate = widget.initialDueDate;
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); _color.dispose(); _checklist.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dueLabel = _dueDate == null ? '—' : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}';
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
          onChanged: (v) { if (v != null) setState(() => _priority = v); },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.kanbanDueDate),
          subtitle: Text(dueLabel),
          trailing: Wrap(children: [
            IconButton(icon: const Icon(Icons.calendar_month_outlined), onPressed: () async {
              final picked = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() { _dueDate = picked; _clearDueDate = false; });
            }),
            if (_dueDate != null) IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _dueDate = null; _clearDueDate = true; })),
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
            checklist: _checklist.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          ));
        }, child: Text(widget.saveLabel)),
      ],
    );
  }
}
