import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every ARB locale has the same keys as English', () {
    final directory = Directory('lib/l10n');
    final englishFile = File('${directory.path}/app_en.arb');
    final english = jsonDecode(englishFile.readAsStringSync()) as Map<String, dynamic>;
    final expectedKeys = english.keys.where((key) => !key.startsWith('@')).toSet();

    final arbFiles = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(arbFiles, isNotEmpty);

    for (final file in arbFiles) {
      final localeCode = file.uri.pathSegments.last
          .replaceFirst('app_', '')
          .replaceFirst('.arb', '');
      final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final declaredLocale = decoded['@@locale'];

      expect(
        declaredLocale,
        localeCode,
        reason: '${file.path} must declare its locale with @@locale.',
      );

      final actualKeys = decoded.keys
          .where((key) => !key.startsWith('@'))
          .toSet();
      expect(
        actualKeys,
        expectedKeys,
        reason: '${file.path} must contain every English localization key.',
      );
    }
  });
}
