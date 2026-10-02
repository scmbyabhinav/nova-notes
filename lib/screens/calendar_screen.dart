import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.onNotes});

  final VoidCallback? onNotes;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<Note> _notes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes.where((note) => !note.isTrashed && !note.isArchived).toList();
      _loading = false;
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Note> get _selectedDayNotes {
    final notes = _notes.where((note) =>
        _sameDay(note.createdAt, _selectedDate) ||
        (note.dueAt != null && _sameDay(note.dueAt!, _selectedDate))).toList();
    notes.sort((a, b) {
      final aTime = a.dueAt != null && _sameDay(a.dueAt!, _selectedDate) ? a.dueAt! : a.createdAt;
      final bTime = b.dueAt != null && _sameDay(b.dueAt!, _selectedDate) ? b.dueAt! : b.createdAt;
      return aTime.compareTo(bTime);
    });
    return notes;
  }

  Future<void> _openNote(Note note) async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(repository: repository, note: note),
    ));
    await _loadNotes();
  }

  DateTime get _initialScheduleDate {
    final selected = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 9);
    final now = DateTime.now();
    return selected.isAfter(now) ? selected : now.add(const Duration(hours: 1));
  }

  Future<void> _scheduleNote() async {
    final repository = await NoteRepositoryProvider.instance();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NoteEditorScreen(
        repository: repository,
        initialDueAt: _initialScheduleDate,
        autoOpenReminder: true,
      ),
    ));
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedNotes = _selectedDayNotes;
    final selectedLabel = DateFormat('EEEE, d MMMM y').format(_selectedDate);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadNotes,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Calendar', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('Notes by day and scheduled reminders', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Notes',
                      onPressed: widget.onNotes,
                      icon: const Icon(Icons.note_alt_outlined),
                    ),
                    IconButton(
                      tooltip: 'Go to today',
                      onPressed: () => setState(() => _selectedDate = DateUtils.dateOnly(DateTime.now())),
                      icon: const Icon(Icons.today_rounded),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverToBoxAdapter(
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: _loading
                      ? const SizedBox(height: 340, child: Center(child: CircularProgressIndicator()))
                      : CalendarDatePicker(
                          key: ValueKey('${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}'),
                          initialDate: _selectedDate,
                          firstDate: DateTime(1, 1, 1),
                          lastDate: DateTime(9999, 12, 31),
                          currentDate: DateUtils.dateOnly(DateTime.now()),
                          onDateChanged: (date) => setState(() => _selectedDate = DateUtils.dateOnly(date)),
                        ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(selectedLabel, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('${selectedNotes.length} ${selectedNotes.length == 1 ? 'note' : 'notes'}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _scheduleNote,
                      icon: const Icon(Icons.alarm_add_rounded),
                      label: const Text('Schedule note'),
                    ),
                  ],
                ),
              ),
            ),
            if (!_loading && selectedNotes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_rounded, size: 44, color: theme.colorScheme.primary),
                        const SizedBox(height: 10),
                        Text('Nothing on this day', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text('Choose another date or schedule a note for this day.', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList.builder(
                  itemCount: selectedNotes.length,
                  itemBuilder: (context, index) {
                    final note = selectedNotes[index];
                    final scheduled = note.dueAt != null && _sameDay(note.dueAt!, _selectedDate);
                    final time = scheduled ? note.dueAt! : note.createdAt;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _openNote(note),
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(scheduled ? Icons.alarm_rounded : Icons.note_alt_outlined, color: theme.colorScheme.onPrimaryContainer),
                          ),
                          title: Text(note.title.isEmpty ? 'Untitled note' : note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${scheduled ? 'Scheduled' : 'Created'} • ${DateFormat('h:mm a').format(time)}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
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
