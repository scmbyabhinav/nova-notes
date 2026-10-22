import 'package:shared_preferences/shared_preferences.dart';

import 'local_note_repository.dart';

class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;

  static Future<LocalNoteRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));
    _repository = LocalNoteRepository(preferences);
    return _repository!;
  }
}
