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
    final rawFolders = prefs.getString(_foldersKey);
    var folders = <VaultFolder>[];
    if (rawFolders != null) {
      try {
        folders = (jsonDecode(rawFolders) as List)
            .whereType<Map>()
            .map((item) => VaultFolder.fromMap(Map<String, dynamic>.from(item)))
            .toList();
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
    setState(() {
      _authenticated = false;
      _loading = true;
      _lockedNotes = const [];
    });
    if (!await _authenticateVault()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final repository = _repository;
    if (!mounted || repository == null) return;
    setState(() => _authenticated = true);
    _subscription = repository.watchVaultNotes().listen((notes) {
      if (!mounted) return;
      setState(() {
        _lockedNotes = notes.where((note) => !note.isTrashed).toList()
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
    _subscription = repository.watchVaultNotes().listen((notes) {
      if (!mounted) return;
      setState(() {
        _lockedNotes = notes.where((note) => !note.isTrashed).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _loading = false;
      });
    });
    await repository.refresh();
  }

  Future<bool> _authenticateVault() async {
    final security = NovaSecurityService();
    if (await security.canUseBiometrics() &&
        await security.authenticateBiometric()) {
      return true;
    }
    if (!await security.hasPin() || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault access requires device biometrics or a PIN. Set a PIN in Settings > Security & Privacy.')),
        );
      }
      return false;
    }
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Unlock Vault'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: const InputDecoration(labelText: '4–8 digit PIN'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop('forgot_pin'), child: const Text('Forgot PIN?')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Unlock')),
        ],
      ),
    );
    controller.dispose();
    if (pin == 'forgot_pin') {
      await _resetVaultPin();
      return false;
    }
    if (pin == null) return false;
    final ok = await security.verifyPin(pin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect Vault PIN.')),
      );
    }
    return ok;
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Vault folder'),
        content: TextField(controller: controller, autofocus: true, maxLength: 40, decoration: const InputDecoration(labelText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final folder = VaultFolder(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name);
    final folders = [..._folders, folder];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_foldersKey, jsonEncode(folders.map((item) => item.toMap()).toList()));
    if (!mounted) return;
    setState(() { _folders = folders; _selectedFolderId = folder.id; });
  }

  Future<void> _assignFolder(Note note, String? folderId) async {
    final repository = _repository;
    if (repository == null) return;
    await repository.saveNote(note.copyWith(vaultFolderId: folderId, clearVaultFolder: folderId == null, updatedAt: DateTime.now()));
  }

  Future<void> _resetVaultPin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Vault PIN?'),
        content: const Text('Resetting your PIN will permanently delete every note currently in the Vault. This cannot be undone because the local private-note data must be cleared to maintain encryption integrity.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete Vault and reset')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repository = _repository ?? await NoteRepositoryProvider.instance();
    final vaultNotes = await repository.getVaultNotes();
    for (final note in vaultNotes) {
      await repository.deleteNote(note.id);
    }
    final security = NovaSecurityService();
    await security.removePin();
    final firstController = TextEditingController();
    final secondController = TextEditingController();
    final newPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create a new Vault PIN'),
        content: TextField(controller: firstController, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'New 4–8 digit PIN')),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext, firstController.text), child: const Text('Continue'))],
      ),
    );
    if (newPin == null || !RegExp(r'^\d{4,8}
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
      appBar: AppBar(title: const Text('Vault / Locked Notes')),
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
                      IconButton(tooltip: 'Create private note', onPressed: () async {
                        final repository = _repository;
                        if (repository == null) return;
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: repository, initialVaultFolderId: _selectedFolderId)));
                        await repository.refresh();
                      }, icon: const Icon(Icons.add_rounded)),
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
                        ChoiceChip(label: Text(folder.name), selected: _selectedFolderId == folder.id, onSelected: (_) => setState(() => _selectedFolderId = folder.id)),
                        const SizedBox(width: 6),
                      ],
                      ActionChip(avatar: const Icon(Icons.create_new_folder_outlined, size: 18), label: const Text('New folder'), onPressed: _createFolder),
                    ]),
                  ),
                ),
                Expanded(child: _lockedNotes.isEmpty
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
                        Text(
                          'Lock a note from its editor to keep it in your private vault.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lockedNotes.where((note) => _selectedFolderId == null || note.vaultFolderId == _selectedFolderId).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final filteredNotes = _lockedNotes.where((item) => _selectedFolderId == null || item.vaultFolderId == _selectedFolderId).toList();
                    final note = filteredNotes[index];
                    final currentFolder = _folders.where((folder) => folder.id == note.vaultFolderId).firstOrNull;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_rounded),
                        title: Text(note.title.isEmpty ? 'Private note' : note.title),
                        subtitle: Text('${currentFolder == null ? 'Unfiled' : currentFolder.name} · Updated ${_relativeTime(note.updatedAt)}'),
                        trailing: PopupMenuButton<String?>(
                          tooltip: 'Move to folder',
                          onSelected: (folderId) => _assignFolder(note, folderId),
                          itemBuilder: (_) => [
                            const PopupMenuItem<String?>(value: null, child: Text('Unfiled')),
                            for (final folder in _folders) PopupMenuItem<String?>(value: folder.id, child: Text(folder.name)),
                          ],
                        ),
                        onTap: () => _openNote(note),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return difference.inMinutes.toString() + 'm ago';
    if (difference.inDays < 1) return difference.inHours.toString() + 'h ago';
    if (difference.inDays < 7) return difference.inDays.toString() + 'd ago';
    return date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString();
  }
}
).hasMatch(newPin)) {
      firstController.dispose();
      secondController.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault was cleared. Set a new PIN in Security & Privacy.')));
      return;
    }
    final confirmPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm new PIN'),
        content: TextField(controller: secondController, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'Confirm 4–8 digit PIN')),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext, secondController.text), child: const Text('Save PIN'))],
      ),
    );
    firstController.dispose();
    secondController.dispose();
    if (confirmPin == newPin) {
      await security.setPin(newPin);
      await security.setAppLockEnabled(true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vault cleared and new PIN saved.')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs did not match. Vault was cleared; set a PIN in Security & Privacy.')));
    }
    if (mounted) Navigator.of(context).pop();
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
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Vault / Locked Notes')),
      body: !_authenticated || _loading
          ? const Center(child: CircularProgressIndicator())
          : _lockedNotes.isEmpty
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
                        Text(
                          'Lock a note from its editor to keep it in your private vault.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lockedNotes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final note = _lockedNotes[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.lock_rounded),
                        title: Text(note.title.isEmpty ? 'Private note' : note.title),
                        subtitle: Text('Updated ' + _relativeTime(note.updatedAt)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _openNote(note),
                      ),
                    );
                  },
                ),
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return difference.inMinutes.toString() + 'm ago';
    if (difference.inDays < 1) return difference.inHours.toString() + 'h ago';
    if (difference.inDays < 7) return difference.inDays.toString() + 'd ago';
    return date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString();
  }
}
