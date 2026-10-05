import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repositories/note_repository.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';

class ArchivedNotesScreen extends StatefulWidget {
  const ArchivedNotesScreen({super.key});

  @override
  State<ArchivedNotesScreen> createState() => _ArchivedNotesScreenState();
}

class _ArchivedNotesScreenState extends State<ArchivedNotesScreen> {
  NoteRepository? _repository;
  StreamSubscription<List<Note>>? _subscription;
  List<Note> _notes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _applyNotes(List<Note> notes) {
    if (!mounted) return;
    setState(() {
      _notes = notes.where((note) => note.isArchived && !note.isTrashed).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _loading = false;
    });
  }

  Future<void> _loadNotes() async {
    final repository = await NoteRepositoryProvider.instance();
    _repository = repository;
    _subscription ??= repository.watchNotes().listen(_applyNotes);
    _applyNotes(await repository.getNotes());
  }

  Future<void> _openNote(Note note) async {
    final repository = _repository ?? await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(repository: repository, note: note),
      ),
    );
    await _loadNotes();
  }

  Future<void> _restore(Note note) async {
    final repository = _repository ?? await NoteRepositoryProvider.instance();
    await repository.saveNote(
      note.copyWith(isArchived: false, updatedAt: DateTime.now()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note restored to your notes.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Notes'),
        actions: [
          IconButton(
            tooltip: 'Refresh archived notes',
            onPressed: _loadNotes,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.archive_outlined,
                          size: 56,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No archived notes',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Notes you archive will appear here. You can open them or restore them to your main notes list.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: _notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final note = _notes[index];
                      final title = note.isLocked
                          ? 'Private note'
                          : (note.title.trim().isEmpty ? 'Untitled note' : note.title);
                      final subtitle = note.isLocked
                          ? 'Locked note • Updated ${_formatDate(note.updatedAt)}'
                          : [
                              if (note.content.trim().isNotEmpty) note.content.trim(),
                              'Updated ${_formatDate(note.updatedAt)}',
                            ].join(' • ');
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: Icon(
                            note.isLocked
                                ? Icons.lock_outline_rounded
                                : Icons.archive_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _openNote(note),
                          trailing: IconButton(
                            tooltip: 'Restore note',
                            onPressed: () => _restore(note),
                            icon: const Icon(Icons.unarchive_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}
