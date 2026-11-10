import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';

import 'brand.dart';
import 'brand_config.dart';

/// App strings plus Material, Widgets, and Cupertino localizations for a
/// locked brand locale.
const List<LocalizationsDelegate<dynamic>> brandLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Locales a locked brand can resolve. French and English are always included
/// so a French lock does not crash Material widgets, and English remains available.
List<Locale> lockedBrandLocales(BrandConfig brand) {
  final locked = brand.materialLocale ?? const Locale('en');
  final locales = <Locale>[
    locked,
    const Locale('fr'),
    const Locale('en'),
    const Locale('en', 'US'),
  ];
  final seen = <String>{};
  return <Locale>[
    for (final locale in locales)
      if (seen.add('${locale.languageCode}_${locale.countryCode ?? ''}'))
        locale,
  ];
}
