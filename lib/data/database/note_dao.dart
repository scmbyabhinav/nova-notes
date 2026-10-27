import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'orah_database.dart';

/// Small persistence boundary for ordinary notes; Vault records stay separate.
class NoteDao {
  const NoteDao(this._database);

  final Database _database;

  Future<List<Map<String, dynamic>>> getAllRows() async {
    final rows = await _database.query('notes', orderBy: 'updated_at DESC');
    return rows.map(OrahDatabase.mapFromRow).toList();
  }

  Future<void> upsert(Map<String, dynamic> payload) async {
    final id = payload['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Note ID cannot be empty.');
    }
    await _database.transaction((txn) async {
      await txn.insert(
        'notes',
        OrahDatabase.rowFor(payload),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _cleanupOrphanedStudyTaskStatuses(txn);
    });
  }

  Future<void> replaceAll(Iterable<Map<String, dynamic>> payloads) async {
    final rows = payloads.toList(growable: false);
    print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] REPLACE_ALL_ENTER count=${rows.length} dbOpen=${_database.isOpen}');
    print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] TRANSACTION_AWAIT_ENTER');
    await _database.transaction((txn) async {
      print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] TRANSACTION_CALLBACK_ENTER');
      await txn.delete('notes');
      print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] DELETE_EXIT');
      for (final payload in rows) {
        final id = payload['id'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException('Note ID cannot be empty.');
        }
        print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] INSERT_ENTER id=$id');
        await txn.insert(
          'notes',
          OrahDatabase.rowFor(payload),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] INSERT_EXIT id=$id');
      }
      await _cleanupOrphanedStudyTaskStatuses(txn);
      print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] TRANSACTION_CALLBACK_EXIT');
    });
    print('[ORAH-DAO-DIAG][${DateTime.now().toUtc().toIso8601String()}] TRANSACTION_AWAIT_EXIT');
  }

  Future<void> delete(String id) async {
    await _database.transaction((txn) async {
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
      await txn.delete(
        'study_task_status',
        where: 'note_id = ?',
        whereArgs: [id],
      );
    });
  }

  static const _studyStatuses = {'new', 'learning', 'mastered'};

  /// Persists status independently from the note payload.
  ///
  /// The note and task are checked inside the same transaction as the status
  /// write, so a task removed by an editor save cannot receive a stale status.
  Future<void> updateStudyTaskStatus(
    String noteId,
    String taskId,
    String status,
  ) async {
    if (!_studyStatuses.contains(status)) {
      throw FormatException('Unsupported study status: $status');
    }
    if (noteId.trim().isEmpty || taskId.trim().isEmpty) {
      throw const FormatException('Note ID and task ID cannot be empty.');
    }

    await _database.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        columns: ['payload'],
        where: 'id = ?',
        whereArgs: [noteId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Cannot update study status: note $noteId does not exist.');
      }

      final decoded = jsonDecode(rows.single['payload'] as String);
      if (decoded is! Map) {
        throw FormatException('Note $noteId has a malformed stored payload.');
      }
      final items = decoded['checklistItems'];
      final exists = items is List && items.any(
        (item) => item is Map && item['id'] == taskId,
      );
      if (!exists) {
        throw StateError(
          'Cannot update study status: task $taskId does not exist in note $noteId.',
        );
      }

      await txn.insert(
        'study_task_status',
        {
          'note_id': noteId,
          'task_id': taskId,
          'study_status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, String>> getStudyTaskStatuses(String noteId) async {
    final rows = await _database.query(
      'study_task_status',
      columns: ['task_id', 'study_status'],
      where: 'note_id = ?',
      whereArgs: [noteId],
    );
    return {
      for (final row in rows)
        row['task_id'] as String: row['study_status'] as String,
    };
  }

  Future<void> deleteStudyTaskStatus(String noteId, String taskId) async {
    await _database.delete(
      'study_task_status',
      where: 'note_id = ? AND task_id = ?',
      whereArgs: [noteId, taskId],
    );
  }

  /// Reconcile sidecar rows after a note save/replacement. Malformed payloads
  /// are preserved conservatively rather than deleting potentially valid state.
  Future<void> _cleanupOrphanedStudyTaskStatuses(
    DatabaseExecutor executor,
  ) async {
    final statuses = await executor.query(
      'study_task_status',
      columns: ['note_id', 'task_id'],
    );
    if (statuses.isEmpty) return;

    final noteRows = await executor.query('notes', columns: ['id', 'payload']);
    final validTasks = <String, Set<String>>{};
    final unreadableNotes = <String>{};

    for (final row in noteRows) {
      final noteId = row['id'] as String;
      try {
        final decoded = jsonDecode(row['payload'] as String);
        if (decoded is! Map) {
          unreadableNotes.add(noteId);
          continue;
        }
        final items = decoded['checklistItems'];
        final taskIds = <String>{};
        if (items is List) {
          for (final item in items) {
            if (item is Map && item['id'] is String) {
              taskIds.add(item['id'] as String);
            }
          }
        }
        validTasks[noteId] = taskIds;
      } catch (_) {
        unreadableNotes.add(noteId);
      }
    }

    for (final status in statuses) {
      final noteId = status['note_id'] as String;
      final taskId = status['task_id'] as String;
      if (unreadableNotes.contains(noteId)) continue;
      if (!(validTasks[noteId]?.contains(taskId) ?? false)) {
        await executor.delete(
          'study_task_status',
          where: 'note_id = ? AND task_id = ?',
          whereArgs: [noteId, taskId],
        );
      }
    }
  }

  Future<int> count() async {
    final result = await _database.rawQuery('SELECT COUNT(*) AS count FROM notes');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
