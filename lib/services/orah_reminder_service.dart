import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../data/repositories/note_repository_provider.dart';
import '../screens/note_editor_screen.dart';
import '../core/navigation/orah_navigation.dart';

class OrahReminderService {
  OrahReminderService._();
  static final instance = OrahReminderService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  bool _initialized = false;\n  String? _pendingLaunchPayload;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings, onDidReceiveNotificationResponse: _onNotificationResponse);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    final noteId = response.payload;
    if (noteId == null || noteId.isEmpty) return;
    final repository = await NoteRepositoryProvider.instance();
    final note = await repository.getNote(noteId);
    if (note == null) return;
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: repository, note: note)));
  }

  int _notificationId(String key) =>
      ByteData.view(Uint8List.fromList(sha256.convert(utf8.encode(key)).bytes).buffer).getInt32(0) & 0x7fffffff;

  Future<void> schedule({required String noteId, required String title, required DateTime when, String? payloadNoteId}) async {
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
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payloadNoteId ?? noteId,
    );
  }

  Future<void> cancel(String noteId) async {\n    if (!_initialized) await initialize();\n    await Future.wait([\n      _plugin.cancel(id: _notificationId('note:$noteId')),\n      // Clear reminders created by older Orah builds before IDs were namespaced.\n      _plugin.cancel(id: _notificationId(noteId)),\n    ]);\n  }
}
