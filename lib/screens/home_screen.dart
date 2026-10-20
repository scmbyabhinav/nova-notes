import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/orah_reminder_service.dart';
import '../core/widgets/orah_wordmark.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../core/navigation/orah_navigation.dart';

import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../services/prompt_service.dart';
import 'note_editor_screen.dart';
import 'reflection_prompt_screen.dart';
import 'archived_notes_screen.dart';
import 'search_screen.dart';
import 'orah_features_screen.dart';
import 'vault_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isActive = true, this.onNewNote, this.onVoiceCapture, this.onChecklist, this.onSettings, this.onNotes, this.onFolders, this.onFavorites, this.onStatistics, this.onCalendarHistory});

  final bool isActive;
  final Future<void> Function()? onNewNote;
  final Future<void> Function()? onVoiceCapture;
  final Future<void> Function()? onChecklist;
  final VoidCallback? onSettings;
  final VoidCallback? onNotes;
  final VoidCallback? onFolders;
  final VoidCallback? onFavorites;
  final VoidCallback? onStatistics;
  final VoidCallback? onCalendarHistory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  bool _gridView = true;
  bool _showFeatures = false;
  bool _hideDailyPrompt = false;
  bool _loading = true;
  String? _loadError;
  String _sort = 'updated';
  String _activeFilter = 'all';
  List<Note> _notes = const [];
  String? _selectedNoteId;
  StreamSubscription<List<Note>>? _notesSubscription;
  PageRoute<dynamic>? _subscribedRoute;
  int _notesLoadGeneration = 0;
  Timer? _trashSnackBarTimer;
  Timer? _reflectionCheckTimer;
  bool _openingScheduledReflection = false;

  // Resolve localized strings for callbacks and helpers outside build().
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _loadNotes();
    _reflectionCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkScheduledReflection());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScheduledReflection());
  }


  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Home and Settings remain mounted in an IndexedStack; route callbacks do
    // not fire when switching tabs, so refresh preferences when Home returns.
    if (!oldWidget.isActive && widget.isActive) {
      _loadPreferences();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        orahRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      orahRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    // Refresh persisted notes and display preferences when returning from another screen.
    _loadNotes();
    _loadPreferences();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile persisted state after Android suspends/resumes the app.
      _loadNotes();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gridView = prefs.getBool('orah_grid_view') ?? true;
      _sort = prefs.getString('orah_note_sort') ?? 'updated';
      _hideDailyPrompt = prefs.getBool('orah_hide_daily_prompt') ?? false;
    });
  }

  Future<void> _setDailyPromptHidden(bool hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('orah_hide_daily_prompt', hidden);
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _hideDailyPrompt = hidden);
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('orah_grid_view', _gridView);
    await prefs.setString('orah_note_sort', _sort);
  }

  Future<void> _loadNotes() async {
    final loadGeneration = ++_notesLoadGeneration;
    try {
      final repository = await NoteRepositoryProvider.instance().timeout(
        const Duration(seconds: 12),
      );

      // Keep one live subscription for the lifetime of HomeScreen.
      _notesSubscription ??= repository.watchNotes().listen(
        _applyNotes,
        onError: (Object error, StackTrace stack) {
          debugPrint('ORAH home notes stream failed: ${error.runtimeType}');
          if (!mounted) return;
          setState(() {
            _loadError = 'Notes could not be refreshed. Please retry.';
            _loading = false;
          });
        },
      );

      await repository.refresh().timeout(const Duration(seconds: 12));
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      final notes = await repository.getNotes().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      setState(() => _loadError = null);
      _applyNotes(notes);
    } catch (error, stack) {
      debugPrint('ORAH home notes load failed: ${error.runtimeType}: $error');
      debugPrintStack(stackTrace: stack);
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      setState(() {
        _loadError = 'Notes could not be loaded. Your saved data has not been cleared. Tap Retry.';
        _loading = false;
      });
    }
  }

  void _applyNotes(List<Note> notes) {
    if (!mounted) return;
    setState(() {
      _notes = notes.where((note) => !note.isLocked && !note.isTrashed).toList();
      _loading = false;
      if (_selectedNoteId != null && !_notes.any((note) => note.id == _selectedNoteId)) {
        _selectedNoteId = null;
      }
    });
  }

  void _selectNote(Note note) => setState(() => _selectedNoteId = note.id);

  Future<void> _openPromptNote(ReflectionPrompt prompt) async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          initialTitle: prompt.localizedText(Localizations.localeOf(context).languageCode),
          initialContent: '',
        ),
      ),
    );
    await _loadNotes();
  }

  Future<void> _openReflection() async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReflectionPromptScreen(repository: repository),
      ),
    );
    await _loadNotes();
  }

  Future<void> _checkScheduledReflection() async {
    if (!mounted || !widget.isActive || _openingScheduledReflection) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('orah_daily_reflection_enabled') ?? false)) return;
    final hour = prefs.getInt('orah_daily_reflection_hour') ?? 20;
    final minute = prefs.getInt('orah_daily_reflection_minute') ?? 0;
    final now = DateTime.now();
    if (now.hour * 60 + now.minute < hour * 60 + minute) return;
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (prefs.getString('orah_daily_reflection_last_shown') == today) return;
    _openingScheduledReflection = true;
    await prefs.setString('orah_daily_reflection_last_shown', today);
    try { await OrahReminderService.instance.scheduleDailyReflection(time: TimeOfDay(hour: hour, minute: minute)); } catch (_) {}
    try { await _openReflection(); } finally { _openingScheduledReflection = false; }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    orahRouteObserver.unsubscribe(this);
    _notesSubscription?.cancel();
    _trashSnackBarTimer?.cancel();
    _reflectionCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _openNote(Note note) async {
    final repository = await NoteRepositoryProvider.instance();

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          note: note,
        ),
      ),
    );

    // The editor persists before it closes. Re-read on return as a
    // deterministic lifecycle boundary in addition to the live stream.
    await _loadNotes();
  }

  Future<void> _updateNote(Note note, Note updated) async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(updated);
    // Reconcile the persisted snapshot as well as the live stream, so changes
    // are visible immediately without restarting the app.
    await repository.refresh();
    await _loadNotes();
  }

  Future<void> _restoreFromTrash(Note note) async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(note.copyWith(isTrashed: false, updatedAt: DateTime.now()));
    await _loadNotes();
    if (note.dueAt != null && note.dueAt!.isAfter(DateTime.now())) {
      await OrahReminderService.instance.schedule(noteId: note.id, title: note.title, when: note.dueAt!);
    }
    for (final item in note.checklistItems) {
      if (item.dueAt != null && !item.isDone && item.dueAt!.isAfter(DateTime.now())) {
        await OrahReminderService.instance.schedule(noteId: 'checklist:${item.id}', title: item.text, when: item.dueAt!, payloadNoteId: note.id);
      }
    }
  }

  Future<void> _showNoteMenu(Note note) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const OrahAssetIcon('pin'),
              title: Text(note.isPinned ? l10n.unpinNote : l10n.pinNote),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const OrahAssetIcon('star'),
              title: Text(
                note.isFavorite ? l10n.removeFavorite : l10n.addToFavorites,
              ),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(note.isArchived ? l10n.unarchiveNote : l10n.archiveNote),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n.duplicateNote),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.noteColor),
              onTap: () => Navigator.pop(context, 'color'),
            ),
            ListTile(
              leading: const OrahAssetIcon('trash'),
              title: Text(l10n.moveToTrash),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'duplicate':
        final repository = await NoteRepositoryProvider.instance();
        final duplicate = note.copyWith(
          title: l10n.duplicateTitle(note.title),
          updatedAt: DateTime.now(),
        );
        final duplicateId = '${DateTime.now().microsecondsSinceEpoch}_copy';
        final duplicateItems = note.checklistItems.map((item) => ChecklistItem(
          id: '${duplicateId}_${item.id}', text: item.text, isDone: item.isDone, dueAt: item.dueAt,
        )).toList();
        await repository.saveNote(Note(
          id: duplicateId,
          title: duplicate.title,
          content: duplicate.content,
          type: duplicate.type,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: duplicate.folderId,
          tags: duplicate.tags,
          attachments: const [],
          checklistItems: duplicateItems,
          color: duplicate.color,
          isPinned: false,
          isFavorite: false,
          isArchived: false,
          isLocked: false,
          isTrashed: false,
          dueAt: duplicate.dueAt,
        ));
        if (duplicate.dueAt != null) {
          await OrahReminderService.instance.schedule(noteId: duplicateId, title: duplicate.title, when: duplicate.dueAt!);
        }
        for (final item in duplicateItems) {
          if (item.dueAt != null && !item.isDone) {
            await OrahReminderService.instance.schedule(noteId: 'checklist:${item.id}', title: item.text, when: item.dueAt!, payloadNoteId: duplicateId);
          }
        }
        return;
      case 'color':
        await _showColorPicker(note);
        return;
      case 'pin':
        await _updateNote(
          note,
          note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()),
        );
        return;
      case 'favorite':
        await _updateNote(
          note,
          note.copyWith(
            isFavorite: !note.isFavorite,
            updatedAt: DateTime.now(),
          ),
        );
        return;
      case 'archive':
        await _updateNote(
          note,
          note.copyWith(
            isArchived: !note.isArchived,
            updatedAt: DateTime.now(),
          ),
        );
        return;
      case 'delete':
        final repository = await NoteRepositoryProvider.instance();
        await repository.saveNote(note.copyWith(isTrashed: true, updatedAt: DateTime.now(), isPinned: false, isFavorite: false));
        await HapticFeedback.mediumImpact();
        await _loadNotes();
        await OrahReminderService.instance.cancel(note.id);
        for (final item in note.checklistItems) {
          await OrahReminderService.instance.cancel('checklist:${item.id}');
        }
        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        // Replace any older snackbar and give this confirmation a bounded
        // lifetime so the Undo affordance cannot remain stuck on screen.
        _trashSnackBarTimer?.cancel();
        messenger.hideCurrentSnackBar();
        late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> trashSnackBar;
        trashSnackBar = messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.movedToTrash),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () {
                _trashSnackBarTimer?.cancel();
                trashSnackBar.close();
                _restoreFromTrash(note);
              },
            ),
          ),
        );
        // Enforce dismissal even when Android accessibility timeout settings
        // extend action-bearing SnackBars beyond their configured duration.
        _trashSnackBarTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) trashSnackBar.close();
        });
        return;
    }
  }

  Future<void> _showColorPicker(Note note) async {
    const colors = <Color>[Color(0xFFFFF3C4), Color(0xFFDDF7E8), Color(0xFFDCEBFF), Color(0xFFF1DFFF), Color(0xFFFFE0D2)];
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [InkWell(
              onTap: () => Navigator.pop(context, -1),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: note.color == null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: 2),
                ),
                child: const Icon(Icons.format_color_reset_outlined),
              ),
            ), ...[for (final color in colors) InkWell(
              onTap: () => Navigator.pop(context, color.toARGB32()),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: note.color == color.toARGB32() ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: 2),
                ),
              ),
            )]],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) return;
    final repository = await NoteRepositoryProvider.instance();
    final color = selected == -1 ? null : selected;
    await repository.saveNote(note.copyWith(color: color, clearColor: selected == -1, updatedAt: DateTime.now()));
  }

  String _localizedReflectionCategory(AppLocalizations l10n, String category) {
    switch (category) {
      case 'Gratitude': return l10n.reflectionCategoryGratitude;
      case 'Mindfulness': return l10n.reflectionCategoryMindfulness;
      case 'Personal Growth': return l10n.reflectionCategoryPersonalGrowth;
      case 'Relationships': return l10n.reflectionCategoryRelationships;
      case 'Self-Compassion': return l10n.reflectionCategorySelfCompassion;
      case 'Clarity': return l10n.reflectionCategoryClarity;
      case 'Possibility': return l10n.reflectionCategoryPossibility;
      case 'Daily Review': return l10n.reflectionCategoryDailyReview;
      case 'Purpose & Values': return l10n.reflectionCategoryPurposeValues;
      case 'Resilience': return l10n.reflectionCategoryResilience;
      case 'Creativity & Curiosity': return l10n.reflectionCategoryCreativityCuriosity;
      case 'Rest & Renewal': return l10n.reflectionCategoryRestRenewal;
      default: return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    bool isDailyReflection(Note note) =>
        note.tags.any((tag) => tag.toLowerCase() == 'reflection') ||
        note.title.trim().toLowerCase() == 'daily reflection';

    final pinned = _notes
        .where((note) => note.isPinned && !note.isArchived && !isDailyReflection(note))
        .toList();
    final recent = _notes.where((note) {
      final reflection = isDailyReflection(note);
      switch (_activeFilter) {
        case 'pinned':
          return note.isPinned && !note.isArchived && !reflection;
        case 'favorites':
          return note.isFavorite && !note.isArchived && !reflection;
        case 'checklists':
          return note.type == NoteType.checklist && !note.isArchived && !reflection;
        case 'archived':
          return note.isArchived && !reflection;
        case 'daily_reflection':
          return reflection;
        default:
          return !note.isArchived && !reflection;
      }
    }).toList()
      ..sort((a, b) {
        if (_sort == 'created') return b.createdAt.compareTo(a.createdAt);
        if (_sort == 'title') return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final completed = recent.where((n) => n.type == NoteType.checklist && n.checklistItems.isNotEmpty && n.checklistProgress == 1).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1100) {
          return _DesktopNotesLayout(
            notes: _notes,
            loading: _loading,
            selectedNoteId: _selectedNoteId,
            onSelect: _selectNote,
            onOpen: _openNote,
            onNewNote: widget.onNewNote,
            onVoiceCapture: widget.onVoiceCapture,
          );
        }

        return SafeArea(
          child: RefreshIndicator(
        onRefresh: _loadNotes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Tooltip(
                      message: _showFeatures ? l10n.hideOrahFeatures : l10n.showOrahFeatures,
                      child: Material(
                        elevation: 3,
                        color: theme.colorScheme.primary,
                        shape: const CircleBorder(),
                        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.24),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setState(() => _showFeatures = !_showFeatures),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                'assets/orah_header_icon.svg',
                                fit: BoxFit.contain,
                                semanticsLabel: l10n.orahFeaturesSemantics,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const OrahWordmark(fontSize: 34),
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeTagline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.vaultTooltip,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VaultScreen()),
                      ),
                      icon: const Icon(Icons.security_rounded, size: 24),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.calendarHistoryTooltip,
                      onPressed: widget.onCalendarHistory,
                      icon: const Icon(Icons.calendar_month_rounded, size: 24),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.statisticsTooltip,
                      onPressed: widget.onStatistics,
                      icon: const Icon(Icons.bar_chart_rounded, size: 24),
                    ),
                    IconButton.filledTonal(
                      tooltip: l10n.navDailyReflection,
                      onPressed: _openReflection,
                      icon: SvgPicture.asset(
                        'assets/daily_reflection_icon.svg',
                        width: 24,
                        height: 24,
                        semanticsLabel: l10n.navDailyReflection,
                      ),
                    ),
                    if (_showFeatures)
                      IconButton.filledTonal(
                        tooltip: l10n.appearanceTooltip,
                        onPressed: widget.onSettings,
                        icon: SvgPicture.asset(
                          'assets/appearance_icon.svg',
                          width: 26,
                          height: 26,
                          semanticsLabel: l10n.appearanceSemantics,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _showFeatures
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Card(
                          elevation: 1,
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.exploreOrah,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.homeSubtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ActionChip(
                                      avatar: const Icon(Icons.note_alt_outlined, size: 18),
                                      label: Text(l10n.navNotes),
                                      onPressed: widget.onNotes,
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.folder_outlined, size: 18),
                                      label: Text(l10n.navFolders),
                                      onPressed: widget.onFolders,
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.star_outline_rounded, size: 18),
                                      label: Text(l10n.navFavorites),
                                      onPressed: widget.onFavorites,
                                    ),
                                    ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      padding: const EdgeInsets.symmetric(horizontal: 7),
                                      avatar: const Icon(Icons.archive_outlined, size: 16),
                                      label: Text(l10n.navArchivedNotes),
                                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedNotesScreen())),
                                    ),
                                    ActionChip(
                                      avatar: SvgPicture.asset(
                                        'assets/daily_reflection_icon.svg',
                                        width: 20,
                                        height: 20,
                                      ),
                                      label: Text(l10n.navDailyReflection),
                                      onPressed: _openReflection,
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.mic_none_rounded, size: 18),
                                      label: Text(l10n.navVoiceCapture),
                                      onPressed: widget.onVoiceCapture,
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.checklist_rounded, size: 18),
                                      label: Text(l10n.navChecklists),
                                      onPressed: widget.onChecklist,
                                    ),
                                    ActionChip(
                                      avatar: SvgPicture.asset(
                                        'assets/appearance_icon.svg',
                                        width: 20,
                                        height: 20,
                                      ),
                                      label: Text(l10n.navAppearance),
                                      onPressed: widget.onSettings,
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.search_rounded, size: 18),
                                      label: Text(l10n.navSearch),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const SearchScreen()),
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.cloud_off_outlined, size: 18),
                                      label: Text(l10n.offlineAccess),
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const OrahFeaturesScreen()),
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: const Icon(Icons.ios_share_rounded, size: 18),
                                      label: Text(l10n.backupExport),
                                      onPressed: widget.onSettings,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  hintText: l10n.searchHint,
                  leading: const OrahAssetIcon('search'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchScreen(),
                      ),
                    );
                  },
                  trailing: [
                    IconButton(
                      tooltip: l10n.searchFiltersTooltip,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SearchScreen(),
                          ),
                        );
                      },
                      icon: const OrahAssetIcon('menu'),
                    ),
                  ],
                ),
              ),
            ),
            if (!_hideDailyPrompt)
              SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final prompt = PromptService.instance.getPromptOfDay();
                    return Material(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.58),
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _openPromptNote(prompt),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l10n.dailyInspiration.toUpperCase()}  •  ${_localizedReflectionCategory(l10n, prompt.category).toUpperCase()}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      prompt.localizedText(Localizations.localeOf(context).languageCode),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.lora(
                                        textStyle: theme.textTheme.titleMedium?.copyWith(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.tapToBeginNote,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.hideDailyInspiration,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _setDailyPromptHidden(true),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  children: [
                    for (final filter in [
                      ('all', l10n.navNotes, Icons.notes_rounded),
                      ('pinned', l10n.pinnedOnly, Icons.push_pin_outlined),
                      ('favorites', l10n.favorites, Icons.star_outline_rounded),
                      ('checklists', l10n.checklistType, Icons.checklist_rounded),
                      ('archived', l10n.archivedLabel, Icons.archive_outlined),
                      ('daily_reflection', l10n.navDailyReflection, Icons.auto_awesome_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            filter.$3,
                            size: 16,
                            color: _activeFilter == filter.$1
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          label: Text(filter.$2),
                          selected: _activeFilter == filter.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _activeFilter = filter.$1),
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                          selectedColor: Theme.of(context).colorScheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 12.5,
                            color: _activeFilter == filter.$1
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          side: BorderSide(
                            color: _activeFilter == filter.$1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loadError != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 42),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _loadError = null;
                            });
                            _loadNotes();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              if (_activeFilter == 'all' && pinned.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      l10n.pinned,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: pinned.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onLongPress: () => _showNoteMenu(pinned[index]),
                        child: _NoteCard(
                          note: pinned[index],
                          compact: true,
                          onTap: () => _openNote(pinned[index]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(
                        l10n.recentNotes,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (recent.isNotEmpty)
                        Text(
                          l10n.completedCountLabel(completed),
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: l10n.sortNotesTooltip,
                        initialValue: _sort,
                        onSelected: (value) async { setState(() => _sort = value); await _savePreferences(); },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'updated', child: Text(l10n.recentlyUpdated)),
                          PopupMenuItem(value: 'created', child: Text(l10n.recentlyCreated)),
                          PopupMenuItem(value: 'title', child: Text(l10n.titleAZ)),
                        ],
                        icon: const Icon(Icons.sort_rounded),
                      ),
                      IconButton(
                        tooltip: _gridView ? l10n.listView : l10n.gridView,
                        onPressed: () async {
                          setState(() => _gridView = !_gridView);
                          await _savePreferences();
                        },
                        icon: Icon(
                          _gridView
                              ? Icons.view_list_rounded
                              : Icons.grid_view_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (recent.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(theme: theme),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: _gridView
                      ? SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => GestureDetector(
                              onLongPress: () => _showNoteMenu(recent[index]),
                              child: _NoteCard(
                                note: recent[index],
                                onTap: () => _openNote(recent[index]),
                              ),
                            ),
                            childCount: recent.length,
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.90,
                          ),
                        )
                      : SliverList.builder(
                          itemCount: recent.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onLongPress: () =>
                                  _showNoteMenu(recent[index]),
                              child: _NoteCard(
                                note: recent[index],
                                compact: true,
                                onTap: () => _openNote(recent[index]),
                              ),
                            ),
                          ),
                        ),
                ),
            ],
          ],
        ),
      ),
        );
      },
    );
  }
}

