import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/note.dart';
import '../../models/search_filter.dart';
import 'local_note_repository.dart';

/// Fast, deterministic repository for widget tests. It intentionally performs
/// no SQLite or platform-channel I/O; real persistence is covered by database
/// and repository tests using [LocalNoteRepository].
class InMemoryNoteRepository extends LocalNoteRepository {
  InMemoryNoteRepository(super.preferences);

  final Map<String, Note> _notes = <String, Note>{};
  final StreamController<List<Note>> _changes =
      StreamController<List<Note>>.broadcast(sync: true);

  List<Note> _snapshot() {
    final notes = _notes.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List<Note>.unmodifiable(notes);
  }

  @override
  Stream<List<Note>> watchNotes() => Stream<List<Note>>.multi((controller) {
        controller.add(_snapshot());
        final subscription = _changes.stream.listen(controller.add,
            onError: controller.addError);
        controller.onCancel = subscription.cancel;
      }, isBroadcast: true);

  @override
  Future<List<Note>> getNotes() async => _snapshot();

  @override
  Future<Note?> getNote(String id) async => _notes[id];

  @override
  Future<void> saveNote(Note note) async {
    if (note.id.trim().isEmpty) {
      throw const FormatException('Note ID cannot be empty.');
    }
    _notes[note.id] = note;
    _changes.add(_snapshot());
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
    _changes.add(_snapshot());
  }

  @override
  Future<List<Note>> searchNotes(String query) => search(query);

  @override
  Future<List<Note>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
  }) async {
    final normalized = query.trim().toLowerCase();
    final terms = normalized
        .split(RegExp(r'\\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    return _snapshot().where((note) {
      if (note.isTrashed) return false;
      if (!filter.archivedOnly && note.isArchived) return false;
      if (filter.archivedOnly && !note.isArchived) return false;
      if (filter.favoritesOnly && !note.isFavorite) return false;
      if (filter.pinnedOnly && !note.isPinned) return false;
      if (filter.folderId != null && note.folderId != filter.folderId) {
        return false;
      }
      if (filter.noteType != null && note.type != filter.noteType) return false;
      final searchable =
          '${note.title} ${note.content} ${note.tags.join(' ')}'.toLowerCase();
      return terms.every(searchable.contains);
    }).toList();
  }

  @override
  Future<void> refresh() async {
    _changes.add(_snapshot());
  }

  /// Clears this repository between widget tests.
  void clearForTesting() {
    _notes.clear();
    _changes.add(_snapshot());
  }
}
