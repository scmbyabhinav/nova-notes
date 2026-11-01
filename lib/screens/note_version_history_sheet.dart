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
  int _selectedIndex = 0;

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
                final selectedIndex = _selectedIndex.clamp(0, versions.length - 1);
                final selected = versions[selectedIndex];
                final selectedDate = MaterialLocalizations.of(context).formatMediumDate(selected.savedAt);
                final selectedTime = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(selected.savedAt));
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timeline_rounded),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Version ${selectedIndex + 1} of ${versions.length}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
                              Text('$selectedDate · $selectedTime', style: Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                          Slider(
                            value: selectedIndex.toDouble(),
                            min: 0,
                            max: (versions.length - 1).toDouble(),
                            divisions: versions.length > 1 ? versions.length - 1 : null,
                            label: 'Version ${selectedIndex + 1}',
                            onChanged: versions.length < 2 ? null : (value) => setState(() => _selectedIndex = value.round()),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                            child: Text(_preview(selected.note), maxLines: 5, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _restore(selected),
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restore selected version'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: versions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final version = versions[index];
                          final date = MaterialLocalizations.of(context).formatMediumDate(version.savedAt);
                          final time = MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(version.savedAt));
                          return ListTile(
                            selected: index == selectedIndex,
                            leading: CircleAvatar(child: Icon(index == selectedIndex ? Icons.radio_button_checked_rounded : Icons.history_rounded)),
                            title: Text(_preview(version.note), maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text('$date · $time'),
                            onTap: () => setState(() => _selectedIndex = index),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
