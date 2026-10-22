import 'local_note_repository.dart';
import 'orah_preferences_provider.dart';

class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;

  static Future<LocalNoteRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await OrahPreferencesProvider.instance();
    _repository = LocalNoteRepository(preferences);
    return _repository!;
  }
}
