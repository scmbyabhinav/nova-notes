import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import '../data/repositories/note_repository_provider.dart';

class NovaAttachmentService {
  const NovaAttachmentService();

  Future<String> importXFile(XFile source) async {
    final root = await _attachmentDirectory();
    final name = _uniqueName(root.path, p.basename(source.path));
    final target = File(p.join(root.path, name));
    await File(source.path).copy(target.path);
    return target.path;
  }

  Future<String> importFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('Source attachment not found');
    final root = await _attachmentDirectory();
    final name = _uniqueName(root.path, p.basename(sourcePath));
    final target = File(p.join(root.path, name));
    await source.copy(target.path);
    return target.path;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<String> rename(String sourcePath, String newName) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw const FileSystemException('Attachment not found');
    final directory = source.parent.path;
    final safe = p.basename(newName).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    if (safe.isEmpty) throw const FileSystemException('Invalid file name');
    final extension = p.extension(source.path);
    final desired = p.extension(safe).isEmpty ? '$safe$extension' : safe;
    final target = File(p.join(directory, desired));
    if (target.path == source.path) return source.path;
    if (await target.exists()) {
      final unique = _uniqueName(directory, desired);
      return (await source.rename(p.join(directory, unique))).path;
    }
    return (await source.rename(target.path)).path;
  }

  Future<List<File>> listAttachments() async {
    final root = await _attachmentDirectory();
    if (!await root.exists()) return [];
    return root.listSync().whereType<File>().toList();
  }

  Future<int> totalSize() async {
    var total = 0;
    for (final file in await listAttachments()) {
      try { total += await file.length(); } catch (_) {}
    }
    return total;
  }

  Future<int> cleanupOrphansFromNotes() async {
    final repository = await NoteRepositoryProvider.instance();
    final notes = await repository.getNotes();
    final referenced = <String>{for (final note in notes) ...note.attachments};
    return removeOrphans(referenced);
  }

  Future<int> removeOrphans(Set<String> referencedPaths) async {
    var removed = 0;
    final normalized = referencedPaths.map((path) => File(path).absolute.path).toSet();
    for (final file in await listAttachments()) {
      if (!normalized.contains(file.absolute.path)) {
        try { await file.delete(); removed++; } catch (_) {}
      }
    }
    return removed;
  }

  Future<int> size(String path) async {
    final file = File(path);
    return file.existsSync() ? file.length() : 0;
  }

  Future<Directory> _attachmentDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _uniqueName(String directory, String original) {
    final safe = p.basename(original).replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '$stamp-$safe';
  }
}
