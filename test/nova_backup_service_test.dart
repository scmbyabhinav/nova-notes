import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/services/nova_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  Directory? tempRoot;
  Directory? documentsRoot;
  Directory? temporaryRoot;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('orah-backup-test-');
    documentsRoot = Directory('${tempRoot!.path}/documents');
    temporaryRoot = Directory('${tempRoot!.path}/temporary');
    await documentsRoot!.create(recursive: true);
    await temporaryRoot!.create(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
          return documentsRoot!.path;
        case 'getTemporaryDirectory':
          return temporaryRoot!.path;
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProvider, null);
    if (tempRoot != null && await tempRoot!.exists()) {
      await tempRoot!.delete(recursive: true);
    }
  });

  test('restore rejects a valid archive without the required notes payload', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('unrelated.txt', 4, utf8.encode('test')));
    final bytes = ZipEncoder().encode(archive)!;
    final backupFile = File('${temporaryRoot!.path}/missing-notes.nova');
    await backupFile.writeAsBytes(bytes, flush: true);

    final preferences = await SharedPreferences.getInstance();
    final service = NovaBackupService(preferences);
    await expectLater(
      service.restoreBackup(backupFile),
      throwsA(isA<FormatException>()),
    );
  });

  test('backup round-trip restores note content and checklist metadata', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalNoteRepository(preferences);
    final now = DateTime.now();
    final note = Note(
      id: 'backup-round-trip-note',
      title: 'Release checklist',
      content: 'Verify translated screens',
      type: NoteType.checklist,
      createdAt: now,
      updatedAt: now,
      tags: const ['release', 'localization'],
      checklistItems: const [
        ChecklistItem(id: 'task-1', text: 'Check Arabic RTL', isDone: true),
        ChecklistItem(id: 'task-2', text: 'Restore exported notes'),
      ],
    );
    await repository.saveNote(note);

    final service = NovaBackupService(preferences);
    final backup = await service.createBackup();
    await preferences.remove('nova_notes_v1');

    expect(await repository.getNotes(), isEmpty);
    final restoredCount = await service.restoreBackup(backup);
    expect(restoredCount, 1);

    final restored = await repository.getNote(note.id);
    expect(restored, isNotNull);
    expect(restored!.title, note.title);
    expect(restored.content, note.content);
    expect(restored.tags, note.tags);
    expect(restored.type, NoteType.checklist);
    expect(restored.checklistItems, hasLength(2));
    expect(restored.checklistItems.first.text, 'Check Arabic RTL');
    expect(restored.checklistItems.first.isDone, isTrue);
  });
}
