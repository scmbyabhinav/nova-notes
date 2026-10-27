import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/note.dart';

class CalendarHistoryScreen extends StatefulWidget {
  const CalendarHistoryScreen({super.key, required this.notes});

  final List<Note> notes;

  @override
  State<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends State<CalendarHistoryScreen> {
  static const Color _indigo = Color(0xFF312E81);
  static const Color _emerald = Color(0xFF059669);
  static const Map<String, String> _moodEmoji = {
    'happy': '😊',
    'neutral': '😐',
    'sad': '😢',
    'angry': '😡',
    'thoughtful': '🤔',
  };

  late final List<Note> _activeNotes;
  late final Map<DateTime, List<Note>> _notesByDay;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void initState() {
    super.initState();
    _activeNotes = widget.notes
        .where((note) => !note.isTrashed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _notesByDay = <DateTime, List<Note>>{};
    for (final note in _activeNotes) {
      final day = _dateOnly(note.createdAt.toLocal());
      (_notesByDay[day] ??= <Note>[]).add(note);
    }
  }

  List<Note> _eventsForDay(DateTime day) => _notesByDay[_dateOnly(day)] ?? const [];

  List<Note> get _visibleNotes {
    if (_selectedDay == null) return _activeNotes;
    return _eventsForDay(_selectedDay!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleNotes = _visibleNotes;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? const Color(0xFFF8FAFC)
          : theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Calendar & History'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: _indigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your writing rhythm',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_activeNotes.length} notes',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: _emerald,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TableCalendar<Note>(
                      firstDay: DateTime(2000, 1, 1),
                      lastDay: DateTime(2100, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          _selectedDay != null && isSameDay(_selectedDay, day),
                      eventLoader: _eventsForDay,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      calendarFormat: CalendarFormat.month,
                      availableCalendarFormats: const {CalendarFormat.month: 'Month'},
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle: theme.textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: _indigo),
                        rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: _indigo),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                        weekendStyle: theme.textTheme.labelSmall!.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      calendarStyle: CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: const EdgeInsets.all(4),
                        defaultTextStyle: theme.textTheme.bodyMedium!,
                        weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        todayDecoration: BoxDecoration(
                          color: _emerald.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                          border: Border.all(color: _emerald, width: 1.2),
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: _indigo,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: _emerald,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                        markerSize: 5,
                        markerMargin: const EdgeInsets.symmetric(horizontal: 1),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          return Positioned(
                            bottom: 5,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSameDay(_selectedDay, day)
                                    ? Colors.white
                                    : _emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        },
                      ),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = _dateOnly(selectedDay);
                          _focusedDay = focusedDay;
                        });
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                    ),
                    if (_selectedDay != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _selectedDay = null),
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          label: const Text('Show all notes'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDay == null
                          ? 'History timeline'
                          : DateFormat('EEEE, d MMMM').format(_selectedDay!),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${visibleNotes.length} ${visibleNotes.length == 1 ? 'note' : 'notes'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (visibleNotes.isEmpty)
              _EmptyHistoryState(
                selectedDay: _selectedDay,
                onShowAll: () => setState(() => _selectedDay = null),
              )
            else
              for (final note in visibleNotes) ...[
                _HistoryNoteCard(note: note, moodEmoji: _moodEmoji[note.mood]),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _HistoryNoteCard extends StatelessWidget {
  const _HistoryNoteCard({required this.note, required this.moodEmoji});

  final Note note;
  final String? moodEmoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = note.title.trim().isEmpty ? 'Untitled note' : note.title.trim();
    final time = DateFormat('d MMM yyyy · h:mm a').format(note.createdAt.toLocal());

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF312E81).withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(moodEmoji ?? '📝', style: const TextStyle(fontSize: 22)),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(time, style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          )),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState({required this.selectedDay, required this.onShowAll});

  final DateTime? selectedDay;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelectedDay = selectedDay != null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Icon(
              hasSelectedDay ? Icons.event_busy_rounded : Icons.edit_calendar_rounded,
              size: 38,
              color: _CalendarHistoryColors.indigo,
            ),
            const SizedBox(height: 10),
            Text(
              hasSelectedDay ? 'No notes on this day' : 'Your story starts with a note',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasSelectedDay
                  ? 'Pick a highlighted day to revisit a moment, or browse your full history.'
                  : 'Days with saved notes will be highlighted on your calendar.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasSelectedDay) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onShowAll, child: const Text('Show all notes')),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarHistoryColors {
  static const indigo = Color(0xFF312E81);
}
