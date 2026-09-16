import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/folder_repository.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../data/repositories/note_repository.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'organization_picker_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.repository,
    this.note,
  });

  final NoteRepository repository;
  final Note? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final FocusNode _contentFocus = FocusNode();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  Timer? _saveTimer;
  late final DateTime _createdAt;
  late String _noteId;
  bool _saving = false;
  bool _hasChanges = false;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  String? _folderId;
  List<String> _tags = const [];

  @override
  void initState() {
    super.initState();

    final existing = widget.note;
    _noteId = existing?.id ?? _newId();
    _createdAt = existing?.createdAt ?? DateTime.now();

    _titleController = TextEditingController(text: existing?.title ?? '');
    _contentController =
        TextEditingController(text: existing?.content ?? '');

    _isPinned = existing?.isPinned ?? false;
    _isFavorite = existing?.isFavorite ?? false;
    _isArchived = existing?.isArchived ?? false;
    _folderId = existing?.folderId;
    _tags = [...(existing?.tags ?? const [])];

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';

  void _onChanged() {
    _hasChanges = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _save);

    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_hasChanges && widget.note != null) return;

    if (mounted) setState(() => _saving = true);

    final title = _titleController.text.trim();
    final content = _contentController.text;

    if (title.isEmpty && content.trim().isEmpty) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    final note = Note(
      id: _noteId,
      title: title.isEmpty ? 'Untitled note' : title,
      content: content,
      type: NoteType.text,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      folderId: _folderId,
      tags: _tags,
      isPinned: _isPinned,
      isFavorite: _isFavorite,
      isArchived: _isArchived,
    );

    await widget.repository.saveNote(note);
    _hasChanges = false;

    if (mounted) setState(() => _saving = false);
  }

  Future<void> _close() async {
    _saveTimer?.cancel();
    await _save();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<List<NoteFolder>> _folders() async {
    final repository = await FolderRepositoryProvider.instance();
    return repository.getFolders();
  }

  Future<void> _organize() async {
    await _save();
    final folders = await _folders();

    if (!mounted) return;

    final result = await Navigator.of(context).push<OrganizationSelection>(
      MaterialPageRoute(
        builder: (_) => OrganizationPickerScreen(
          folders: folders,
          selectedFolderId: _folderId,
          selectedTags: _tags,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _folderId = result.folderId;
      _tags = result.tags;
      _hasChanges = true;
    });

    await _save();
  }

  Future<void> _setFlag({
    bool? pinned,
    bool? favorite,
    bool? archived,
  }) async {
    setState(() {
      if (pinned != null) _isPinned = pinned;
      if (favorite != null) _isFavorite = favorite;
      if (archived != null) _isArchived = archived;
      _hasChanges = true;
    });

    await _save();
  }

  Future<void> _delete() async {
    await widget.repository.deleteNote(_noteId);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _close,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            _saving
                ? 'Saving…'
                : (_hasChanges ? 'Unsaved changes' : 'Saved'),
            key: ValueKey('$_saving-$_hasChanges'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isPinned ? 'Unpin' : 'Pin',
            onPressed: () => _setFlag(pinned: !_isPinned),
            icon: Icon(
              _isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'favorite':
                  await _setFlag(favorite: !_isFavorite);
                case 'organize':
                  await _organize();
                case 'archive':
                  await _setFlag(archived: !_isArchived);
                case 'delete':
                  await _delete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'favorite',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                  ),
                  title: Text(
                    _isFavorite ? 'Remove favorite' : 'Add to favorites',
                  ),
                ),
              ),
              const PopupMenuItem(
                value: 'organize',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.label_outline_rounded),
                  title: Text('Folder & tags'),
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  title: Text(_isArchived ? 'Unarchive' : 'Archive'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline_rounded),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_folderId != null || _tags.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                  children: [
                    if (_folderId != null)
                      _MetaChip(
                        icon: Icons.folder_outlined,
                        label: _folderId!,
                      ),
                    ..._tags.map(
                      (tag) => _MetaChip(
                        icon: Icons.tag_rounded,
                        label: tag,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                children: [
                  TextField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contentController,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
              focusNode: _contentFocus,
              textInputAction: TextInputAction.newline,
                    minLines: 18,
                    maxLines: null,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                    decoration: const InputDecoration(
                      hintText: 'Start writing...',
                      filled: false,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              elevation: 4,
              color: theme.colorScheme.surface,
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      _ToolButton(
                        icon: Icons.format_bold_rounded,
                        label: 'Bold',
                        onPressed: () {},
                      ),
                      _ToolButton(
                        icon: Icons.format_italic_rounded,
                        label: 'Italic',
                        onPressed: () {},
                      ),
                      _ToolButton(
                        icon: Icons.format_underlined_rounded,
                        label: 'Underline',
                        onPressed: () {},
                      ),
                      _ToolButton(
                        icon: Icons.check_box_outlined,
                        label: 'Checklist',
                        onPressed: () {},
                      ),
                      _ToolButton(
                        icon: Icons.label_outline_rounded,
                        label: 'Folder & tags',
                        onPressed: _organize,
                      ),
                      _ToolButton(
                        icon: Icons.image_outlined,
                        label: 'Image',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
