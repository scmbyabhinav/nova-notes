import 'package:orah_notes/models/note.dart';

class SearchFilter {
  const SearchFilter({
    this.folderId,
    this.favoritesOnly = false,
    this.pinnedOnly = false,
    this.archivedOnly = false,
    this.noteType,
  });

  final String? folderId;
  final bool favoritesOnly;
  final bool pinnedOnly;
  final bool archivedOnly;
  final NoteType? noteType;

  bool get isEmpty =>
      folderId == null &&
      !favoritesOnly &&
      !pinnedOnly &&
      !archivedOnly &&
      noteType == null;
}
