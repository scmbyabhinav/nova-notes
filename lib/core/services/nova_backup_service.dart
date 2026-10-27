
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class NovaBackupService {
  static const _backupKey = 'nova_notes_last_backup_v1';

  Future<void> saveBackup(String notesJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupKey, notesJson);
  }

  Future<String?> readBackup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupKey);
  }

  Future<void> clearBackup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_backupKey);
  }

  /// Creates a backup envelope for future file/share integrations.
  String buildEnvelope({
    required String notesJson,
    required String appVersion,
  }) {
    return jsonEncode({
      'product': 'NOVA Notes',
      'format': 'nova_notes_backup',
      'version': 1,
      'appVersion': appVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'payload': jsonDecode(notesJson),
    });
  }
}
