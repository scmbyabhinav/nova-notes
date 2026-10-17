import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical utility screens do not regress to hard-coded UI copy', () {
    const screens = <String>[
      'lib/app.dart',
      'lib/screens/about_nova_screen.dart',
      'lib/screens/android_features_screen.dart',
      'lib/screens/archived_notes_screen.dart',
      'lib/screens/calendar_history_screen.dart',
      'lib/screens/calendar_screen.dart',
      'lib/screens/export_note_sheet.dart',
      'lib/screens/favorites_screen.dart',
      'lib/screens/folders_screen.dart',
      'lib/screens/home_screen.dart',
      'lib/screens/note_editor_screen.dart',
      'lib/screens/orah_pro_screen.dart',
      'lib/screens/orah_registration_screen.dart',
      'lib/screens/organization_picker_screen.dart',
      'lib/screens/privacy_pledge_screen.dart',
      'lib/screens/reflection_prompt_screen.dart',
      'lib/screens/search_screen.dart',
      'lib/screens/security_settings_screen.dart',
      'lib/screens/settings_screen.dart',
      'lib/screens/statistics_screen.dart',
      'lib/screens/trash_screen.dart',
      'lib/screens/vault_screen.dart',
      'lib/screens/welcome_splash_screen.dart',
    ];
    final hardCodedText = RegExp(r'''(?:Text|SelectableText)\(\s*(?:const\s+)?['"]([^'"]{2,})['"]''');
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      final matches = hardCodedText.allMatches(source)
          .map((match) => match.group(1)!)
          .where((value) {
            if (value.contains(String.fromCharCode(36))) return false;
            return value.toLowerCase() != 'orah' &&
                value.toLowerCase() != 'orah pro' &&
                value != 'Abhinav Bajpai' &&
                value != 'vajpaiabhinav@gmail.com';
          })
          .toList();
      expect(matches, isEmpty, reason: '$path contains hard-coded UI text: $matches');

      final hardCodedAttributes = RegExp(
        r'''(?:tooltip|message|hintText|labelText|helpText|semanticsLabel|label)\s*:\s*(['"])([^'"]{2,})\1''',
      ).allMatches(source).map((match) => match.group(2)!).where((value) =>
        !value.contains(String.fromCharCode(36)) &&
        value.toLowerCase() != 'orah' &&
        value.toLowerCase() != 'orah pro'
      ).toList();
      expect(hardCodedAttributes, isEmpty,
          reason: '$path contains hard-coded tooltip/label copy: $hardCodedAttributes');

      final hardCodedSpans = RegExp(
        r'''TextSpan\(\s*text:\s*(['"])([^'"]{2,})\1''',
      ).allMatches(source).map((match) => match.group(2)!).where((value) =>
        !value.contains(String.fromCharCode(36)) &&
        value.toLowerCase() != 'orah' &&
        value.toLowerCase() != 'orah pro'
      ).toList();
      expect(hardCodedSpans, isEmpty,
          reason: '$path contains hard-coded rich-text copy: $hardCodedSpans');
    }
  });
}
