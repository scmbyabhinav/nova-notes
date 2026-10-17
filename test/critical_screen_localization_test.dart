import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical utility screens do not regress to hard-coded UI copy', () {
    const screens = <String>[
      'lib/screens/trash_screen.dart',
      'lib/screens/security_settings_screen.dart',
      'lib/screens/vault_screen.dart',
      'lib/screens/privacy_pledge_screen.dart',
      'lib/screens/about_nova_screen.dart',
      'lib/screens/favorites_screen.dart',
      'lib/screens/archived_notes_screen.dart',
    ];
    final hardCodedText = RegExp(r'''Text\(\s*(?:const\s+)?['"]([^'"]{2,})['"]''');
    for (final path in screens) {
      final source = File(path).readAsStringSync();
      final matches = hardCodedText.allMatches(source).map((match) => match.group(1)!).where((value) =>
        value != 'Abhinav Bajpai' && value != 'vajpaiabhinav@gmail.com',
      ).toList();
      expect(matches, isEmpty, reason: '$path contains hard-coded UI text: $matches');
    }
  });
}