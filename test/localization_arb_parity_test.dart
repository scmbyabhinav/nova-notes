import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orah_notes/l10n/app_localizations.dart';

const _fullyTranslatedLocales = <String>{'ar', 'de', 'es', 'fr', 'he', 'hi', 'id', 'it', 'ja', 'ko', 'pt', 'tr', 'zh'};

final _placeholderPattern = RegExp(r'\{([A-Za-z][A-Za-z0-9_]*)\}');

// These are proper names or intentionally language-neutral product/format labels.
const _languageNeutralKeys = <String>{
  'appTitle',
  'orahPro',
  'pdf',
  'ai',
  'pro',
  'android',
  // Canonical format names and extensions are intentionally unchanged.
  'exportFormatPdf',
  'exportFormatWord',
  'exportFormatMarkdown',
  'exportFormatExcel',
  // Planned export names are canonical file formats/protocols; their descriptions are localized.
  'plannedExportRichText',
  'plannedExportOpenDocument',
  'plannedExportHtml',
  'plannedExportEpub',
  'plannedExportMobi',
  'plannedExportAzw3',
  'plannedExportFb2',
  'plannedExportLatex',
  'plannedExportLatexPdf',
  'plannedExportBibtex',
  'plannedExportCsv',
  'plannedExportJson',
  'plannedExportXml',
  'plannedExportYaml',
  'plannedExportTsv',
  'plannedExportPowerPoint',
  'plannedExportMp3',
  'plannedExportWav',
  'plannedExportSrt',
  'plannedExportVtt',
  'plannedExportEml',
  'plannedExportJupyter',
  'plannedExportZip',
  'plannedExport7z',
  'plannedExportSqlite',
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
  'de': {'pin', 'details', 'moodNeutral'},
  'es': {'pin', 'total', 'moodNeutral', 'templateAgenda', 'vaultAutoLockDuration'},
  'id': {'pin', 'total', 'templateAgenda', 'exportData'},
  'it': {'pin', 'exportCategoryDatabase', 'vaultAutoLockDuration'},
  'pt': {'pin', 'total', 'vaultAutoLockDuration'},
  'tr': {'pin'},
  // These French interface labels are accepted as conventional wording.
  'fr': {'total', 'notes', 'templateImportant', 'templateDates', 'trashNote', 'exportDocuments', 'vaultAutoLockDuration'},
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
  testWidgets('MaterialApp resolves all 14 locales and RTL direction correctly', (tester) async {
    const locales = <String>[
      'en', 'hi', 'es', 'fr', 'de', 'he', 'ar',
      'id', 'it', 'ja', 'ko', 'pt', 'tr', 'zh',
    ];
    for (final localeCode in locales) {
      TextDirection? resolvedDirection;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(localeCode),
          supportedLocales: locales.map((code) => Locale(code)).toList(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              resolvedDirection = Directionality.of(context);
              final l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(l10n.captureDescription),
                      Text(l10n.searchFilterHint),
                      Text(l10n.vaultResetWarning),
                      Text(l10n.featureVoiceCaptureDescription),
                      Text(l10n.notificationDailyReflectionTitle),
                      Text(l10n.notificationDailyReflectionBody),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final expected = await AppLocalizations.delegate.load(Locale(localeCode));
      expect(find.text(expected.captureDescription), findsOneWidget,
          reason: 'Capture copy did not resolve for $localeCode.');
      expect(find.text(expected.searchFilterHint), findsOneWidget,
          reason: 'Search copy did not resolve for $localeCode.');
      expect(find.text(expected.vaultResetWarning), findsOneWidget,
          reason: 'Vault warning did not resolve for $localeCode.');
      expect(find.text(expected.featureVoiceCaptureDescription), findsOneWidget,
          reason: 'Feature copy did not resolve for $localeCode.');
      expect(find.text(expected.notificationDailyReflectionTitle), findsOneWidget,
          reason: 'Notification title did not resolve for $localeCode.');
      expect(find.text(expected.notificationDailyReflectionBody), findsOneWidget,
          reason: 'Notification body did not resolve for $localeCode.');
      expect(resolvedDirection,
          (localeCode == 'ar' || localeCode == 'he')
              ? TextDirection.rtl
              : TextDirection.ltr,
          reason: 'Incorrect text direction for $localeCode.');
    }
  });

}
