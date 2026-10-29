import 'local_note_repository.dart';
import 'orah_preferences_provider.dart';

class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;

  /// Replaces persistent storage with a test repository before pumping widgets.
  static void overrideForTesting(LocalNoteRepository repository) {
    _repository = repository;
  }

  static void resetForTesting() {
    _repository = null;
  }

  static Future<LocalNoteRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await OrahPreferencesProvider.instance();
    _repository = LocalNoteRepository(preferences);
    return _repository!;
  }
}
