import '../models/note.dart';

/// Builds local search fields from note relationships and attachment metadata.
///
/// OCR text is stored in the note body by the editor's existing OCR action, so
/// the main search index already searches it without rerunning OCR on every key.
class OrahUniversalSearchIndex {
  OrahUniversalSearchIndex._();

  /// Maps each note ID to titles of its linked notes and notes linking back to it.
  ///
  /// Locked and trashed notes are deliberately excluded so search cannot reveal
  /// private-note titles through relationship metadata.
  static Map<String, List<String>> relatedTitlesByNoteId(
    Iterable<Note> source,
  ) {
    final notes = source
        .where((note) => !note.isLocked && !note.isTrashed)
        .toList(growable: false);
    final byId = <String, Note>{for (final note in notes) note.id: note};
    final titles = <String, Set<String>>{};

    for (final note in notes) {
      for (final linkedId in note.linkedNoteIds) {
        final linked = byId[linkedId];
        if (linked == null || linked.id == note.id) continue;
        titles.putIfAbsent(note.id, () => <String>{}).add(linked.title.trim());
        titles.putIfAbsent(linked.id, () => <String>{}).add(note.title.trim());
      }
    }

    return {
      for (final entry in titles.entries)
        entry.key: entry.value.where((title) => title.isNotEmpty).toList()
    };
  }

  /// Returns searchable file names without exposing the full local file path.
  static List<String> attachmentNames(Note note) {
    final paths = <String>[
      ...note.attachments,
      if (note.imagePath != null && note.imagePath!.trim().isNotEmpty)
        note.imagePath!,
    ];
    return paths
        .map((path) => path.replaceAll('\\\\', '/').split('/').last.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }
}
