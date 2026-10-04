import 'dart:async';

import 'package:flutter/material.dart';

import '../core/services/nova_security_service.dart';
import '../data/repositories/local_note_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  LocalNoteRepository? _repository;
  StreamSubscription<List<Note>>? _subscription;
  List<Note> _lockedNotes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (!await _authenticateVault()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
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
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Unlock')),
        ],
      ),
    );
    controller.dispose();
    if (pin == null) return false;
    final ok = await security.verifyPin(pin);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect Vault PIN.')),
      );
    }
    return ok;
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
      body: _loading
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
