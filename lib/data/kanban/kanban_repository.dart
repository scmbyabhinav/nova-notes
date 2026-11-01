import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../database/orah_database.dart';

enum KanbanStatus { todo, inProgress, done }
enum KanbanPriority { low, medium, high }

extension KanbanStatusValue on KanbanStatus {
  String get dbValue => switch (this) {
    KanbanStatus.todo => 'todo',
    KanbanStatus.inProgress => 'in_progress',
    KanbanStatus.done => 'done',
  };
}

class KanbanCard {
  const KanbanCard({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.colorLabel,
    this.checklist = const [],
    this.goalId,
    this.archivedAt,
    this.deletedAt,
  });

  final String id;
  final String title;
  final String description;
  final KanbanStatus status;
  final KanbanPriority priority;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final String? colorLabel;
  final List<String> checklist;
  final String? goalId;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  factory KanbanCard.fromRow(Map<String, Object?> row) => KanbanCard(
    id: row['id']! as String,
    title: row['title']! as String,
    description: row['description'] as String? ?? '',
    status: KanbanStatus.values.firstWhere((value) => value.dbValue == row['status']),
    priority: KanbanPriority.values.firstWhere((value) => value.name == row['priority']),
    sortOrder: row['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    dueDate: row['due_date'] == null ? null : DateTime.parse(row['due_date']! as String),
    colorLabel: row['color_label'] as String?,
    checklist: _decodeChecklist(row['checklist_json']),
    goalId: row['goal_id'] as String?,
    archivedAt: row['archived_at'] == null ? null : DateTime.parse(row['archived_at']! as String),
    deletedAt: row['deleted_at'] == null ? null : DateTime.parse(row['deleted_at']! as String),
  );

  static List<String> _decodeChecklist(Object? value) {
    if (value is! String) return const [];
    final decoded = jsonDecode(value);
    return decoded is List ? decoded.whereType<String>().toList(growable: false) : const [];
  }
}

class KanbanGoal {
  const KanbanGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.targetDate,
    this.archivedAt,
    this.deletedAt,
  });
  final String id;
  final String title;
  final String description;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? targetDate;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  factory KanbanGoal.fromRow(Map<String, Object?> row) => KanbanGoal(
    id: row['id']! as String,
    title: row['title']! as String,
    description: row['description'] as String? ?? '',
    sortOrder: row['sort_order'] as int? ?? 0,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    targetDate: row['target_date'] == null ? null : DateTime.parse(row['target_date']! as String),
    archivedAt: row['archived_at'] == null ? null : DateTime.parse(row['archived_at']! as String),
    deletedAt: row['deleted_at'] == null ? null : DateTime.parse(row['deleted_at']! as String),
  );
}

/// SQLite-backed Kanban persistence. Streams are invalidated after successful
/// writes so the board updates immediately; no global DB state is owned here.
class KanbanRepository {
  KanbanRepository(this.database);

  final Database database;
  final _cardsController = StreamController<List<KanbanCard>>.broadcast();
  final _goalsController = StreamController<List<KanbanGoal>>.broadcast();

