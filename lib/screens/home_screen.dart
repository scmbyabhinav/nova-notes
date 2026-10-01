import 'dart:async';

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/orah_reminder_service.dart';
import '../core/widgets/nova_polish.dart';
import '../core/navigation/orah_navigation.dart';

import '../data/repositories/note_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import 'orah_pro_screen.dart';
import 'reflection_prompt_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onNewNote, this.onVoiceCapture, this.onSettings});

  final Future<void> Function()? onNewNote;
  final Future<void> Function()? onVoiceCapture;
  final VoidCallback? onSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  bool _gridView = true;
  bool _loading = true;
  String _sort = 'updated';
  List<Note> _notes = const [];
  String? _selectedNoteId;
  StreamSubscription<List<Note>>? _notesSubscription;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadNotes();
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
    // The editor, Trash, or another pushed screen may have changed notes.
    // Read persistent storage directly when returning instead of relying only
    // on a broadcast event that may have been missed while this screen was idle.
    _loadNotes();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _gridView = prefs.getBool('orah_grid_view') ?? true;
      _sort = prefs.getString('orah_note_sort') ?? 'updated';
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('orah_grid_view', _gridView);
    await prefs.setString('orah_note_sort', _sort);
  }

  Future<void> _loadNotes() async {
    final repository = await NoteRepositoryProvider.instance();

    // Keep one live subscription for the lifetime of HomeScreen. Replacing
    // the subscription during navigation can create a small window in which
    // a broadcast emission is dropped while the editor is closing.
    _notesSubscription ??= repository.watchNotes().listen(_applyNotes);

    // Read the persisted snapshot as well. This covers startup and any
    // update that happened before the stream listener was attached.
    await repository.refresh();
    final notes = await repository.getNotes();
    _applyNotes(notes);
  }

  void _applyNotes(List<Note> notes) {
    if (!mounted) return;
    setState(() {
      _notes = notes.where((note) => !note.isTrashed).toList();
      _loading = false;
      if (_selectedNoteId != null && !_notes.any((note) => note.id == _selectedNoteId)) {
        _selectedNoteId = null;
      }
    });
  }

  void _selectNote(Note note) => setState(() => _selectedNoteId = note.id);

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

  @override
  void dispose() {
    orahRouteObserver.unsubscribe(this);
    _notesSubscription?.cancel();
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
              leading: Icon(
                note.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
              ),
              title: Text(note.isPinned ? 'Unpin note' : 'Pin note'),
              onTap: () => Navigator.pop(context, 'pin'),
            ),
            ListTile(
              leading: Icon(
                note.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
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
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Move to Trash'),
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
        await _loadNotes();
        await OrahReminderService.instance.cancel(note.id);
        for (final item in note.checklistItems) {
          await OrahReminderService.instance.cancel('checklist:${item.id}');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Moved to Trash'),
            action: SnackBarAction(label: 'Undo', onPressed: () => _restoreFromTrash(note)),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final pinned = _notes
        .where((note) => note.isPinned && !note.isArchived)
        .toList();
    final recent = _notes.where((note) => !note.isArchived).toList()
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
                    IconButton.filledTonal(
                      tooltip: 'ORAH Pro',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrahProScreen()),
                      ),
                      icon: const Text(
                        'O',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.appTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Think it. Write it. Keep it.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Daily Reflection',
                      onPressed: _openReflection,
                      icon: const Icon(Icons.auto_awesome_rounded),
                    ),

                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  hintText: l10n.searchHint,
                  leading: const Icon(Icons.search_rounded),
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
                      icon: const Icon(Icons.tune_rounded),
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
            else ...[
              if (pinned.isNotEmpty) ...[
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
                          '${completed} done',
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: SliverToBoxAdapter(
                    child: _EmptyState(theme: theme),
                  ),
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
                        leading: const Icon(Icons.search_rounded, size: 19),
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
                      icon: Icons.note_outlined,
                      label: 'All Notes',
                      count: active.length,
                      selected: true,
                      onTap: () {},
                    ),
                    _SidebarItem(
                      icon: Icons.bookmark_border_rounded,
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
                                  icon: const Icon(Icons.add_rounded, size: 18),
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
                                  icon: const Icon(Icons.mic_none_rounded),
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
          icon: Icons.folder_outlined,
          label: 'Folders',
          onTap: () {},
        ),
      ];
    }
    return folders.entries.take(5).map((entry) {
      return _SidebarItem(
        icon: Icons.folder_outlined,
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
    required this.icon,
    required this.label,
    this.count,
    this.selected = false,
    required this.onTap,
  });

  final IconData icon;
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
                Icon(
                  icon,
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
                icon: Icon(
                  note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Favorite',
                onPressed: () {},
                icon: Icon(
                  note.isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                ),
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

class _SmartBadge extends StatelessWidget {
  const _SmartBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: scheme.primary), const SizedBox(width: 4), Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary))]),
    );
  }
}

class _NoteIcon extends StatelessWidget {
  const _NoteIcon({required this.type});

  final NoteType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      NoteType.checklist => Icons.checklist_rounded,
      NoteType.voice => Icons.mic_none_rounded,
      NoteType.image => Icons.image_outlined,
      NoteType.drawing => Icons.draw_outlined,
      NoteType.text => Icons.note_alt_outlined,
    };

    final color = Theme.of(context).colorScheme.primary;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 21),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.note_add_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Your notes live here',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to capture your first thought.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');

  return '$month/$day/${local.year}';
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
    final title = note.title.trim().isEmpty ? 'Untitled note' : note.title;
    final body = note.content.trim().replaceAll(RegExp(r'\s+'), ' ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: note.color == null ? null : Color(note.color!),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _formatDate(note.updatedAt),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

