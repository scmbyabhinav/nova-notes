import 'package:intl/intl.dart';

class OrahSmartDetection {
  OrahSmartDetection._();

  static final _amount = RegExp(r'(?:₹|INR|Rs\.?|USD|\$|EUR|€|GBP|£)\s?\d[\d,]*(?:\.\d{1,2})?', caseSensitive: false);
  static final _date = RegExp(r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b');

  static List<String> amounts(String text) => _amount.allMatches(text).map((m) => m.group(0)!).toList();

  static List<DateTime> dates(String text) {
    final result = <DateTime>[];
    for (final match in _date.allMatches(text)) {
      final raw = match.group(0)!;
      final parts = raw.split(RegExp(r'[/-]')).map(int.tryParse).toList();
      DateTime? date;
      if (parts.length == 3) {
        if (parts[0]! > 31) {
          date = DateTime.tryParse(raw.replaceAll('/', '-'));
        } else {
          var year = parts[2]!;
          if (year < 100) year += 2000;
          date = DateTime(year, parts[1]!, parts[0]!);
        }
      }
      if (date != null) result.add(date);
    }
    return result;
  }

  static String summary(String text) {
    final a = amounts(text);
    final d = dates(text);
    final dateText = d.isEmpty ? 'No dates' : d.map((x) => DateFormat('d MMM yyyy').format(x)).join(', ');
    final amountText = a.isEmpty ? 'No amounts' : a.join(', ');
    return '$dateText\n$amountText';
  }
}
