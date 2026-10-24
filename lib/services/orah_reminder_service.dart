import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../screens/note_editor_screen.dart';
import '../screens/reflection_prompt_screen.dart';
import '../screens/orah_connect_screen.dart';
import '../services/orah_scheduled_post_store.dart';

class OrahReminderService {
  OrahReminderService._();
  static final instance = OrahReminderService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const doneAction = 'orah_done';
  static const snooze10Action = 'orah_snooze_10';
  static const snooze60Action = 'orah_snooze_60';
  bool _initialized = false;
  String? _pendingLaunchPayload;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    // ORAH's current primary locale is India; keep scheduled DateTimes aligned
    // with the device's expected local clock rather than timezone package UTC.
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _onNotificationResponse);
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingLaunchPayload = launch?.notificationResponse?.payload;
    }
    _initialized = true;
    await reconcileScheduledReminders();
  }

  /// Reconcile persisted note due dates with Android's pending local alarms.
  /// The plugin's boot receiver restores alarms across restarts; this also
  /// repairs missing alarms the next time the app is opened.
  Future<void> reconcileScheduledReminders() async {
    if (!_initialized) return;
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    final now = DateTime.now();
    for (final note in notes) {
      if (note.isTrashed || note.isLocked) continue;
      final dueAt = note.dueAt;
      if (dueAt != null) {
        if (dueAt.isAfter(now)) {
          await schedule(noteId: note.id, title: note.title, when: dueAt);
        } else {
          await cancel(note.id);
          await repository.saveNote(note.copyWith(clearDueAt: true, updatedAt: now));
        }
      }
      for (final item in note.checklistItems) {
        final itemDueAt = item.dueAt;
        if (itemDueAt == null || item.isDone) continue;
        final reminderId = 'checklist:${item.id}';
        if (itemDueAt.isAfter(now)) {
          await schedule(
            noteId: reminderId,
            title: item.text,
            when: itemDueAt,
            payloadNoteId: note.id,
            payloadChecklistId: item.id,
          );
        } else {
          await cancel(reminderId);
          final updatedItems = note.checklistItems.map((candidate) =>
              candidate.id == item.id ? candidate.copyWith(clearDueAt: true) : candidate).toList();
          await repository.saveNote(note.copyWith(checklistItems: updatedItems, updatedAt: now));
        }
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final action = response.actionId;
    if (action == doneAction || action == snooze10Action || action == snooze60Action) {
      await _handleAction(action!, response.payload);
      return;
    }
    await openPayload(response.payload);
  }

  Future<void> _handleAction(String action, String? payload) async {
    final target = _decodePayload(payload);
    final noteId = target.noteId;
    if (noteId == null || noteId.isEmpty) return;
    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(noteId);
    if (note == null || note.isTrashed || note.isLocked) return;

    if (action == doneAction) {
      if (target.checklistId != null) {
        final index = note.checklistItems.indexWhere((item) => item.id == target.checklistId);
        if (index >= 0) {
          final items = [...note.checklistItems];
          items[index] = items[index].copyWith(isDone: true);
          await repository.saveNote(note.copyWith(checklistItems: items, updatedAt: DateTime.now()));
          await cancel('checklist:${target.checklistId}');
        }
      } else {
        await cancel(noteId);
      }
      return;
    }

    final delay = action == snooze60Action ? const Duration(hours: 1) : const Duration(minutes: 10);
    final when = DateTime.now().add(delay);
    if (target.checklistId != null) {
      final index = note.checklistItems.indexWhere((item) => item.id == target.checklistId);
      if (index < 0) return;
      final item = note.checklistItems[index];
      if (item.isDone) return;
      await schedule(
        noteId: 'checklist:${target.checklistId}',
        title: item.text,
        when: when,
        payloadNoteId: noteId,
        payloadChecklistId: target.checklistId,
      );
    } else {
      await schedule(noteId: noteId, title: note.title, when: when, payloadNoteId: noteId);
    }
  }

  Future<void> openPendingNotification() async {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    if (payload != null && payload.isNotEmpty) await openPayload(payload);
  }

  Future<void> openPayload(String? payload) async {
    if (payload != null && payload.isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map && decoded['type'] == 'daily_reflection') {
          await _openDailyReflection();
          return;
        }
      if (decoded is Map && decoded['type'] == 'scheduled_connect_post') {
        final postId = decoded['postId'];
        if (postId is String && postId.isNotEmpty) {
          final post = await OrahScheduledPostStore.instance.getById(postId);
          if (post == null) return;
          final navigator = orahNavigatorKey.currentState;
          if (navigator == null) return;
          navigator.push(MaterialPageRoute(
            builder: (_) => OrahConnectScreen(
              noteTitle: 'Scheduled share · ${post.platform}',
              noteContent: post.caption,
              scheduledPostId: post.id,
              preferredPlatform: post.platform,
              imagePath: post.imagePath,
            ),
          ));
          return;
        }
      }
      } catch (_) {
        // Existing note reminders may use a plain note ID payload.
      }
    }

    final target = _decodePayload(payload);
    final noteId = target.noteId;
    if (noteId == null || noteId.isEmpty) return;
    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(noteId);
    if (note == null || note.isTrashed || note.isLocked) return;
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: repository, note: note)));
  }

  Future<void> _openDailyReflection() async {
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('orah_daily_reflection_last_shown', today);

    final repository = await NoteRepositoryProvider.instance();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ReflectionPromptScreen(repository: repository),
      ),
    );
  }

  Future<void> scheduleDailyReflection({required TimeOfDay time}) async {
    if (!_initialized) await initialize();
    await _requestNotificationPermission();

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'orah_daily_reflection',
        'Daily Reflection',
        channelDescription: 'A gentle daily prompt to pause and reflect',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );

    await _plugin.zonedSchedule(
      id: _notificationId('daily-reflection'),
      title: 'Time for your Daily Reflection',
      body: 'Take a quiet moment to write down what is on your mind.',
      scheduledDate: tz.TZDateTime.from(next.toLocal(), tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: jsonEncode({'type': 'daily_reflection'}),
    );
  }

  /// Fires a local reminder that reopens the saved share draft for a final,
  /// user-confirmed share. This does not publish content automatically.
  Future<void> scheduleConnectPost({
    required String postId,
    required String platform,
    required String caption,
    required DateTime when,
  }) async {
    if (!_initialized) await initialize();
    await _requestNotificationPermission();
    if (!when.isAfter(DateTime.now())) {
      throw ArgumentError.value(when, 'when', 'Must be a future date/time');
    }
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'orah_connect_scheduled_shares',
        'ORAH Connect reminders',
        channelDescription: 'Reminders to share saved ORAH Connect drafts',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      id: _notificationId('connect:$postId'),
      title: 'Ready to share with $platform?',
      body: caption.trim().isEmpty ? 'Open ORAH to finish sharing your draft.' : caption.trim().replaceAll(RegExp(r'\\s+'), ' '),
      scheduledDate: tz.TZDateTime.from(when.toLocal(), tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({'type': 'scheduled_connect_post', 'postId': postId}),
    );
  }

  Future<void> cancelConnectPost(String postId) async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id: _notificationId('connect:$postId'));
  }

  Future<void> cancelDailyReflection() async {
    if (!_initialized) await initialize();
    await _plugin.cancel(id: _notificationId('daily-reflection'));
  }

  int _notificationId(String key) =>
      ByteData.view(Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes).buffer).getInt32(0) & 0x7fffffff;

  Future<void> schedule({
    required String noteId,
    required String title,
    required DateTime when,
    String? payloadNoteId,
    String? payloadChecklistId,
  }) async {
    if (!_initialized) await initialize();
    await _requestNotificationPermission();
    if (!when.isAfter(DateTime.now())) {
      await cancel(noteId);
      return;
    }
    if (title.trim().isEmpty) return;
    final safeTitle = title.trim();
    final payload = jsonEncode({
      'noteId': payloadNoteId ?? noteId,
      if (payloadChecklistId != null) 'checklistId': payloadChecklistId,
    });
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'orah_reminders',
        'Orah reminders',
        channelDescription: 'Reminders for notes and tasks',
        importance: Importance.high,
        priority: Priority.high,
        actions: const [
          AndroidNotificationAction(doneAction, 'Done', showsUserInterface: true),
          AndroidNotificationAction(snooze10Action, 'Snooze 10m', showsUserInterface: true),
          AndroidNotificationAction(snooze60Action, 'Snooze 1h', showsUserInterface: true),
        ],
      ),
    );
    await _plugin.zonedSchedule(
      id: _notificationId('note:$noteId'),
      title: 'ORAH reminder',
      body: safeTitle,
      scheduledDate: tz.TZDateTime.from(when.toLocal(), tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancel(String noteId) async {
    if (!_initialized) await initialize();
    await Future.wait([
      _plugin.cancel(id: _notificationId('note:$noteId')),
      _plugin.cancel(id: _notificationId(noteId)),
    ]);
  }

  _ReminderTarget _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const _ReminderTarget();
    try {
      final raw = jsonDecode(payload);
      if (raw is Map) {
        final noteId = raw['noteId'];
        final checklistId = raw['checklistId'];
        return _ReminderTarget(
          noteId: noteId is String ? noteId : null,
          checklistId: checklistId is String ? checklistId : null,
        );
      }
    } catch (_) {}
    return _ReminderTarget(noteId: payload);
  }
}

class _ReminderTarget {
  const _ReminderTarget({this.noteId, this.checklistId});
  final String? noteId;
  final String? checklistId;
}
