import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:orah_notes/data/kanban/kanban_repository.dart';
import 'package:orah_notes/data/database/orah_database.dart';
import '../../support/isolated_sqlite_test_setup.dart';

void main() {
  setUpIsolatedSqliteTestDatabase();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('creates cards and moves a card between persisted columns', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Write launch plan');
    expect(card.status, KanbanStatus.todo);

    await repository.moveCard(card, KanbanStatus.inProgress);
    final moved = (await repository.getCards()).single;
    expect(moved.id, card.id);
    expect(moved.status, KanbanStatus.inProgress);
    await repository.dispose();
  });

  test('archived cards are hidden but remain stored for recovery', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Ship Kanban');
    await repository.archiveCard(card.id);

    expect(await repository.getCards(), isEmpty);
    final archived = await repository.getCards(includeArchived: true);
    expect(archived.single.id, card.id);
    expect(archived.single.archivedAt, isNotNull);
    await repository.dispose();
  });

  test('moving a running card to Done closes its time entry', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Timer test');
    await repository.startTimer(card.id);
    final activeBefore = await repository.database.query('time_entries',
      where: 'card_id = ? AND ended_at IS NULL', whereArgs: [card.id]);
    expect(activeBefore, hasLength(1));

    await repository.moveCard(card, KanbanStatus.done);
    final activeAfter = await repository.database.query('time_entries',
      where: 'card_id = ? AND ended_at IS NULL', whereArgs: [card.id]);
    expect(activeAfter, isEmpty);
    await repository.dispose();
  });

  test('starting another card pauses the first timer by default', () async {
    final repository = await openKanbanRepository();
    final first = await repository.createCard(title: 'First');
    final second = await repository.createCard(title: 'Second');
    await repository.startTimer(first.id);
    await repository.startTimer(second.id);

    final active = await repository.database.query('time_entries',
      where: 'ended_at IS NULL AND deleted_at IS NULL');
    expect(active, hasLength(1));
    expect(active.single['card_id'], second.id);
    final firstEntries = await repository.database.query('time_entries',
      where: 'card_id = ? AND ended_at IS NOT NULL', whereArgs: [first.id]);
    expect(firstEntries, hasLength(1));
    await repository.dispose();
  });

  test('timer sessions remain persisted and totals include ended sessions', () async {
    final repository = await openKanbanRepository();
    final card = await repository.createCard(title: 'Persist timer');
    final start = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
    final end = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    await repository.database.insert('time_entries', {
      'id': 'timer-session-1', 'card_id': card.id,
      'started_at': start.toIso8601String(), 'ended_at': end.toIso8601String(),
      'created_at': start.toIso8601String(), 'updated_at': end.toIso8601String(), 'deleted_at': null,
    });
    final database = repository.database;
    await repository.dispose();
    final reopenedRepository = KanbanRepository(database);
    expect(await reopenedRepository.totalSecondsForCard(card.id), inInclusiveRange(50, 70));
    final persisted = await database.query('time_entries', where: 'card_id = ?', whereArgs: [card.id]);
    expect(persisted, hasLength(1));
    await reopenedRepository.dispose();
  });

  test('Kanban schema adds tables without changing existing note rows', () async {
    final prefs = await SharedPreferences.getInstance();
    final database = await OrahDatabase.open(prefs);
    await database.insert('notes', {
      'id': 'legacy-note-1',
      'title': 'Keep me',
      'content': 'Original content',
      'type': 'text',
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
      'tags': '[]',
      'is_pinned': 0,
      'deadline': null,
      'focus_minutes': 0,
      'font_family': null,
      'payload': '{"id":"legacy-note-1","title":"Keep me","content":"Original content"}',
    });

    final tables = await database.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
    final names = tables.map((row) => row['name']).toSet();
    expect(names, containsAll(['kanban_cards', 'goals', 'links', 'time_entries']));
    final note = await database.query('notes', where: 'id = ?', whereArgs: ['legacy-note-1']);
    expect(note.single['title'], 'Keep me');
    expect(note.single['content'], 'Original content');
    expect((await database.rawQuery('PRAGMA user_version')).single['user_version'], OrahDatabase.schemaVersion);
  });
}
