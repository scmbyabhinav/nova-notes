import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../data/repositories/folder_repository.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../data/repositories/note_repository.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'organization_picker_screen.dart';
import 'export_note_sheet.dart';
import '../services/nova_attachment_service.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.repository,
    this.note,
    this.initialType = NoteType.text,
  });

  final NoteRepository repository;
  final Note? note;
  final NoteType initialType;

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
  late NoteType _noteType;
  bool _saving = false;
  bool _hasChanges = false;
  bool _isPinned = false;
  bool _isFavorite = false;
  bool _isArchived = false;
  String? _folderId;
  List<String> _tags = const [];
  List<String> _attachments = const [];
  bool _previewMode = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.note;
    _noteId = existing?.id ?? _newId();
    _createdAt = existing?.createdAt ?? DateTime.now();
    _noteType = existing?.type ?? widget.initialType;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _contentController =
        TextEditingController(text: existing?.content ?? '');

    _isPinned = existing?.isPinned ?? false;
    _isFavorite = existing?.isFavorite ?? false;
    _isArchived = existing?.isArchived ?? false;
    _folderId = existing?.folderId;
    _tags = [...(existing?.tags ?? const [])];
    _attachments = [...(existing?.attachments ?? const [])];

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

    final note = widget.note == null
        ? Note(
            id: _noteId,
            title: title.isEmpty ? 'Untitled note' : title,
            content: content,
            type: _noteType,
            createdAt: _createdAt,
            updatedAt: DateTime.now(),
            folderId: _folderId,
            tags: _tags,
            attachments: _attachments,
            isPinned: _isPinned,
            isFavorite: _isFavorite,
            isArchived: _isArchived,
          )
        : widget.note!.copyWith(
            title: title.isEmpty ? 'Untitled note' : title,
            content: content,
            type: _noteType,
            updatedAt: DateTime.now(),
            folderId: _folderId,
            tags: _tags,
            attachments: _attachments,
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


  String _renderableContent() {
    if (_noteType != NoteType.checklist) return _contentController.text;
    return _contentController.text
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .map((line) => '- [ ] ' + line.replaceFirst(RegExp(r'^[-*•]\s*'), ''))
        .join('\n');
  }

  void _wrapSelection(String before, String after) {
    final value = _contentController.value;
    final selection = value.selection;
    if (!selection.isValid) return;
    final selected = selection.textInside(value.text);
    final replacement = before + selected + after;
    _contentController.value = value.replaced(selection, replacement);
    _contentController.selection =
        TextSelection.collapsed(offset: selection.start + replacement.length);
    _contentFocus.requestFocus();
  }

  void _insertPrefix(String prefix) {
    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final lineStart = value.text.lastIndexOf('\n', start - 1) + 1;
    _contentController.value = value.replaced(
      TextSelection.collapsed(offset: lineStart),
      prefix,
    );
    _contentController.selection =
        TextSelection.collapsed(offset: start + prefix.length);
    _contentFocus.requestFocus();
  }

  Future<void> _insertLink() async {
    final url = await _textDialog('Insert link', 'https://example.com');
    if (url == null || url.isEmpty) return;
    final value = _contentController.value;
    final selected = value.selection.textInside(value.text);
    _contentController.value = value.replaced(
      value.selection,
      selected.isEmpty ? '[link](' + url + ')' : '[' + selected + '](' + url + ')',
    );
    _contentFocus.requestFocus();
  }

  Future<String?> _textDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Insert')),
        ],
      ),
    );
  }


  Future<void> _addImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 92,
      );
      if (picked == null) return;
      final path = await const NovaAttachmentService().importXFile(picked);
      setState(() {
        _attachments = [..._attachments, path];
        _hasChanges = true;
      });
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add image: $e')),
        );
      }
    }
  }

  Future<void> _addFiles() async {
    try {
      final files = await FilePicker.pickFiles(allowMultiple: true);
      if (files.isEmpty) return;
      final imported = <String>[];
      for (final file in files) {
        if (file.path == null) continue;
        imported.add(
          await const NovaAttachmentService().importFile(file.path!),
        );
      }
      if (imported.isEmpty) return;
      setState(() {
        _attachments = [..._attachments, ...imported];
        _hasChanges = true;
      });
      await _save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add files: $e')),
        );
      }
    }
  }

  Future<void> _removeAttachment(String path) async {
    await const NovaAttachmentService().delete(path);
    setState(() {
      _attachments = _attachments.where((item) => item != path).toList();
      _hasChanges = true;
    });
    await _save();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Attach files'),
              onTap: () {
                Navigator.pop(sheetContext);
                _addFiles();
              },
            ),
          ],
        ),
      ),
    );
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
            tooltip: _previewMode ? 'Edit' : 'Preview',
            onPressed: () => setState(() => _previewMode = !_previewMode),
            icon: Icon(_previewMode ? Icons.edit_outlined : Icons.visibility_outlined),
          ),
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
                case 'export':
                  await _save();
                  if (!mounted) return;
                  await showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (_) => ExportNoteSheet(
                      note: Note(
                        id: _noteId,
                        title: _titleController.text.trim().isEmpty ? 'Untitled note' : _titleController.text.trim(),
                        content: _contentController.text,
                        type: _noteType,
                        attachments: _attachments,
                        createdAt: _createdAt,
                        updatedAt: DateTime.now(),
                        folderId: _folderId,
                        tags: _tags,
                        isPinned: _isPinned,
                        isFavorite: _isFavorite,
                        isArchived: _isArchived,
                      ),
                    ),
                  );
                  return;
                case 'favorite':
                  await _setFlag(favorite: !_isFavorite);
                  return;
                case 'organize':
                  await _organize();
                  return;
                case 'archive':
                  await _setFlag(archived: !_isArchived);
                  return;
                case 'delete':
                  await _delete();
                  return;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.ios_share_rounded),
                  title: Text('Export'),
                ),
              ),
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
            if (_attachments.isNotEmpty)
              SizedBox(
                height: 112,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _attachments[index];
                    final isImage = ['.jpg','.jpeg','.png','.webp','.gif','.heic']
                        .contains(p.extension(path).toLowerCase());
                    return Stack(
                      children: [
                        Container(
                          width: 104,
                          height: 96,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: isImage
                              ? Image.file(File(path), fit: BoxFit.cover)
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.insert_drive_file_outlined, size: 30),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Text(
                                        p.basename(path),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton.filledTonal(
                            tooltip: 'Remove',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _removeAttachment(path),
                            icon: const Icon(Icons.close_rounded, size: 16),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: _previewMode
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                      children: [
                        if (_titleController.text.trim().isNotEmpty)
                          Text(
                            _titleController.text.trim(),
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        const SizedBox(height: 12),
                        MarkdownBody(data: _renderableContent(), selectable: true),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                      children: [
                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          decoration: const InputDecoration(hintText: 'Title', filled: false, border: InputBorder.none, contentPadding: EdgeInsets.zero),
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
                          decoration: InputDecoration(
                            hintText: _noteType == NoteType.checklist ? 'Add one task per line...' : 'Start writing...',
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
                        onPressed: () => _wrapSelection('**', '**'),
                      ),
                      _ToolButton(
                        icon: Icons.format_italic_rounded,
                        label: 'Italic',
                        onPressed: () => _wrapSelection('*', '*'),
                      ),
                      _ToolButton(
                        icon: Icons.strikethrough_s_rounded,
                        label: 'Strikethrough',
                        onPressed: () => _wrapSelection('~~', '~~'),
                      ),
                      _ToolButton(
                        icon: Icons.title_rounded,
                        label: 'Heading',
                        onPressed: () => _insertPrefix('## '),
                      ),
                      _ToolButton(
                        icon: Icons.format_list_bulleted_rounded,
                        label: 'Bullets',
                        onPressed: () => _insertPrefix('- '),
                      ),
                      _ToolButton(
                        icon: Icons.format_list_numbered_rounded,
                        label: 'Numbered list',
                        onPressed: () => _insertPrefix('1. '),
                      ),
                      _ToolButton(
                        icon: Icons.format_quote_rounded,
                        label: 'Quote',
                        onPressed: () => _insertPrefix('> '),
                      ),
                      _ToolButton(
                        icon: Icons.link_rounded,
                        label: 'Link',
                        onPressed: _insertLink,
                      ),
                      _ToolButton(
                        icon: _noteType == NoteType.checklist
                            ? Icons.check_box_rounded
                            : Icons.check_box_outlined,
                        label: _noteType == NoteType.checklist
                            ? 'Text note'
                            : 'Checklist',
                        onPressed: () {
                          setState(() {
                            _noteType = _noteType == NoteType.checklist
                                ? NoteType.text
                                : NoteType.checklist;
                            _hasChanges = true;
                          });
                          _save();
                        },
                      ),
                      _ToolButton(
                        icon: Icons.label_outline_rounded,
                        label: 'Folder & tags',
                        onPressed: _organize,
                      ),
                      _ToolButton(
                        icon: Icons.attach_file_rounded,
                        label: 'Add image or file',
                        onPressed: _showAttachmentMenu,
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
