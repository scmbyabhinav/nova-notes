import 'package:flutter/material.dart';
import '../data/repositories/local_note_repository.dart';
import '../models/note.dart';
import '../models/note_version.dart';

class NoteVersionHistorySheet extends StatefulWidget {
  const NoteVersionHistorySheet({super.key, required this.repository, required this.noteId});
  final LocalNoteRepository repository;
  final String noteId;

  @override
  State<NoteVersionHistorySheet> createState() => _NoteVersionHistorySheetState();
}

class _NoteVersionHistorySheetState extends State<NoteVersionHistorySheet> {
  late final Future<List<NoteVersion>> _versions;

  @override
  void initState() {
    super.initState();
    _versions = widget.repository.getNoteVersions(widget.noteId);
  }

  String _preview(Note note) {
    final title = note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();
    final body = note.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (body.isEmpty) return title;
    final preview = body.length > 100 ? '${body.substring(0, 100)}…' : body;
    return '$title\n$preview';
  }

  Future<void> _restore(NoteVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this version?'),
        content: const Text('Your current note will be saved in history before this version is restored.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.of(context).pop(version.note);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              const Icon(Icons.history_rounded),
              const SizedBox(width: 10),
              Expanded(child: Text('Version history', style: Theme.of(context).textTheme.titleLarge)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<NoteVersion>>(
              future: _versions,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text('Could not load version history.'));
                final versions = snapshot.data ?? const <NoteVersion>[];
                if (versions.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history_toggle_off_rounded, size: 42),
                      SizedBox(height: 12),
                      Text('No previous versions yet'),
                      SizedBox(height: 6),
                      Text('Orah saves a snapshot when you change note content.', textAlign: TextAlign.center),
                    ]),
                  ));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: versions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    final date = MaterialLocalizations.of(context).formatMediumDate(version.savedAt);
                    final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(version.savedAt));
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.history_rounded)),
                      title: Text(_preview(version.note), maxLines: 3, overflow: TextOverflow.ellipsis),
                      subtitle: Text('$date · $time'),
                      trailing: const Icon(Icons.restore_rounded),
                      onTap: () => _restore(version),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
