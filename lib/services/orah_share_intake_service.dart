import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../data/repositories/note_repository_provider.dart';
import '../models/note.dart';

class OrahShareIntakeService {
  OrahShareIntakeService._();
  static final instance = OrahShareIntakeService._();
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(_handle, onError: (_) {});
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      await _handle(initial);
      ReceiveSharingIntent.instance.reset();
    } catch (_) {}
  }

  Future<void> _handle(List<SharedMediaFile> items) async {
    if (items.isEmpty) return;
    try {
      final repo = await NoteRepositoryProvider.instance();
      final now = DateTime.now();
      final text = <String>[];
      final paths = <String>[];
      for (final item in items) {
        if (item.type == SharedMediaType.text) {
          if (item.path.trim().isNotEmpty) text.add(item.path.trim());
        } else if (item.path.trim().isNotEmpty) {
          paths.add(item.path.trim());
        }
      }
      await repo.saveNote(Note(
        id: now.microsecondsSinceEpoch.toString(),
        title: text.isEmpty ? 'Shared item' : 'Shared note',
        content: text.join('\n\n'),
        type: paths.isEmpty ? NoteType.text : NoteType.image,
        createdAt: now,
        updatedAt: now,
        attachments: paths,
      ));
    } catch (_) {}
  }
}
