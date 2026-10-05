import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';

import '../core/services/nova_security_service.dart';
import '../data/repositories/local_note_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../models/vault_folder.dart';
import 'note_editor_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  LocalNoteRepository? _repository;
  StreamSubscription<List<Note>>? _subscription;
  List<Note> _lockedNotes = const [];
  bool _loading = true;
  bool _authenticated = false;
  DateTime? _pausedAt;
  int _autoLockMinutes = 5;
  List<VaultFolder> _folders = const [];
  String? _selectedFolderId;
  static const _autoLockKey = 'orah_vault_auto_lock_minutes';
  static const _foldersKey = 'orah_vault_folders_v1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVaultPreferences();
    _initialize();
  }

  Future<void> _loadVaultPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_foldersKey);
    var folders = <VaultFolder>[];
    if (raw != null) {
      try {
        folders = (jsonDecode(raw) as List).whereType<Map>()
            .map((item) => VaultFolder.fromMap(Map<String, dynamic>.from(item))).toList();
      } catch (_) {
        folders = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _autoLockMinutes = prefs.getInt(_autoLockKey) ?? 5;
      _folders = folders;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final elapsed = DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      if (_autoLockMinutes != 0 && elapsed >= Duration(minutes: _autoLockMinutes)) {
        _reauthenticateAfterTimeout();
      }
    }
  }

  Future<void> _reauthenticateAfterTimeout() async {
    if (!mounted || !_authenticated) return;
    await _subscription?.cancel();
    setState(() { _authenticated = false; _loading = true; _lockedNotes = const []; });
    if (!await _authenticateVault()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final repository = _repository;
    if (!mounted || repository == null) return;
    setState(() => _authenticated = true);
    _subscription = repository.watchNotes().listen((notes) {
      if (!mounted) return;
      setState(() {
        _lockedNotes = notes.where((note) => note.isLocked && !note.isTrashed).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _loading = false;
      });
    });
    await repository.refresh();
  }

  Future<void> _initialize() async {
    if (!await _authenticateVault()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    setState(() => _authenticated = true);
    _repository = repository;
    _subscription = repository.watchNotes().listen((notes) {
      if (!mounted) return;
      setState(() {
        _lockedNotes = notes.where((note) => note.isLocked && !note.isTrashed).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _loading = false;
      });
    });
    await repository.refresh();
  }

  Future<String?> _promptVaultPin({required String title, required bool confirm}) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: first, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: '4–8 digit Vault PIN')),
            if (confirm) TextField(controller: second, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Confirm PIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (confirm && first.text != second.text) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('PINs do not match.')));
                return;
              }
              Navigator.of(dialogContext).pop(first.text);
            },
            child: Text(confirm ? 'Create Vault' : 'Unlock'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    if (result == null || !RegExp(r'^\\d{4,8}$').hasMatch(result)) {
      if (result != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault PIN must contain 4–8 digits.')));
      return null;
    }
    return result;
  }

  Future<bool> _authenticateVault() async {
    final security = NovaSecurityService();
    final hasPin = await security.hasVaultPin();
    final pin = await _promptVaultPin(title: hasPin ? 'Unlock Vault' : 'Create Vault PIN', confirm: !hasPin);
    if (pin == null) return false;
    if (!hasPin) {
      await security.setVaultPin(pin);
      return true;
    }
    final ok = await security.verifyVaultPin(pin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Vault PIN.')));
    }
    return ok;
  }

  Future<void> _changeVaultPin() async {
    final current = await _promptVaultPin(title: 'Verify current Vault PIN', confirm: false);
    if (current == null || !await NovaSecurityService().verifyVaultPin(current)) {
      if (mounted && current != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect current Vault PIN.')));
      return;
    }
    final next = await _promptVaultPin(title: 'Create new Vault PIN', confirm: true);
    if (next == null) return;
    await NovaSecurityService().setVaultPin(next);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault PIN changed.')));
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Vault folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
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
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (!mounted || name == null || name.isEmpty || name.length > 40) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final folder = VaultFolder(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
    );
    final folders = [..._folders, folder];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((item) => item.toMap()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _selectedFolderId = folder.id;
    });
  }

  Future<void> _renameFolder(VaultFolder folder) async {
    final controller = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Vault folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
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

    if (!mounted || name == null || name.isEmpty || name.length > 40) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final renamed = VaultFolder(id: folder.id, name: name);
    final folders = _folders
        .map((item) => item.id == folder.id ? renamed : item)
        .toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((item) => item.toMap()).toList()),
    );
    if (!mounted) return;
    setState(() => _folders = folders);
  }

  Future<void> _deleteFolder(VaultFolder folder) async {
    final noteCount = _lockedNotes.where((note) => note.vaultFolderId == folder.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${folder.name}?'),
        content: Text(
          noteCount == 0
              ? 'This folder is empty.'
              : 'Are you sure? $noteCount private note(s) will be moved to Unfiled.',
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

    final repository = _repository;
    if (repository != null) {
      final notesToUnassign = _lockedNotes
          .where((note) => note.vaultFolderId == folder.id)
          .toList();
      for (final note in notesToUnassign) {
        await repository.saveNote(
          note.copyWith(clearVaultFolder: true, updatedAt: DateTime.now()),
        );
      }
    }

    final folders = _folders.where((item) => item.id != folder.id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _foldersKey,
      jsonEncode(folders.map((item) => item.toMap()).toList()),
    );
    if (!mounted) return;
    setState(() {
      _folders = folders;
      if (_selectedFolderId == folder.id) _selectedFolderId = null;
    });
  }

  Future<void> _assignFolder(Note note, String? folderId) async {
    final repository = _repository;
    if (repository == null) return;
    await repository.saveNote(note.copyWith(vaultFolderId: folderId, clearVaultFolder: folderId == null, updatedAt: DateTime.now()));
  }

  Future<void> _createPrivateNote() async {
    final repository = _repository;
    if (repository == null) return;
    final security = NovaSecurityService();
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final content = await security.encryptPrivatePayload(jsonEncode({'title': '', 'content': '', 'tags': <String>[], 'checklistItems': <Map<String, dynamic>>[]}));
    final note = Note(id: id, title: '', content: content, type: NoteType.text, createdAt: now, updatedAt: now, isLocked: true, vaultFolderId: _selectedFolderId);
    await repository.saveNote(note);
    if (mounted) await _openNote(note);
  }

  Future<void> _openNote(Note note) async {
    final repository = _repository;
    if (repository == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(repository: repository, note: note),
      ),
    );
    await repository.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault / Locked Notes'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) { if (value == 'change_pin') _changeVaultPin(); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'change_pin', child: Text('Change Vault PIN')),
            ],
          ),
        ],
      ),
      body: !_authenticated || _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('End-to-End Encrypted', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      IconButton(tooltip: 'Create private note', onPressed: _createPrivateNote, icon: const Icon(Icons.add_rounded)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      ChoiceChip(label: const Text('All folders'), selected: _selectedFolderId == null, onSelected: (_) => setState(() => _selectedFolderId = null)),
                      const SizedBox(width: 6),
                      for (final folder in _folders) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChoiceChip(
                              label: Text(folder.name),
                              selected: _selectedFolderId == folder.id,
                              onSelected: (_) => setState(() => _selectedFolderId = folder.id),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Vault folder options',
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
                          ],
                        ),
                        const SizedBox(width: 6),
                      ],
                      ActionChip(avatar: const Icon(Icons.create_new_folder_outlined, size: 18), label: const Text('New folder'), onPressed: _createFolder),
                    ]),
                  ),
                ),
                Expanded(
                  child: _lockedNotes.where((note) => _selectedFolderId == null || note.vaultFolderId == _selectedFolderId).isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 56, color: theme.colorScheme.primary),
                                const SizedBox(height: 14),
                                Text('Your vault is empty', style: theme.textTheme.titleLarge),
                                const SizedBox(height: 8),
                                Text('Lock a note from its editor or create a private note.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _lockedNotes.where((note) => _selectedFolderId == null || note.vaultFolderId == _selectedFolderId).length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notes = _lockedNotes.where((note) => _selectedFolderId == null || note.vaultFolderId == _selectedFolderId).toList();
                            final note = notes[index];
                            VaultFolder? folder;
                            for (final candidate in _folders) {
                              if (candidate.id == note.vaultFolderId) folder = candidate;
                            }
                            return Card(
                              child: ListTile(
                                leading: const Icon(Icons.lock_rounded),
                                title: Text(note.title.isEmpty ? 'Private note' : note.title),
                                subtitle: Text('${folder?.name ?? 'Unfiled'} · Updated ${_relativeTime(note.updatedAt)}'),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Move to folder',
                                  onSelected: (folderId) => _assignFolder(note, folderId == '__unfiled__' ? null : folderId),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: '__unfiled__', child: Text('Unfiled')),
                                    for (final folder in _folders) PopupMenuItem(value: folder.id, child: Text(folder.name)),
                                  ],
                                ),
                                onTap: () => _openNote(note),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
