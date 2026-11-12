import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/services/orah_local_text_analyzer.dart';

void main() {
  const analyzer = OrahLocalTextAnalyzer();

  test('suggests deterministic tags and category from local keywords', () {
    final result = analyzer.analyze('Meeting with supplier. Payment invoice for office project.');
    expect(result.tags, containsAll(['Meeting', 'Finance', 'Work']));
    expect(result.category, 'Work');
  });

  test('extracts explicit and relative dates without duplicates', () {
    final result = analyzer.analyze(
      'Meet on 18 December 2026 and follow up next Monday. Also tomorrow.',
      referenceDate: DateTime(2026, 11, 12),
    );
    expect(result.dates, contains(DateTime(2026, 12, 18)));
    expect(result.dates, contains(DateTime(2026, 11, 16)));
    expect(result.dates, contains(DateTime(2026, 11, 13)));
    expect(result.dates.length, 3);
  });

  test('extracts currency values and preserves currency identity', () {
    final result = analyzer.analyze('Payment ₹45,000, USD 120.50 and EUR 80.');
    expect(result.amounts.map((a) => (a.value, a.currency)).toList(), [
      (45000, 'INR'),
      (120.50, 'USD'),
      (80, 'EUR'),
    ]);
  });

  test('does not suggest anything for empty or unrelated text', () {
    expect(analyzer.analyze('   ').isEmpty, isTrue);
    expect(analyzer.analyze('Blue sky and quiet trees.').isEmpty, isTrue);
  });
}
