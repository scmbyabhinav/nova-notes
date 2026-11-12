import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Offline-only Pomodoro history. Each completed focus interval is stored once
/// under a stable session ID so timer restoration cannot double-count it.
class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.durationMinutes,
    this.noteId,
  });

  final String id;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationMinutes;
  final String? noteId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'noteId': noteId,
      };

  factory FocusSession.fromMap(Map<String, dynamic> map) => FocusSession(
        id: map['id'] as String,
        startedAt: DateTime.parse(map['startedAt'] as String),
        completedAt: DateTime.parse(map['completedAt'] as String),
        durationMinutes: (map['durationMinutes'] as num).toInt(),
        noteId: map['noteId'] as String?,
      );
}

class FocusSessionService {
  FocusSessionService(this._preferences);

  static const storageKey = 'orah_focus_sessions_v1';
  final SharedPreferences _preferences;

  Future<List<FocusSession>> getSessions() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final sessions = <FocusSession>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          sessions.add(FocusSession.fromMap(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip a damaged history row; preserve the remaining history.
        }
      }
      sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return sessions;
    } on FormatException {
      return const [];
    }
  }

  Future<bool> recordCompleted({
    required String id,
    required DateTime startedAt,
    required DateTime completedAt,
    required int durationMinutes,
    String? noteId,
  }) async {
    if (id.isEmpty || durationMinutes <= 0 || !completedAt.isAfter(startedAt)) {
      return false;
    }
    final sessions = (await getSessions()).toList();
    if (sessions.any((session) => session.id == id)) return false;
    sessions.add(FocusSession(
      id: id,
      startedAt: startedAt,
      completedAt: completedAt,
      durationMinutes: durationMinutes,
      noteId: noteId,
    ));
    sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    // Bound local history to prevent unbounded preference growth.
    final retained = sessions.take(5000).map((session) => session.toMap()).toList();
    await _preferences.setString(storageKey, jsonEncode(retained));
    return true;
  }

  Future<int> totalMinutes({DateTime? since}) async {
    final sessions = await getSessions();
    return sessions
        .where((session) => since == null || !session.completedAt.isBefore(since))
        .fold<int>(0, (total, session) => total + session.durationMinutes);
  }

  Future<int> count({DateTime? since}) async {
    final sessions = await getSessions();
    return sessions.where((session) =>
        since == null || !session.completedAt.isBefore(since)).length;
  }

  Future<String> exportJson() async {
    final sessions = await getSessions();
    return jsonEncode({
      'format': 'orah_focus_history',
      'version': 1,
      'sessions': sessions.map((session) => session.toMap()).toList(),
    });
  }

  Future<int> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['format'] != 'orah_focus_history' ||
        decoded['version'] != 1 ||
        decoded['sessions'] is! List) {
      throw const FormatException('Invalid ORAH focus history backup.');
    }
    final existing = await getSessions();
    final byId = <String, FocusSession>{for (final s in existing) s.id: s};
    var imported = 0;
    for (final item in decoded['sessions'] as List) {
      if (item is! Map) continue;
      final session = FocusSession.fromMap(Map<String, dynamic>.from(item));
      if (!byId.containsKey(session.id)) {
        byId[session.id] = session;
        imported++;
      }
    }
    final retained = byId.values.toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    await _preferences.setString(
      storageKey,
      jsonEncode(retained.take(5000).map((s) => s.toMap()).toList()),
    );
    return imported;
  }
}