  /// Same seeding pattern as LocalNoteRepository.watchNotes — proven stable in CI.
  Stream<List<KanbanCard>> watchCards({String? goalId, bool includeArchived = false}) {
    return Stream.multi(
      (controller) {
        var sawLiveUpdate = false;

        late final StreamSubscription<List<KanbanCard>> subscription;
        subscription = _cardsController.stream.listen(
          (cards) {
            // Filter client-side so one shared controller serves all goal filters.
            final filtered = cards.where((c) {
              if (!includeArchived && c.archivedAt != null) return false;
              if (goalId != null && c.goalId != goalId) return false;
              return true;
            }).toList(growable: false);
            sawLiveUpdate = true;
            controller.add(filtered);
          },
          onError: controller.addError,
        );
        controller.onCancel = subscription.cancel;

        getCards(goalId: goalId, includeArchived: includeArchived).then(
          (cards) {
            if (!sawLiveUpdate && !controller.isClosed) {
              controller.add(cards);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      isBroadcast: true,
    );
  }

  Future<List<KanbanCard>> getCards({String? goalId, bool includeArchived = false}) async {
    final where = <String>['deleted_at IS NULL'];
    final args = <Object?>[];
    if (!includeArchived) where.add('archived_at IS NULL');
    if (goalId != null) {
      where.add('goal_id = ?');
      args.add(goalId);
    }
    final rows = await database.query(
      'kanban_cards',
      where: where.join(' AND '),
      whereArgs: args,
      orderBy:
          "CASE status WHEN 'todo' THEN 0 WHEN 'in_progress' THEN 1 ELSE 2 END, sort_order ASC, created_at ASC",
    );
    return rows.map(KanbanCard.fromRow).toList(growable: false);
  }

  Stream<List<KanbanGoal>> watchGoals() {
    return Stream.multi(
      (controller) {
        var sawLiveUpdate = false;

        late final StreamSubscription<List<KanbanGoal>> subscription;
        subscription = _goalsController.stream.listen(
          (goals) {
            sawLiveUpdate = true;
            controller.add(goals);
          },
          onError: controller.addError,
        );
        controller.onCancel = subscription.cancel;

        getGoals().then(
          (goals) {
            if (!sawLiveUpdate && !controller.isClosed) {
              controller.add(goals);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      isBroadcast: true,
    );
  }

  Future<List<KanbanGoal>> getGoals({bool includeArchived = false}) async {
    final rows = await database.query(
      'goals',
      where: includeArchived
          ? 'deleted_at IS NULL'
          : 'deleted_at IS NULL AND archived_at IS NULL',
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(KanbanGoal.fromRow).toList(growable: false);
  }

  Future<void> _publishCards() async {
    if (_cardsController.isClosed) return;
    try {
      final cards = await getCards(includeArchived: true);
      if (!_cardsController.isClosed) {
        _cardsController.add(cards);
      }
    } catch (error, stackTrace) {
      if (!_cardsController.isClosed) {
        _cardsController.addError(error, stackTrace);
      }
    }
  }

  Future<void> _publishGoals() async {
    if (_goalsController.isClosed) return;
    try {
      final goals = await getGoals(includeArchived: true);
      if (!_goalsController.isClosed) {
        _goalsController.add(goals);
      }
    } catch (error, stackTrace) {
      if (!_goalsController.isClosed) {
        _goalsController.addError(error, stackTrace);
      }
    }
  }

  Future<KanbanCard> createCard({
    required String title,
    String description = '',
    KanbanStatus status = KanbanStatus.todo,
    KanbanPriority priority = KanbanPriority.medium,
    DateTime? dueDate,
    String? colorLabel,
    List<String> checklist = const [],
    String? goalId,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid();
    final siblings = await database.query(
      'kanban_cards',
      columns: ['sort_order'],
      where: 'status = ? AND deleted_at IS NULL AND archived_at IS NULL',
      whereArgs: [status.dbValue],
      orderBy: 'sort_order DESC',
      limit: 1,
    );
    await database.insert('kanban_cards', {
      'id': id,
      'title': title.trim(),
      'description': description,
      'status': status.dbValue,
      'priority': priority.name,
      'due_date': dueDate?.toUtc().toIso8601String(),
      'color_label': colorLabel,
      'checklist_json': jsonEncode(checklist),
      'goal_id': goalId,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sort_order': siblings.isEmpty ? 0 : (siblings.single['sort_order'] as int) + 1,
    });
    await _publishCards();
    await _publishGoals();
    return (await getCards()).firstWhere((card) => card.id == id);
  }

  Future<void> updateCard(
    KanbanCard card, {
    String? title,
    String? description,
    KanbanStatus? status,
    KanbanPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? colorLabel,
    bool clearColorLabel = false,
    List<String>? checklist,
    String? goalId,
    bool clearGoal = false,
  }) async {
    final values = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null) values['title'] = title.trim();
    if (description != null) values['description'] = description;
    if (status != null) values['status'] = status.dbValue;
    if (priority != null) values['priority'] = priority.name;
    if (dueDate != null) values['due_date'] = dueDate.toUtc().toIso8601String();
    if (clearDueDate) values['due_date'] = null;
    if (colorLabel != null) values['color_label'] = colorLabel;
    if (clearColorLabel) values['color_label'] = null;
    if (checklist != null) values['checklist_json'] = jsonEncode(checklist);
    if (goalId != null) values['goal_id'] = goalId;
    if (clearGoal) values['goal_id'] = null;
    await database.update(
      'kanban_cards',
      values,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [card.id],
    );
    await _publishCards();
    await _publishGoals();
  }

  Future<void> moveCard(KanbanCard card, KanbanStatus status, {int? sortOrder}) async {
    final siblings = await database.query(
      'kanban_cards',
      columns: ['sort_order'],
      where: 'status = ? AND id != ? AND deleted_at IS NULL AND archived_at IS NULL',
      whereArgs: [status.dbValue, card.id],
      orderBy: 'sort_order DESC',
      limit: 1,
    );
    final nextOrder =
        sortOrder ?? (siblings.isEmpty ? 0 : (siblings.single['sort_order'] as int) + 1);
    await database.transaction((txn) async {
      await txn.update(
        'kanban_cards',
        {
          'status': status.dbValue,
          'sort_order': nextOrder,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [card.id],
      );
      if (status == KanbanStatus.done) await _stopTimerIn(txn, card.id);
    });
    await _publishCards();
    await _publishGoals();
  }

  Future<void> reorderCard(KanbanCard card, int sortOrder) async {
    await database.update(
      'kanban_cards',
      {
        'sort_order': sortOrder,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [card.id],
    );
    await _publishCards();
  }

  Future<void> archiveCard(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.update(
      'kanban_cards',
      {'archived_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    await stopTimer(id);
    await _publishCards();
    await _publishGoals();
  }

  Future<void> restoreCard(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.update(
      'kanban_cards',
      {'archived_at': null, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    await _publishCards();
    await _publishGoals();
  }

  Future<void> deleteCardPermanently(String id) async {
    await database.transaction((txn) async {
      await _stopTimerIn(txn, id);
      await txn.update(
        'links',
        {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        where:
            '(source_type = ? AND source_id = ?) OR (target_type = ? AND target_id = ?)',
        whereArgs: ['card', id, 'card', id],
      );
      await txn.update(
        'time_entries',
        {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        where: 'card_id = ?',
        whereArgs: [id],
      );
      await txn.delete('kanban_cards', where: 'id = ?', whereArgs: [id]);
    });
    await _publishCards();
    await _publishGoals();
  }

  Future<KanbanGoal> createGoal({
    required String title,
    String description = '',
    DateTime? targetDate,
  }) async {
    final now = DateTime.now().toUtc();
    final id = _uuid();
    final rows = await database.query(
      'goals',
      columns: ['sort_order'],
      where: 'deleted_at IS NULL AND archived_at IS NULL',
      orderBy: 'sort_order DESC',
      limit: 1,
    );
    await database.insert('goals', {
      'id': id,
      'title': title.trim(),
      'description': description,
      'target_date': targetDate?.toUtc().toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sort_order': rows.isEmpty ? 0 : (rows.single['sort_order'] as int) + 1,
    });
    await _publishGoals();
    return (await getGoals()).firstWhere((goal) => goal.id == id);
  }

  Future<void> archiveGoal(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.update(
      'goals',
      {'archived_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    await _publishGoals();
  }

  Future<void> restoreGoal(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.update(
      'goals',
      {'archived_at': null, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    await _publishGoals();
  }

  Future<void> deleteGoalPermanently(String id) async {
    await database.transaction((txn) async {
      await txn.update(
        'kanban_cards',
        {
          'goal_id': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'goal_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'links',
        {'deleted_at': DateTime.now().toUtc().toIso8601String()},
        where:
            '(source_type = ? AND source_id = ?) OR (target_type = ? AND target_id = ?)',
        whereArgs: ['goal', id, 'goal', id],
      );
      await txn.delete('goals', where: 'id = ?', whereArgs: [id]);
    });
    await _publishGoals();
    await _publishCards();
  }

  Future<void> startTimer(String cardId, {bool allowMultiple = false}) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      if (!allowMultiple) {
        final active = await txn.query(
          'time_entries',
          where: 'ended_at IS NULL AND deleted_at IS NULL AND card_id != ?',
          whereArgs: [cardId],
        );
        for (final entry in active) {
          await txn.update(
            'time_entries',
            {'ended_at': now, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [entry['id']],
          );
        }
      }
      final existing = await txn.query(
        'time_entries',
        where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL',
        whereArgs: [cardId],
        limit: 1,
      );
      if (existing.isEmpty) {
        await txn.insert('time_entries', {
          'id': _uuid(),
          'card_id': cardId,
          'started_at': now,
          'ended_at': null,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
    await _publishCards();
  }

  Future<void> stopTimer(String cardId) async {
    await _stopTimerIn(database, cardId);
    await _publishCards();
  }

  Future<void> _stopTimerIn(DatabaseExecutor db, String cardId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'time_entries',
      {'ended_at': now, 'updated_at': now},
      where: 'card_id = ? AND ended_at IS NULL AND deleted_at IS NULL',
      whereArgs: [cardId],
    );
  }

  Future<int> totalSecondsForCard(String cardId, {DateTime? now}) async {
    final reference = (now ?? DateTime.now()).toUtc();
    final rows = await database.query(
      'time_entries',
      where: 'card_id = ? AND deleted_at IS NULL',
      whereArgs: [cardId],
    );
    var total = 0;
    for (final row in rows) {
      final start = DateTime.parse(row['started_at']! as String).toUtc();
      final end = row['ended_at'] == null
          ? reference
          : DateTime.parse(row['ended_at']! as String).toUtc();
      total += max(0, end.difference(start).inSeconds);
    }
    return total;
  }

  Future<int> totalSecondsForGoal(String goalId, {DateTime? now}) async {
    final cards = await database.query(
      'kanban_cards',
      columns: ['id'],
      where: 'goal_id = ? AND deleted_at IS NULL AND archived_at IS NULL',
      whereArgs: [goalId],
    );
    var total = 0;
    for (final card in cards) {
      total += await totalSecondsForCard(card['id']! as String, now: now);
    }
    return total;
  }

  Future<int> totalSecondsToday({DateTime? now}) async {
    final local = now ?? DateTime.now();
    final start = DateTime(local.year, local.month, local.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final rows = await database.query(
      'time_entries',
      where:
          'deleted_at IS NULL AND started_at < ? AND (ended_at IS NULL OR ended_at > ?)',
      whereArgs: [end.toIso8601String(), start.toIso8601String()],
    );
    var total = 0;
    for (final row in rows) {
      final sessionStart = DateTime.parse(row['started_at']! as String).toUtc();
      final sessionEnd = row['ended_at'] == null
          ? local.toUtc()
          : DateTime.parse(row['ended_at']! as String).toUtc();
      final clippedStart = sessionStart.isAfter(start) ? sessionStart : start;
      final clippedEnd = sessionEnd.isBefore(end) ? sessionEnd : end;
      if (clippedEnd.isAfter(clippedStart)) {
        total += clippedEnd.difference(clippedStart).inSeconds;
      }
    }
    return total;
  }

  Future<void> addLink({
    required String sourceType,
    required String sourceId,
    required String targetType,
    required String targetId,
    String linkKind = 'related',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await database.insert(
      'links',
      {
        'id': _uuid(),
        'source_type': sourceType,
        'source_id': sourceId,
        'target_type': targetType,
        'target_id': targetId,
        'link_kind': linkKind,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, Object?>>> getLinks(String sourceType, String sourceId) =>
      database.query(
        'links',
        where: 'source_type = ? AND source_id = ? AND deleted_at IS NULL',
        whereArgs: [sourceType, sourceId],
        orderBy: 'created_at ASC',
      );

  Future<void> dispose() async {
    await _cardsController.close();
    await _goalsController.close();
  }

  static String _uuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

Future<KanbanRepository> openKanbanRepository() async {
  final preferences = await SharedPreferences.getInstance();
  return KanbanRepository(await OrahDatabase.open(preferences));
}
