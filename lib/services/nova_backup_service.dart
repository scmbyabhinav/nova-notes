import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/local_note_repository.dart';

class NovaBackupService {
  const NovaBackupService(this.preferences);
  final SharedPreferences preferences;
  static const format = 'nova_notes_portable_backup';
  static const version = 2;
  static const maxBackupBytes = 512 * 1024 * 1024;

  Future<File> createBackup() async {
    final notes = LocalNoteRepository(preferences);
    final rawNotes = jsonDecode(await notes.exportJson()) as Map<String, dynamic>;
    final files = <String, List<int>>{};
    final foldersRaw = preferences.getString('nova_folders_v1');
    if (foldersRaw != null) files['data/folders.json'] = utf8.encode(foldersRaw);
    final manifest = <Map<String, String>>[];
    final root = await _attachmentDirectory();
    final rootPath = root.absolute.path;
    final list = rawNotes['notes'] as List<dynamic>? ?? [];
    for (final raw in list) {
      final map = Map<String, dynamic>.from(raw as Map);
      final attachments = List<String>.from(map['attachments'] as List? ?? const []);
      final portable = <String>[];
      for (final path in attachments) {
        final file = File(path);
        if (!await file.exists()) continue;
        final absolute = file.absolute.path;
        if (absolute != rootPath && !p.isWithin(rootPath, absolute)) continue;
        final archiveName = 'attachments/${map['id']}-${p.basename(path)}';
        files[archiveName] = await file.readAsBytes();
        portable.add(archiveName);
        manifest.add({'source': path, 'archive': archiveName});
      }
      map['attachments'] = portable;
    }
    rawNotes['format'] = format;
    rawNotes['version'] = version;
    rawNotes['attachments'] = manifest;
    files['data/notes.json'] = utf8.encode(jsonEncode(rawNotes));
    if (files.isEmpty) throw const FormatException('Nothing available to back up.');
    final archive = Archive();
    for (final e in files.entries) archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
    final encoded = ZipEncoder().encode(archive) ?? <int>[];
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(dir.path, 'Orah_Backup_$stamp.nova'));
    await file.writeAsBytes(encoded, flush: true);
    return file;
  }

  Future<int> restoreBackup(File backup) async {
    final bytes = await backup.readAsBytes();
    if (bytes.length > maxBackupBytes) throw const FormatException('Backup is too large to restore safely.');
    final archive = ZipDecoder().decodeBytes(bytes);
    final notesFile = archive.findFile('data/notes.json');
    if (notesFile == null) throw const FormatException('Invalid Orah backup: notes.json missing.');
    final raw = jsonDecode(utf8.decode(notesFile.content as List<int>));
    if (raw is! Map || raw['format'] != format) throw const FormatException('Invalid Orah portable backup.');
    final backupVersion = raw['version'] is num ? (raw['version'] as num).toInt() : 0;
    if (backupVersion <= 0 || backupVersion > version) throw const FormatException('Unsupported Orah backup version.');
    final extracted = <String, String>{};
    var extractedBytes = 0;
    const maxAttachmentBytes = 512 * 1024 * 1024;
    final root = await _attachmentDirectory();
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('attachments/')) continue;
      if (file.name.contains('..') || file.name.contains('\\')) throw const FormatException('Invalid attachment path in backup.');
      final name = p.basename(file.name);
      if (name.isEmpty || name == '.' || name == '..') throw const FormatException('Invalid attachment name in backup.');
      extractedBytes += (file.content as List<int>).length;
      if (extractedBytes > maxAttachmentBytes) throw const FormatException('Backup attachments are too large to restore safely.');
      final base = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      var target = File(p.join(root.path, name));
      if (await target.exists()) target = File(p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}-$base$ext'));
      await target.writeAsBytes(file.content as List<int>, flush: true);
      extracted[file.name] = target.path;
    }
    final rawNoteList = raw['notes'];
    if (rawNoteList is! List) throw const FormatException('Invalid Orah backup: notes are missing.');
    final noteList = rawNoteList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      final paths = List<String>.from(map['attachments'] as List? ?? const []);
      map['attachments'] = paths.map((x) => extracted[x]).whereType<String>().toList();
      return map;
    }).toList();
    final payload = {'format': 'nova_notes_backup', 'version': 1, 'exportedAt': raw['exportedAt'] ?? DateTime.now().toIso8601String(), 'notes': noteList};
    final count = await LocalNoteRepository(preferences).importJson(jsonEncode(payload));
    final foldersFile = archive.findFile('data/folders.json');
    if (foldersFile != null) await preferences.setString('nova_folders_v1', utf8.decode(foldersFile.content as List<int>));
    return count;
  }

  Future<Directory> _attachmentDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
