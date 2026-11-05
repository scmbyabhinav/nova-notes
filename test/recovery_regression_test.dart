import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/screens/export_note_sheet.dart';
import 'package:orah_notes/services/nova_attachment_service.dart';
import 'package:orah_notes/services/orah_reminder_service.dart';

import 'support/isolated_sqlite_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpIsolatedSqliteTestDatabase();

  late LocalNoteRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalNoteRepository(await SharedPreferences.getInstance());
  });

  Note makeNote({
    String id = 'recovery-note',
    String? folderId,
    bool isTrashed = false,
  }) {
    final dueAt = DateTime(2026, 12, 10, 9, 30);
    return Note(
      id: id,
      title: 'Recovery note',
      content: 'Keep this content',
      type: NoteType.checklist,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
      folderId: folderId,
      tags: const ['work'],
      linkedNoteIds: const ['linked-note'],
      attachments: const ['/attachments/brief.pdf'],
      imagePath: '/attachments/cover.png',
      focusMinutes: 35,
      dueAt: dueAt,
      isTrashed: isTrashed,
      checklistItems: [
        ChecklistItem(
          id: 'recovery-task',
          text: 'Submit the report',
          dueAt: dueAt.add(const Duration(days: 1)),
        ),
      ],
    );
  }

  test('trash and Undo persistence restore note, attachment and reminder metadata', () async {
    final original = makeNote();
    await repository.saveNote(original);

    await repository.saveNote(
      original.copyWith(isTrashed: true, isPinned: false, isFavorite: false),
    );
    final trashed = await repository.getNote(original.id);
    expect(trashed, isNotNull);
    expect(trashed!.isTrashed, isTrue);

    await repository.saveNote(
      trashed.copyWith(isTrashed: false, updatedAt: DateTime.now()),
    );
    final restored = await repository.getNote(original.id);

    expect(restored, isNotNull);
    expect(restored!.isTrashed, isFalse);
    expect(restored.attachments, original.attachments);
    expect(restored.imagePath, original.imagePath);
    expect(restored.dueAt, original.dueAt);
    expect(restored.checklistItems.single.dueAt,
        original.checklistItems.single.dueAt);
    expect(restored.focusMinutes, 35);
  });

  test('move changes folder without dropping note metadata', () async {
    final original = makeNote();
    await repository.saveNote(original);

    await repository.saveNote(
      original.copyWith(folderId: 'destination-folder'),
    );
    final moved = await repository.getNote(original.id);

    expect(moved, isNotNull);
    expect(moved!.folderId, 'destination-folder');
    expect(moved.attachments, original.attachments);
    expect(moved.linkedNoteIds, original.linkedNoteIds);
    expect(moved.dueAt, original.dueAt);
    expect(moved.checklistItems.single.dueAt,
        original.checklistItems.single.dueAt);
  });

  test('copy creates a separate note while retaining attachments and metadata', () async {
    final original = makeNote();
    await repository.saveNote(original);

    final copied = Note(
      id: 'recovery-note-copy',
      title: '${original.title} (Copy)',
      content: original.content,
      type: original.type,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      folderId: 'destination-folder',
      tags: original.tags,
      linkedNoteIds: original.linkedNoteIds,
      attachments: original.attachments,
      checklistItems: original.checklistItems
          .map((item) => ChecklistItem(
                id: 'copy-${item.id}',
                text: item.text,
                isDone: item.isDone,
                dueAt: item.dueAt,
              ))
          .toList(),
      imagePath: original.imagePath,
      focusMinutes: original.focusMinutes,
      dueAt: original.dueAt,
    );
    await repository.saveNote(copied);

    final restoredCopy = await repository.getNote(copied.id);
    expect(restoredCopy, isNotNull);
    expect(restoredCopy!.id, isNot(original.id));
    expect(restoredCopy.attachments, original.attachments);
    expect(restoredCopy.linkedNoteIds, original.linkedNoteIds);
    expect(restoredCopy.checklistItems.single.id, isNot('recovery-task'));
    expect(restoredCopy.checklistItems.single.dueAt,
        original.checklistItems.single.dueAt);
    expect(await repository.getNote(original.id), isNotNull);
  });

  test('attachment import reports a missing source instead of silently succeeding', () async {
    await expectLater(
      const NovaAttachmentService().importFile(
        '${Directory.systemTemp.path}/orah-source-that-does-not-exist.pdf',
      ),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('reminder scheduler submits a future reminder to the notification plugin', () async {
    const channel = MethodChannel('dexterous.com/flutter/local_notifications');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getNotificationAppLaunchDetails') {
        return <String, Object?>{'didNotificationLaunchApp': false};
      }
      return true;
    });

    try {
      await OrahReminderService.instance.schedule(
        noteId: 'recovery-reminder',
        title: 'Submit the report',
        when: DateTime.now().add(const Duration(hours: 2)),
      );

      expect(
        calls.any((call) => call.method == 'zonedSchedule'),
        isTrue,
        reason: 'A future due date must be handed to the platform scheduler.',
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets('export failure is surfaced to the user', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportNoteSheet(note: makeNote()),
        ),
      ),
    );

    await tester.tap(find.text('Plain Text (.txt)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Export failed:'), findsOneWidget);
  });
}
