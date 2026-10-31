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
    await _database.insert(
      'notes',
      OrahDatabase.rowFor(payload),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceAll(Iterable<Map<String, dynamic>> payloads) async {
    await _database.transaction((txn) async {
      await txn.delete('notes');
      for (final payload in payloads) {
        final id = payload['id'];
        if (id is! String || id.trim().isEmpty) {
          throw const FormatException('Note ID cannot be empty.');
        }
        await txn.insert(
          'notes',
          OrahDatabase.rowFor(payload),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> delete(String id) async {
    await _database.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final result = await _database.rawQuery('SELECT COUNT(*) AS count FROM notes');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
