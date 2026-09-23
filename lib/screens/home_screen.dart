import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/widgets/nova_polish.dart';

import '../data/repositories/note_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _gridView = true;
  bool _loading = true;
  String _sort = 'updated';
  List<Note> _notes = const [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
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
    final notes = await repository.getNotes();

    if (!mounted) return;

    setState(() {
      _notes = notes.where((note) => !note.isTrashed).toList();
      _loading = false;
    });
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

    _loadNotes();
  }

  Future<void> _updateNote(Note note, Note updated) async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(updated);
    await _loadNotes();
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
        await repository.saveNote(Note(
          id: '${DateTime.now().microsecondsSinceEpoch}_copy',
          title: duplicate.title,
          content: duplicate.content,
          type: duplicate.type,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          folderId: duplicate.folderId,
          tags: duplicate.tags,
          attachments: const [],
          checklistItems: duplicate.checklistItems,
          color: duplicate.color,
          isPinned: false,
          isFavorite: false,
          isArchived: false,
          isLocked: false,
          isTrashed: false,
          dueAt: duplicate.dueAt,
        ));
        await _loadNotes();
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
        return;
    }
  }

  Future<void> _showColorPicker(Note note) async {
    const colors = <Color?>[null, Color(0xFFFFF3C4), Color(0xFFDDF7E8), Color(0xFFDCEBFF), Color(0xFFF1DFFF), Color(0xFFFFE0D2)];
    final color = await showModalBottomSheet<Color?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [for (final color in colors) InkWell(
              onTap: () => Navigator.pop(context, color),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: color ?? Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: note.color == color?.value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant, width: 2),
                ),
                child: color == null ? const Icon(Icons.format_color_reset_outlined) : null,
              ),
            )],
          ),
        ),
      ),
    );
    if (!mounted) return;
    // A dismissed sheet returns null too; only clear when the user explicitly chose reset.
    if (color == null && note.color == null) return;
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(note.copyWith(color: color?.value, clearColor: color == null, updatedAt: DateTime.now()));
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orah',
                            style: theme.textTheme.headlineSmall?.copyWith(
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
                    const CircleAvatar(
                      radius: 19,
                      child: Text('A'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              sliver: SliverToBoxAdapter(
                child: SearchBar(
                  hintText: 'Search your notes...',
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
                      'Pinned',
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
                        'Recent Notes',
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
  }
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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: note.color == null
                ? theme.colorScheme.surface
                : Color(note.color!),
            borderRadius: BorderRadius.circular(18),
          ),
          child: compact
              ? Row(
                  children: [
                    _NoteIcon(type: note.type),
                    const SizedBox(width: 14),
                    Expanded(child: _NoteText(note: note)),
                    if (note.isFavorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.star_rounded, size: 18),
                      ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoteIcon(type: note.type),
                    const Spacer(),
                    _NoteText(note: note),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (note.dueAt != null)
                          _SmartBadge(
                            icon: Icons.notifications_active_outlined,
                            label: _dueLabel(note.dueAt!),
                          ),
                        if (note.type == NoteType.checklist && note.checklistItems.any((item) => item.dueAt != null && !item.isDone && item.dueAt!.isBefore(DateTime.now())))
                          const _SmartBadge(icon: Icons.warning_amber_rounded, label: 'Overdue'),
                        if (note.isFavorite)
                          const Icon(Icons.star_rounded, size: 16),
                        if (note.attachments.isNotEmpty)
                          const Icon(Icons.attach_file_rounded, size: 16),
                        if (note.isPinned)
                          const Icon(Icons.push_pin_rounded, size: 16),
                        if (note.tags.isNotEmpty)
                          Text(
                            '#${note.tags.first}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(note.updatedAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _dueLabel(DateTime date) {
    final now = DateTime.now();
    if (date.isBefore(now)) return 'Overdue';
    final difference = date.difference(now);
    if (difference.inHours < 24) return 'Today';
    if (difference.inHours < 48) return 'Tomorrow';
    return '${date.day}/${date.month}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.day}/${date.month}/${date.year}';
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
          note.title.isEmpty ? 'Untitled note' : note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        if (note.type == NoteType.checklist && note.checklistItems.isNotEmpty) ...[
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
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35, color: theme.colorScheme.onSurfaceVariant),
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
