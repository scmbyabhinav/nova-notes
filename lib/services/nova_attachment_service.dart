import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

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
    final root = await _attachmentDirectory();
    final name = _uniqueName(root.path, p.basename(sourcePath));
    final target = File(p.join(root.path, name));
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
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