class _DesktopNotesLayout extends StatelessWidget {
  const _DesktopNotesLayout({
    required this.notes,
    required this.loading,
    required this.selectedNoteId,
    required this.onSelect,
    required this.onOpen,
    required this.onNewNote,
    required this.onVoiceCapture,
  });

  final List<Note> notes;
  final bool loading;
  final String? selectedNoteId;
  final ValueChanged<Note> onSelect;
  final ValueChanged<Note> onOpen;
  final Future<void> Function()? onNewNote;
  final Future<void> Function()? onVoiceCapture;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final active = notes.where((n) => !n.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    Note? selected = active.isEmpty ? null : active.first;
    if (selectedNoteId != null) {
      for (final note in active) {
        if (note.id == selectedNoteId) {
          selected = note;
          break;
        }
      }
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          SizedBox(
            width: 250,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 18, 14),
                      child: Text(
                        l10n.notes,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: SearchBar(
                        hintText: AppLocalizations.of(context)!.searchLabel,
                        leading: const OrahAssetIcon('search', size: 19),
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: WidgetStatePropertyAll(
                          theme.colorScheme.surfaceContainerHighest.withValues(alpha: .7),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SearchScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SidebarLabel(label: l10n.notes),
                    _SidebarItem(
                      assetIcon: 'notes',
                      label: l10n.navNotes,
                      count: active.length,
                      selected: true,
                      onTap: () {},
                    ),
                    _SidebarItem(
                      assetIcon: 'star',
                      label: l10n.favorites,
                      count: active.where((n) => n.isFavorite).length,
                      onTap: () {},
                    ),
                    _SidebarItem(
                      icon: Icons.access_time_rounded,
                      label: l10n.recentNotes,
                      count: active.length > 8 ? 8 : active.length,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    _SidebarLabel(label: l10n.folders),
                    ..._folderEntries(active, l10n),
                    const Spacer(),
                    if (onNewNote != null || onVoiceCapture != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        child: Row(
                          children: [
                            if (onNewNote != null)
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: onNewNote,
                                  icon: OrahAssetIcon('new-note', size: 18, color: theme.colorScheme.onPrimary),
                                  label: Text(AppLocalizations.of(context)!.newNoteLabel),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            if (onNewNote != null && onVoiceCapture != null)
                              const SizedBox(width: 8),
                            if (onVoiceCapture != null)
                              SizedBox(
                                width: 48,
                                height: 44,
                                child: IconButton.filledTonal(
                                  tooltip: AppLocalizations.of(context)!.microphoneTooltip,
                                  onPressed: onVoiceCapture,
                                  icon: OrahAssetIcon('microphone', color: theme.colorScheme.onSecondaryContainer),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 25, 16, 18),
                      child: Row(
                        children: [
                          Text(
                            l10n.navNotes,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            l10n.activeNotesCount(active.length),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (active.isEmpty)
                      Expanded(child: Center(child: Text(AppLocalizations.of(context)!.noNotesYet)))
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                          itemCount: active.length,
                          itemBuilder: (context, index) {
                            final note = active[index];
                            return _DesktopNoteRow(
                              note: note,
                              selected: note.id == selected?.id,
                              onTap: () => onSelect(note),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: selected == null
                  ? Center(
                      child: Text(
                        l10n.selectNotePrompt,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _DesktopNotePreview(
                      note: selected,
                      onEdit: () => onOpen(selected!),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _folderEntries(List<Note> active, AppLocalizations l10n) {
    final folders = <String, int>{};
    for (final note in active) {
      final id = note.folderId;
      if (id != null && id.trim().isNotEmpty) {
        folders[id] = (folders[id] ?? 0) + 1;
      }
    }
    if (folders.isEmpty) {
      return [
        _SidebarItem(
          assetIcon: 'folder',
          label: l10n.folders,
          onTap: () {},
        ),
      ];
    }
    return folders.entries.take(5).map((entry) {
      return _SidebarItem(
        assetIcon: 'folder',
        label: entry.key,
        count: entry.value,
        onTap: () {},
      );
    }).toList();
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 12, 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    this.icon,
    this.assetIcon,
    required this.label,
    this.count,
    this.selected = false,
    required this.onTap,
  }) : assert(icon != null || assetIcon != null);

  final IconData? icon;
  final String? assetIcon;
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: .72)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                if (assetIcon != null)
                  OrahAssetIcon(
                    assetIcon!,
                    size: 18,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  )
                else
                  Icon(
                    icon!,
                    size: 18,
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNoteRow extends StatelessWidget {
  const _DesktopNoteRow({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final Note note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final body = note.isLocked
        ? l10n.lockedContent
        : note.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: .68)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.trim().isEmpty ? l10n.untitledNote : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  '${_formatDate(context, note.updatedAt)}  ·  ${note.folderId ?? l10n.notes}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNotePreview extends StatelessWidget {
  const _DesktopNotePreview({
    required this.note,
    required this.onEdit,
  });

  final Note note;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final body = note.content.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 22, 10),
          child: Row(
            children: [
              Text(
                '${_formatDate(context, note.updatedAt)}  ·  ${note.folderId ?? l10n.notes}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: note.isPinned ? AppLocalizations.of(context)!.unpinTooltip : AppLocalizations.of(context)!.pinTooltip,
                onPressed: () {},
                icon: const OrahAssetIcon('pin'),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context)!.favoriteTooltip,
                onPressed: () {},
                icon: const OrahAssetIcon('star'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 8, 48, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.trim().isEmpty ? l10n.untitledNote : note.title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.1,
                  ),
                ),
                const SizedBox(height: 14),
                if (note.type == NoteType.checklist)
                  _DesktopChecklistPreview(note: note)
                else
                  SelectableText(
                    body.isEmpty ? l10n.desktopNoteEmpty : body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.7,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(AppLocalizations.of(context)!.editNoteLabel),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopChecklistPreview extends StatelessWidget {
  const _DesktopChecklistPreview({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: note.checklistItems.map((item) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            item.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
          ),
          title: Text(
            item.text,
            style: TextStyle(
              decoration: item.isDone ? TextDecoration.lineThrough : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _NoteText extends StatelessWidget {
  const _NoteText({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.isLocked ? l10n.privateNote : (note.title.isEmpty ? l10n.untitledNote : note.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        if (note.isLocked) ...[
          Text(AppLocalizations.of(context)!.lockedContent, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ] else if (note.type == NoteType.checklist && note.checklistItems.isNotEmpty) ...[
          Text(
            '${note.completedChecklistItems}/${note.checklistItems.length} ${l10n.completedLabel}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: note.checklistProgress, minHeight: 5),
          ),
        ] else
          Text(
            note.content.isEmpty ? l10n.noContentLabel : note.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 14, height: 1.35, color: const Color(0xFF5B5B66)),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF8CE7BE).withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 52,
                color: Color(0xFF1D8A63),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.noNotesYet,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D4D37),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyNotesHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF6A9A84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRelativeTime(BuildContext context, AppLocalizations l10n, DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return l10n.justNow;
  if (difference.inMinutes < 60) return '${difference.inMinutes} ${l10n.minutesAgoSuffix}';
  if (difference.inHours < 24) return '${difference.inHours} ${l10n.hoursAgoSuffix}';
  if (difference.inDays < 7) return '${difference.inDays} ${l10n.daysAgoSuffix}';
  return _formatDate(context, date);
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatShortDate(date.toLocal());
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    this.compact = false,
  });

  final Note note;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = note.isLocked
        ? l10n.privateNote
        : (note.title.trim().isEmpty ? l10n.untitledNote : note.title);
    final contentPreview = note.isLocked
        ? l10n.lockedContent
        : note.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    final body = contentPreview.isNotEmpty
        ? contentPreview
        : (note.type == NoteType.checklist
            ? note.checklistItems.take(2).map((item) => item.text).join(' · ')
            : '');
    final cardColor = note.color == null
        ? theme.colorScheme.surface
        : Color(note.color!);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.10),
      clipBehavior: Clip.antiAlias,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          width: 0.7,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (note.isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.push_pin_rounded,
                        size: 15, color: theme.colorScheme.primary),
                  ],
                  if (note.isFavorite) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.star_rounded,
                        size: 16, color: theme.colorScheme.primary),
                  ],
                ],
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatRelativeTime(context, l10n, note.updatedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (note.type == NoteType.checklist &&
                      note.checklistItems.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle_outline_rounded,
                        size: 13, color: theme.colorScheme.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${note.completedChecklistItems}/${note.checklistItems.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (note.attachments.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.attach_file_rounded,
                        size: 14, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
