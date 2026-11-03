import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../core/utils/lifecycle_timeout.dart';
import '../core/utils/note_tag_filter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/orah_reminder_service.dart';
import '../core/widgets/orah_wordmark.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../core/navigation/orah_navigation.dart';

import '../data/repositories/note_repository_provider.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../services/prompt_service.dart';
import 'note_editor_screen.dart';
import 'reflection_prompt_screen.dart';
import 'archived_notes_screen.dart';
import 'search_screen.dart';
import 'orah_features_screen.dart';
import 'vault_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.isActive = true, this.onNewNote, this.onVoiceCapture, this.onChecklist, this.onSettings, this.onNotes, this.onFolders, this.onFavorites, this.onStatistics, this.onCalendarHistory, this.onKanban});

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
  final VoidCallback? onKanban;

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
  String? _activeTagFilter;
  List<Note> _notes = const [];
  String? _selectedNoteId;
  StreamSubscription<List<Note>>? _notesSubscription;
  PageRoute<dynamic>? _subscribedRoute;
  int _notesLoadGeneration = 0;
  Timer? _trashSnackBarTimer;
  Timer? _reflectionCheckTimer;
  bool _openingScheduledReflection = false;
  final LifecycleTimeout _loadTimeout = LifecycleTimeout();

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
      final repository = await _loadTimeout.run(NoteRepositoryProvider.instance(), const Duration(seconds: 8));

      // Keep one live subscription for the lifetime of HomeScreen.
      _notesSubscription ??= repository.watchNotes().listen(
        _applyNotes,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('ORAH notes stream failed: $error');
        },
      );

      await _loadTimeout.run(repository.refresh(), const Duration(seconds: 8));
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      final notes = await _loadTimeout.run(repository.getNotes(), const Duration(seconds: 8));
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      setState(() => _loadError = null);
      _applyNotes(notes);
    } catch (error, stackTrace) {
      debugPrint('ORAH home notes load failed: $error\\n$stackTrace');
      if (!mounted || loadGeneration != _notesLoadGeneration) return;
      setState(() {
        _loading = false;
        _loadError = 'Storage error (${error.runtimeType}). Your saved notes have not been deleted. Tap Retry to try again.';
      });
    }
  }

  void _applyNotes(List<Note> notes) {
    if (!mounted) return;
    final availableTags = collectNoteTags(
      notes.where((note) => !note.isLocked && !note.isTrashed),
    );
    setState(() {
      _notes = notes.where((note) => !note.isLocked && !note.isTrashed).toList();
      if (_activeTagFilter != null &&
          !availableTags.any((tag) => tag.toLowerCase() == _activeTagFilter!.trim().toLowerCase())) {
        _activeTagFilter = null;
      }
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
          initialTitle: prompt.text,
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
    _loadTimeout.dispose();
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
              leading: const Icon(Icons.drive_file_rename_outline_rounded),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline_rounded),
              title: const Text('Move to folder'),
              onTap: () => Navigator.pop(context, 'move_folder'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Copy to folder'),
              onTap: () => Navigator.pop(context, 'copy_folder'),
            ),
            ListTile(
              leading: const OrahAssetIcon('pin'),
              title: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: const OrahAssetIcon('star'),
              title: Text(
                note.isFavorite ? 'Remove favorite' : 'Add to favorites',
              ),
              onTap: () => Navigator.pop(context, 'favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(note.isArchived ? 'Unarchive' : 'Archive'),
              onTap: () => Navigator.pop(context, 'archive'),
            ),
            ListTile(
              leading: const Icon(Icons.merge_type_rounded),
              title: const Text('Merge with…'),
              subtitle: const Text('Combine this note with another'),
              onTap: () => Navigator.pop(context, 'merge'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate note'),
              onTap: () => Navigator.pop(context, 'duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Note color'),
              onTap: () => Navigator.pop(context, 'color'),
            ),
            ListTile(
              leading: const OrahAssetIcon('trash'),
              title: const Text('Move to Trash'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case 'rename':
        await _renameNote(note);
        return;
      case 'move_folder':
        await _moveOrCopyNoteToFolder(note, copy: false);
        return;
      case 'copy_folder':
        await _moveOrCopyNoteToFolder(note, copy: true);
        return;
      case 'merge':
        await _mergeNoteWithAnother(note);
        return;
      case 'duplicate':
        final repository = await NoteRepositoryProvider.instance();
        final duplicate = note.copyWith(
          title: '${note.title} (Copy)',
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
            content: const Text('Moved to trash'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
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

  Future<void> _renameNote(Note note) async {
    final controller = TextEditingController(text: note.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note title', hintText: 'Enter a title'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || title == null) return;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A note title cannot be empty.')));
      return;
    }
    if (title == note.title) return;
    await _updateNote(note, note.copyWith(title: title, updatedAt: DateTime.now()));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note renamed.')));
  }

  Future<void> _moveOrCopyNoteToFolder(Note note, {required bool copy}) async {
    final folderRepository = await FolderRepositoryProvider.instance();
    final folders = await folderRepository.getFolders();
    if (!mounted) return;
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a folder first, then you can file notes in it.')));
      return;
    }
    final selectedFolderId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy ? 'Copy note to folder' : 'Move note to folder'),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final folder in folders)
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder.name),
                  subtitle: folder.id == note.folderId ? const Text('Current folder') : null,
                  onTap: () => Navigator.pop(dialogContext, folder.id),
                ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel'))],
      ),
    );
    if (!mounted || selectedFolderId == null) return;
    if (!copy && selectedFolderId == note.folderId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This note is already in that folder.')));
      return;
    }
    final now = DateTime.now();
    if (!copy) {
      await _updateNote(note, note.copyWith(folderId: selectedFolderId, updatedAt: now));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note moved to folder.')));
      return;
    }
    final duplicateId = 'orah_copy_${now.microsecondsSinceEpoch}';
    final copiedChecklist = note.checklistItems.map((item) => ChecklistItem(
      id: '${duplicateId}_${item.id}',
      text: item.text,
      isDone: item.isDone,
      dueAt: item.dueAt,
    )).toList();
    final duplicate = Note(
      id: duplicateId,
      title: note.title.trim().isEmpty ? 'Untitled note (Copy)' : '${note.title} (Copy)',
      content: note.content,
      type: note.type,
      createdAt: now,
      updatedAt: now,
      folderId: selectedFolderId,
      tags: note.tags,
      linkedNoteIds: note.linkedNoteIds,
      attachments: note.attachments,
      checklistItems: copiedChecklist,
      color: note.color,
      isPinned: false,
      isFavorite: false,
      isArchived: false,
      isLocked: false,
      isTrashed: false,
      isInbox: false,
      dueAt: note.dueAt,
      mood: note.mood,
      imagePath: note.imagePath,
    );
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(duplicate);
    await _loadNotes();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copy saved to folder.')));
  }

  Future<void> _mergeNoteWithAnother(Note target) async {
    if (target.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock private notes before merging.')),
      );
      return;
    }
    final repository = await NoteRepositoryProvider.instance();
    final notes = (await repository.getNotes())
      .where((note) => note.id != target.id && !note.isTrashed && !note.isLocked)
      .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (!mounted) return;
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create another note before merging.')),
      );
      return;
    }
    final source = await showDialog<Note>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Merge with…'),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('The selected note will be combined into this note and removed after confirmation.'),
              const SizedBox(height: 8),
              for (final candidate in notes)
                ListTile(
                  leading: const Icon(Icons.note_alt_outlined),
                  title: Text(candidate.title.trim().isEmpty ? 'Untitled note' : candidate.title),
                  subtitle: Text(candidate.content.trim().replaceAll(RegExp(r'\\s+'), ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(dialogContext, candidate),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
        ],
      ),
    );
    if (!mounted || source == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm merge'),
        content: Text('Merge "${source.title.isEmpty ? 'Untitled note' : source.title}" into "${target.title.isEmpty ? 'Untitled note' : target.title}"? The source note will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Merge notes')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final now = DateTime.now();
    final sections = <String>[];
    if (target.content.trim().isNotEmpty) {
      sections.add(target.content.trim());
    }
    if (source.content.trim().isNotEmpty) {
      sections.add('---\nMerged from: ${source.title.trim().isEmpty ? 'Untitled note' : source.title.trim()}\n\n${source.content.trim()}');
    }
    final mergedChecklist = <ChecklistItem>[
      ...target.checklistItems,
      ...source.checklistItems.map((item) => ChecklistItem(
        id: '${target.id}_merged_${now.microsecondsSinceEpoch}_${item.id}',
        text: item.text,
        isDone: item.isDone,
        dueAt: item.dueAt,
      )),
    ];
    final linkedIds = <String>{
      ...target.linkedNoteIds,
      ...source.linkedNoteIds,
      source.id,
    }..remove(target.id)..remove(source.id);
    final merged = target.copyWith(
      title: target.title.trim().isNotEmpty ? target.title : source.title,
      content: sections.join('\n\n'),
      type: target.type == NoteType.checklist && source.type == NoteType.checklist
          ? NoteType.checklist
          : NoteType.text,
      updatedAt: now,
      tags: {...target.tags, ...source.tags}.toList(),
      attachments: {...target.attachments, ...source.attachments}.toList(),
      checklistItems: mergedChecklist,
      linkedNoteIds: linkedIds.toList(),
      dueAt: target.dueAt ?? source.dueAt,
    );

    try {
      await repository.saveNote(merged);
      // Redirect other notes' links to the surviving note before removing the source.
      final allNotes = await repository.getNotes();
      for (final note in allNotes) {
        if (note.id == target.id || note.id == source.id || !note.linkedNoteIds.contains(source.id)) continue;
        final updatedLinks = <String>{...note.linkedNoteIds, target.id}..remove(source.id);
        await repository.saveNote(note.copyWith(linkedNoteIds: updatedLinks.toList(), updatedAt: now));
      }
      await repository.deleteNote(source.id);
      if (!mounted) return;
      await _loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes merged successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not merge notes: $error')),
      );
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
    final updated = note.copyWith(
      color: color,
      clearColor: selected == -1,
      updatedAt: DateTime.now(),
    );
    await repository.saveNote(updated);
    if (!mounted) return;
    // Update the visible cards immediately; don't make the user leave Home
    // just to see the new colour.
    setState(() {
      _notes = _notes.map((item) => item.id == updated.id ? updated : item).toList();
    });
    await repository.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    bool isDailyReflection(Note note) =>
        note.tags.any((tag) => tag.toLowerCase() == 'reflection') ||
        note.title.trim().toLowerCase() == 'daily reflection';

    final tagFilteredNotes = filterNotesByTag(_notes, _activeTagFilter);
    final pinned = tagFilteredNotes
        .where((note) => note.isPinned && !note.isArchived && !isDailyReflection(note))
        .toList();
    final recent = tagFilteredNotes.where((note) {
      final reflection = isDailyReflection(note);
      switch (_activeFilter) {
        case 'inbox':
          return note.isInbox && !note.isArchived && !reflection;
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
          // Pinned notes already have their own section above Recent Notes.
          // Keep them out of the default recent feed to avoid duplicate-looking cards.
          return !note.isArchived && !note.isPinned && !reflection;
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
        final compactHeader = constraints.maxWidth < 600;
        if (constraints.maxWidth >= 1100) {
          return _DesktopNotesLayout(
            notes: tagFilteredNotes,
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
                      message: _showFeatures ? 'Hide Orah features' : 'Show Orah features',
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
                                semanticsLabel: 'Orah features',
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
                          OrahWordmark(fontSize: compactHeader ? 27 : 34, fontWeight: FontWeight.w700),
                          const SizedBox(height: 2),
                          if (!compactHeader) Text(
                            'Think it. Write it. Keep it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Vault / Locked Notes',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const VaultScreen()),
                      ),
                      icon: const Icon(Icons.security_rounded, size: 24),
                    ),
                    if (!compactHeader) IconButton.filledTonal(
                      tooltip: 'Calendar & history',
                      onPressed: widget.onCalendarHistory,
                      icon: const Icon(Icons.calendar_month_rounded, size: 24),
                    ),
                    if (!compactHeader) IconButton.filledTonal(
                      tooltip: 'Mood & insights',
                      onPressed: widget.onStatistics,
                      icon: const Icon(Icons.mood_rounded, size: 24),
                    ),
                    if (!compactHeader) IconButton.filledTonal(
                      tooltip: 'Daily Reflection',
                      onPressed: _openReflection,
                      icon: SvgPicture.asset(
                        'assets/daily_reflection_icon.svg',
                        width: 24,
                        height: 24,
                        semanticsLabel: 'Daily Reflection',
                      ),
                    ),
                    if (compactHeader)
                      PopupMenuButton<String>(
                        tooltip: 'Quick actions',
                        icon: const Icon(Icons.more_horiz_rounded, size: 26),
                        onSelected: (action) {
                          switch (action) {
                            case 'calendar':
                              widget.onCalendarHistory?.call();
                              break;
                            case 'mood':
                              widget.onStatistics?.call();
                              break;
                            case 'reflection':
                              _openReflection();
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'calendar',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.calendar_month_rounded),
                              title: Text('Calendar & history'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'mood',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.mood_rounded),
                              title: Text('Mood & insights'),
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'reflection',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.auto_awesome_rounded),
                              title: Text('Daily Reflection'),
                            ),
                          ),
                        ],
                      ),
                    if (_showFeatures)
                      IconButton.filledTonal(
                        tooltip: 'Appearance',
                        onPressed: widget.onSettings,
                        icon: SvgPicture.asset(
                          'assets/appearance_icon.svg',
                          width: 26,
                          height: 26,
                          semanticsLabel: 'Appearance settings',
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
                                  'Explore Orah',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'A calm space for notes, plans, and reflection.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, panelConstraints) {
                                    final columns = panelConstraints.maxWidth >= 520 ? 3 : 2;
                                    final actions = <Widget>[
                                      _ExploreAction(icon: Icons.access_time_rounded, label: 'Recent Notes', onTap: widget.onNotes),
                                      _ExploreAction(icon: Icons.star_outline_rounded, label: 'Favorites', onTap: widget.onFavorites),
                                      _ExploreAction(icon: Icons.folder_outlined, label: 'Folders', onTap: widget.onFolders),
                                      _ExploreAction(icon: Icons.view_kanban_outlined, label: AppLocalizations.of(context)!.kanban, onTap: widget.onKanban),
                                      _ExploreAction(icon: Icons.archive_outlined, label: 'Archived Notes', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedNotesScreen()))),
                                      _ExploreAction(icon: Icons.palette_outlined, label: 'Appearance', onTap: widget.onSettings),
                                      _ExploreAction(icon: Icons.ios_share_rounded, label: 'Backup & Export', onTap: widget.onSettings),
                                      _ExploreAction(icon: Icons.checklist_rounded, label: 'Checklists', onTap: widget.onChecklist),
                                      _ExploreAction(icon: Icons.auto_awesome_outlined, label: 'Daily Reflection', onTap: _openReflection),
                                      _ExploreAction(icon: Icons.cloud_off_outlined, label: 'Offline access', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrahFeaturesScreen()))),
                                      _ExploreAction(icon: Icons.search_rounded, label: 'Search', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()))),
                                      _ExploreAction(icon: Icons.mic_none_rounded, label: 'Voice Capture', onTap: widget.onVoiceCapture),
                                    ];
                                    return GridView.count(
                                      crossAxisCount: columns,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 3.2,
                                      children: actions,
                                    );
                                  },
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
                      tooltip: 'Search filters',
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
                                      'DAILY INSPIRATION  •  ${prompt.category.toUpperCase()}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      prompt.text,
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
                                      'Tap to begin a note',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hide daily inspiration',
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
                    for (final filter in const [
                      ('all', 'All', Icons.notes_rounded),
                      ('inbox', 'Inbox', Icons.inbox_outlined),
                      ('pinned', 'Pinned', Icons.push_pin_outlined),
                      ('favorites', 'Favorites', Icons.star_outline_rounded),
                      ('checklists', 'Checklists', Icons.checklist_rounded),
                      ('archived', 'Archived', Icons.archive_outlined),
                      ('daily_reflection', 'Daily Ref', Icons.auto_awesome_rounded),
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
            if (_notes.any((note) => note.tags.any((tag) => tag.trim().isNotEmpty)))
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('All tags'),
                          selected: _activeTagFilter == null,
                          onSelected: (_) => setState(() => _activeTagFilter = null),
                        ),
                      ),
                      for (final tag in collectNoteTags(_notes))
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: const Icon(Icons.sell_outlined, size: 15),
                            label: Text(tag),
                            selected: _activeTagFilter?.toLowerCase() == tag.toLowerCase(),
                            onSelected: (_) => setState(() {
                              _activeTagFilter = _activeTagFilter?.toLowerCase() == tag.toLowerCase() ? null : tag;
                            }),
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
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync_problem_rounded, size: 42),
                        const SizedBox(height: 12),
                        const Text('ORAH could not load your notes', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadNotes,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
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
                          '$completed done',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        tooltip: 'Sort notes',
                        initialValue: _sort,
                        onSelected: (value) async { setState(() => _sort = value); await _savePreferences(); },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'updated', child: Text('Recently updated')),
                          PopupMenuItem(value: 'created', child: Text('Recently created')),
                          PopupMenuItem(value: 'title', child: Text('Title A–Z')),
                        ],
                        icon: const Icon(Icons.sort_rounded),
                      ),
                      IconButton(
                        tooltip: _gridView ? 'List view' : 'Grid view',
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
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 160 + MediaQuery.of(context).padding.bottom),
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
                            childAspectRatio: 1.04,
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
                        'Notes',
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
                        hintText: 'Search',
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
                    const _SidebarLabel(label: 'LIBRARY'),
                    _SidebarItem(
                      assetIcon: 'notes',
                      label: 'All Notes',
                      count: active.length,
                      selected: true,
                      onTap: () {},
                    ),
                    _SidebarItem(
                      assetIcon: 'star',
                      label: 'Favorites',
                      count: active.where((n) => n.isFavorite).length,
                      onTap: () {},
                    ),
                    _SidebarItem(
                      icon: Icons.access_time_rounded,
                      label: 'Recent',
                      count: active.length > 8 ? 8 : active.length,
                      onTap: () {},
                    ),
                    const SizedBox(height: 16),
                    const _SidebarLabel(label: 'FOLDERS'),
                    ..._folderEntries(active),
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
                                  label: const Text('New Note'),
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
                                  tooltip: 'Microphone',
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
                            'All Notes',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '@@ACTIVE_COUNT@@ notes',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (loading)
                      const Expanded(child: Center(child: CircularProgressIndicator()))
                    else if (active.isEmpty)
                      const Expanded(child: Center(child: Text('No notes yet')))
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
                        'Select a note',
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

  List<Widget> _folderEntries(List<Note> active) {
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
          label: 'Folders',
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

class _ExploreAction extends StatelessWidget {
  const _ExploreAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: .7)),
      ),
      child: Row(children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
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
    final theme = Theme.of(context);
    final body = note.isLocked
        ? 'Locked content'
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
                  note.title.trim().isEmpty ? 'Untitled note' : note.title,
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
                  '${_formatDate(note.updatedAt)}  ·  ${note.folderId ?? 'Notes'}',
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
                '@@DATE@@  ·  @@FOLDER@@',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              IconButton(
                tooltip: note.isPinned ? 'Unpin' : 'Pin',
                onPressed: () {},
                icon: const OrahAssetIcon('pin'),
              ),
              IconButton(
                tooltip: 'Favorite',
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
                  note.title.trim().isEmpty ? 'Untitled note' : note.title,
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
                    body.isEmpty ? 'This note is empty.' : body,
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
              label: const Text('Edit note'),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.isLocked ? 'Private note' : (note.title.isEmpty ? 'Untitled note' : note.title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        if (note.isLocked) ...[
          Text('Locked content', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ] else if (note.type == NoteType.checklist && note.checklistItems.isNotEmpty) ...[
          Text(
            '${note.completedChecklistItems}/${note.checklistItems.length} completed',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: note.checklistProgress, minHeight: 5),
          ),
        ] else
          Text(
            note.content.isEmpty ? 'No content' : note.content,
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
              'No notes yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1D4D37),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to capture your first thought.',
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

String _formatRelativeTime(DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
  if (difference.inHours < 24) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return _formatDate(date);
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');

  return '$month/$day/${local.year}';
}

String _cleanNotePreview(String content) {
  var text = content.trim();
  if (text.isEmpty) return '';

  // Render a clean text excerpt instead of exposing Markdown image tokens.
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'!\[[^\]\r\n]*'), ' ');
  text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'), r'$1');
  text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
  text = text.replaceAll(RegExp(r'[*_~]{1,3}'), '');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
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
    final theme = Theme.of(context);
    final title = note.isLocked
        ? 'Private note'
        : (note.title.trim().isEmpty ? 'Untitled note' : note.title);
    final contentPreview = note.isLocked
        ? 'Locked content'
        : _cleanNotePreview(note.content);
    final checklistPreview = note.type == NoteType.checklist
        ? note.checklistItems.take(2).map((item) => item.text.trim()).where((item) => item.isNotEmpty).join(' · ')
        : '';
    final body = contentPreview.isNotEmpty
        ? contentPreview
        : (checklistPreview.isNotEmpty
            ? checklistPreview
            : (note.imagePath != null || note.attachments.isNotEmpty
                ? (note.imagePath != null ? 'Image attachment' : 'Attachment')
                : 'No additional text'));
    final cardColor = note.color == null
        ? theme.colorScheme.surface
        : Color(note.color!);

    final card = Card(
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
          padding: EdgeInsets.all(compact ? 11 : 12),
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
              if (note.dueAt != null) ...[
                const SizedBox(height: 9),
                _DeadlineCountdownRibbon(dueAt: note.dueAt!),
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
                      _formatRelativeTime(note.updatedAt),
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
    if (!note.isInbox) return card;
    return Dismissible(
      key: ValueKey('inbox-${note.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final repository = await NoteRepositoryProvider.instance();
        if (direction == DismissDirection.startToEnd) {
          await repository.saveNote(note.copyWith(isInbox: false, updatedAt: DateTime.now()));
          return true;
        }
        final controller = TextEditingController();
        final tag = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Tag this note'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Tag',
                hintText: 'e.g. Work, Ideas, Read later',
              ),
              onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('Add tag')),
            ],
          ),
        );
        controller.dispose();
        if (tag == null || tag.trim().isEmpty) return false;
        final tags = [...note.tags];
        if (!tags.any((value) => value.toLowerCase() == tag.trim().toLowerCase())) {
          tags.add(tag.trim());
        }
        await repository.saveNote(note.copyWith(tags: tags, updatedAt: DateTime.now()));
        return false;
      },
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Colors.green.shade700, borderRadius: BorderRadius.circular(16)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.drive_file_move_outline, color: Colors.white),
          SizedBox(width: 8),
          Text('File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(16)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.sell_outlined, color: Colors.white),
          SizedBox(width: 8),
          Text('Tag', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ),
      child: card,
    );
  }
}


class _DeadlineCountdownRibbon extends StatelessWidget {
  const _DeadlineCountdownRibbon({required this.dueAt});

  final DateTime dueAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueAt.year, dueAt.month, dueAt.day);
    final days = dueDay.difference(today).inDays;
    final Color color;
    final IconData icon;
    final String label;
    if (days < 0) {
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
      label = 'Overdue by ${days.abs()} day${days.abs() == 1 ? '' : 's'}';
    } else if (days == 0) {
      color = Colors.red;
      icon = Icons.timer_outlined;
      label = 'Due today';
    } else if (days <= 2) {
      color = Colors.deepOrange;
      icon = Icons.hourglass_bottom_rounded;
      label = 'Due in ${days} day${days == 1 ? '' : 's'}';
    } else if (days <= 7) {
      color = Colors.amber.shade800;
      icon = Icons.hourglass_top_rounded;
      label = 'Due in ${days} days';
    } else {
      color = Colors.green.shade700;
      icon = Icons.event_available_rounded;
      label = 'Due in ${days} days';
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
