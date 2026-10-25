import 'local_note_repository.dart';
import 'orah_preferences_provider.dart';

/// Owns one repository instance for the lifetime of the app.
///
/// Home and the editor can request the repository in the same frame (for
/// example, when Quick Capture is tapped while Home is loading its first
/// snapshot). Cache the in-flight construction as well as the completed
/// instance so concurrent callers cannot create competing repositories.
class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;
  static Future<LocalNoteRepository>? _pending;

  static Future<LocalNoteRepository> instance() async {
    final cached = _repository;
    if (cached != null) return cached;

    final pending = _pending ??= _createRepository();
    try {
      final repository = await pending;
      _repository = repository;
      return repository;
    } catch (_) {
      // A failed initialization must not poison future retry attempts.
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  static Future<LocalNoteRepository> _createRepository() async {
    final preferences = await OrahPreferencesProvider.instance();
    return LocalNoteRepository(preferences);
  }
}
