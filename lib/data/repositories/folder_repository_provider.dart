import 'package:shared_preferences/shared_preferences.dart';

import 'local_folder_repository.dart';

class FolderRepositoryProvider {
  FolderRepositoryProvider._();

  static LocalFolderRepository? _repository;

  static Future<LocalFolderRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await SharedPreferences.getInstance().timeout(const Duration(seconds: 5));
    _repository = LocalFolderRepository(preferences);
    return _repository!;
  }
}
