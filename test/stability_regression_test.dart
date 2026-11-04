import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/repositories/local_note_repository.dart';
import 'package:orah_notes/data/kanban/kanban_repository.dart';
import 'package:orah_notes/models/note.dart';
import 'support/isolated_sqlite_test_setup.dart';

void main() {
  setUpIsolatedSqliteTestDatabase();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('note persistence preserves image content, attachments, focus minutes and reminders', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = LocalNoteRepository(preferences);
    final dueAt = DateTime(2026, 12, 10, 9, 30);
    final checklistDueAt = DateTime(2026, 12, 11, 10);

    final note = Note(
      id: 'stability-rich-note',
      title: 'Rich note',
      content: 'Before image\n![diagram](local-image.png)\nAfter image',
      type: NoteType.text,
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 2),
      attachments: const ['/attachments/reference.pdf'],
      imagePath: '/attachments/local-image.png',
      focusMinutes: 25,
      dueAt: dueAt,
      checklistItems: [
        ChecklistItem(
          id: 'task-reminder-1',
          text: 'Review the diagram',
          dueAt: checklistDueAt,
        ),
      ],
    );

    await repository.saveNote(note);
    final restored = await repository.getNote(note.id);

    expect(restored, isNotNull);
    expect(restored!.content, note.content);
    expect(restored.attachments, note.attachments);
    expect(restored.imagePath, note.imagePath);
    expect(restored.focusMinutes, 25);
    expect(restored.dueAt, dueAt);
    expect(restored.checklistItems.single.dueAt, checklistDueAt);
    expect(restored.checklistItems.single.text, 'Review the diagram');
  });

  test('Kanban stream emits the persisted state after a card is moved', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Move across columns');

    final movedEvent = repository.watchCards().firstWhere(
      (cards) => cards.any(
        (candidate) =>
            candidate.id == card.id &&
            candidate.status == KanbanStatus.inProgress,
      ),
    );

    await repository.moveCard(card, KanbanStatus.inProgress);
    final emittedCards = await movedEvent;
    final movedCard = emittedCards.singleWhere((candidate) => candidate.id == card.id);

    expect(movedCard.status, KanbanStatus.inProgress);
    expect((await repository.getCards()).single.status, KanbanStatus.inProgress);
    await repository.dispose();
  });

  test('Kanban timer totals include a running session at the supplied time', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Focus timer regression');
    final start = DateTime.now().toUtc().subtract(const Duration(minutes: 3));
    await repository.database.insert('time_entries', {
      'id': 'stability-running-session',
      'card_id': card.id,
      'started_at': start.toIso8601String(),
      'ended_at': null,
      'created_at': start.toIso8601String(),
      'updated_at': start.toIso8601String(),
      'deleted_at': null,
    });

    final total = await repository.totalSecondsForCard(
      card.id,
      now: start.add(const Duration(minutes: 3)),
    );

    expect(total, inInclusiveRange(179, 181));
    await repository.dispose();
  });
}
