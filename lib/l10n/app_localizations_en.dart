// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsGeneralTitle => 'General Settings';

  @override
  String get settingsGeneralDescription =>
      'Application preferences and configuration.';

  @override
  String get settingsAppearanceTitle => 'Appearance Settings';

  @override
  String get settingsAppearanceSubtitle => 'Customize the look and feel';

  @override
  String get appearanceScreenTitle => 'Appearance';

  @override
  String get appearanceDescription =>
      'Customize the look and feel of the application.';

  @override
  String get appearanceThemeMode => 'Theme Mode';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get appearanceAccentColor => 'Accent Color';
}
