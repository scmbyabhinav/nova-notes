import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/navigation/orah_navigation.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';
import '../screens/note_editor_screen.dart';
import 'nova_attachment_service.dart';

class OrahShareIntentService {
  OrahShareIntentService._();
  static final instance = OrahShareIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  bool _initialized = false;
  bool _opening = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _openShared,
      onError: (_) {},
    );
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      if (initial.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openShared(initial));
      }
    } catch (_) {}
  }

  Future<void> _openShared(List<SharedMediaFile> media) async {
    if (_opening || media.isEmpty) return;
    _opening = true;
    try {
      final repository = await NoteRepositoryProvider.instance();
      final attachments = <String>[];
      final textParts = <String>[];
      String? title;

      for (final item in media) {
        final isText = item.type == SharedMediaType.text ||
            item.type == SharedMediaType.url;
        if (isText) {
          if (item.path.trim().isNotEmpty) textParts.add(item.path.trim());
          continue;
        }
        try {
          final imported = await const NovaAttachmentService().importFile(item.path);
          attachments.add(imported);
          title ??= item.path.split(RegExp(r'[/\\]')).last;
        } catch (_) {}
      }

      final content = textParts.join('\n\n');
      final navigator = orahNavigatorKey.currentState;
      if (navigator == null) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            repository: repository,
            initialType: NoteType.text,
            initialTitle: title ?? (content.isEmpty ? 'Shared item' : 'Shared note'),
            initialContent: content,
            initialAttachments: attachments,
          ),
        ),
      );
      await ReceiveSharingIntent.instance.reset();
    } finally {
      _opening = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
