import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';
import 'nova_attachment_service.dart';

class OrahShareIntakeService {
  OrahShareIntakeService._();
  static final instance = OrahShareIntakeService._();

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(_consume, onError: (_) {});
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) await _consume(initial);
      await ReceiveSharingIntent.instance.reset();
    } catch (_) {}
  }

  Future<void> _consume(List<SharedMediaFile> media) async {
    if (media.isEmpty) return;
    final navigator = orahNavigatorKey.currentState;
    if (navigator == null) return;

    final textItems = media
        .where((item) => item.type == SharedMediaType.text || item.type == SharedMediaType.url)
        .map((item) => item.path.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final fileItems = media.where((item) => item.type != SharedMediaType.text && item.type != SharedMediaType.url).toList();
    final repository = await NoteRepositoryProvider.instance();

    if (fileItems.isEmpty) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            repository: repository,
            initialTitle: textItems.isEmpty ? 'Shared from another app' : textItems.first.length > 60 ? '${textItems.first.substring(0, 60)}…' : textItems.first,
            initialContent: textItems.join('\n\n'),
          ),
        ),
      );
      return;
    }

    final attachments = <String>[];
    const attachmentService = NovaAttachmentService();
    for (final item in fileItems) {
      try {
        attachments.add(await attachmentService.importFile(item.path));
      } catch (_) {}
    }

    final now = DateTime.now();
    final note = Note(
      id: now.microsecondsSinceEpoch.toString() + '_shared',
      title: textItems.isEmpty ? 'Shared attachment' : textItems.first,
      content: textItems.join('\n\n'),
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      attachments: attachments,
      checklistItems: const [],
    );
    await repository.saveNote(note);
    if (orahNavigatorKey.currentState != null) {
      navigator.push(MaterialPageRoute(builder: (_) => NoteEditorScreen(repository: repository, note: note)));
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
