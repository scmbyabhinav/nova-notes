import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-only action scheduling for ORAH. No network, API, account, or backend.
enum OrahActionStatus { scheduled, completed, cancelled, failed }

enum OrahActionRecurrence { none, daily, weekly, monthly }

class OrahAction {
  const OrahAction({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.timeZoneName,
    required this.recurrence,
    required this.status,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String timeZoneName;
  final OrahActionRecurrence recurrence;
  final OrahActionStatus status;
  final int retryCount;
  final String? lastError;

  OrahAction copyWith({
    String? title,
    DateTime? scheduledAt,
    String? timeZoneName,
    OrahActionRecurrence? recurrence,
    OrahActionStatus? status,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
  }) => OrahAction(
    id: id,
    title: title ?? this.title,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    timeZoneName: timeZoneName ?? this.timeZoneName,
    recurrence: recurrence ?? this.recurrence,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    lastError: clearLastError ? null : (lastError ?? this.lastError),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'scheduledAt': scheduledAt.toIso8601String(),
    'timeZoneName': timeZoneName,
    'recurrence': recurrence.name,
    'status': status.name,
    'retryCount': retryCount,
    'lastError': lastError,
  };

  factory OrahAction.fromJson(Map<String, dynamic> json) => OrahAction(
    id: json['id'] as String,
    title: json['title'] as String,
    scheduledAt: DateTime.parse(json['scheduledAt'] as String),
    timeZoneName: json['timeZoneName'] as String? ?? DateTime.now().timeZoneName,
    recurrence: OrahActionRecurrence.values.firstWhere(
      (value) => value.name == json['recurrence'],
      orElse: () => OrahActionRecurrence.none,
    ),
    status: OrahActionStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => OrahActionStatus.failed,
    ),
    retryCount: json['retryCount'] as int? ?? 0,
    lastError: json['lastError'] as String?,
  );
}

/// Persists action metadata on-device and schedules local Android notifications.
/// Recurrence is calculated from the device's local wall clock.
class OrahActionsService {
  OrahActionsService._();
  static final instance = OrahActionsService._();

  static const _storageKey = 'orah_local_actions_v1';
  static const maxRetries = 3;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _notifications.initialize(settings: settings);
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<List<OrahAction>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((value) => OrahAction.fromJson(Map<String, dynamic>.from(value)))
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    } catch (_) {
      // Preserve app stability if an older/corrupt record is encountered.
      return const [];
    }
  }

  Future<void> _save(List<OrahAction> actions) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(actions.map((action) => action.toJson()).toList()),
    );
  }

  Future<OrahAction> schedule({
    required String id,
    required String title,
    required DateTime scheduledAt,
    OrahActionRecurrence recurrence = OrahActionRecurrence.none,
  }) async {
    await initialize();
    final cleanTitle = title.trim();
    if (id.trim().isEmpty) throw ArgumentError.value(id, 'id', 'Must not be empty');
    if (cleanTitle.isEmpty) throw ArgumentError.value(title, 'title', 'Must not be empty');
    if (!scheduledAt.isAfter(DateTime.now())) {
      throw ArgumentError.value(scheduledAt, 'scheduledAt', 'Must be in the future');
    }

    final actions = await getAll();
    final previous = actions.where((action) => action.id == id).firstOrNull;
    if (previous != null) await _notifications.cancel(id: _notificationId(id));

    final action = OrahAction(
      id: id,
      title: cleanTitle,
      scheduledAt: scheduledAt,
      timeZoneName: DateTime.now().timeZoneName,
      recurrence: recurrence,
      status: OrahActionStatus.scheduled,
    );
    final updated = [...actions.where((item) => item.id != id), action];
    await _save(updated);
    try {
      await _notifications.zonedSchedule(
        id: _notificationId(id),
        title: 'ORAH reminder',
        body: cleanTitle,
        scheduledDate: tz.TZDateTime.from(scheduledAt.toLocal(), tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'orah_actions',
            'ORAH Actions',
            channelDescription: 'Locally scheduled ORAH reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: id,
      );
    } catch (error) {
      await _replace(action.copyWith(
        status: OrahActionStatus.failed,
        lastError: error.toString(),
      ));
      rethrow;
    }
    return action;
  }

  Future<void> complete(String id) async {
    await initialize();
    await _notifications.cancel(id: _notificationId(id));
    final action = await _find(id);
    if (action == null) return;
    if (action.recurrence == OrahActionRecurrence.none) {
      await _replace(action.copyWith(status: OrahActionStatus.completed));
      return;
    }
    final next = _nextOccurrence(action.scheduledAt, action.recurrence);
    await schedule(
      id: action.id,
      title: action.title,
      scheduledAt: next,
      recurrence: action.recurrence,
    );
  }

  Future<void> cancel(String id) async {
    await initialize();
    await _notifications.cancel(id: _notificationId(id));
    final action = await _find(id);
    if (action != null) {
      await _replace(action.copyWith(status: OrahActionStatus.cancelled));
    }
  }

  /// Retries a failed scheduling operation up to [maxRetries] times.
  Future<bool> retry(String id) async {
    final action = await _find(id);
    if (action == null || action.status != OrahActionStatus.failed ||
        action.retryCount >= maxRetries || !action.scheduledAt.isAfter(DateTime.now())) {
      return false;
    }
    final updated = action.copyWith(
      status: OrahActionStatus.scheduled,
      retryCount: action.retryCount + 1,
      clearLastError: true,
    );
    await _replace(updated);
    try {
      await initialize();
      await _notifications.zonedSchedule(
        id: _notificationId(id),
        title: 'ORAH reminder',
        body: action.title,
        scheduledDate: tz.TZDateTime.from(action.scheduledAt.toLocal(), tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'orah_actions',
            'ORAH Actions',
            channelDescription: 'Locally scheduled ORAH reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: id,
      );
      return true;
    } catch (error) {
      await _replace(updated.copyWith(
        status: OrahActionStatus.failed,
        lastError: error.toString(),
      ));
      return false;
    }
  }

  Future<OrahAction?> _find(String id) async {
    for (final action in await getAll()) {
      if (action.id == id) return action;
    }
    return null;
  }

  Future<void> _replace(OrahAction replacement) async {
    final actions = await getAll();
    await _save([
      ...actions.where((action) => action.id != replacement.id),
      replacement,
    ]);
  }

  DateTime _nextOccurrence(DateTime from, OrahActionRecurrence recurrence) {
    switch (recurrence) {
      case OrahActionRecurrence.none:
        return from;
      case OrahActionRecurrence.daily:
        return DateTime(from.year, from.month, from.day + 1, from.hour, from.minute);
      case OrahActionRecurrence.weekly:
        return DateTime(from.year, from.month, from.day + 7, from.hour, from.minute);
      case OrahActionRecurrence.monthly:
        final monthStart = DateTime(from.year, from.month + 1, 1, from.hour, from.minute);
        final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
        return DateTime(
          monthStart.year,
          monthStart.month,
          from.day > lastDay ? lastDay : from.day,
          from.hour,
          from.minute,
        );
    }
  }

  int _notificationId(String id) =>
      ByteData.view(Uint8List.fromList(sha256.convert(utf8.encode(id)).bytes).buffer)
          .getInt32(0) & 0x7fffffff;
}
