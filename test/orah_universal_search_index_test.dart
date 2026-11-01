import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/services/orah_universal_search_index.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1);

  Note note({
    required String id,
    required String title,
    List<String> linkedNoteIds = const [],
    List<String> attachments = const [],
    String? imagePath,
    bool isLocked = false,
    bool isTrashed = false,
  }) {
    return Note(
      id: id,
      title: title,
      content: '',
      type: NoteType.text,
      createdAt: now,
      updatedAt: now,
      linkedNoteIds: linkedNoteIds,
      attachments: attachments,
      imagePath: imagePath,
      isLocked: isLocked,
      isTrashed: isTrashed,
    );
  }

  group('ORAH universal search index', () {
    test('indexes linked note titles in both directions', () {
      final notes = [
        note(id: 'a', title: 'Quarterly planning', linkedNoteIds: const ['b']),
        note(id: 'b', title: 'Budget forecast'),
      ];

      final index = OrahUniversalSearchIndex.relatedTitlesByNoteId(notes);

      expect(index['a'], contains('Budget forecast'));
      expect(index['b'], contains('Quarterly planning'));
    });

    test('does not reveal locked or trashed note titles through links', () {
      final notes = [
        note(id: 'a', title: 'Ordinary note', linkedNoteIds: const ['private', 'trash']),
        note(id: 'private', title: 'Confidential plan', isLocked: true),
        note(id: 'trash', title: 'Deleted project', isTrashed: true),
      ];

      final index = OrahUniversalSearchIndex.relatedTitlesByNoteId(notes);

      expect(index['a'], isNull);
      expect(index.containsKey('private'), isFalse);
      expect(index.containsKey('trash'), isFalse);
    });

    test('indexes attachment file names but not their parent directories', () {
      final value = note(
        id: 'a',
        title: 'Scanned invoice',
        attachments: const ['/private/files/Invoice-Oct.PDF', r'C:\\Docs\\Receipt.jpg'],
        imagePath: '/private/images/scan-01.png',
      );

      final names = OrahUniversalSearchIndex.attachmentNames(value);

      expect(names, contains('invoice-oct.pdf'));
      expect(names, contains('receipt.jpg'));
      expect(names, contains('scan-01.png'));
      expect(names.any((name) => name.contains('private')), isFalse);
    });
  });
}
