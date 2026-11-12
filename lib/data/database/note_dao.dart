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

  /// Returns matching ordinary-note IDs ordered by FTS5 relevance.
  /// Null means this SQLite build does not support FTS5, so callers should
  /// use the existing local search implementation as a compatibility fallback.
  Future<List<String>?> searchIds(String query) async {
    if (!OrahDatabase.fts5Available) return null;
    final terms = query.trim().split(RegExp(r'\\s+')).where((term) => term.isNotEmpty).toList();
    if (terms.isEmpty) return const [];
    // Quoting each token prevents FTS operators or punctuation in user input
    // from becoming executable MATCH syntax. Prefix matching supports typing
    // partial words such as "plan" while entering "planning".
    final expression = terms
        .map((term) => '"${term.replaceAll('"', '""')}"*')
        .join(' AND ');
    try {
      final rows = await _database.rawQuery(
        'SELECT note_id FROM note_search WHERE note_search MATCH ? ORDER BY bm25(note_search)',
        [expression],
      );
      return rows.map((row) => row['note_id'] as String).toList();
    } catch (_) {
      // Malformed/unsupported MATCH expressions must never break note search.
      return null;
    }
  }

  Future<int> count() async {
    final result = await _database.rawQuery('SELECT COUNT(*) AS count FROM notes');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
