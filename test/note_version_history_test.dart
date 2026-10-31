import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'support/isolated_sqlite_test_setup.dart';

void main() {
  setUpIsolatedSqliteTestDatabase();
  late LocalNoteRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = LocalNoteRepository(await SharedPreferences.getInstance());
  });

  Note note({String title = 'Original', String content = 'First draft', bool locked = false}) {
    final now = DateTime.utc(2026, 1, 1);
    return Note(
      id: 'version-test',
      title: locked ? '' : title,
      content: locked ? 'ciphertext-only' : content,
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      isLocked: locked,
    );
  }

  test('records previous content and exposes it newest first', () async {
    await repository.saveNote(note());
    await repository.saveNote(note(title: 'Updated', content: 'Second draft'));

    final versions = await repository.getNoteVersions('version-test');
    expect(versions, hasLength(1));
    expect(versions.single.note.title, 'Original');
    expect(versions.single.note.content, 'First draft');
  });

  test('metadata-only updates do not create content versions', () async {
    await repository.saveNote(note());
    await repository.saveNote(note().copyWith(isPinned: true, updatedAt: DateTime.now()));

    expect(await repository.getNoteVersions('version-test'), isEmpty);
  });

  test('locked notes are not copied into version history', () async {
    await repository.saveNote(note(locked: true));
    await repository.saveNote(note(locked: true).copyWith(content: 'new-ciphertext'));

    expect(await repository.getNoteVersions('version-test'), isEmpty);
  });
}
