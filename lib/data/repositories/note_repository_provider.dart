import 'package:shared_preferences/shared_preferences.dart';

import 'local_note_repository.dart';

class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;

  static Future<LocalNoteRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await SharedPreferences.getInstance();
    _repository = LocalNoteRepository(preferences);
    return _repository!;
  }
}
