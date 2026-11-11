import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr')
  ];

  /// Title of the general settings screen.
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get settingsGeneralTitle;

  /// Intro sentence on the general settings screen.
  ///
  /// In en, this message translates to:
  /// **'Application preferences and configuration.'**
  String get settingsGeneralDescription;

  /// Entry to the appearance settings, and heading of that screen.
  ///
  /// In en, this message translates to:
  /// **'Appearance Settings'**
  String get settingsAppearanceTitle;

  /// Subtitle of the appearance settings entry.
  ///
  /// In en, this message translates to:
  /// **'Customize the look and feel'**
  String get settingsAppearanceSubtitle;

  /// App bar title of the appearance settings screen.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceScreenTitle;

  /// Intro sentence on the appearance settings screen.
  ///
  /// In en, this message translates to:
  /// **'Customize the look and feel of the application.'**
  String get appearanceDescription;

  /// Label of the light/dark/system theme choice.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get appearanceThemeMode;

  /// Light theme option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Theme that follows the operating system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Label of the brand accent color row.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get appearanceAccentColor;

  /// No description provided for @commonBackToSettings.
  ///
  /// In en, this message translates to:
  /// **'Back to Settings'**
  String get commonBackToSettings;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @desktopSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Desktop Settings'**
  String get desktopSettingsTitle;

  /// No description provided for @desktopHeading.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get desktopHeading;

  /// No description provided for @desktopDescription.
  ///
  /// In en, this message translates to:
  /// **'Desktop-specific settings and file operations.'**
  String get desktopDescription;

  /// No description provided for @desktopFileOperations.
  ///
  /// In en, this message translates to:
  /// **'File Operations'**
  String get desktopFileOperations;

  /// No description provided for @desktopFileOperationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage file operations and permissions'**
  String get desktopFileOperationsSubtitle;

  /// No description provided for @desktopGuiAutomation.
  ///
  /// In en, this message translates to:
  /// **'GUI Automation'**
  String get desktopGuiAutomation;

  /// No description provided for @desktopGuiAutomationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure desktop automation'**
  String get desktopGuiAutomationSubtitle;

  /// No description provided for @llmProviderSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'LLM Provider Settings'**
  String get llmProviderSettingsTitle;

  /// No description provided for @llmProviderHermesDescription.
  ///
  /// In en, this message translates to:
  /// **'This application uses Hermes Agent as the primary runtime. Chat and related features go through your local Hermes install.'**
  String get llmProviderHermesDescription;

  /// No description provided for @llmProviderOpenConfig.
  ///
  /// In en, this message translates to:
  /// **'Open Config'**
  String get llmProviderOpenConfig;

  /// No description provided for @llmProviderSystemStatus.
  ///
  /// In en, this message translates to:
  /// **'System Status'**
  String get llmProviderSystemStatus;

  /// No description provided for @llmProviderPrimaryRuntime.
  ///
  /// In en, this message translates to:
  /// **'Primary agent runtime'**
  String get llmProviderPrimaryRuntime;

  /// No description provided for @llmProviderSupportProviders.
  ///
  /// In en, this message translates to:
  /// **'Support model providers'**
  String get llmProviderSupportProviders;

  /// No description provided for @llmProviderSupportProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional helpers such as Ollama or LM Studio'**
  String get llmProviderSupportProvidersSubtitle;

  /// No description provided for @visionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vision Settings'**
  String get visionSettingsTitle;

  /// No description provided for @visionServiceStatus.
  ///
  /// In en, this message translates to:
  /// **'Service Status'**
  String get visionServiceStatus;

  /// No description provided for @visionMainService.
  ///
  /// In en, this message translates to:
  /// **'Main Vision Service'**
  String get visionMainService;

  /// No description provided for @visionRegionCaptureService.
  ///
  /// In en, this message translates to:
  /// **'Region Capture Service'**
  String get visionRegionCaptureService;

  /// No description provided for @visionCameraCaptureService.
  ///
  /// In en, this message translates to:
  /// **'Camera Capture Service'**
  String get visionCameraCaptureService;

  /// No description provided for @visionOcrService.
  ///
  /// In en, this message translates to:
  /// **'OCR Engine Service'**
  String get visionOcrService;

  /// No description provided for @visionInitialized.
  ///
  /// In en, this message translates to:
  /// **'Initialized'**
  String get visionInitialized;

  /// No description provided for @visionNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Not initialized'**
  String get visionNotInitialized;

  /// No description provided for @visionCameraPreview.
  ///
  /// In en, this message translates to:
  /// **'Camera Preview'**
  String get visionCameraPreview;

  /// No description provided for @visionCameraPreviewNote.
  ///
  /// In en, this message translates to:
  /// **'Local-only preview (v4l2/ffmpeg). Frames are not saved or sent.'**
  String get visionCameraPreviewNote;

  /// No description provided for @visionTestResults.
  ///
  /// In en, this message translates to:
  /// **'Test Results'**
  String get visionTestResults;

  /// No description provided for @visionInitializeAll.
  ///
  /// In en, this message translates to:
  /// **'Initialize All Services'**
  String get visionInitializeAll;

  /// No description provided for @visionInitializing.
  ///
  /// In en, this message translates to:
  /// **'Initializing services...'**
  String get visionInitializing;

  /// No description provided for @visionInitComplete.
  ///
  /// In en, this message translates to:
  /// **'Initialization complete'**
  String get visionInitComplete;

  /// No description provided for @visionInitFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed: {error}'**
  String visionInitFailed(String error);

  /// No description provided for @visionResultInitialized.
  ///
  /// In en, this message translates to:
  /// **'✅ {service} initialized'**
  String visionResultInitialized(String service);

  /// No description provided for @visionResultError.
  ///
  /// In en, this message translates to:
  /// **'❌ {service}: {error}'**
  String visionResultError(String service, String error);

  /// No description provided for @visionLinuxCameraStarted.
  ///
  /// In en, this message translates to:
  /// **'✅ Linux camera capture started ({device})'**
  String visionLinuxCameraStarted(String device);

  /// No description provided for @visionLinuxCameraError.
  ///
  /// In en, this message translates to:
  /// **'❌ Linux camera: {error}'**
  String visionLinuxCameraError(String error);

  /// No description provided for @visionFatalError.
  ///
  /// In en, this message translates to:
  /// **'❌ Fatal error: {error}'**
  String visionFatalError(String error);

  /// No description provided for @meshTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Mesh'**
  String get meshTitle;

  /// No description provided for @meshRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke device?'**
  String get meshRevokeTitle;

  /// No description provided for @meshRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'Revoke {device}? The device will need to re-register to reconnect.'**
  String meshRevokeBody(String device);

  /// No description provided for @meshRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get meshRevoke;

  /// No description provided for @meshRevoked.
  ///
  /// In en, this message translates to:
  /// **'Device revoked'**
  String get meshRevoked;

  /// No description provided for @meshRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to revoke device'**
  String get meshRevokeFailed;

  /// No description provided for @meshThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get meshThisDevice;

  /// No description provided for @meshRegisteredDevices.
  ///
  /// In en, this message translates to:
  /// **'Registered devices'**
  String get meshRegisteredDevices;

  /// No description provided for @meshLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load devices'**
  String get meshLoadFailed;

  /// No description provided for @meshNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No other devices registered.'**
  String get meshNoDevices;

  /// No description provided for @meshStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected to cloud connector'**
  String get meshStatusConnected;

  /// No description provided for @meshStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get meshStatusConnecting;

  /// No description provided for @meshStatusError.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get meshStatusError;

  /// No description provided for @meshStatusDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get meshStatusDisconnected;

  /// No description provided for @meshUnknownPlatform.
  ///
  /// In en, this message translates to:
  /// **'unknown platform'**
  String get meshUnknownPlatform;

  /// No description provided for @meshNever.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get meshNever;

  /// No description provided for @meshOnline.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get meshOnline;

  /// No description provided for @meshLastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen {time}'**
  String meshLastSeen(String time);

  /// No description provided for @meshRuntimeAvailable.
  ///
  /// In en, this message translates to:
  /// **'runtime available'**
  String get meshRuntimeAvailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
