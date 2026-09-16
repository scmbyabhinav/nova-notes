import '../../models/folder.dart';

abstract interface class FolderRepository {
  Future<List<NoteFolder>> getFolders();

  Future<void> saveFolder(NoteFolder folder);

  Future<void> deleteFolder(String id);
}
