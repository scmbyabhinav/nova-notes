import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/services/nova_backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/isolated_sqlite_test_setup.dart';

void main() {
  setUpIsolatedSqliteTestDatabase();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'nova_folders_v1': '[{"id":"existing","name":"Existing"}]',
      'orah_theme_mode_v1': 'dark',
    });
  });

  test('rejects malformed database snapshot without changing preferences', () async {
    final preferences = await SharedPreferences.getInstance();
    final archive = Archive()
      ..addFile(ArchiveFile(
        'data/notes.json',
        utf8.encode(jsonEncode({
          'format': NovaBackupService.format,
          'version': NovaBackupService.version,
          'exportedAt': '2026-11-13T00:00:00.000Z',
          'notes': <Object>[],
        })).length,
        utf8.encode(jsonEncode({
          'format': NovaBackupService.format,
          'version': NovaBackupService.version,
          'exportedAt': '2026-11-13T00:00:00.000Z',
          'notes': <Object>[],
        })),
      ))
      ..addFile(ArchiveFile(
        'data/database.json',
        utf8.encode(jsonEncode({
          'format': 'unexpected_database_snapshot',
          'version': 1,
          'tables': <String, Object>{},
        })).length,
        utf8.encode(jsonEncode({
          'format': 'unexpected_database_snapshot',
          'version': 1,
          'tables': <String, Object>{},
        })),
      ));

    final temp = await Directory.systemTemp.createTemp('orah_bad_backup_');
    final backup = File('${temp.path}/malformed.nova');
    await backup.writeAsBytes(ZipEncoder().encode(archive)!);

    try {
      await expectLater(
        NovaBackupService(preferences).restoreBackup(backup),
        throwsFormatException,
      );
      expect(preferences.getString('nova_folders_v1'),
          '[{"id":"existing","name":"Existing"}]');
      expect(preferences.getString('orah_theme_mode_v1'), 'dark');
    } finally {
      await temp.delete(recursive: true);
    }
  });
}
