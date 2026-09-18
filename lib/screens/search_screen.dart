import 'package:flutter/material.dart';
import '../core/widgets/nova_polish.dart';

import '../data/repositories/note_repository_provider.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/search_filter.dart';
import 'note_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<Note> _allNotes = const [];
  List<Note> _results = const [];
  SearchFilter _filter = const SearchFilter();
  bool _loading = true;
  List<NoteFolder> _folders = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_search);
    _load();
  }

  Future<void> _load() async {
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    final folderRepository = await FolderRepositoryProvider.instance();
    final folders = await folderRepository.getFolders();

    if (!mounted) return;

    setState(() {
      _allNotes = notes;
      _folders = folders;
      _results = notes.where((note) => !note.isArchived).toList();
      _loading = false;
    });
  }

  void _search() {
    final query = _controller.text.trim().toLowerCase();

    final terms = query
        .split(RegExp(r'\\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final ranked = <({Note note, int score})>[];

    for (final note in _allNotes) {
      if (!_filter.archivedOnly && note.isArchived) continue;
      if (_filter.archivedOnly && !note.isArchived) continue;
      if (_filter.favoritesOnly && !note.isFavorite) continue;
      if (_filter.pinnedOnly && !note.isPinned) continue;
      if (_filter.folderId != null && note.folderId != _filter.folderId) continue;
      if (_filter.noteType != null && note.type != _filter.noteType) continue;

      if (terms.isEmpty) {
        ranked.add((note: note, score: 0));
        continue;
      }

      final title = note.title.toLowerCase();
      final content = note.content.toLowerCase();
      final tags = note.tags.map((tag) => tag.toLowerCase()).toList();
      final haystack = [title, content, ...tags].join(' ');

      if (!terms.every(haystack.contains)) continue;

      var score = 0;
      for (final term in terms) {
        if (title == term) {
          score += 1000;
        } else if (title.contains(term)) {
          score += 500;
        }
        if (tags.any((tag) => tag == term)) {
          score += 350;
        } else if (tags.any((tag) => tag.contains(term))) {
          score += 200;
        }
        if (content.contains(term)) score += 100;
      }

      if (title.startsWith(query)) score += 250;
      ranked.add((note: note, score: score));
    }

    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });

    final results = ranked.map((item) => item.note).toList();

    if (mounted) {
      setState(() => _results = results);
    }
  }

  Future<void> _open(Note note) async {
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

    _load();
  }

  Future<void> _showFilters() async {
    var folderId = _filter.folderId;
    var favorites = _filter.favoritesOnly;
    var pinned = _filter.pinnedOnly;
    var archived = _filter.archivedOnly;
    NoteType? type = _filter.noteType;

    final result = await showModalBottomSheet<SearchFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Search filters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          folderId = null;
                          favorites = false;
                          pinned = false;
                          archived = false;
                          type = null;
                        });
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                SwitchListTile(
                  value: favorites,
                  title: const Text('Favorites only'),
                  onChanged: (value) =>
                      setSheetState(() => favorites = value),
                ),
                SwitchListTile(
                  value: pinned,
                  title: const Text('Pinned only'),
                  onChanged: (value) => setSheetState(() => pinned = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: folderId,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All folders'),
                    ),
                    ..._folders.map(
                      (folder) => DropdownMenuItem<String?>(
                        value: folder.id,
                        child: Text(folder.name),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => folderId = value),
                ),
                SwitchListTile(
                  value: archived,
                  title: const Text('Archived'),
                  onChanged: (value) => setSheetState(() => archived = value),
                ),
                DropdownButtonFormField<NoteType?>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Note type',
                  ),
                  items: const [
                    DropdownMenuItem<NoteType?>(
                      value: null,
                      child: Text('All types'),
                    ),
                    DropdownMenuItem(
                      value: NoteType.text,
                      child: Text('Text'),
                    ),
                    DropdownMenuItem(
                      value: NoteType.checklist,
                      child: Text('Checklist'),
                    ),
                    DropdownMenuItem(
                      value: NoteType.voice,
                      child: Text('Voice'),
                    ),
                    DropdownMenuItem(
                      value: NoteType.image,
                      child: Text('Image'),
                    ),
                    DropdownMenuItem(
                      value: NoteType.drawing,
                      child: Text('Drawing'),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => type = value),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        SearchFilter(
                          folderId: folderId,
                          favoritesOnly: favorites,
                          pinnedOnly: pinned,
                          archivedOnly: archived,
                          noteType: type,
                        ),
                      );
                    },
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null) return;

    setState(() => _filter = result);
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _controller.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: _showFilters,
            icon: Badge(
              isLabelVisible: !_filter.isEmpty,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SearchBar(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      hintText: 'Search title, content or tags...',
                      leading: const Icon(Icons.search_rounded),
                      trailing: [
                        if (query.isNotEmpty)
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: () => _controller.clear(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          query.isEmpty
                              ? '${_results.length} notes'
                              : '${_results.length} result${_results.length == 1 ? '' : 's'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (!_filter.isEmpty)
                          Text(
                            'Filters active',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notes found',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try another word or remove a filter.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 30),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final note = _results[index];
                              return _SearchResultTile(
                                note: note,
                                query: query,
                                onTap: () => _open(note),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.note,
    required this.query,
    required this.onTap,
  });

  final Note note;
  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = note.content.isEmpty ? 'No content' : note.content;

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: const CircleAvatar(
          child: Icon(Icons.note_alt_outlined),
        ),
        title: _HighlightedText(
          text: note.title.isEmpty ? 'Untitled note' : note.title,
          query: query,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: _HighlightedText(
            text: text,
            query: query,
            maxLines: 2,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText({
    required this.text,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index == -1) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final before = text.substring(0, index);
    final match = text.substring(index, index + query.length);
    final after = text.substring(index + query.length);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: style?.copyWith(
              fontWeight: FontWeight.w900,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          TextSpan(text: after),
        ],
        style: style,
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
