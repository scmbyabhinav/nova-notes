import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/widgets/orah_asset_icon.dart';
import '../data/repositories/folder_repository_provider.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../services/nova_attachment_service.dart';
import 'note_editor_screen.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  bool _loading = true;
  List<NoteFolder> _folders = const [];
  Map<String, int> _counts = const {};
  final Set<String> _selectedFolderIds = <String>{};

  bool get _selectionMode => _selectedFolderIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folderRepository = await FolderRepositoryProvider.instance();
    final noteRepository = await NoteRepositoryProvider.instance();

    final folders = await folderRepository.getFolders();
    final notes = await noteRepository.getNotes();

    final counts = <String, int>{};
    for (final note in notes) {
      if (note.folderId != null && !note.isArchived && !note.isTrashed) {
        counts[note.folderId!] = (counts[note.folderId!] ?? 0) + 1;
      }
    }

    if (!mounted) return;
    setState(() {
      _folders = folders;
      _counts = counts;
      _selectedFolderIds.removeWhere(
        (id) => !folders.any((folder) => folder.id == id),
      );
      _loading = false;
    });
  }

  Future<_FolderDraft?> _promptFolderDetails({
    required String title,
    String initialValue = '',
    String? initialImagePath,
    required String actionLabel,
  }) async {
    var value = initialValue;
    var imagePath = initialImagePath;

    final result = await showDialog<_FolderDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final pickedPath = await _pickFolderImage();
                    if (pickedPath == null || !dialogContext.mounted) return;
                    setDialogState(() => imagePath = pickedPath);
                  },
                  child: CircleAvatar(
                    radius: 42,
                    backgroundImage: imagePath != null &&
                            File(imagePath!).existsSync()
                        ? FileImage(File(imagePath!))
                        : null,
                    child: imagePath == null ||
                            !File(imagePath!).existsSync()
                        ? const Icon(Icons.add_photo_alternate_outlined, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final pickedPath = await _pickFolderImage();
                    if (pickedPath == null || !dialogContext.mounted) return;
                    setDialogState(() => imagePath = pickedPath);
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    imagePath == null ? 'Add folder image' : 'Change image',
                  ),
                ),
                if (imagePath != null)
                  TextButton(
                    onPressed: () => setDialogState(() => imagePath = null),
                    child: const Text('Remove image'),
                  ),
                TextFormField(
                  initialValue: initialValue,
                  autofocus: true,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Folder name',
                    hintText: 'e.g. Work, Ideas, Personal',
                  ),
                  onChanged: (text) => value = text,
                  onFieldSubmitted: (_) {
                    final trimmed = value.trim();
                    if (trimmed.isNotEmpty && trimmed.length <= 80) {
                      Navigator.of(dialogContext).pop(
                        _FolderDraft(trimmed, imagePath),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = value.trim();
                if (trimmed.isEmpty || trimmed.length > 80) return;
                Navigator.of(dialogContext).pop(
                  _FolderDraft(trimmed, imagePath),
                );
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return null;
    return result;
  }

  Future<String?> _pickFolderImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (picked == null) return null;
    return const NovaAttachmentService().importXFile(picked);
  }

  Future<void> _addFolder() async {
    final draft = await _promptFolderDetails(
      title: 'New folder',
      actionLabel: 'Create',
    );
    if (draft == null) return;

    final repository = await FolderRepositoryProvider.instance();
    await repository.saveFolder(
      NoteFolder(
        id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
        name: draft.name,
        createdAt: DateTime.now(),
        folderCoverImagePath: draft.imagePath,
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final draft = await _promptFolderDetails(
      title: 'Edit folder',
      initialValue: folder.name,
      initialImagePath: folder.folderCoverImagePath,
      actionLabel: 'Save',
    );
    if (draft == null) return;

    final repository = await FolderRepositoryProvider.instance();
    await repository.saveFolder(
      NoteFolder(
        id: folder.id,
        name: draft.name,
        createdAt: folder.createdAt,
        iconCodePoint: folder.iconCodePoint,
        color: folder.color,
        folderCoverImagePath: draft.imagePath,
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteFolder(NoteFolder folder) async {
    final count = _counts[folder.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${folder.name}?'),
        content: Text(
          count == 0
              ? 'The folder is empty.'
              : '$count note(s) will be kept and moved back to All Notes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || confirmed != true) return;

    await _deleteFoldersById({folder.id});
  }

  Future<void> _deleteSelectedFolders() async {
    if (_selectedFolderIds.isEmpty) return;

    final selectedCount = _selectedFolderIds.length;
    final noteCount = _selectedFolderIds.fold<int>(
      0,
      (total, id) => total + (_counts[id] ?? 0),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete $selectedCount folder${selectedCount == 1 ? '' : 's'}?',
        ),
        content: Text(
          noteCount == 0
              ? 'The selected folders are empty.'
              : '$noteCount note(s) will be kept and moved back to All Notes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete selected'),
          ),
        ],
      ),
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || confirmed != true) return;

    await _deleteFoldersById({..._selectedFolderIds});
  }

  Future<void> _deleteFoldersById(Set<String> ids) async {
    final folderRepository = await FolderRepositoryProvider.instance();
    final noteRepository = await NoteRepositoryProvider.instance();

    // Unassign notes first so no normal note keeps a stale folder ID.
    final notes = await noteRepository.getNotes();
    for (final note in notes.where((note) => ids.contains(note.folderId))) {
      await noteRepository.saveNote(
        note.copyWith(
          clearFolder: true,
          updatedAt: DateTime.now(),
        ),
      );
    }

    for (final id in ids) {
      await folderRepository.deleteFolder(id);
    }

    if (!mounted) return;
    setState(() => _selectedFolderIds.clear());
    await _load();
  }

  void _toggleSelection(NoteFolder folder) {
    setState(() {
      if (!_selectedFolderIds.add(folder.id)) {
        _selectedFolderIds.remove(folder.id);
      }
    });
  }

  Future<void> _openFolder(NoteFolder folder) async {
    if (_selectionMode) {
      _toggleSelection(folder);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderNotesScreen(folder: folder),
      ),
    );

    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: () =>
                    setState(() => _selectedFolderIds.clear()),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _selectionMode
              ? '${_selectedFolderIds.length} selected'
              : 'Folders',
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              tooltip: 'Delete selected folders',
              onPressed: _deleteSelectedFolders,
              icon: const Icon(Icons.delete_outline_rounded),
            )
          else
            IconButton(
              tooltip: 'New folder',
              onPressed: _addFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
        ],
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _addFolder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New folder'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? _EmptyFolders(onCreate: _addFolder)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: _folders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    final selected = _selectedFolderIds.contains(folder.id);
                    final count = _counts[folder.id] ?? 0;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        selected: selected,
                        leading: selected
                            ? CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Icon(
                                  Icons.check_rounded,
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                ),
                              )
                            : CircleAvatar(
                                backgroundImage: folder.folderCoverImagePath != null &&
                                        File(folder.folderCoverImagePath!).existsSync()
                                    ? FileImage(File(folder.folderCoverImagePath!))
                                    : null,
                                child: folder.folderCoverImagePath == null ||
                                        !File(folder.folderCoverImagePath!).existsSync()
                                    ? const OrahAssetIcon(
                                        'folder',
                                        size: 22,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                        title: Text(
                          folder.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '$count note${count == 1 ? '' : 's'}',
                        ),
                        onTap: () => _openFolder(folder),
                        onLongPress: () => _toggleSelection(folder),
                        trailing: _selectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (_) => _toggleSelection(folder),
                              )
                            : PopupMenuButton<String>(
                                tooltip: 'Folder options',
                                onSelected: (action) {
                                  if (action == 'open') {
                                    _openFolder(folder);
                                  } else if (action == 'rename') {
                                    _renameFolder(folder);
                                  } else if (action == 'delete') {
                                    _deleteFolder(folder);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'open',
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(Icons.folder_open_outlined),
                                      title: Text('Open'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: ListTile(
                                      dense: true,
                                      leading:
                                          Icon(Icons.drive_file_rename_outline),
                                      title: Text('Rename'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Delete'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

class FolderNotesScreen extends StatefulWidget {
  const FolderNotesScreen({super.key, required this.folder});

  final NoteFolder folder;

  @override
  State<FolderNotesScreen> createState() => _FolderNotesScreenState();
}

class _FolderNotesScreenState extends State<FolderNotesScreen> {
  bool _loading = true;
  List<Note> _notes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    if (!mounted) return;

    setState(() {
      _notes = notes
          .where(
            (note) =>
                note.folderId == widget.folder.id &&
                !note.isTrashed &&
                !note.isArchived &&
                !note.isLocked,
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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

    if (mounted) await _load();
  }

  Future<void> _removeFromFolder(Note note) async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(
      note.copyWith(
        clearFolder: true,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _moveToTrash(Note note) async {
    final repository = await NoteRepositoryProvider.instance();
    await repository.saveNote(
      note.copyWith(
        isTrashed: true,
        isPinned: false,
        isFavorite: false,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.name),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'No notes in this folder yet.\nOpen a note and choose Organize to add it here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final preview = note.content
                        .trim()
                        .replaceAll(RegExp(r'\s+'), ' ');

                    return ListTile(
                      leading: Icon(
                        note.type == NoteType.checklist
                            ? Icons.checklist_rounded
                            : Icons.note_outlined,
                      ),
                      title: Text(
                        note.title.trim().isEmpty
                            ? 'Untitled note'
                            : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: preview.isEmpty
                          ? null
                          : Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _openNote(note),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'remove') {
                            _removeFromFolder(note);
                          } else if (action == 'trash') {
                            _moveToTrash(note);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove from folder'),
                          ),
                          PopupMenuItem(
                            value: 'trash',
                            child: Text('Move to Trash'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _FolderDraft {
  const _FolderDraft(this.name, this.imagePath);

  final String name;
  final String? imagePath;
}

class _EmptyFolders extends StatelessWidget {
  const _EmptyFolders({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No folders yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create folders to keep related notes together.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create folder'),
            ),
          ],
        ),
      ),
    );
  }
}
