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

    final monthNames = <String, int>{
      'jan': 1, 'january': 1, 'feb': 2, 'february': 2,
      'mar': 3, 'march': 3, 'apr': 4, 'april': 4,
      'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
      'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
      'oct': 10, 'october': 10, 'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    final pattern = RegExp(
      r'\\b(\\d{1,2})\\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)(?:\\s+(\\d{4}))?\\b|\\b(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\\s+(\\d{1,2})(?:,?\\s+(\\d{4}))?\\b',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(text)) {
      final day = int.tryParse(match.group(1) ?? match.group(5) ?? '');
      final monthName = (match.group(2) ?? match.group(4) ?? '').toLowerCase();
      final explicitYear = int.tryParse(match.group(3) ?? match.group(6) ?? '');
      final month = monthNames[monthName];
      if (day == null || month == null) continue;
      var year = explicitYear ?? reference.year;
      final lastDay = DateTime(year, month + 1, 0).day;
      if (day < 1 || day > lastDay) continue;
      var parsed = DateTime(year, month, day);
      if (explicitYear == null && parsed.isBefore(DateTime(reference.year, reference.month, reference.day))) {
        year++;
        if (day <= DateTime(year, month + 1, 0).day) parsed = DateTime(year, month, day);
      }
      add(parsed);
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
