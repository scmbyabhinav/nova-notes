import '../../models/note.dart';
import '../../models/search_filter.dart';

abstract interface class NoteRepository {
  Future<List<Note>> getNotes();

  Stream<List<Note>> watchNotes();

  Future<Note?> getNote(String id);

  Future<void> saveNote(Note note);

  Future<void> deleteNote(String id);

  Future<List<Note>> searchNotes(String query);

  Future<List<Note>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
  });
}
