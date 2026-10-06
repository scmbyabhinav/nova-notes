import 'package:intl/intl.dart';

class OrahSmartDetection {
  OrahSmartDetection._();

  static final _amount = RegExp(
    r'(?:(?:₹|INR|Rs\.?|USD|\$|EUR|€|GBP|£)\s*\d[\d,]*(?:\.\d{1,2})?|(?<![\w.])\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?\s*(?:rupees?|dollars?|euros?|pounds?)\b)',
    caseSensitive: false,
  );

  static final _numericDate = RegExp(
    r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b',
  );

  static final _namedDate = RegExp(
    r'\b(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?\b',
    caseSensitive: false,
  );

  static final _time = RegExp(
    r'\b(?:[01]?\d|2[0-3])(?::[0-5]\d)?\s*(?:a\.?m\.?|p\.?m\.?)\b|\b(?:[01]?\d|2[0-3]):[0-5]\d\b',
    caseSensitive: false,
  );

  static List<String> amounts(String text) {
    final matches = _amount.allMatches(text);
    return matches
        .map((m) => m.group(0)!.trim())
        .map((amount) => amount.replaceAll(RegExp(r'[,\s]+$'), ''))
        .toList();
  }

  static List<DateTime> dates(String text, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final result = <DateTime>[];

    for (final match in _numericDate.allMatches(text)) {
      final raw = match.group(0)!;
      final parts = raw.split(RegExp(r'[/-]')).map(int.tryParse).toList();
      DateTime? date;
      if (parts.length == 3) {
        if (parts[0]! > 31) {
          date = _validDate(parts[0]!, parts[1]!, parts[2]!);
        } else {
          var year = parts[2]!;
          if (year < 100) year += 2000;
          date = _validDate(year, parts[1]!, parts[0]!);
        }
      }
      if (date != null) result.add(date);
    }

    for (final match in _namedDate.allMatches(text)) {
      final raw = match.group(0)!;
      final cleaned = raw.replaceAll(
        RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false),
        r'\$1',
      );
      final parsed = _parseNamedDate(cleaned, base);
      if (parsed != null) result.add(parsed);
    }

    final lower = text.toLowerCase();
    if (RegExp(r'\bday after tomorrow\b').hasMatch(lower)) {
      result.add(DateTime(base.year, base.month, base.day + 2));
    } else if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
      result.add(DateTime(base.year, base.month, base.day + 1));
    } else if (RegExp(r'\btoday\b').hasMatch(lower)) {
      result.add(DateTime(base.year, base.month, base.day));
    }

    return _uniqueDates(result);
  }

  static DateTime? detectDateTime(String text, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final detectedDates = dates(text, now: base);
    final timeMatch = _time.firstMatch(text);

    if (detectedDates.isEmpty && timeMatch == null) return null;

    DateTime date = detectedDates.isNotEmpty
        ? detectedDates.first
        : DateTime(base.year, base.month, base.day);

    if (timeMatch == null) {
      date = DateTime(date.year, date.month, date.day, 9);
    } else {
      final parsedTime = _parseTime(timeMatch.group(0)!);
      if (parsedTime == null) return null;
      date = DateTime(date.year, date.month, date.day, parsedTime.$1, parsedTime.$2);
    }

    if (detectedDates.isEmpty && !date.isAfter(base)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  static String summary(String text) {
    final a = amounts(text);
    final d = dates(text);
    final dateText = d.isEmpty
        ? 'No dates'
        : d.map((x) => DateFormat('d MMM yyyy').format(x)).join(', ');
    final amountText = a.isEmpty ? 'No amounts' : a.join(', ');
    return '$dateText\n$amountText';
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1) return null;
    final candidate = DateTime(year, month, day);
    return candidate.year == year &&
            candidate.month == month &&
            candidate.day == day
        ? candidate
        : null;
  }

  static DateTime? _parseNamedDate(String raw, DateTime base) {
    final match = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2})(?:,?\s+(\d{4}))?$',
    ).firstMatch(raw);
    if (match == null) return null;

    final month = _monthNumber(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3) ?? '') ?? base.year;
    if (month == null || day == null) return null;

    final candidate = _validDate(year, month, day);
    if (candidate == null) return null;
    if (match.group(3) == null &&
        candidate.isBefore(DateTime(base.year, base.month, base.day))) {
      return DateTime(year + 1, month, day);
    }
    return candidate;
  }

  static int? _monthNumber(String value) {
    const months = <String, int>{
      'jan': 1, 'january': 1, 'feb': 2, 'february': 2,
      'mar': 3, 'march': 3, 'apr': 4, 'april': 4, 'may': 5,
      'jun': 6, 'june': 6, 'jul': 7, 'july': 7, 'aug': 8,
      'august': 8, 'sep': 9, 'september': 9, 'oct': 10,
      'october': 10, 'nov': 11, 'november': 11, 'dec': 12,
      'december': 12,
    };
    return months[value.toLowerCase()];
  }

  static (int, int)? _parseTime(String raw) {
    final normalized = raw
        .toLowerCase()
        .replaceAll('.', '')
        .replaceAll(' ', '');
    final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)?$')
        .firstMatch(normalized);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3);

    if (minute > 59) return null;
    if (period != null) {
      if (hour < 1 || hour > 12) return null;
      if (period == 'am' && hour == 12) hour = 0;
      if (period == 'pm' && hour != 12) hour += 12;
    } else if (hour > 23) {
      return null;
    }
    return (hour, minute);
  }

  static List<DateTime> _uniqueDates(List<DateTime> input) {
    final seen = <String>{};
    return input.where((date) => seen.add(
      DateTime(date.year, date.month, date.day).toIso8601String(),
    )).toList();
  }
}