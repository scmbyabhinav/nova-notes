import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/streak_service.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key, required this.notes});
  final List<Note> notes;

  static const moods = <String, (String, String, Color)>{
    'happy': ('Happy', '😊', Color(0xFFF59E0B)),
    'neutral': ('Neutral', '😐', Color(0xFF64748B)),
    'sad': ('Sad', '😢', Color(0xFF3B82F6)),
    'angry': ('Angry', '😡', Color(0xFFEF4444)),
    'thoughtful': ('Thoughtful', '🤔', Color(0xFF8B5CF6)),
  };
  static const indigo = Color(0xFF312E81);
  static const emerald = Color(0xFF059669);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeNotes = notes.where((note) => !note.isTrashed).toList();
    final streak = const StreakService().calculateCurrentStreak(activeNotes);
    final counts = <String, int>{
      for (final mood in moods.keys)
        mood: activeNotes.where((note) => note.mood == mood).length,
    };
    final moodTotal = counts.values.fold<int>(0, (sum, count) => sum + count);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final weekly = List<int>.generate(7, (i) {
      final day = start.add(Duration(days: i));
      return activeNotes.where((note) {
        final created = note.createdAt.toLocal();
        return created.year == day.year && created.month == day.month && created.day == day.day;
      }).length;
    });
    final maxCount = weekly.fold<int>(0, (max, n) => n > max ? n : max);
    final chartMax = maxCount == 0 ? 4.0 : (maxCount + 1).toDouble();
    final interval = maxCount <= 4 ? 1.0 : (maxCount / 4).ceilToDouble();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light ? const Color(0xFFF8FAFC) : theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Your Journey')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('Small moments add up.', style: theme.textTheme.titleLarge?.copyWith(color: indigo, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('A gentle look at your writing habits and reflections.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _MetricCard(label: 'Current Streak', value: '$streak', detail: streak == 1 ? 'day in a row' : 'days in a row', icon: Icons.local_fire_department_rounded, accent: const Color(0xFFEA580C))),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(label: 'Total Notes', value: '${activeNotes.length}', detail: 'notes saved', icon: Icons.description_rounded, accent: emerald)),
            ]),
            const SizedBox(height: 22),
            _SectionCard(
              title: 'Mood Distribution',
              subtitle: 'The feelings you have captured',
              child: moodTotal == 0
                  ? const _EmptyMoodState()
                  : Column(children: [
                      SizedBox(
                        height: 190,
                        child: PieChart(PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: [
                            for (final entry in counts.entries)
                              if (entry.value > 0)
                                PieChartSectionData(
                                  value: entry.value.toDouble(),
                                  color: moods[entry.key]!.$3,
                                  radius: 54,
                                  title: '${(entry.value * 100 / moodTotal).round()}%',
                                  titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                          ],
                        )),
                      ),
                      const SizedBox(height: 14),
                      Wrap(spacing: 14, runSpacing: 10, children: [
                        for (final entry in counts.entries)
                          if (entry.value > 0)
                            _MoodLegend(emoji: moods[entry.key]!.$2, label: moods[entry.key]!.$1, count: entry.value, color: moods[entry.key]!.$3),
                      ]),
                    ]),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Weekly Activity',
              subtitle: 'Notes created over the last 7 days',
              child: SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMax,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${rod.toY.round()} notes', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: interval,
                      getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    )),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 6) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(DateFormat('E').format(start.add(Duration(days: i))), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        );
                      },
                    )),
                  ),
                  barGroups: [
                    for (var i = 0; i < weekly.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: weekly[i].toDouble(),
                          width: 18,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          color: i == 6 ? emerald : indigo.withValues(alpha: 0.72),
                        ),
                      ]),
                  ],
                )),
              ),
            ),
            const SizedBox(height: 12),
            Text('Your notes stay on this device. These insights are calculated from your saved notes.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, required this.detail, required this.icon, required this.accent});
  final String label, value, detail;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: label == 'Current Streak' ? indigo : const Color(0xFF059669))),
          Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          child,
        ]),
      ),
    );
  }
}

class _MoodLegend extends StatelessWidget {
  const _MoodLegend({required this.emoji, required this.label, required this.count, required this.color});
  final String emoji, label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('$emoji $label', style: theme.textTheme.bodySmall),
      const SizedBox(width: 4),
      Text('$count', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}

class _EmptyMoodState extends StatelessWidget {
  const _EmptyMoodState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Text('🌱', style: TextStyle(fontSize: 34)),
        const SizedBox(height: 8),
        Text('Your mood story starts here', textAlign: TextAlign.center, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text('Choose a mood when you write a note. Your distribution will appear here.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}
