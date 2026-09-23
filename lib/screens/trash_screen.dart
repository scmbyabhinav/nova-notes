import 'package:flutter/material.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../services/orah_reminder_service.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Note> _notes = const [];
  bool _loading = true;

  Future<void> _load() async {
    final repo = await NoteRepositoryProvider.instance();
    final notes = await repo.getNotes();
    if (!mounted) return;
    setState(() { _notes = notes.where((n) => n.isTrashed).toList(); _loading = false; });
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _restore(Note note) async {
    final repo = await NoteRepositoryProvider.instance();
    await repo.saveNote(note.copyWith(isTrashed: false, updatedAt: DateTime.now()));
    if (note.dueAt != null && note.dueAt!.isAfter(DateTime.now())) {
      await OrahReminderService.instance.schedule(noteId: note.id, title: note.title, when: note.dueAt!);
    }
    for (final item in note.checklistItems) {
      if (item.dueAt != null && !item.isDone && item.dueAt!.isAfter(DateTime.now())) {
        await OrahReminderService.instance.schedule(noteId: 'checklist:${item.id}', title: item.text, when: item.dueAt!);
      }
    }
    await _load();
  }

  Future<void> _deleteForever(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text('This note will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await NoteRepositoryProvider.instance();
    await repo.deleteNote(note.id);
    await _load();
  }

  Future<void> _emptyTrash() async {
    if (_notes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text('Permanently delete ' + _notes.length.toString() + ' note' + (_notes.length == 1 ? '' : 's') + '?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Empty Trash')),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = await NoteRepositoryProvider.instance();
    for (final note in _notes) { await repo.deleteNote(note.id); }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (_notes.isNotEmpty) IconButton(tooltip: 'Empty Trash', onPressed: _emptyTrash, icon: const Icon(Icons.delete_sweep_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text('Trash is empty'))
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final note = _notes[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.delete_outline_rounded),
                        title: Text(note.isLocked ? 'Private note' : note.title),
                        subtitle: Text(note.isLocked ? 'Locked note' : (note.type == NoteType.checklist ? 'Checklist' : 'Note')),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => value == 'restore' ? _restore(note) : _deleteForever(note),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'restore', child: Text('Restore')),
                            PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
