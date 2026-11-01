import 'note.dart';

/// An immutable prior snapshot of an ordinary note.
class NoteVersion {
  const NoteVersion({required this.id, required this.noteId, required this.savedAt, required this.note});
  final int id;
  final String noteId;
  final DateTime savedAt;
  final Note note;
}
