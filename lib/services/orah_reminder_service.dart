import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class OrahReminderService {
  OrahReminderService._();
  static final instance = OrahReminderService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> schedule({required String noteId, required String title, required DateTime when}) async {
    if (when.isBefore(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: noteId.hashCode & 0x7fffffff,
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

  Future<void> cancel(String noteId) async => _plugin.cancel(noteId.hashCode & 0x7fffffff);
}
