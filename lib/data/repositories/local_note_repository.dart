import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/note.dart';
import '../../models/search_filter.dart';
import 'note_repository.dart';

class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _storageKey = 'nova_notes_v1';

  @override
  Future<List<Note>> getNotes() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final notes = decoded
          .map((item) => _fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();

      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Note?> getNote(String id) async {
    final notes = await getNotes();
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<void> saveNote(Note note) async {
    final notes = await getNotes();
    final index = notes.indexWhere((item) => item.id == note.id);

    if (index == -1) {
      notes.add(note);
    } else {
      notes[index] = note;
    }

    await _write(notes);
  }

  @override
  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    notes.removeWhere((note) => note.id == id);
    await _write(notes);
  }

  @override
  Future<List<Note>> searchNotes(String query) => search(query);

  @override
  Future<List<Note>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
  }) async {
    final normalized = query.trim().toLowerCase();
    final notes = await getNotes();

    final terms = normalized
        .split(RegExp(r'\\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    final ranked = <({Note note, int score})>[];

    for (final note in notes) {
      if (!filter.archivedOnly && note.isArchived) continue;
      if (filter.archivedOnly && !note.isArchived) continue;
      if (filter.favoritesOnly && !note.isFavorite) continue;
      if (filter.pinnedOnly && !note.isPinned) continue;
      if (filter.folderId != null && note.folderId != filter.folderId) continue;
      if (filter.noteType != null && note.type != filter.noteType) continue;

      if (terms.isEmpty) {
        ranked.add((note: note, score: 0));
        continue;
      }

      final title = note.title.toLowerCase();
      final content = [note.content, ...note.checklistItems.map((item) => item.text)].join(' ').toLowerCase();
      final tags = note.tags.map((tag) => tag.toLowerCase()).toList();
      final haystack = [title, content, ...tags].join(' ');
      if (!terms.every(haystack.contains)) continue;

      var score = 0;
      for (final term in terms) {
        if (title == term) {
          score += 1000;
        } else if (title.contains(term)) {
          score += 500;
        }
        if (tags.any((tag) => tag == term)) {
          score += 350;
        } else if (tags.any((tag) => tag.contains(term))) {
          score += 200;
        }
        if (content.contains(term)) score += 100;
      }
      if (title.startsWith(normalized)) score += 250;
      ranked.add((note: note, score: score));
    }

    ranked.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });
    return ranked.map((item) => item.note).toList();
  }

  Future<void> _write(List<Note> notes) async {
    final encoded = notes.map(_toMap).toList();
    await _preferences.setString(_storageKey, jsonEncode(encoded));
  }

  Map<String, dynamic> _toMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'type': note.type.name,
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
      'folderId': note.folderId,
      'tags': note.tags,
      'color': note.color,
      'isPinned': note.isPinned,
      'isFavorite': note.isFavorite,
      'isArchived': note.isArchived,
      'isLocked': note.isLocked,
      'dueAt': note.dueAt?.toIso8601String(),
      'attachments': note.attachments,
      'checklistItems': note.checklistItems.map((item) => item.toMap()).toList(),
    };
  }

  Note _fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: NoteType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => NoteType.text,
      ),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      folderId: map['folderId'] as String?,
      tags: List<String>.from(map['tags'] as List? ?? const []),
      color: map['color'] as int?,
      isPinned: map['isPinned'] as bool? ?? false,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isLocked: map['isLocked'] as bool? ?? false,
      dueAt: map['dueAt'] == null ? null : DateTime.tryParse(map['dueAt'] as String),
      attachments: List<String>.from(map['attachments'] as List? ?? const []),
      checklistItems: _checklistItemsFromMap(map),
    );
  }

  List<ChecklistItem> _checklistItemsFromMap(Map<String, dynamic> map) {
    final raw = map['checklistItems'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item as Map))).toList();
    }
    final content = map['content'] as String? ?? '';
    if (map['type'] == NoteType.checklist.name && content.trim().isNotEmpty) {
      return content.split(RegExp(r'\\r?\\n')).where((line) => line.trim().isNotEmpty).map((line) {
        final trimmed = line.trim();
        final done = trimmed.startsWith('[x]') || trimmed.startsWith('[X]') || trimmed.startsWith('☑');
        final text = trimmed.replaceFirst(RegExp(r'^(?:\\[[ xX]\\]|☐|☑)\\s*'), '').replaceFirst(RegExp(r'^[-*•]\\s*'), '');
        return ChecklistItem(id: DateTime.now().microsecondsSinceEpoch.toString() + text.hashCode.toString(), text: text, isDone: done);
      }).toList();
    }
    return const [];
  }

  /// Returns a portable JSON backup containing all notes.
  Future<String> exportJson() async {
    final notes = await getNotes();
    return jsonEncode({
      'format': 'nova_notes_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': notes.map(_toMap).toList(),
    });
  }

  /// Imports a NOVA backup and merges notes by stable ID.
  Future<int> importJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['format'] != 'nova_notes_backup') {
      throw const FormatException('Invalid NOVA Notes backup.');
    }

    final rawNotes = decoded['notes'];
    if (rawNotes is! List) {
      throw const FormatException('Backup contains no valid notes.');
    }

    final imported = rawNotes
        .map((item) => _fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final existing = await getNotes();
    final byId = <String, Note>{for (final n in existing) n.id: n};

    for (final note in imported) {
      final current = byId[note.id];
      // Newer copy wins when merging.
      if (current == null || note.updatedAt.isAfter(current.updatedAt)) {
        byId[note.id] = note;
      }
    }

    await _write(byId.values.toList());
    return imported.length;
  }

}
