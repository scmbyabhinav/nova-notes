import 'dart:convert';

import 'package:flutter/material.dart';
import '../core/services/nova_security_service.dart';
import '../core/widgets/orah_asset_icon.dart';
import '../data/repositories/note_repository_provider.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../models/search_filter.dart';
import 'note_editor_screen.dart' show NoteEditorScreen;
import '../services/orah_feature_gate.dart';
import 'orah_pro_screen.dart';
import 'vault_screen.dart';

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
  bool _advancedBlocked = false;
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
    final vaultNotes = await repository.getVaultNotes();
    final folderRepository = await FolderRepositoryProvider.instance();
    final folders = await folderRepository.getFolders();

    if (!mounted) return;

    setState(() {
      _allNotes = [...notes, ...vaultNotes];
      _folders = folders;
      _results = notes.where((note) => !note.isArchived && !note.isTrashed).toList();
      _loading = false;
    });
  }

  Future<void> _search() async {
    final rawQuery = _controller.text.trim().toLowerCase();
    final tokens = rawQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final hasAdvancedOperator = tokens.any((token) =>
        token.startsWith('is:') ||
        token.startsWith('has:') ||
        token.startsWith('tag:') ||
        token.startsWith('folder:') ||
        token.startsWith('type:') ||
        token.startsWith('before:') ||
        token.startsWith('after:'));
    if (hasAdvancedOperator && !OrahFeatureGate.allowed(OrahFeature.advancedSearch)) {
      if (mounted) setState(() { _results = const []; _advancedBlocked = true; });
      return;
    }
    if (_advancedBlocked && mounted) setState(() => _advancedBlocked = false);

    bool? pinned;
    bool? favorite;
    bool? locked;
    bool? archived;
    bool? reminder;
    String? folderTerm;
    String? tagTerm;
    String? typeTerm;
    DateTime? before;
    DateTime? after;
    bool hasAttachment = false;

    final terms = <String>[];
    for (final token in tokens) {
      if (token == 'is:pinned') { pinned = true; continue; }
      if (token == 'is:favorite' || token == 'is:favourite') { favorite = true; continue; }
      if (token == 'is:locked' || token == 'is:private') { locked = true; continue; }
      if (token == 'is:archived') { archived = true; continue; }
      if (token == 'is:active') { archived = false; continue; }
      if (token == 'has:reminder' || token == 'has:due') { reminder = true; continue; }
      if (token == 'has:attachment' || token == 'has:image' || token == 'has:file') { hasAttachment = true; continue; }
      if (token.startsWith('tag:')) { tagTerm = token.substring(4); continue; }
      if (token.startsWith('folder:')) { folderTerm = token.substring(7); continue; }
      if (token.startsWith('type:')) { typeTerm = token.substring(5); continue; }
      if (token.startsWith('before:')) { before = DateTime.tryParse(token.substring(7)); continue; }
      if (token.startsWith('after:')) { after = DateTime.tryParse(token.substring(6)); continue; }
      terms.add(token);
    }

    final ranked = <({Note note, int score})>[];

    String folderName(String? id) {
      if (id == null) return '';
      for (final folder in _folders) {
        if (folder.id == id) return folder.name.toLowerCase();
      }
      return '';
    }

    bool typeMatches(Note note) {
      if (typeTerm == null || typeTerm!.isEmpty) return true;
      return note.type.name.toLowerCase() == typeTerm ||
          (typeTerm == 'task' && note.type == NoteType.checklist);
    }

    for (final note in _allNotes) {
      if (note.isTrashed) continue;
      if (_filter.favoritesOnly && !note.isFavorite) continue;
      if (_filter.pinnedOnly && !note.isPinned) continue;
      if (_filter.archivedOnly && !note.isArchived) continue;
      if (_filter.noteType != null && note.type != _filter.noteType) continue;
      if (_filter.folderId != null && note.folderId != _filter.folderId) continue;
      if (locked == true && !note.isLocked) continue;
      if (note.isLocked && terms.isEmpty && locked != true) continue;
      if (pinned == true && !note.isPinned) continue;
      if (favorite == true && !note.isFavorite) continue;
      if (archived == true && !note.isArchived) continue;
      if (archived == false && note.isArchived) continue;
      if (reminder == true && note.dueAt == null && !note.checklistItems.any((item) => item.dueAt != null)) continue;
      if (hasAttachment && note.attachments.isEmpty) continue;
      if (!typeMatches(note)) continue;
      if (before != null && !note.updatedAt.isBefore(before!)) continue;
      if (after != null && !note.updatedAt.isAfter(after!)) continue;

      final noteFolder = folderName(note.folderId);
      if (folderTerm != null && noteFolder != folderTerm && note.folderId != folderTerm) continue;
      if (tagTerm != null && !note.tags.any((tag) => tag.toLowerCase() == tagTerm || tag.toLowerCase().contains(tagTerm!))) continue;

      var title = note.title.toLowerCase();
      var content = note.content.toLowerCase();
      var tags = note.tags.map((tag) => tag.toLowerCase()).toList();
      var checklist = note.checklistItems.map((item) => item.text.toLowerCase()).toList();

      if (note.isLocked && terms.isNotEmpty) {
        try {
          final clearText = await NovaSecurityService().decryptPrivatePayload(note.content);
          final payload = jsonDecode(clearText);
          if (payload is Map) {
            title = (payload['title'] as String? ?? '').toLowerCase();
            content = (payload['content'] as String? ?? '').toLowerCase();
            tags = (payload['tags'] is List)
                ? List<String>.from((payload['tags'] as List).whereType<String>())
                    .map((tag) => tag.toLowerCase()).toList()
                : <String>[];
            checklist = (payload['checklistItems'] is List)
                ? (payload['checklistItems'] as List)
                    .whereType<Map>()
                    .map((item) => (item['text'] as String? ?? '').toLowerCase())
                    .toList()
                : <String>[];
          }
        } catch (_) {
          continue;
        }
      }

      final haystack = note.isLocked && terms.isEmpty
          ? 'locked note private note'
          : [title, content, ...tags, ...checklist, noteFolder].join(' ');
      if (terms.isNotEmpty && !terms.every(haystack.contains)) continue;

      var score = 0;
      for (final term in terms) {
        if (title == term) {
          score += 1000;
        } else if (title.contains(term)) {
          score += 500;
        }
        if (tags.any((tag) => tag == term)) score += 350;
        if (tags.any((tag) => tag.contains(term))) score += 200;
        if (content.contains(term)) score += 100;
        if (checklist.any((item) => item.contains(term))) score += 125;
      }
      if (terms.isNotEmpty && title.startsWith(terms.join(' '))) score += 250;
      ranked.add((note: note, score: score));
    }

    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });

    if (mounted) setState(() => _results = ranked.map((item) => item.note).toList());
  }

  Future<void> _open(Note note) async {
    if (note.isLocked) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      );
      await _load();
      return;
    }
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
              child: const OrahAssetIcon('menu'),
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
                      hintText: 'Search title, content or tags...',
                      leading: const OrahAssetIcon('search'),
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
                                  Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.search_off_rounded,
                                      size: 42,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _advancedBlocked ? 'Advanced search is a Pro feature' : 'No notes found',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _advancedBlocked ? 'Use normal keywords for free, or open ORAH Pro to unlock filters and operators.' : 'Try another word or remove a filter.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (_advancedBlocked) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const OrahProScreen()),
                                      ),
                                      icon: const Icon(Icons.workspace_premium_rounded),
                                      label: const Text('Open ORAH Pro'),
                                    ),
                                  ],
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
    final text = note.isLocked ? 'Authenticate to open this private note' : (note.content.isEmpty ? 'No content' : note.content);

    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: note.isLocked ? theme.colorScheme.primaryContainer : null,
          child: note.isLocked
              ? Icon(Icons.lock_rounded, color: theme.colorScheme.onPrimaryContainer)
              : const OrahAssetIcon('notes', size: 24),
        ),
        title: _HighlightedText(
          text: note.isLocked ? '🔒 Locked Note' : (note.title.isEmpty ? 'Untitled note' : note.title),
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
        trailing: Icon(note.isLocked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: note.isLocked ? theme.colorScheme.primary : null),
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
