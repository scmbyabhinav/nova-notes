
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NovaLocalizations {
  NovaLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('pt'),
    Locale('ja'),
    Locale('ko'),
    Locale('ar'),
  ];

  static NovaLocalizations of(BuildContext context) =>
      Localizations.of<NovaLocalizations>(context, NovaLocalizations)!;

  String get appName => 'Orah';

  String get notes => _value('Notes', 'नोट्स');
  String get folders => _value('Folders', 'फ़ोल्डर');
  String get favorites => _value('Favorites', 'पसंदीदा');
  String get settings => _value('Settings', 'सेटिंग्स');

  String _value(String english, String hindi) {
    if (locale.languageCode == 'hi') return hindi;
    return english;
  }
}

class NovaLocalizationsDelegate
    extends LocalizationsDelegate<NovaLocalizations> {
  const NovaLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      NovaLocalizations.supportedLocales.any(
        (item) => item.languageCode == locale.languageCode,
      );

  @override
  Future<NovaLocalizations> load(Locale locale) =>
      SynchronousFuture<NovaLocalizations>(NovaLocalizations(locale));

  @override
  bool shouldReload(covariant NovaLocalizationsDelegate old) => false;
}
