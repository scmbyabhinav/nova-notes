
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_notes/models/note.dart';

void main() {
  test('note preserves Unicode and lock metadata', () {
    final note = Note(
      id: '1',
      title: '日本語 🚀 مرحباً',
      content: 'नमस्ते • Café • 中文 • 한국어',
      type: NoteType.text,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
      isLocked: true,
      attachments: const ['photo.jpg'],
    );

    expect(note.title, contains('日本語'));
    expect(note.content, contains('नमस्ते'));
    expect(note.isLocked, isTrue);
    expect(note.attachments, contains('photo.jpg'));
  });
}
