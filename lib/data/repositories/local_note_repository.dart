import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/note.dart';
import '../../core/services/nova_security_service.dart';
import '../../models/search_filter.dart';
import 'note_repository.dart';

class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository(this._preferences);

  final SharedPreferences _preferences;
  final NovaSecurityService _security = NovaSecurityService();
  final StreamController<List<Note>> _notesController = StreamController<List<Note>>.broadcast();

  static const _storageKey = 'nova_notes_v1';

  @override
  Stream<List<Note>> watchNotes() {
    return Stream.multi(
      (controller) {
        var sawLiveUpdate = false;

        late final StreamSubscription<List<Note>> subscription;
        subscription = _notesController.stream.listen(
          (notes) {
            sawLiveUpdate = true;
            controller.add(notes);
          },
          onError: controller.addError,
        );
        controller.onCancel = subscription.cancel;

        // Broadcast streams intentionally do not buffer events for listeners
        // that were not present when the event was published. Seed each new
        // Home subscriber from persistent storage so it cannot miss the note
        // created immediately before/around navigation.
        getNotes().then(
          (notes) {
            if (!sawLiveUpdate && !controller.isClosed) {
              controller.add(List<Note>.unmodifiable(notes));
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          },
        );
      },
      isBroadcast: true,
    );
  }

  /// Re-publish the persisted snapshot after a navigation boundary.
  ///
  /// This is intentionally separate from [saveNote]: callers use it when a
  /// screen returns to a list that may have missed a transient broadcast.
  Future<void> refresh() async {
    _publish(await getNotes());
  }

  @override
  Future<List<Note>> getNotes() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final seen = <String>{};
      final notes = <Note>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final note = _fromMap(Map<String, dynamic>.from(item));
          if (note.id.trim().isNotEmpty && seen.add(note.id)) notes.add(note);
        } catch (_) {
          // Skip one malformed record without hiding otherwise valid notes.
        }
      }

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

    if (note.id.trim().isEmpty) throw const FormatException('Note ID cannot be empty.');
    if (index == -1) {
      notes.add(note);
    } else {
      notes[index] = note;
    }

    await _write(notes);
    // Publish the persisted snapshot, not the pre-write working list. This
    // guarantees every subscriber receives exactly what is now on disk.
    _publish(await getNotes());
  }

  @override
  Future<void> deleteNote(String id) async {
    final notes = await getNotes();
    notes.removeWhere((note) => note.id == id);
    await _write(notes);
    _publish(notes);
  }

  @override
  Future<List<Note>> searchNotes(String query) => search(query);

  @override
  Future<List<Note>> search(
    String query, {
    SearchFilter filter = const SearchFilter(),
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.length > 200) {
      throw const FormatException('Search query is too long.');
    }
    final notes = await getNotes();

    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    if (terms.length > 200) {
      throw const FormatException('Search query contains too many terms.');
    }

    final ranked = <({Note note, int score})>[];

    for (final note in notes) {
      if (note.isTrashed) continue;
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

      final title = note.isLocked ? 'private note' : note.title.toLowerCase();
      final content = note.isLocked ? '' : [note.content, ...note.checklistItems.map((item) => item.text)].join(' ').toLowerCase();
      final tags = note.isLocked ? const <String>[] : note.tags.map((tag) => tag.toLowerCase()).toList();
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
    final encoded = <Map<String, dynamic>>[];
    for (final note in notes) {
      encoded.add(await _toMap(note));
    }
    await _preferences.setString(_storageKey, jsonEncode(encoded));
  }

  void _publish(List<Note> notes) {
    final snapshot = [...notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _notesController.add(List<Note>.unmodifiable(snapshot));
  }

  Future<Map<String, dynamic>> _toMap(Note note) async {
    if (note.isLocked) {
      // A locked note loaded from storage already contains ciphertext and the
      // generic "Private note" label. Preserve that ciphertext when only
      // metadata (such as archived state) changes; otherwise it would be
      // encrypted a second time and could no longer be unlocked.
      if (note.title == 'Private note' && note.content.startsWith('vault:v1:')) {
        // Verify that this is actually an encrypted private payload before
        // preserving it. A user-entered string that merely starts with the
        // marker must still be encrypted as ordinary note content.
        try {
          final plaintext = await _security.decryptPrivatePayload(note.content);
          final decoded = jsonDecode(plaintext);
          if (decoded is Map &&
              decoded['version'] == 1 &&
              decoded['title'] is String &&
              decoded['content'] is String) {
            return {
              'id': note.id,
              'title': 'Private note',
              'content': note.content,
              'type': note.type.name,
              'createdAt': note.createdAt.toIso8601String(),
              'updatedAt': note.updatedAt.toIso8601String(),
              'folderId': note.folderId,
              'tags': const <String>[],
              'color': note.color,
              'isPinned': note.isPinned,
              'isFavorite': note.isFavorite,
              'isArchived': note.isArchived,
              'isLocked': true,
              'isTrashed': note.isTrashed,
              'dueAt': note.dueAt?.toIso8601String(),
              'attachments': note.attachments,
              'checklistItems': const <Map<String, dynamic>>[],
            };
          }
        } catch (_) {
          // Treat invalid marker-like text as normal content and encrypt it.
        }
      }

      final payload = jsonEncode({
        'version': 1,
        'title': note.title,
        'content': note.content,
        'tags': note.tags,
        'checklistItems':
            note.checklistItems.map((item) => item.toMap()).toList(),
      });
      final ciphertext = await _security.encryptPrivatePayload(payload);
      return {
        'id': note.id,
        'title': 'Private note',
        'content': ciphertext,
        'type': note.type.name,
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
        'folderId': note.folderId,
        'tags': const <String>[],
        'color': note.color,
        'isPinned': note.isPinned,
        'isFavorite': note.isFavorite,
        'isArchived': note.isArchived,
        'isLocked': true,
        'isTrashed': note.isTrashed,
        'dueAt': note.dueAt?.toIso8601String(),
        'attachments': note.attachments,
        'checklistItems': const <Map<String, dynamic>>[],
      };
    }

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
      'isTrashed': note.isTrashed,
      'dueAt': note.dueAt?.toIso8601String(),
      'attachments': note.attachments,
      'checklistItems': note.checklistItems.map((item) => item.toMap()).toList(),
    };
  }

  Note _fromMap(Map<String, dynamic> map) {
    final createdAt = DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? createdAt;
    return Note(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      type: NoteType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => NoteType.text,
      ),
      createdAt: createdAt,
      updatedAt: updatedAt,
      folderId: map['folderId'] as String?,
      tags: (map['tags'] is List) ? List<String>.from((map['tags'] as List).whereType<String>()) : const [],
      color: map['color'] as int?,
      isPinned: map['isPinned'] as bool? ?? false,
      isFavorite: map['isFavorite'] as bool? ?? false,
      isArchived: map['isArchived'] as bool? ?? false,
      isLocked: map['isLocked'] as bool? ?? false,
      isTrashed: map['isTrashed'] as bool? ?? false,
      dueAt: map['dueAt'] is String ? DateTime.tryParse(map['dueAt'] as String) : null,
      attachments: (map['attachments'] is List) ? List<String>.from((map['attachments'] as List).whereType<String>()) : const [],
      checklistItems: _checklistItemsFromMap(map),
    );
  }

  List<ChecklistItem> _checklistItemsFromMap(Map<String, dynamic> map) {
    final raw = map['checklistItems'];
    if (raw is List && raw.isNotEmpty) {
      final items = <ChecklistItem>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          items.add(ChecklistItem.fromMap(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip malformed checklist entries while preserving the note.
        }
      }
      return items;
    }
    final content = map['content'] as String? ?? '';
    if (map['type'] == NoteType.checklist.name && content.trim().isNotEmpty) {
      return content.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).map((line) {
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
    if (notes.length > 100000) {
      throw const FormatException('Too many notes to export safely.');
    }
    return jsonEncode({
      'format': 'nova_notes_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'notes': [for (final note in notes) await _toMap(note)],
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

    if (rawNotes.length > 100000) {
      throw const FormatException('Backup contains too many notes.');
    }

    final imported = <Note>[];
    final seenIds = <String>{};
    for (final item in rawNotes) {
      if (item is! Map) {
        throw const FormatException('Backup contains a malformed note record.');
      }
      final note = _fromMap(Map<String, dynamic>.from(item));
      if (note.id.length > 256 || note.title.length > 10000 || note.content.length > 1000000) {
        throw const FormatException('Backup contains an oversized note field.');
      }
      if (note.id.trim().isEmpty || !seenIds.add(note.id)) continue;
      imported.add(note);
    }

    final existing = await getNotes();
    final byId = <String, Note>{for (final n in existing) n.id: n};

    for (final note in imported) {
      final current = byId[note.id];
      // Newer copy wins when merging.
      if (current == null || note.updatedAt.isAfter(current.updatedAt)) {
        byId[note.id] = note;
      }
    }

    final merged = byId.values.toList();
    await _write(merged);
    _publish(merged);
    return imported.length;
  }

}
