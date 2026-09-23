import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/folder.dart';
import 'folder_repository.dart';

class LocalFolderRepository implements FolderRepository {
  LocalFolderRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _storageKey = 'nova_folders_v1';

  @override
  Future<List<NoteFolder>> getFolders() async {
    final raw = _preferences.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return _defaultFolders();
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final folders = <NoteFolder>[];
      final ids = <String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final folder = _fromMap(Map<String, dynamic>.from(item));
          if (folder.id.trim().isEmpty || !ids.add(folder.id)) continue;
          folders.add(folder);
        } catch (_) {
          // Skip one malformed folder without losing valid folders.
        }
      }

      folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return folders;
    } catch (_) {
      return _defaultFolders();
    }
  }

  @override
  Future<void> saveFolder(NoteFolder folder) async {
    final folders = await getFolders();
    final index = folders.indexWhere((item) => item.id == folder.id);

    if (folder.id.trim().isEmpty) throw const FormatException('Folder ID cannot be empty.');
    if (folder.name.trim().isEmpty) throw const FormatException('Folder name cannot be empty.');
    if (folder.name.trim().length > 80) throw const FormatException('Folder name is too long.');
    if (index == -1) {
      folders.add(folder);
    } else {
      folders[index] = folder;
    }

    await _write(folders);
  }

  @override
  Future<void> deleteFolder(String id) async {
    final folders = await getFolders();
    folders.removeWhere((folder) => folder.id == id);
    await _write(folders);
  }

  Future<List<NoteFolder>> _defaultFolders() async {
    final now = DateTime.now();
    final defaults = [
      NoteFolder(id: 'personal', name: 'Personal', createdAt: now),
      NoteFolder(id: 'work', name: 'Work', createdAt: now),
      NoteFolder(id: 'ideas', name: 'Ideas', createdAt: now),
      NoteFolder(id: 'study', name: 'Study', createdAt: now),
    ];

    await _write(defaults);
    return defaults;
  }

  Future<void> _write(List<NoteFolder> folders) async {
    final encoded = folders
        .map(
          (folder) => {
            'id': folder.id,
            'name': folder.name,
            'createdAt': folder.createdAt.toIso8601String(),
            'iconCodePoint': folder.iconCodePoint,
            'color': folder.color,
          },
        )
        .toList();

    await _preferences.setString(_storageKey, jsonEncode(encoded));
  }

  NoteFolder _fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now();
    return NoteFolder(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Folder',
      createdAt: createdAt,
      iconCodePoint: map['iconCodePoint'] is int ? map['iconCodePoint'] as int : null,
      color: map['color'] is int ? map['color'] as int : null,
    );
  }
}
