import 'package:flutter/material.dart';
import '../core/widgets/orah_asset_icon.dart';

import '../data/repositories/folder_repository_provider.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/folder.dart';

class FoldersScreen extends StatefulWidget {
  const FoldersScreen({super.key});

  @override
  State<FoldersScreen> createState() => _FoldersScreenState();
}

class _FoldersScreenState extends State<FoldersScreen> {
  bool _loading = true;
  List<NoteFolder> _folders = const [];
  Map<String, int> _counts = const {};

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
      if (note.folderId != null && !note.isArchived) {
        counts[note.folderId!] = (counts[note.folderId!] ?? 0) + 1;
      }
    }

    if (!mounted) return;

    setState(() {
      _folders = folders;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _addFolder() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Folder name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (!mounted || name == null || name.isEmpty || name.length > 80) return;

    // Let the dialog route finish deactivating before changing the folder list.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final repository = await FolderRepositoryProvider.instance();
    await repository.saveFolder(
      NoteFolder(
        id: 'folder_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        createdAt: DateTime.now(),
      ),
    );

    if (!mounted) return;
    await _load();
  }

  Future<void> _renameFolder(NoteFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Folder name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || name == null || name.isEmpty || name.length > 80) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final repository = await FolderRepositoryProvider.instance();
    await repository.saveFolder(
      NoteFolder(
        id: folder.id,
        name: name,
        createdAt: folder.createdAt,
        iconCodePoint: folder.iconCodePoint,
        color: folder.color,
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
              : '$count note(s) will be moved to the main list without a folder.',
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

    if (!mounted || confirmed != true) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final folderRepository = await FolderRepositoryProvider.instance();
    final noteRepository = await NoteRepositoryProvider.instance();

    // Unassign notes before removing the folder, so no note retains a stale ID.
    final notes = await noteRepository.getNotes();
    for (final note in notes.where((note) => note.folderId == folder.id)) {
      await noteRepository.saveNote(
        note.copyWith(clearFolder: true, updatedAt: DateTime.now()),
      );
    }
    await folderRepository.deleteFolder(folder.id);

    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 12, 14),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Folders',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'New folder',
                            onPressed: _addFolder,
                            icon: const OrahAssetIcon('folder-plus'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverList.builder(
                      itemCount: _folders.length,
                      itemBuilder: (context, index) {
                        final folder = _folders[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: const OrahAssetIcon('folder', size: 24, color: Colors.white),
                              ),
                              title: Text(
                                folder.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${_counts[folder.id] ?? 0} notes',
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Folder options',
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _renameFolder(folder);
                                  } else if (action == 'delete') {
                                    _deleteFolder(folder);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(Icons.drive_file_rename_outline),
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
                          ),
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
