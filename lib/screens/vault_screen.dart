import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/services/nova_security_service.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultPreview {
  const _VaultPreview({required this.note, required this.title, required this.content});
  final Note note;
  final String title;
  final String content;
}

class _VaultScreenState extends State<VaultScreen> {
  final _security = NovaSecurityService();
  final _searchController = TextEditingController();
  List<_VaultPreview> _previews = const [];
  bool _authenticated = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _pinDialog({required String title, bool confirm = false}) async {
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
            TextField(
              controller: first,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: '4–8 digit PIN'),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (confirm && first.text != second.text) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('PINs do not match.')));
              return;
            }
            Navigator.pop(dialogContext, first.text);
          }, child: Text(confirm ? 'Create Vault' : 'Unlock')),
        ],
      ),
    );
    if (result == null) return null;
    if (!RegExp(r'^\d{4,8}$').hasMatch(result)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must contain 4–8 digits.')));
      return null;
    }
    return result;
  }

  Future<void> _authenticate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasPin = await _security.hasVaultPin();
      final pin = await _pinDialog(
        title: hasPin ? 'Open Vault' : 'Create Vault PIN',
        confirm: !hasPin,
      );
      if (pin == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (hasPin) {
        if (!await _security.verifyVaultPin(pin)) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'Incorrect PIN. Vault remains locked.';
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect Vault PIN.')));
            Navigator.of(context).pop();
          }
          return;
        }
      } else {
        await _security.setVaultPin(pin);
      }
      await _loadVaultContents();
      if (mounted) setState(() {
        _authenticated = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = 'Vault could not be opened: $e';
      });
    }
  }

  Future<void> _loadVaultContents() async {
    final repository = await NoteRepositoryProvider.instance();
    final encryptedNotes = await repository.getVaultNotes();
    final previews = <_VaultPreview>[];
    for (final note in encryptedNotes) {
      try {
        final payload = jsonDecode(await _security.decryptPrivatePayload(note.content)) as Map<String, dynamic>;
        previews.add(_VaultPreview(
          note: note,
          title: (payload['title'] as String? ?? '').trim().isEmpty ? 'Untitled note' : payload['title'] as String,
          content: payload['content'] as String? ?? '',
        ));
      } catch (_) {
        previews.add(_VaultPreview(note: note, title: 'Unreadable private note', content: 'This note could not be decrypted.'));
      }
    }
    if (mounted) setState(() => _previews = previews);
  }

  List<_VaultPreview> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _previews;
    return _previews.where((item) => item.title.toLowerCase().contains(query) || item.content.toLowerCase().contains(query)).toList();
  }

  Future<void> _openNote(_VaultPreview preview) async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(repository: repository, note: preview.note),
    ));
    await _loadVaultContents();
  }

  Future<void> _unlockNote(_VaultPreview preview) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move note out of Vault?'),
        content: const Text('The note will become a normal note and will no longer be protected by the Vault PIN.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Unlock note')),
        ],
      ),
    );
    if (confirm != true) return;
    final repository = await NoteRepositoryProvider.instance();
    await repository.unlockVaultNote(preview.note.id);
    await _loadVaultContents();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note moved to normal notes.')));
  }

  Future<void> _deleteNote(_VaultPreview preview) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Vault note?'),
        content: const Text('This permanently deletes the note. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    final repository = await NoteRepositoryProvider.instance();
    await repository.deleteVaultNote(preview.note.id);
    await _loadVaultContents();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vault')),
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? 'Vault is locked.', textAlign: TextAlign.center),
        )),
      );
    }
    final notes = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            tooltip: 'Lock Vault',
            icon: const Icon(Icons.lock_outline),
            onPressed: () {
              setState(() {
                _authenticated = false;
                _previews = const [];
                _searchController.clear();
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search Vault notes',
                suffixIcon: _searchController.text.isEmpty ? null : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('Your Vault is empty. Lock a note to move it here.'))
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = notes[index];
                      return ListTile(
                        leading: const Icon(Icons.lock_rounded),
                        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(item.content.isEmpty ? 'Private note' : item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _openNote(item),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'unlock') _unlockNote(item);
                            if (value == 'delete') _deleteNote(item);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'unlock', child: Text('Unlock and move out')),
                            PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
