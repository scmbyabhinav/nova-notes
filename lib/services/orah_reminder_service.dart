import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../screens/note_editor_screen.dart';

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
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _onNotificationResponse);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingLaunchPayload = launch?.notificationResponse?.payload;
    }
    _initialized = true;
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
        noteId: 'checklist:\${target.checklistId}',
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
