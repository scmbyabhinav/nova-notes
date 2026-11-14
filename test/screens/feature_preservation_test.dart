import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/app.dart';
import 'package:orah_notes/data/repositories/in_memory_note_repository.dart';
import 'package:orah_notes/data/repositories/note_repository_provider.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/screens/trash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late InMemoryNoteRepository repository;

  final now = DateTime.utc(2026, 11, 14, 10);

  Note note(String id, String title, String content, {bool trashed = false}) {
    return Note(
      id: id,
      title: title,
      content: content,
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      isTrashed: trashed,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = InMemoryNoteRepository(preferences);
    NoteRepositoryProvider.overrideForTesting(repository);
  });

  testWidgets('critical note menu retains Merge and Delete actions', (tester) async {
    await repository.saveNote(note('preserve-target', 'Target note', 'Target content'));
    await repository.saveNote(note('preserve-source', 'Source note', 'Source content'));

    await tester.pumpWidget(const OrahApp(skipRegistrationForTesting: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.text('Target note').first);
    await tester.pumpAndSettle();

    expect(find.text('Merge with…'), findsOneWidget);
    expect(find.text('Delete note (move to Trash)'), findsOneWidget);
  });

  testWidgets('merge notes combines content and removes source only after confirmation', (tester) async {
    await repository.saveNote(note('merge-target', 'Target', 'Target paragraph'));
    await repository.saveNote(note('merge-source', 'Source', 'Source paragraph'));

    await tester.pumpWidget(const OrahApp(skipRegistrationForTesting: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.text('Target').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Merge with…'));
    await tester.pumpAndSettle();

    expect(find.text('Source'), findsOneWidget);
    await tester.tap(find.text('Source'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm merge'), findsOneWidget);
    await tester.tap(find.text('Merge notes'));
    await tester.pumpAndSettle();

    final target = await repository.getNote('merge-target');
    final source = await repository.getNote('merge-source');
    expect(target, isNotNull);
    expect(target!.content, contains('Target paragraph'));
    expect(target.content, contains('Source paragraph'));
    expect(target.content, contains('Merged from: Source'));
    expect(source, isNull);
  });

  testWidgets('delete action moves note to Trash and Undo restores it', (tester) async {
    await repository.saveNote(note('delete-undo', 'Delete me', 'Keep this note'));

    await tester.pumpWidget(const OrahApp(skipRegistrationForTesting: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.text('Delete me').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete note (move to Trash)'));
    await tester.pumpAndSettle();

    expect((await repository.getNote('delete-undo'))!.isTrashed, isTrue);
    expect(find.text('Moved to trash'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await repository.getNote('delete-undo'))!.isTrashed, isFalse);
  });

  testWidgets('Trash screen restores a trashed note', (tester) async {
    await repository.saveNote(
      note('trash-restore', 'Restore me', 'Recover this content', trashed: true),
    );

    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Restore me'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    final restored = await repository.getNote('trash-restore');
    expect(restored, isNotNull);
    expect(restored!.isTrashed, isFalse);
    expect(find.text('No notes yet.'), findsOneWidget);
  });
}
