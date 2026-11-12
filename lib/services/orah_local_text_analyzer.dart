import 'package:intl/intl.dart';

/// Deterministic, on-device suggestions derived from note text.
/// Nothing is persisted or changed until the user explicitly accepts a value.
class SmartNoteSuggestions {
  const SmartNoteSuggestions({
    this.tags = const [],
    this.dates = const [],
    this.amounts = const [],
    this.category,
  });

  final List<String> tags;
  final List<DateTime> dates;
  final List<ExtractedAmount> amounts;
  final String? category;

  bool get isEmpty => tags.isEmpty && dates.isEmpty && amounts.isEmpty && category == null;
}

class ExtractedAmount {
  const ExtractedAmount({required this.value, required this.currency, required this.source});
  final num value;
  final String currency;
  final String source;
}

class OrahLocalTextAnalyzer {
  const OrahLocalTextAnalyzer();

  static const _tagRules = <String, List<String>>{
    'Meeting': ['meeting', 'agenda', 'minutes', 'discussion'],
    'Work': ['work', 'office', 'project', 'task', 'deadline'],
    'Finance': ['payment', 'invoice', 'amount', 'budget', 'salary', 'expense', '₹', 'inr', 'rs.'],
    'Shopping': ['buy', 'purchase', 'shopping', 'grocery', 'order'],
    'Travel': ['travel', 'trip', 'flight', 'hotel', 'booking', 'train'],
    'Health': ['doctor', 'hospital', 'medicine', 'appointment', 'health'],
    'Personal': ['family', 'birthday', 'home', 'personal'],
    'Study': ['study', 'exam', 'class', 'course', 'assignment'],
  };

  SmartNoteSuggestions analyze(String text, {DateTime? referenceDate}) {
    final source = text.trim();
    if (source.isEmpty) return const SmartNoteSuggestions();
    final lower = source.toLowerCase();
    final tags = <String>[];
    for (final entry in _tagRules.entries) {
      if (entry.value.any((word) => lower.contains(word))) tags.add(entry.key);
    }

    final dates = _extractDates(source, referenceDate ?? DateTime.now());
    final amounts = _extractAmounts(source);
    final category = _categoryFor(tags);
    return SmartNoteSuggestions(
      tags: tags,
      dates: dates,
      amounts: amounts,
      category: category,
    );
  }

  String? _categoryFor(List<String> tags) {
    const priority = ['Work', 'Finance', 'Meeting', 'Study', 'Travel', 'Health', 'Shopping', 'Personal'];
    for (final item in priority) {
      if (tags.contains(item)) return item;
    }
    return null;
  }

  List<DateTime> _extractDates(String text, DateTime reference) {
    final results = <DateTime>[];
    final normalized = text.toLowerCase();
    void add(DateTime date) {
      final value = DateTime(date.year, date.month, date.day);
      if (!results.any((existing) => existing.year == value.year && existing.month == value.month && existing.day == value.day)) {
        results.add(value);
      }
    }

    if (RegExp(r'\btoday\b').hasMatch(normalized)) add(reference);
    if (RegExp(r'\btomorrow\b').hasMatch(normalized)) add(reference.add(const Duration(days: 1)));
    final weekdayMatch = RegExp(r'\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b').firstMatch(normalized);
    if (weekdayMatch != null) {
      const weekdays = {'monday': DateTime.monday, 'tuesday': DateTime.tuesday, 'wednesday': DateTime.wednesday, 'thursday': DateTime.thursday, 'friday': DateTime.friday, 'saturday': DateTime.saturday, 'sunday': DateTime.sunday};
      final target = weekdays[weekdayMatch.group(1)]!;
      var delta = (target - reference.weekday) % 7;
      if (delta == 0) delta = 7;
      add(reference.add(Duration(days: delta)));
    }

    final pattern = RegExp(r'\b(\d{1,2}\s+(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)(?:\s+\d{4})?|(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2}(?:,?\s+\d{4})?)\b', caseSensitive: false);
    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0)!;
      DateTime? parsed;
      for (final format in ['d MMMM yyyy', 'd MMM yyyy', 'd MMMM', 'd MMM', 'MMMM d yyyy', 'MMM d yyyy', 'MMMM d', 'MMM d']) {
        try {
          parsed = DateFormat(format, 'en').parseStrict(raw);
          if (!RegExp(r'\d{4}').hasMatch(raw)) {
            parsed = DateTime(reference.year, parsed.month, parsed.day);
            if (DateTime(parsed.year, parsed.month, parsed.day).isBefore(DateTime(reference.year, reference.month, reference.day))) {
              parsed = DateTime(reference.year + 1, parsed.month, parsed.day);
            }
          }
          break;
        } catch (_) {}
      }
      if (parsed != null) add(parsed);
    }
    results.sort((a, b) => a.compareTo(b));
    return results;
  }

  List<ExtractedAmount> _extractAmounts(String text) {
    final pattern = RegExp(r'(?:(₹|Rs\.?|INR|\$|USD|€|EUR|£|GBP)\s*([0-9][0-9,]*(?:\.\d{1,2})?)|\b([0-9][0-9,]*(?:\.\d{1,2})?)\s*(INR|USD|EUR|GBP)\b)', caseSensitive: false);
    final results = <ExtractedAmount>[];
    for (final match in pattern.allMatches(text)) {
      final symbol = (match.group(1) ?? match.group(4) ?? '').toUpperCase();
      final raw = match.group(2) ?? match.group(3) ?? '';
      final value = num.tryParse(raw.replaceAll(',', ''));
      if (value == null) continue;
      final currency = switch (symbol) {
        '₹' || 'RS' || 'RS.' || 'INR' => 'INR',
        r'$' || 'USD' => 'USD',
        '€' || 'EUR' => 'EUR',
        '£' || 'GBP' => 'GBP',
        _ => '',
      };
      if (currency.isEmpty) continue;
      if (!results.any((item) => item.value == value && item.currency == currency)) {
        results.add(ExtractedAmount(value: value, currency: currency, source: match.group(0)!));
      }
    }
    return results;
  }
}
