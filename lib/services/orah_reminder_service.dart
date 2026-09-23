import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

import '../data/repositories/note_repository_provider.dart';
import '../screens/note_editor_screen.dart';
import '../core/navigation/orah_navigation.dart';

class OrahReminderService {
  OrahReminderService._();
  static final instance = OrahReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _pendingLaunchPayload;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _pendingLaunchPayload = launch?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final data = _decodePayload(response.payload);

    switch (response.actionId) {
      case 'orah_done':
        await _completeReminder(data);
        return;
      case 'orah_snooze_10':
        await _snoozeReminder(data, const Duration(minutes: 10));
        return;
      case 'orah_snooze_60':
        await _snoozeReminder(data, const Duration(hours: 1));
        return;
    }

    await openPayload(response.payload);
  }

  Map<String, String>? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      final raw = jsonDecode(payload);
      if (raw is Map) {
        final noteId = raw['noteId'] as String?;
        final scheduleId = raw['scheduleId'] as String?;
        if (noteId != null && noteId.isNotEmpty) {
          return {
            'noteId': noteId,
            'scheduleId': scheduleId ?? noteId,
          };
        }
      }
    } catch (_) {}

    // Backward compatibility with reminders created by older Orah builds.
    return {'noteId': payload, 'scheduleId': payload};
  }

  Future<void> _completeReminder(Map<String, String>? data) async {
    if (data == null) return;

    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(data['noteId']!);
    if (note == null || note.isTrashed) return;

    final scheduleId = data['scheduleId']!;

    if (scheduleId.startsWith('checklist:')) {
      final itemId = scheduleId.substring('checklist:'.length);
      final items = note.checklistItems
          .map(
            (item) => item.id == itemId
                ? item.copyWith(isDone: true)
                : item,
          )
          .toList();

      await repository.saveNote(
        note.copyWith(
          checklistItems: items,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await repository.saveNote(
        note.copyWith(
          clearDueAt: true,
          updatedAt: DateTime.now(),
        ),
      );
    }

    await cancel(scheduleId);
  }

  Future<void> _snoozeReminder(
    Map<String, String>? data,
    Duration delay,
  ) async {
    if (data == null) return;

    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(data['noteId']!);
    if (note == null || note.isTrashed) return;

    final scheduleId = data['scheduleId']!;
    var title = note.title.trim().isEmpty ? 'Reminder' : note.title.trim();

    if (scheduleId.startsWith('checklist:')) {
      final itemId = scheduleId.substring('checklist:'.length);
      for (final item in note.checklistItems) {
        if (item.id == itemId) {
          title = item.text;
          break;
        }
      }
    }

    await cancel(scheduleId);
    await schedule(
      noteId: scheduleId,
      title: title,
      when: DateTime.now().add(delay),
      payloadNoteId: note.id,
    );
  }

  Future<void> openPendingNotification() async {
    final payload = _pendingLaunchPayload;
    _pendingLaunchPayload = null;

    if (payload != null && payload.isNotEmpty) {
      await openPayload(payload);
    }
  }

  Future<void> openPayload(String? payload) async {
    final data = _decodePayload(payload);
    final noteId = data?['noteId'];
    if (noteId == null || noteId.isEmpty) return;

    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(noteId);
    if (note == null || note.isTrashed) return;

    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          repository: repository,
          note: note,
        ),
      ),
    );
  }

  int _notificationId(String key) {
    return ByteData.view(
          Uint8List.fromList(
            sha256.convert(utf8.encode(key)).bytes,
          ).buffer,
        ).getInt32(0) &
        0x7fffffff;
  }

  Future<void> schedule({
    required String noteId,
    required String title,
    required DateTime when,
    String? payloadNoteId,
  }) async {
    if (!_initialized) await initialize();
    if (!when.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: _notificationId('note:$noteId'),
      title: 'Orah reminder',
      body: title,
      scheduledDate: tz.TZDateTime.from(when.toLocal(), tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'orah_reminders',
          'Orah reminders',
          channelDescription: 'Reminders for notes and tasks',
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              'orah_done',
              'Done',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'orah_snooze_10',
              '10 min',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'orah_snooze_60',
              '1 hour',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'noteId': payloadNoteId ?? noteId,
        'scheduleId': noteId,
      }),
    );
  }

  Future<void> cancel(String noteId) async {
    if (!_initialized) await initialize();

    await Future.wait([
      _plugin.cancel(id: _notificationId('note:$noteId')),
      // Clear reminders created by older Orah builds before IDs were namespaced.
      _plugin.cancel(id: _notificationId(noteId)),
    ]);
  }
}
