import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/repositories/local_note_repository.dart';
import '../data/database/orah_database.dart';
import '../services/focus_session_service.dart';
import '../core/services/nova_security_service.dart';

class NovaBackupService {
  const NovaBackupService(this.preferences);
  final SharedPreferences preferences;
  static const format = 'nova_notes_portable_backup';
  static const version = 3;
  static const _databaseTables = <String>['note_versions', 'habits', 'goals', 'kanban_cards', 'links', 'time_entries'];
  static const _portablePreferenceKeys = <String>['nova_folders_v1', 'orah_vault_notes_v1', 'orah_focus_sessions_v1', 'orah_theme_mode_v1', 'orah_accent_color_v1', 'orah_view_mode_v1', 'orah_vault_folders_v1', 'orah_vault_auto_lock_minutes'];
  static const maxBackupBytes = 512 * 1024 * 1024;

  Future<File> createBackup({String? vaultPassphrase}) async {
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
    // Vault records are stored separately from ordinary notes. Their
    // attachment paths must be rewritten to archive-relative names too.
    final vaultRaw = preferences.getString('orah_vault_notes_v1');
    if (vaultRaw != null && vaultRaw.isNotEmpty) {
      if (vaultPassphrase == null || vaultPassphrase.trim().length < 12) {
        throw const FormatException('Set a backup passphrase of at least 12 characters to include Vault notes.');
      }
      final security = NovaSecurityService();
      final decodedVault = jsonDecode(vaultRaw);
      if (decodedVault is! List) {
        throw const FormatException('Vault storage is malformed; backup was not created.');
      }
      final portableVault = <Map<String, dynamic>>[];
      for (final rawVaultNote in decodedVault) {
        if (rawVaultNote is! Map || rawVaultNote['id'] is! String) {
          throw const FormatException('A Vault record is malformed; backup was not created.');
        }
        final vaultNote = Map<String, dynamic>.from(rawVaultNote);
        if (vaultNote['content'] is! String) {
          throw const FormatException('A Vault record has no encrypted content.');
        }
        // Convert the device-bound ciphertext into a passphrase-protected
        // envelope. The device Keystore key itself never leaves this device.
        final clearPayload = await security.decryptPrivatePayload(vaultNote['content'] as String);
        final payloadValue = jsonDecode(clearPayload);
        if (payloadValue is! Map) {
          throw const FormatException('A decrypted Vault payload is malformed.');
        }
        final portablePayload = Map<String, dynamic>.from(payloadValue);
        final embeddedImage = portablePayload['imagePath'];
        if (embeddedImage is String && embeddedImage.isNotEmpty) {
          final imageFile = File(embeddedImage);
          final imageAbsolute = imageFile.absolute.path;
          if (!await imageFile.exists() || (imageAbsolute != rootPath && !p.isWithin(rootPath, imageAbsolute))) {
            throw FormatException('A Vault image is missing or outside ORAH storage: ${p.basename(embeddedImage)}.');
          }
          final imageArchiveName = 'attachments/vault-${vaultNote['id']}-image-${p.basename(embeddedImage)}';
          files[imageArchiveName] = await imageFile.readAsBytes();
          portablePayload['imagePath'] = imageArchiveName;
          manifest.add({'source': embeddedImage, 'archive': imageArchiveName});
        }
        vaultNote['content'] = await security.encryptPortableVaultPayload(
          jsonEncode(portablePayload), vaultPassphrase,
        );
        final attachments = vaultNote['attachments'];
        if (attachments != null && attachments is! List) {
          throw const FormatException('Vault attachment metadata is malformed.');
        }
        final portableAttachments = <String>[];
        for (final attachmentPath in (attachments as List? ?? const [])) {
          if (attachmentPath is! String || attachmentPath.trim().isEmpty) {
            throw const FormatException('A Vault attachment path is invalid.');
          }
          final attachment = File(attachmentPath);
          final absolute = attachment.absolute.path;
          if (!await attachment.exists() || (absolute != rootPath && !p.isWithin(rootPath, absolute))) {
            throw FormatException('A Vault attachment is missing or outside ORAH storage: ${p.basename(attachmentPath)}.');
          }
          final archiveName = 'attachments/vault-${vaultNote['id']}-${p.basename(attachmentPath)}';
          files[archiveName] = await attachment.readAsBytes();
          portableAttachments.add(archiveName);
          manifest.add({'source': attachmentPath, 'archive': archiveName});
        }
        vaultNote['attachments'] = portableAttachments;
        portableVault.add(vaultNote);
      }
      files['data/vault.json'] = utf8.encode(jsonEncode({
        'format': 'orah_vault_snapshot',
        'version': 1,
        'records': portableVault,
      }));
    }

    rawNotes['format'] = format;
    rawNotes['version'] = version;
    rawNotes['attachments'] = manifest;
    files['data/notes.json'] = utf8.encode(jsonEncode(rawNotes));

    // Snapshot every structured local data domain that is not already inside
    // notes.json. Keep the table list explicit: never export SQLite internals,
    // FTS virtual tables, migration state, or credentials.
    final db = await OrahDatabase.open(preferences);
    final databaseSnapshot = <String, dynamic>{
      'format': 'orah_database_snapshot',
      'version': 1,
      'tables': <String, dynamic>{
        for (final table in _databaseTables) table: await db.query(table),
      },
    };
    files['data/database.json'] = utf8.encode(jsonEncode(databaseSnapshot));

    final portablePreferences = <String, dynamic>{};
    for (final key in _portablePreferenceKeys) {
      final value = preferences.get(key);
      if (value != null && key != 'orah_vault_notes_v1') portablePreferences[key] = value;
    }
    files['data/preferences.json'] = utf8.encode(jsonEncode({
      'format': 'orah_preferences_snapshot',
      'version': 1,
      'values': portablePreferences,
    }));
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

  Future<int> restoreBackup(File backup, {String? vaultPassphrase}) async {
    final bytes = await backup.readAsBytes();
    if (bytes.length > maxBackupBytes) throw const FormatException('Backup is too large to restore safely.');
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.length > 100000) {
      throw const FormatException('Backup contains too many archive entries.');
    }
    final notesFile = archive.findFile('data/notes.json');
    if (notesFile == null) throw const FormatException('Invalid Orah backup: notes.json missing.');
    final raw = jsonDecode(utf8.decode(notesFile.content as List<int>));
    if (raw is! Map || raw['format'] != format) throw const FormatException('Invalid Orah portable backup.');
    final backupVersion = raw['version'] is num ? (raw['version'] as num).toInt() : 0;
    if (backupVersion <= 0 || backupVersion > version) throw const FormatException('Unsupported Orah backup version.');
    final rawNoteList = raw['notes'];
    if (rawNoteList is! List) throw const FormatException('Invalid Orah backup: notes are missing.');
    if (rawNoteList.length > 100000) throw const FormatException('Backup contains too many notes.');
    final foldersFile = archive.findFile('data/folders.json');
    String? foldersPayload;
    if (foldersFile != null) {
      try {
        final folderBytes = foldersFile.content as List<int>;
        final decodedFolders = jsonDecode(utf8.decode(folderBytes));
        if (decodedFolders is! List || decodedFolders.length > 10000) {
          throw const FormatException('Invalid Orah backup: folders are malformed.');
        }
        for (final item in decodedFolders) {
          if (item is! Map) {
            throw const FormatException('Invalid Orah backup: a folder record is malformed.');
          }
          final map = Map<String, dynamic>.from(item);
          final id = map['id'];
          final name = map['name'];
          if (id is! String || id.trim().isEmpty || name is! String || name.trim().isEmpty || name.trim().length > 80) {
            throw const FormatException('Invalid Orah backup: a folder record is invalid.');
          }
        }
        foldersPayload = utf8.decode(folderBytes);
      } catch (_) {
        throw const FormatException('Invalid Orah backup: folders are malformed.');
      }
    }

    // Validate every optional snapshot before extracting files or mutating app data.
    Map<String, dynamic>? validatedTables;
    final databaseFile = archive.findFile('data/database.json');
    if (databaseFile != null) {
      final snapshot = jsonDecode(utf8.decode(databaseFile.content as List<int>));
      if (snapshot is! Map || snapshot['format'] != 'orah_database_snapshot' ||
          snapshot['version'] != 1 || snapshot['tables'] is! Map) {
        throw const FormatException('Invalid ORAH database snapshot.');
      }
      validatedTables = Map<String, dynamic>.from(snapshot['tables'] as Map);
      for (final table in validatedTables.entries) {
        if (!_databaseTables.contains(table.key)) {
          throw FormatException('Unexpected ORAH database table: ${table.key}.');
        }
        final rows = table.value;
        if (rows is! List || rows.length > 100000 || rows.any((row) => row is! Map)) {
          throw FormatException('Invalid ORAH database table: ${table.key}.');
        }
        for (final rawRow in rows) {
          final row = Map<String, Object?>.from(rawRow as Map);
          final requiredId = table.key == 'note_versions' ? row['id'] : row['id'];
          if (requiredId == null || (requiredId is String && requiredId.trim().isEmpty)) {
            throw FormatException('A record in ${table.key} has no valid ID.');
          }
        }
      }
    }

    Map<String, dynamic>? validatedPreferences;
    final preferencesFile = archive.findFile('data/preferences.json');
    if (preferencesFile != null) {
      final snapshot = jsonDecode(utf8.decode(preferencesFile.content as List<int>));
      if (snapshot is! Map || snapshot['format'] != 'orah_preferences_snapshot' ||
          snapshot['version'] != 1 || snapshot['values'] is! Map) {
        throw const FormatException('Invalid ORAH preferences snapshot.');
      }
      validatedPreferences = Map<String, dynamic>.from(snapshot['values'] as Map);
      for (final entry in validatedPreferences.entries) {
        if (!_portablePreferenceKeys.contains(entry.key)) {
          throw FormatException('Unexpected ORAH preference key: ${entry.key}.');
        }
        final value = entry.value;
        if (value is! String && value is! bool && value is! int && value is! double &&
            !(value is List && value.every((item) => item is String))) {
          throw FormatException('Invalid ORAH preference value: ${entry.key}.');
        }
      }
    }

    List<Map<String, dynamic>>? validatedVaultRecords;
    final vaultFile = archive.findFile('data/vault.json');
    if (vaultFile != null) {
      final snapshot = jsonDecode(utf8.decode(vaultFile.content as List<int>));
      if (snapshot is! Map || snapshot['format'] != 'orah_vault_snapshot' ||
          snapshot['version'] != 1 || snapshot['records'] is! List) {
        throw const FormatException('Invalid ORAH Vault snapshot.');
      }
      final records = snapshot['records'] as List;
      if (records.length > 100000 || records.any((item) => item is! Map)) {
        throw const FormatException('Invalid ORAH Vault records.');
      }
      validatedVaultRecords = records.map((item) {
        final record = Map<String, dynamic>.from(item as Map);
        if (record['id'] is! String || (record['id'] as String).trim().isEmpty ||
            record['content'] is! String || record['isLocked'] != true ||
            (record['attachments'] is! List)) {
          throw const FormatException('A Vault record is malformed.');
        }
        for (final path in record['attachments'] as List) {
          if (path is! String || !path.startsWith('attachments/')) {
            throw const FormatException('A Vault attachment reference is invalid.');
          }
        }
        return record;
      }).toList();
    }

    List<Map<String, dynamic>>? portableVaultPayloads;
    if (validatedVaultRecords != null) {
      if (vaultPassphrase == null || vaultPassphrase.trim().length < 12) {
        throw const FormatException('Enter the backup passphrase to restore Vault notes.');
      }
      // Authenticate and parse every Vault payload before importing ordinary
      // notes or extracting attachments. A wrong passphrase must be a no-op.
      final security = NovaSecurityService();
      portableVaultPayloads = <Map<String, dynamic>>[];
      for (final record in validatedVaultRecords) {
        final clear = await security.decryptPortableVaultPayload(
          record['content'] as String, vaultPassphrase,
        );
        final decoded = jsonDecode(clear);
        if (decoded is! Map) {
          throw const FormatException('A decrypted portable Vault payload is malformed.');
        }
        final payload = Map<String, dynamic>.from(decoded);
        final imagePath = payload['imagePath'];
        if (imagePath != null &&
            (imagePath is! String || !imagePath.startsWith('attachments/'))) {
          throw const FormatException('A Vault image reference is invalid.');
        }
        portableVaultPayloads.add(payload);
      }
    }
    final extracted = <String, String>{};
    final createdPaths = <String>[];
    final archiveAttachmentNames = <String>{};
    var extractedBytes = 0;
    const maxAttachmentBytes = 512 * 1024 * 1024;
    final root = await _attachmentDirectory();

    try {
      for (final file in archive.files) {
        if (!file.isFile || !file.name.startsWith('attachments/')) continue;
        if (file.name.contains('..') || file.name.contains('\\')) throw const FormatException('Invalid attachment path in backup.');
        final name = p.basename(file.name);
        if (!archiveAttachmentNames.add(file.name)) {
          throw const FormatException('Duplicate attachment entry in backup.');
        }
        if (name.isEmpty || name == '.' || name == '..') throw const FormatException('Invalid attachment name in backup.');
        extractedBytes += (file.content as List<int>).length;
        if (extractedBytes > maxAttachmentBytes) throw const FormatException('Backup attachments are too large to restore safely.');
        final base = p.basenameWithoutExtension(name);
        final ext = p.extension(name);
        var target = File(p.join(root.path, name));
        var suffix = 0;
        while (await target.exists()) {
          suffix++;
          target = File(p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}-$suffix-$base$ext'));
        }
        await target.writeAsBytes(file.content as List<int>, flush: true);
        createdPaths.add(target.path);
        extracted[file.name] = target.path;
      }

      final noteList = rawNoteList.map((item) {
        if (item is! Map) throw const FormatException('Invalid Orah backup: a note record is malformed.');
        final map = Map<String, dynamic>.from(item);
        final rawAttachments = map['attachments'];
        if (rawAttachments != null && rawAttachments is! List) {
          throw const FormatException('Invalid Orah backup: note attachments are malformed.');
        }
        final paths = rawAttachments is List ? rawAttachments.whereType<String>().toList() : const <String>[];
        for (final path in paths) {
          if (!path.startsWith('attachments/') || !extracted.containsKey(path)) {
            throw const FormatException('Invalid Orah backup: attachment reference is missing.');
          }
        }
        map['attachments'] = paths.map((x) => extracted[x]!).toList();
        return map;
      }).toList();

      final payload = {'format': 'nova_notes_backup', 'version': 1, 'exportedAt': raw['exportedAt'] ?? DateTime.now().toIso8601String(), 'notes': noteList};
      final count = await LocalNoteRepository(preferences).importJson(jsonEncode(payload));
      if (foldersPayload != null) await preferences.setString('nova_folders_v1', foldersPayload);

      // All archive sections were validated before any app data was changed.
      if (validatedTables != null) {
        final db = await OrahDatabase.open(preferences);
        await db.transaction((txn) async {
          for (final table in _databaseTables) {
            final rows = validatedTables![table] as List? ?? const [];
            for (final rawRow in rows) {
              final row = Map<String, Object?>.from(rawRow as Map);
              await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        });
      }

      if (validatedVaultRecords != null) {
        final security = NovaSecurityService();
        for (var index = 0; index < validatedVaultRecords!.length; index++) {
          final record = validatedVaultRecords[index];
          record['attachments'] = (record['attachments'] as List).map((path) {
            final restoredPath = extracted[path];
            if (restoredPath == null) {
              throw const FormatException('A Vault attachment is missing from the backup archive.');
            }
            return restoredPath;
          }).toList();
          // Re-encrypt under this device's own Keystore-backed Vault key.
          final payload = portableVaultPayloads![index];
          final imagePath = payload['imagePath'];
          if (imagePath is String && imagePath.startsWith('attachments/')) {
            final restoredImage = extracted[imagePath];
            if (restoredImage == null) {
              throw const FormatException('A Vault image is missing from the backup archive.');
            }
            payload['imagePath'] = restoredImage;
          }
          record['content'] = await security.encryptPrivatePayload(jsonEncode(payload));
        }
        await preferences.setString('orah_vault_notes_v1', jsonEncode(validatedVaultRecords));
      }

      if (validatedPreferences != null) {
        for (final entry in validatedPreferences.entries) {
          final value = entry.value;
          if (value is String) {
            await preferences.setString(entry.key, value);
          } else if (value is bool) {
            await preferences.setBool(entry.key, value);
          } else if (value is int) {
            await preferences.setInt(entry.key, value);
          } else if (value is double) {
            await preferences.setDouble(entry.key, value);
          } else if (value is List) {
            await preferences.setStringList(entry.key, value.cast<String>());
          }
        }
      }
      return count;
    } catch (error) {
      for (final path in createdPaths) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<Directory> _attachmentDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'attachments'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
