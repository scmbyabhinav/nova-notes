import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _fullyTranslatedLocales = <String>{'hi', 'es', 'fr', 'de'};

final _placeholderPattern = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

// These are proper names or intentionally language-neutral product/format labels.
const _languageNeutralKeys = <String>{
  'appTitle',
  'orahPro',
  'pdf',
  'ai',
  'pro',
  'android',
};

// Locale-specific exceptions for conventional examples and technical labels.
const _localeNeutralKeys = <String, Set<String>>{
  // Email example address format is shared in these locales.
  'ar': {'emailExample'},
  'he': {'emailExample'},
  'hi': {'emailExample'},
  'ja': {'emailExample', 'pin'},
  'ko': {'emailExample', 'pin'},
  'zh': {'emailExample'},
  // PIN is a standard technical abbreviation; these short labels are approved.
  'de': {'pin', 'details', 'moodNeutral', 'linkLabel'},
  'es': {'pin', 'total', 'moodNeutral', 'templateAgenda'},
  'id': {'pin', 'template', 'total'},
  'it': {'pin'},
  'pt': {'pin', 'total'},
  'tr': {'pin'},
  // These French interface labels are accepted as conventional wording.
  'fr': {'total', 'notes', 'templateImportant', 'templateDates'},
};

void main() {
  final directory = Directory('lib/l10n');

  Map<String, dynamic> readArb(File file) =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  Set<String> placeholders(String value) =>
      _placeholderPattern.allMatches(value).map((match) => match[1]!).toSet();

  List<File> getArbFiles() => directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every ARB locale has the same keys as English', () {
    final english = readArb(File('${directory.path}/app_en.arb'));
    final expectedKeys = messageKeys(english);
    final arbFiles = getArbFiles();

    expect(arbFiles, hasLength(14));

    for (final file in arbFiles) {
      final localeCode = file.uri.pathSegments.last
          .replaceFirst('app_', '')
          .replaceFirst('.arb', '');
      final decoded = readArb(file);

      expect(
        decoded['@@locale'],
        localeCode,
        reason: '${file.path} must declare its locale with @@locale.',
      );
      expect(
        messageKeys(decoded),
        expectedKeys,
        reason: '${file.path} must contain every English localization key.',
      );
    }
  });

  test('all translations are non-empty and preserve English placeholders', () {
    final english = readArb(File('${directory.path}/app_en.arb'));
    final englishKeys = messageKeys(english);

    for (final file in getArbFiles()) {
      final locale = file.uri.pathSegments.last
          .replaceFirst('app_', '')
          .replaceFirst('.arb', '');
      if (locale == 'en') continue;

      final translated = readArb(file);
      for (final key in englishKeys) {
        final englishValue = english[key];
        final translatedValue = translated[key];

        if (englishValue is! String || translatedValue is! String) continue;

        expect(
          translatedValue.trim(),
          isNotEmpty,
          reason: '${file.path}: "$key" has an empty translation.',
        );
        expect(
          placeholders(translatedValue),
          placeholders(englishValue),
          reason: '${file.path}: "$key" must preserve placeholder names.',
        );
      }
    }
  });

  test('non-English locales do not silently reuse English messages', () {
    final english = readArb(File('${directory.path}/app_en.arb'));
    final englishKeys = messageKeys(english);
    final untranslated = <String>[];

    for (final file in getArbFiles()) {
      final locale = file.uri.pathSegments.last
          .replaceFirst('app_', '')
          .replaceFirst('.arb', '');
      if (locale == 'en' || !_fullyTranslatedLocales.contains(locale)) continue;

      final translated = readArb(file);
      for (final key in englishKeys) {
        final source = english[key];
        final target = translated[key];
        if (source is! String || target is! String) continue;
        if (key.startsWith('@') ||
            _languageNeutralKeys.contains(key) ||
            (_localeNeutralKeys[locale]?.contains(key) ?? false)) continue;

        // Exact equality for an entire message is a strong signal of an
        // accidental English fallback. Proper names and short technical
        // abbreviations should be added to the explicit allowlist above.
        if (source.trim().isNotEmpty && source == target) {
          untranslated.add('$locale: $key = "$target"');
        }
      }
    }

    expect(
      untranslated,
      isEmpty,
      reason: 'Review exact English fallbacks in non-English ARB files:\n'
          '${untranslated.join('\n')}',
    );
  });
}
