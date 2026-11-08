import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/orah_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-first timer; it does not modify notes, folders, attachments or Kanban.
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with WidgetsBindingObserver {
  static const _focus = Duration(minutes: 25);
  static const _short = Duration(minutes: 5);
  static const _long = Duration(minutes: 15);
  Timer? _ticker;
  String _mode = 'focus';
  Duration _remaining = _focus;
  DateTime? _deadline;
  bool _running = false;
  bool _loaded = false;
  int _completed = 0;
  int _cycle = 0;

  Duration get _duration => _mode == 'shortBreak'
      ? _short : _mode == 'longBreak' ? _long : _focus;
  bool get _isFocus => _mode == 'focus';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loaded && _running) _syncClock();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    _mode = p.getString('orah_pomodoro_mode') ?? 'focus';
    _remaining = Duration(seconds: p.getInt('orah_pomodoro_remaining') ?? 1500);
    _completed = p.getInt('orah_pomodoro_completed') ?? 0;
    _cycle = p.getInt('orah_pomodoro_cycle') ?? 0;
    _running = p.getBool('orah_pomodoro_running') ?? false;
    final ms = p.getInt('orah_pomodoro_deadline');
    _deadline = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    _loaded = true;
    if (_running && _deadline != null) {
      _syncClock();
      unawaited(_syncCompletionAlert());
    } else {
      setState(() {});
    }
  }

  Future<void> _syncCompletionAlert() async {
    if (_running && _deadline != null) {
      await OrahReminderService.instance.schedulePomodoroCompletion(
        when: _deadline!,
        mode: _mode,
      );
    } else {
      await OrahReminderService.instance.cancelPomodoroCompletion();
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('orah_pomodoro_mode', _mode);
    await p.setInt('orah_pomodoro_remaining', _remaining.inSeconds);
    await p.setInt('orah_pomodoro_completed', _completed);
    await p.setInt('orah_pomodoro_cycle', _cycle);
    await p.setBool('orah_pomodoro_running', _running);
    if (_deadline == null) {
      await p.remove('orah_pomodoro_deadline');
    } else {
      await p.setInt('orah_pomodoro_deadline', _deadline!.millisecondsSinceEpoch);
    }
  }

  void _syncClock() {
    if (!_running || _deadline == null) return;
    final left = _deadline!.difference(DateTime.now());
    if (left <= Duration.zero) {
      _finish();
      return;
    }
    if (mounted) setState(() => _remaining = left);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running || _deadline == null) return;
      final left = _deadline!.difference(DateTime.now());
      if (left <= Duration.zero) {
        _finish();
      } else if (mounted) {
        setState(() => _remaining = left);
      }
    });
  }

  Future<void> _toggle() async {
    if (_running) {
      _ticker?.cancel();
      _remaining = _deadline?.difference(DateTime.now()) ?? _remaining;
      if (_remaining.isNegative) _remaining = Duration.zero;
      _running = false;
      _deadline = null;
    } else {
      _running = true;
      _deadline = DateTime.now().add(_remaining);
      _syncClock();
    }
    await _save();
    await _syncCompletionAlert();
    if (mounted) setState(() {});
  }

  Future<void> _reset() async {
    _ticker?.cancel();
    _running = false;
    _deadline = null;
    _remaining = _duration;
    await _save();
    await _syncCompletionAlert();
    if (mounted) setState(() {});
  }

  Future<void> _choose(String mode) async {
    if (_running) return;
    _mode = mode;
    _remaining = _duration;
    _deadline = null;
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _finish() async {
    if (!_running) return;
    _ticker?.cancel();
    final wasFocus = _isFocus;
    if (wasFocus) {
      _completed++;
      _cycle++;
      _mode = _cycle % 4 == 0 ? 'longBreak' : 'shortBreak';
    } else {
      _mode = 'focus';
    }
    _running = false;
    _deadline = null;
    _remaining = _duration;
    await _save();
    await OrahReminderService.instance.cancelPomodoroCompletion();
    // Audible system alert and haptic feedback for foreground completion;
    // the scheduled notification provides the background-device alert.
    unawaited(SystemSound.play(SystemSoundType.alert));
    unawaited(HapticFeedback.vibrate());
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(wasFocus
          ? (_mode == 'longBreak' ? 'Focus complete. Long break!' : 'Focus complete. Short break!')
          : 'Break complete. Ready to focus?'),
    ));
  }

  String _clock(Duration d) {
    final seconds = d.inSeconds.clamp(0, 5999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isFocus ? theme.colorScheme.primary : theme.colorScheme.tertiary;
    final progress = (1 - (_remaining.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)).toDouble();
    return Scaffold(
      appBar: AppBar(
        title: const Text('ORAH Focus'),
        // Keep the live countdown pinned below the app bar so it cannot
        // scroll out of view while the timer is running.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined,
                    size: 19, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 9),
                Text(
                  'TIME LEFT  ${_clock(_remaining)}',
                  key: const ValueKey('pomodoro_pinned_countdown'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _running ? 'RUNNING' : 'PAUSED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: !_loaded ? const Center(child: CircularProgressIndicator())
            : Center(child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(children: [
                  Text('Make room for deep work', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 14),
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Icon(Icons.timer_rounded, color: theme.colorScheme.onPrimaryContainer, size: 28),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TIME REMAINING',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  )),
                                Text(_clock(_remaining),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w900,
                                  )),
                              ],
                            ),
                          ),
                          Text(_running ? 'RUNNING' : 'PAUSED',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'focus', label: Text('Focus')),
                      ButtonSegment(value: 'shortBreak', label: Text('Short break')),
                      ButtonSegment(value: 'longBreak', label: Text('Long break')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _running ? null : (v) => _choose(v.first),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(width: 260, height: 260, child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(child: CircularProgressIndicator(
                        value: progress, strokeWidth: 12, strokeCap: StrokeCap.round,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: color,
                      )),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_clock(_remaining), style: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w800)),
                        Text(_running ? 'IN SESSION' : 'READY', style: theme.textTheme.labelLarge),
                      ]),
                    ],
                  )),
                  const SizedBox(height: 28),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    FilledButton.icon(
                      onPressed: _toggle,
                      icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      label: Text(_running ? 'Pause' : 'Start focus'),
                      style: FilledButton.styleFrom(minimumSize: const Size(170, 56)),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      tooltip: 'Reset timer', onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded), iconSize: 26,
                    ),
                  ]),
                  const SizedBox(height: 28),
                  Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _PomodoroStat(label: 'Focus sessions', value: '$_completed'),
                      _PomodoroStat(label: 'Cycle', value: '${_cycle % 4}/4'),
                    ],
                  ))),
                  const SizedBox(height: 12),
                  Text('25 min focus · 5 min short break · 15 min long break after 4 focus sessions',
                    textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ]),
              ),
            )),
      ),
    );
  }
}

class _PomodoroStat extends StatelessWidget {
  const _PomodoroStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(label, style: Theme.of(context).textTheme.bodySmall),
  ]);
}
