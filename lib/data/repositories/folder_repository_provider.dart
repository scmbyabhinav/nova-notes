import 'local_folder_repository.dart';
import 'orah_preferences_provider.dart';

class FolderRepositoryProvider {
  FolderRepositoryProvider._();

  static LocalFolderRepository? _repository;

  static Future<LocalFolderRepository> instance() async {
    if (_repository != null) return _repository!;

    final preferences = await OrahPreferencesProvider.instance();
    _repository = LocalFolderRepository(preferences);
    return _repository!;
  }
}
