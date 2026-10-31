import '../../models/note.dart';

/// Returns distinct, trimmed note tags in case-insensitive alphabetical order.
/// The first spelling encountered is preserved for display.
List<String> collectNoteTags(Iterable<Note> notes) {
  final labelsByKey = <String, String>{};
  for (final note in notes) {
    for (final rawTag in note.tags) {
      final label = rawTag.trim();
      if (label.isEmpty) continue;
      labelsByKey.putIfAbsent(label.toLowerCase(), () => label);
    }
  }
  final labels = labelsByKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return labels;
}

/// Filters notes by tag, ignoring surrounding whitespace and letter case.
List<Note> filterNotesByTag(Iterable<Note> notes, String? selectedTag) {
  if (selectedTag == null || selectedTag.trim().isEmpty) {
    return notes.toList();
  }
  final normalized = selectedTag.trim().toLowerCase();
  return notes
      .where((note) => note.tags.any((tag) => tag.trim().toLowerCase() == normalized))
      .toList();
}
