import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/models/note.dart';
import 'package:orah_notes/services/orah_smart_detection.dart';

void main() {
  test('note round-trip preserves reminder, color, trash and checklist due date', () {
    final due = DateTime(2026, 10, 15, 9, 30);
    final itemDue = DateTime(2026, 10, 16, 10);
    final note = Note(
      id: 'n1',
      title: 'Test',
      content: '₹1,250',
      type: NoteType.checklist,
      createdAt: due,
      updatedAt: due,
      color: 0xFFFF0000,
      isTrashed: true,
      dueAt: due,
      checklistItems: [ChecklistItem(id: 'c1', text: 'Pay bill', dueAt: itemDue)],
    );
    final restored = Note.fromMap(note.toMap());
    expect(restored.dueAt, due);
    expect(restored.color, note.color);
    expect(restored.isTrashed, isTrue);
    expect(restored.checklistItems.single.dueAt, itemDue);
  });

  test('smart detection finds Indian and international amounts', () {
    final values = OrahSmartDetection.amounts('Budget ₹1,250, USD 42.50 and €99');
    expect(values, contains('₹1,250'));
    expect(values, contains('USD 42.50'));
    expect(values, contains('€99'));
  });

  test('smart detection rejects impossible dates', () {
    final dates = OrahSmartDetection.dates('31/02/2026 15/10/2026');
    expect(dates, hasLength(1));
    expect(dates.single, DateTime(2026, 10, 15));
  });
}
