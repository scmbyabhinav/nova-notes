import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:orah_notes/services/nova_backup_service.dart';
import 'package:orah_notes/data/database/orah_database.dart';
import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/isolated_sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpIsolatedSqliteTestDatabase();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'nova_folders_v1': '[{"id":"existing","name":"Existing"}]',
      'orah_theme_mode_v1': 'dark',
    });
  });

  test('backup and restore round-trip restores notes, structured rows and preferences', () async {
    final preferences = await SharedPreferences.getInstance();
    final temp = await Directory.systemTemp.createTemp('orah_roundtrip_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
          return temp.path;
        case 'getTemporaryDirectory':
          return temp.path;
        default:
          return null;
      }
    });

    final repository = LocalNoteRepository(preferences);
    final now = DateTime.utc(2026, 11, 13);
    await repository.saveNote(Note(
      id: 'roundtrip-note',
      title: 'Backup round trip',
      content: 'This note must survive export and restore.',
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      tags: const ['backup', 'test'],
    ));
    final database = await OrahDatabase.open(preferences);
    await database.insert('goals', {
      'id': 'roundtrip-goal',
      'title': 'Restore goal',
      'description': 'Structured data',
      'target_date': null,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'deleted_at': null,
      'archived_at': null,
      'sort_order': 4,
    });
    await preferences.setString('nova_folders_v1',
        '[{"id":"roundtrip-folder","name":"Round trip"}]');

    File? backup;
    try {
      backup = await NovaBackupService(preferences).createBackup();
      await repository.deleteNote('roundtrip-note');
      await database.delete('goals', where: 'id = ?', whereArgs: ['roundtrip-goal']);
      await preferences.remove('nova_folders_v1');

      await NovaBackupService(preferences).restoreBackup(backup);

      final restored = await repository.getNote('roundtrip-note');
      expect(restored, isNotNull);
      expect(restored!.title, 'Backup round trip');
      expect(restored.content, 'This note must survive export and restore.');
      expect(restored.tags, ['backup', 'test']);
      final goals = await database.query('goals',
          where: 'id = ?', whereArgs: ['roundtrip-goal']);
      expect(goals, hasLength(1));
      expect(goals.single['title'], 'Restore goal');
      expect(preferences.getString('nova_folders_v1'),
          '[{"id":"roundtrip-folder","name":"Round trip"}]');
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (backup != null && await backup.exists()) await backup.delete();
      await temp.delete(recursive: true);
    }
  });

  test('rolls back notes, database and preferences when a later database write fails', () async {
    final preferences = await SharedPreferences.getInstance();
    final database = await OrahDatabase.open(preferences);
    await database.insert('goals', {
      'id': 'keep-goal',
      'title': 'Existing goal',
      'description': 'Must survive failed restore',
      'target_date': null,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'deleted_at': null,
      'archived_at': null,
      'sort_order': 0,
    });

    final notesJson = jsonEncode({
      'format': NovaBackupService.format,
      'version': NovaBackupService.version,
      'exportedAt': '2026-11-13T00:00:00.000Z',
      'notes': <Object>[],
    });
    final databaseJson = jsonEncode({
      'format': 'orah_database_snapshot',
      'version': 1,
      'tables': {
        // ID passes the current structural preflight, but the missing
        // required title causes SQLite to reject this after note import.
        'goals': [{'id': 'invalid-goal'}],
      },
    });
    final archive = Archive()
      ..addFile(ArchiveFile('data/notes.json', utf8.encode(notesJson).length, utf8.encode(notesJson)))
      ..addFile(ArchiveFile('data/database.json', utf8.encode(databaseJson).length, utf8.encode(databaseJson)));

    final temp = await Directory.systemTemp.createTemp('orah_rollback_backup_');
    final backup = File('${temp.path}/rollback.nova');
    await backup.writeAsBytes(ZipEncoder().encode(archive)!);

    try {
      await expectLater(
        NovaBackupService(preferences).restoreBackup(backup),
        throwsA(anything),
      );
      final goals = await database.query('goals');
      expect(goals, hasLength(1));
      expect(goals.single['id'], 'keep-goal');
      expect(goals.single['title'], 'Existing goal');
      expect(preferences.getString('nova_folders_v1'),
          '[{"id":"existing","name":"Existing"}]');
      expect(preferences.getString('orah_theme_mode_v1'), 'dark');
    } finally {
      await temp.delete(recursive: true);
    }
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
