import 'package:flutter/foundation.dart';

import 'local_note_repository.dart';
import 'orah_preferences_provider.dart';

/// Owns one repository instance for the lifetime of the app.
///
/// Home and the editor can request the repository in the same frame (for
/// example, when Quick Capture is tapped while Home is loading its first
/// snapshot). Cache the in-flight construction as well as the completed
/// instance so concurrent callers cannot create competing repositories.
class NoteRepositoryProvider {
  NoteRepositoryProvider._();

  static LocalNoteRepository? _repository;
  static Future<LocalNoteRepository>? _pending;
  static int _generation = 0;

  static Future<LocalNoteRepository> instance() async {
    final cached = _repository;
    if (cached != null) {
      return cached;
    }

    final generation = _generation;
    final pending = _pending ??= _createRepository();
    try {
      final repository = await pending;
      if (generation == _generation) _repository = repository;
      return repository;
    } catch (error, stackTrace) {
      // A failed initialization must not poison future retry attempts.
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
  }

  static Future<LocalNoteRepository> _createRepository() async {
    final preferences = await OrahPreferencesProvider.instance();
    final repository = LocalNoteRepository(preferences);
    return repository;
  }
  @visibleForTesting
  static Future<void> resetForTesting() async {
    _generation++;
    final pending = _pending;
    if (pending != null) { try { await pending; } catch (_) {} }
    _repository = null;
    _pending = null;
  }
}
