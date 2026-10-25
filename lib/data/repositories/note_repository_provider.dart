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
    print('[ORAH-DIAG] repository.instance entered');
    final cached = _repository;
    if (cached != null) {
      print('[ORAH-DIAG] repository.instance using cached repository');
      return cached;
    }

    print('[ORAH-DIAG] repository.instance awaiting construction');
    final pending = _pending ??= _createRepository();
    try {
      final repository = await pending;
      print('[ORAH-DIAG] repository.instance construction completed');
      _repository = repository;
      return repository;
    } catch (error, stackTrace) {
      print('[ORAH-DIAG] repository.instance failed: $error\n$stackTrace');
      // A failed initialization must not poison future retry attempts.
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  static Future<LocalNoteRepository> _createRepository() async {
    print('[ORAH-DIAG] repository construction: requesting preferences');
    final preferences = await OrahPreferencesProvider.instance();
    print('[ORAH-DIAG] repository construction: preferences ready');
    final repository = LocalNoteRepository(preferences);
    print('[ORAH-DIAG] repository construction: LocalNoteRepository created');
    return repository;
  }
}
