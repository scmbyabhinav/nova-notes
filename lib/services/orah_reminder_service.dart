import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class OrahReminderService {
  OrahReminderService._();
  static final instance = OrahReminderService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  int _notificationId(String key) =>
      ByteData.view(Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes).buffer).getInt32(0) & 0x7fffffff;

  Future<void> schedule({required String noteId, required String title, required DateTime when}) async {
    if (!_initialized) await initialize();
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: _notificationId(noteId),
      title: 'Orah reminder',
      body: title,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'orah_reminders',
          'Orah reminders',
          channelDescription: 'Reminders for notes and tasks',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: noteId,
    );
  }

  Future<void> cancel(String noteId) async => _plugin.cancel(id: _notificationId(noteId));
}
