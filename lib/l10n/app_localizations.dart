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

  /// No description provided for @commonConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get commonConnected;

  /// No description provided for @commonDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get commonDisconnected;

  /// No description provided for @connectionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Settings'**
  String get connectionSettingsTitle;

  /// No description provided for @connectionHeading.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionHeading;

  /// No description provided for @connectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage tunnel and daemon connections.'**
  String get connectionDescription;

  /// No description provided for @connectionDaemonSettings.
  ///
  /// In en, this message translates to:
  /// **'Daemon Settings'**
  String get connectionDaemonSettings;

  /// No description provided for @connectionDaemonSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure system tray daemon'**
  String get connectionDaemonSubtitle;

  /// No description provided for @connectionDeviceMeshSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Registered devices and cloud presence'**
  String get connectionDeviceMeshSubtitle;

  /// No description provided for @connectionStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection Status'**
  String get connectionStatusTitle;

  /// No description provided for @connectionStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View current connection status'**
  String get connectionStatusSubtitle;

  /// No description provided for @connectionRerunWizard.
  ///
  /// In en, this message translates to:
  /// **'Re-run Setup Wizard'**
  String get connectionRerunWizard;

  /// No description provided for @connectionRerunWizardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure gateway connection again'**
  String get connectionRerunWizardSubtitle;

  /// No description provided for @connectionRerunWizardBody.
  ///
  /// In en, this message translates to:
  /// **'This will clear your saved setup configuration and restart the setup wizard. You will need to reconfigure your gateway connection.\n\nContinue?'**
  String get connectionRerunWizardBody;

  /// No description provided for @connectionClearAndRerun.
  ///
  /// In en, this message translates to:
  /// **'Clear & Re-run'**
  String get connectionClearAndRerun;

  /// No description provided for @connectionClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear setup data: {error}'**
  String connectionClearFailed(String error);

  /// No description provided for @daemonSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Tray Daemon Settings'**
  String get daemonSettingsTitle;

  /// No description provided for @daemonHeading.
  ///
  /// In en, this message translates to:
  /// **'System Tray Configuration'**
  String get daemonHeading;

  /// No description provided for @daemonDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the system tray daemon behavior and appearance'**
  String get daemonDescription;

  /// No description provided for @daemonSaved.
  ///
  /// In en, this message translates to:
  /// **'Daemon settings saved successfully'**
  String get daemonSaved;

  /// No description provided for @daemonSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings: {error}'**
  String daemonSaveFailed(String error);

  /// No description provided for @daemonRestarting.
  ///
  /// In en, this message translates to:
  /// **'Restarting system tray daemon...'**
  String get daemonRestarting;

  /// No description provided for @daemonRestarted.
  ///
  /// In en, this message translates to:
  /// **'System tray daemon restarted successfully'**
  String get daemonRestarted;

  /// No description provided for @daemonRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restart daemon: {error}'**
  String daemonRestartFailed(String error);

  /// No description provided for @daemonRealtimeStatus.
  ///
  /// In en, this message translates to:
  /// **'Real-time Connection Status'**
  String get daemonRealtimeStatus;

  /// No description provided for @daemonConnectionType.
  ///
  /// In en, this message translates to:
  /// **'Connection Type'**
  String get daemonConnectionType;

  /// No description provided for @daemonVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get daemonVersion;

  /// No description provided for @daemonAvailableModels.
  ///
  /// In en, this message translates to:
  /// **'Available Models'**
  String get daemonAvailableModels;

  /// No description provided for @daemonModelCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 model} other{{count} models}}'**
  String daemonModelCount(int count);

  /// No description provided for @daemonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get daemonError;

  /// No description provided for @daemonLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {time}'**
  String daemonLastUpdated(String time);

  /// No description provided for @daemonLoadingStatus.
  ///
  /// In en, this message translates to:
  /// **'Loading connection status...'**
  String get daemonLoadingStatus;

  /// No description provided for @daemonEnableTray.
  ///
  /// In en, this message translates to:
  /// **'Enable System Tray'**
  String get daemonEnableTray;

  /// No description provided for @daemonStartMinimized.
  ///
  /// In en, this message translates to:
  /// **'Start Minimized'**
  String get daemonStartMinimized;

  /// No description provided for @daemonStartMinimizedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start application minimized to system tray'**
  String get daemonStartMinimizedSubtitle;

  /// No description provided for @daemonEnableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable Notifications'**
  String get daemonEnableNotifications;

  /// No description provided for @daemonEnableNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show system notifications for important events'**
  String get daemonEnableNotificationsSubtitle;

  /// No description provided for @daemonAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Auto-start Daemon'**
  String get daemonAutoStart;

  /// No description provided for @daemonAutoStartSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically start tray daemon with system'**
  String get daemonAutoStartSubtitle;

  /// No description provided for @daemonTrayIconTheme.
  ///
  /// In en, this message translates to:
  /// **'Tray Icon Theme'**
  String get daemonTrayIconTheme;

  /// No description provided for @daemonTrayIconThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose icon style for system tray'**
  String get daemonTrayIconThemeSubtitle;

  /// No description provided for @themeMonochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get themeMonochrome;

  /// No description provided for @daemonConnectionTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection Timeout'**
  String get daemonConnectionTimeout;

  /// No description provided for @daemonConnectionTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Timeout for daemon connections (seconds)'**
  String get daemonConnectionTimeoutSubtitle;

  /// No description provided for @daemonHealthCheckInterval.
  ///
  /// In en, this message translates to:
  /// **'Health Check Interval'**
  String get daemonHealthCheckInterval;

  /// No description provided for @daemonHealthCheckIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Interval for daemon health checks (seconds)'**
  String get daemonHealthCheckIntervalSubtitle;

  /// No description provided for @daemonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get daemonActions;

  /// No description provided for @daemonSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get daemonSaveSettings;

  /// No description provided for @daemonRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart Daemon'**
  String get daemonRestart;

  /// No description provided for @commonRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonErrorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonErrorDetails(String error);

  /// No description provided for @nodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nodes'**
  String get nodesTitle;

  /// No description provided for @nodesAgentRuntimes.
  ///
  /// In en, this message translates to:
  /// **'Agent Runtimes'**
  String get nodesAgentRuntimes;

  /// No description provided for @nodesNoAgentRuntimes.
  ///
  /// In en, this message translates to:
  /// **'No agent runtimes discovered'**
  String get nodesNoAgentRuntimes;

  /// No description provided for @nodesSupportProviders.
  ///
  /// In en, this message translates to:
  /// **'Support Providers'**
  String get nodesSupportProviders;

  /// No description provided for @nodesNoSupportProviders.
  ///
  /// In en, this message translates to:
  /// **'No support providers discovered'**
  String get nodesNoSupportProviders;

  /// No description provided for @nodesTailscaleDevices.
  ///
  /// In en, this message translates to:
  /// **'Tailscale Devices'**
  String get nodesTailscaleDevices;

  /// No description provided for @nodesNoTailscaleDevices.
  ///
  /// In en, this message translates to:
  /// **'No Tailscale devices discovered'**
  String get nodesNoTailscaleDevices;

  /// No description provided for @nodesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load discovery data: {error}'**
  String nodesLoadError(String error);

  /// No description provided for @nodesSelectedRuntime.
  ///
  /// In en, this message translates to:
  /// **'Agent runtime: {name} ({version})'**
  String nodesSelectedRuntime(String name, String version);

  /// No description provided for @nodesVersionUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get nodesVersionUnknown;

  /// No description provided for @nodesNoRuntimeSelected.
  ///
  /// In en, this message translates to:
  /// **'No agent runtime selected'**
  String get nodesNoRuntimeSelected;

  /// No description provided for @channelDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel Details'**
  String get channelDetailsTitle;

  /// No description provided for @channelNotFound.
  ///
  /// In en, this message translates to:
  /// **'Channel not found'**
  String get channelNotFound;

  /// No description provided for @channelBadgeNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get channelBadgeNew;

  /// No description provided for @channelBadgeRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get channelBadgeRead;

  /// No description provided for @channelStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get channelStatistics;

  /// No description provided for @channelMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get channelMessages;

  /// No description provided for @channelPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get channelPlatform;

  /// No description provided for @channelPlatformUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get channelPlatformUnknown;

  /// No description provided for @channelLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last Activity'**
  String get channelLastActivity;

  /// No description provided for @channelNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get channelNever;

  /// No description provided for @channelControls.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get channelControls;

  /// No description provided for @channelStart.
  ///
  /// In en, this message translates to:
  /// **'Start Channel'**
  String get channelStart;

  /// No description provided for @channelStop.
  ///
  /// In en, this message translates to:
  /// **'Stop Channel'**
  String get channelStop;

  /// No description provided for @channelReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get channelReconnect;

  /// No description provided for @channelViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get channelViewLogs;

  /// No description provided for @channelActionPerformed.
  ///
  /// In en, this message translates to:
  /// **'Action {action} performed for channel {channelId}'**
  String channelActionPerformed(String action, String channelId);

  /// No description provided for @channelJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get channelJustNow;

  /// No description provided for @channelMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String channelMinutesAgo(int minutes);

  /// No description provided for @channelHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String channelHoursAgo(int hours);

  /// No description provided for @channelDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String channelDaysAgo(int days);

  /// No description provided for @usageTitle.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usageTitle;

  /// No description provided for @usageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get usageToday;

  /// No description provided for @usageWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get usageWeek;

  /// No description provided for @usageMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get usageMonth;

  /// No description provided for @usageActiveConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Active Concurrency'**
  String get usageActiveConcurrency;

  /// No description provided for @usageOfLimit.
  ///
  /// In en, this message translates to:
  /// **'of {limit}'**
  String usageOfLimit(int limit);

  /// No description provided for @usageConcurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Concurrent requests in flight'**
  String get usageConcurrencySubtitle;

  /// No description provided for @usageConcurrencyUtilization.
  ///
  /// In en, this message translates to:
  /// **'Concurrency utilization'**
  String get usageConcurrencyUtilization;

  /// No description provided for @usageRequestRate.
  ///
  /// In en, this message translates to:
  /// **'Request Rate'**
  String get usageRequestRate;

  /// No description provided for @usageRequestsPerMinuteUnit.
  ///
  /// In en, this message translates to:
  /// **'req/min'**
  String get usageRequestsPerMinuteUnit;

  /// No description provided for @usageRequestRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests per minute across models'**
  String get usageRequestRateSubtitle;

  /// No description provided for @usageRpmUtilization.
  ///
  /// In en, this message translates to:
  /// **'RPM utilization'**
  String get usageRpmUtilization;

  /// No description provided for @usageTokenRate.
  ///
  /// In en, this message translates to:
  /// **'Token Rate'**
  String get usageTokenRate;

  /// No description provided for @usageTokensPerMinuteUnit.
  ///
  /// In en, this message translates to:
  /// **'tok/min'**
  String get usageTokensPerMinuteUnit;

  /// No description provided for @usageTokenRateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tokens per minute across models'**
  String get usageTokenRateSubtitle;

  /// No description provided for @usageTpmUtilization.
  ///
  /// In en, this message translates to:
  /// **'TPM utilization'**
  String get usageTpmUtilization;

  /// No description provided for @usageChartTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Token Usage Over Time'**
  String get usageChartTokenUsage;

  /// No description provided for @usageChartRequestVolume.
  ///
  /// In en, this message translates to:
  /// **'Request Volume'**
  String get usageChartRequestVolume;

  /// No description provided for @usageChartResourceTrends.
  ///
  /// In en, this message translates to:
  /// **'Resource Trends'**
  String get usageChartResourceTrends;

  /// No description provided for @usageChartPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Chart placeholder'**
  String get usageChartPlaceholder;

  /// No description provided for @usageNoActiveModels.
  ///
  /// In en, this message translates to:
  /// **'No active models'**
  String get usageNoActiveModels;

  /// No description provided for @usagePerModelConcurrency.
  ///
  /// In en, this message translates to:
  /// **'Per-model concurrency'**
  String get usagePerModelConcurrency;

  /// No description provided for @usageNoRateData.
  ///
  /// In en, this message translates to:
  /// **'No rate data'**
  String get usageNoRateData;

  /// No description provided for @usageTopModelsByRpm.
  ///
  /// In en, this message translates to:
  /// **'Top models by RPM'**
  String get usageTopModelsByRpm;

  /// No description provided for @usageNoTokenData.
  ///
  /// In en, this message translates to:
  /// **'No token data'**
  String get usageNoTokenData;

  /// No description provided for @usageTopModelsByTpm.
  ///
  /// In en, this message translates to:
  /// **'Top models by TPM'**
  String get usageTopModelsByTpm;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsExport.
  ///
  /// In en, this message translates to:
  /// **'Export Logs'**
  String get logsExport;

  /// No description provided for @logsServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Log service unavailable'**
  String get logsServiceUnavailable;

  /// No description provided for @logsExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Logs exported to {path}'**
  String logsExportedTo(String path);

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied to clipboard'**
  String get logsCopied;

  /// No description provided for @logsNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No logs found'**
  String get logsNoneFound;

  /// No description provided for @logsAdjustFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters'**
  String get logsAdjustFilters;

  /// No description provided for @logsNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No logs available'**
  String get logsNoneAvailable;

  /// No description provided for @logsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search logs...'**
  String get logsSearchHint;

  /// No description provided for @logsSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get logsSeverity;

  /// No description provided for @logsSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get logsSource;

  /// No description provided for @logsClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get logsClearAll;

  /// No description provided for @logsViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get logsViewDetails;

  /// No description provided for @logsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Details'**
  String get logsDetailsTitle;

  /// No description provided for @logsTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get logsTimestamp;

  /// No description provided for @logsMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get logsMessage;

  /// No description provided for @logsError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get logsError;

  /// No description provided for @logsStackTrace.
  ///
  /// In en, this message translates to:
  /// **'Stack Trace'**
  String get logsStackTrace;

  /// No description provided for @logsFilterBySource.
  ///
  /// In en, this message translates to:
  /// **'Filter by Source'**
  String get logsFilterBySource;

  /// No description provided for @logsDetailLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}:'**
  String logsDetailLabel(String label);

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get commonUnknownError;

  /// No description provided for @commonFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}:'**
  String commonFieldLabel(String label);

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @commonActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActions;

  /// No description provided for @commonName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// No description provided for @commonType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commonType;

  /// No description provided for @commonMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get commonMessages;

  /// No description provided for @commonNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get commonNever;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeSecondsAgo.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s ago'**
  String timeSecondsAgo(int seconds);

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String timeDaysAgo(int days);

  /// No description provided for @agentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get agentsTitle;

  /// No description provided for @agentsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Agent'**
  String get agentsAdd;

  /// No description provided for @agentsTabRegistry.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get agentsTabRegistry;

  /// No description provided for @agentsTabMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get agentsTabMonitor;

  /// No description provided for @agentsTabConfig.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get agentsTabConfig;

  /// No description provided for @agentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Agents Registered'**
  String get agentsEmptyTitle;

  /// No description provided for @agentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Agents will appear here when registered'**
  String get agentsEmptyMessage;

  /// No description provided for @agentsNoTask.
  ///
  /// In en, this message translates to:
  /// **'No task assigned'**
  String get agentsNoTask;

  /// No description provided for @agentsActivityCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed: {task}'**
  String agentsActivityCompleted(String task);

  /// No description provided for @agentsActivityFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String agentsActivityFailed(String error);

  /// No description provided for @agentsActivityStarted.
  ///
  /// In en, this message translates to:
  /// **'Started: {task}'**
  String agentsActivityStarted(String task);

  /// No description provided for @agentsActivityTaskFallback.
  ///
  /// In en, this message translates to:
  /// **'task'**
  String get agentsActivityTaskFallback;

  /// No description provided for @agentsActivityErrorFallback.
  ///
  /// In en, this message translates to:
  /// **'unknown error'**
  String get agentsActivityErrorFallback;

  /// No description provided for @agentsRegistryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Agent registry is unavailable until the API backend is connected'**
  String get agentsRegistryUnavailable;

  /// No description provided for @agentsRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to register agent'**
  String get agentsRegisterFailed;

  /// No description provided for @agentsRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered {name}'**
  String agentsRegistered(String name);

  /// No description provided for @agentsEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {name}'**
  String agentsEditTitle(String name);

  /// No description provided for @agentsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update {name}'**
  String agentsUpdateFailed(String name);

  /// No description provided for @agentsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {name}'**
  String agentsUpdated(String name);

  /// No description provided for @agentsRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove {name}'**
  String agentsRemoveFailed(String name);

  /// No description provided for @agentsRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String agentsRemoved(String name);

  /// No description provided for @agentsStatTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get agentsStatTasks;

  /// No description provided for @agentsStatAvgLatency.
  ///
  /// In en, this message translates to:
  /// **'Avg Latency'**
  String get agentsStatAvgLatency;

  /// No description provided for @agentsStatLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last Active'**
  String get agentsStatLastActive;

  /// No description provided for @agentsStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'ONLINE'**
  String get agentsStatusOnline;

  /// No description provided for @agentsStatusBusy.
  ///
  /// In en, this message translates to:
  /// **'BUSY'**
  String get agentsStatusBusy;

  /// No description provided for @agentsStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'OFFLINE'**
  String get agentsStatusOffline;

  /// No description provided for @agentsStatusError.
  ///
  /// In en, this message translates to:
  /// **'ERROR'**
  String get agentsStatusError;

  /// No description provided for @agentsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total Agents'**
  String get agentsTotal;

  /// No description provided for @agentsTasksToday.
  ///
  /// In en, this message translates to:
  /// **'Tasks Today'**
  String get agentsTasksToday;

  /// No description provided for @agentsErrors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get agentsErrors;

  /// No description provided for @agentsNoActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'No Recent Activity'**
  String get agentsNoActivityTitle;

  /// No description provided for @agentsNoActivityMessage.
  ///
  /// In en, this message translates to:
  /// **'Agent activity will appear here'**
  String get agentsNoActivityMessage;

  /// No description provided for @agentsPoolSettings.
  ///
  /// In en, this message translates to:
  /// **'Agent Pool Settings'**
  String get agentsPoolSettings;

  /// No description provided for @agentsAutoScale.
  ///
  /// In en, this message translates to:
  /// **'Auto-scale agents'**
  String get agentsAutoScale;

  /// No description provided for @agentsAutoScaleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically add agents based on load'**
  String get agentsAutoScaleSubtitle;

  /// No description provided for @agentsMin.
  ///
  /// In en, this message translates to:
  /// **'Min agents'**
  String get agentsMin;

  /// No description provided for @agentsMinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Minimum number of active agents'**
  String get agentsMinSubtitle;

  /// No description provided for @agentsMax.
  ///
  /// In en, this message translates to:
  /// **'Max agents'**
  String get agentsMax;

  /// No description provided for @agentsMaxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of concurrent agents'**
  String get agentsMaxSubtitle;

  /// No description provided for @agentsTimeoutSettings.
  ///
  /// In en, this message translates to:
  /// **'Timeout Settings'**
  String get agentsTimeoutSettings;

  /// No description provided for @agentsRequestTimeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout'**
  String get agentsRequestTimeout;

  /// No description provided for @agentsRequestTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum time to wait for agent response'**
  String get agentsRequestTimeoutSubtitle;

  /// No description provided for @agentsQueueTimeout.
  ///
  /// In en, this message translates to:
  /// **'Queue timeout'**
  String get agentsQueueTimeout;

  /// No description provided for @agentsQueueTimeoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum time in queue before rejection'**
  String get agentsQueueTimeoutSubtitle;

  /// No description provided for @agentsPause.
  ///
  /// In en, this message translates to:
  /// **'Pause Agent'**
  String get agentsPause;

  /// No description provided for @agentsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume Agent'**
  String get agentsResume;

  /// No description provided for @agentsRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart Agent'**
  String get agentsRestart;

  /// No description provided for @agentsEditConfig.
  ///
  /// In en, this message translates to:
  /// **'Edit Configuration'**
  String get agentsEditConfig;

  /// No description provided for @agentsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Agent'**
  String get agentsRemove;

  /// No description provided for @agentsRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove {name}?'**
  String agentsRemoveConfirm(String name);

  /// No description provided for @agentsRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Agent'**
  String get agentsRegisterTitle;

  /// No description provided for @agentsRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get agentsRegister;

  /// No description provided for @agentsIdsRequired.
  ///
  /// In en, this message translates to:
  /// **'Subagent ID and parent agent ID are required'**
  String get agentsIdsRequired;

  /// No description provided for @agentsSubagentId.
  ///
  /// In en, this message translates to:
  /// **'Subagent ID'**
  String get agentsSubagentId;

  /// No description provided for @agentsParentId.
  ///
  /// In en, this message translates to:
  /// **'Parent Agent ID'**
  String get agentsParentId;

  /// No description provided for @agentsDisplayLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Label'**
  String get agentsDisplayLabel;

  /// No description provided for @agentsTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get agentsTaskDescription;

  /// No description provided for @agentDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Details'**
  String get agentDetailTitle;

  /// No description provided for @agentDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Agent not found'**
  String get agentDetailNotFound;

  /// No description provided for @agentDetailIdValue.
  ///
  /// In en, this message translates to:
  /// **'ID: {id}'**
  String agentDetailIdValue(String id);

  /// No description provided for @agentDetailActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get agentDetailActivity;

  /// No description provided for @agentDetailLastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last Update'**
  String get agentDetailLastUpdate;

  /// No description provided for @agentDetailStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get agentDetailStart;

  /// No description provided for @agentDetailStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get agentDetailStop;

  /// No description provided for @agentDetailRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get agentDetailRestart;

  /// No description provided for @agentDetailInformation.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get agentDetailInformation;

  /// No description provided for @agentDetailId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get agentDetailId;

  /// No description provided for @agentStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get agentStateIdle;

  /// No description provided for @agentStateStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting...'**
  String get agentStateStarting;

  /// No description provided for @agentStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get agentStateRunning;

  /// No description provided for @agentStateStopping.
  ///
  /// In en, this message translates to:
  /// **'Stopping...'**
  String get agentStateStopping;

  /// No description provided for @agentStateError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get agentStateError;

  /// No description provided for @agentStateOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get agentStateOffline;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTitle;

  /// No description provided for @sessionsTabWebSocket.
  ///
  /// In en, this message translates to:
  /// **'WebSocket'**
  String get sessionsTabWebSocket;

  /// No description provided for @sessionsTabConversations.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get sessionsTabConversations;

  /// No description provided for @sessionsTabUsers.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get sessionsTabUsers;

  /// No description provided for @sessionsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh sessions'**
  String get sessionsRefresh;

  /// No description provided for @sessionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Sessions'**
  String get sessionsEmptyTitle;

  /// No description provided for @sessionsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No active sessions for this category.'**
  String get sessionsEmptyMessage;

  /// No description provided for @sessionsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Details'**
  String get sessionsDetailsTitle;

  /// No description provided for @sessionsId.
  ///
  /// In en, this message translates to:
  /// **'Session ID'**
  String get sessionsId;

  /// No description provided for @sessionsUserOrAgent.
  ///
  /// In en, this message translates to:
  /// **'User/Agent'**
  String get sessionsUserOrAgent;

  /// No description provided for @sessionsStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get sessionsStarted;

  /// No description provided for @sessionsDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sessionsDuration;

  /// No description provided for @sessionsTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get sessionsTokens;

  /// No description provided for @sessionsDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String sessionsDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @sessionsDurationMinutesSeconds.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m {seconds}s'**
  String sessionsDurationMinutesSeconds(int minutes, int seconds);

  /// No description provided for @sessionsDurationSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String sessionsDurationSeconds(int seconds);

  /// No description provided for @sessionsTerminateTitle.
  ///
  /// In en, this message translates to:
  /// **'Terminate Session'**
  String get sessionsTerminateTitle;

  /// No description provided for @sessionsTerminateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to terminate session {id}?\n\nThis will disconnect {who} and cannot be undone.'**
  String sessionsTerminateConfirm(String id, String who);

  /// No description provided for @sessionsServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Session service unavailable'**
  String get sessionsServiceUnavailable;

  /// No description provided for @sessionsTerminated.
  ///
  /// In en, this message translates to:
  /// **'Session {id} terminated'**
  String sessionsTerminated(String id);

  /// No description provided for @sessionsTerminateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to terminate session {id}'**
  String sessionsTerminateFailed(String id);

  /// No description provided for @sessionsTerminate.
  ///
  /// In en, this message translates to:
  /// **'Terminate'**
  String get sessionsTerminate;

  /// No description provided for @sessionsViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get sessionsViewDetails;

  /// No description provided for @sessionsTerminateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Terminate session'**
  String get sessionsTerminateTooltip;

  /// No description provided for @channelsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelsTitle;

  /// No description provided for @channelsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh channels'**
  String get channelsRefresh;

  /// No description provided for @channelsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load channels: {error}'**
  String channelsLoadError(String error);

  /// No description provided for @channelsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Channels'**
  String get channelsEmptyTitle;

  /// No description provided for @channelsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No communication channels are currently available.'**
  String get channelsEmptyMessage;

  /// No description provided for @channelsMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}'**
  String channelsMessageCount(int count);

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeNoAgentTitle.
  ///
  /// In en, this message translates to:
  /// **'No Agent Connected'**
  String get homeNoAgentTitle;

  /// No description provided for @homeNoAgentBanner.
  ///
  /// In en, this message translates to:
  /// **'Configure an agent runtime in Settings to enable AI responses and desktop control.'**
  String get homeNoAgentBanner;

  /// No description provided for @homeStatusConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get homeStatusConfigured;

  /// No description provided for @homeStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get homeStatusOffline;

  /// No description provided for @homeNoAgentStandalone.
  ///
  /// In en, this message translates to:
  /// **'Configure an agent runtime in Settings to get started, or use the avatar and local features while offline.'**
  String get homeNoAgentStandalone;

  /// No description provided for @homeOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get homeOpenSettings;

  /// No description provided for @homeConfigureManually.
  ///
  /// In en, this message translates to:
  /// **'Configure connection manually'**
  String get homeConfigureManually;

  /// No description provided for @homeMessagePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Message {name}...'**
  String homeMessagePlaceholder(String name);

  /// No description provided for @homePillarAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get homePillarAvatar;

  /// No description provided for @homePillarTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get homePillarTools;

  /// No description provided for @homePillarMood.
  ///
  /// In en, this message translates to:
  /// **'Mood'**
  String get homePillarMood;

  /// No description provided for @homeMoodTitle.
  ///
  /// In en, this message translates to:
  /// **'{possessive} Mood'**
  String homeMoodTitle(String possessive, String name);

  /// No description provided for @homeMoodNotReady.
  ///
  /// In en, this message translates to:
  /// **'Personality engine not ready yet.'**
  String get homeMoodNotReady;

  /// No description provided for @homeMoodAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent: {name}'**
  String homeMoodAgent(String name);

  /// No description provided for @homeTraitFormality.
  ///
  /// In en, this message translates to:
  /// **'Formality'**
  String get homeTraitFormality;

  /// No description provided for @homeTraitHumor.
  ///
  /// In en, this message translates to:
  /// **'Humor'**
  String get homeTraitHumor;

  /// No description provided for @homeTraitEnthusiasm.
  ///
  /// In en, this message translates to:
  /// **'Enthusiasm'**
  String get homeTraitEnthusiasm;

  /// No description provided for @homeTraitEmpathy.
  ///
  /// In en, this message translates to:
  /// **'Empathy'**
  String get homeTraitEmpathy;

  /// No description provided for @homeMoodEvolution.
  ///
  /// In en, this message translates to:
  /// **'Evolution: {stage}'**
  String homeMoodEvolution(String stage);

  /// No description provided for @homeToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'What {name} Can Do'**
  String homeToolsTitle(String name);

  /// No description provided for @homeToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Available offline • Connect to unlock more'**
  String get homeToolsSubtitle;

  /// No description provided for @homeToolDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop Control'**
  String get homeToolDesktop;

  /// No description provided for @homeToolDesktopDescription.
  ///
  /// In en, this message translates to:
  /// **'Click, type, scroll, drag on your PC'**
  String get homeToolDesktopDescription;

  /// No description provided for @homeToolVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get homeToolVision;

  /// No description provided for @homeToolVisionDescription.
  ///
  /// In en, this message translates to:
  /// **'See and analyze your screen'**
  String get homeToolVisionDescription;

  /// No description provided for @homeToolVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get homeToolVoice;

  /// No description provided for @homeToolVoiceDescription.
  ///
  /// In en, this message translates to:
  /// **'Speak and listen'**
  String get homeToolVoiceDescription;

  /// No description provided for @homeToolWebSearch.
  ///
  /// In en, this message translates to:
  /// **'Web Search'**
  String get homeToolWebSearch;

  /// No description provided for @homeToolWebSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'Search and extract web content'**
  String get homeToolWebSearchDescription;

  /// No description provided for @homeToolRequiresAgent.
  ///
  /// In en, this message translates to:
  /// **'Requires agent connection'**
  String get homeToolRequiresAgent;

  /// No description provided for @homeToolCode.
  ///
  /// In en, this message translates to:
  /// **'Code Execution'**
  String get homeToolCode;

  /// No description provided for @homeToolCodeDescription.
  ///
  /// In en, this message translates to:
  /// **'Run Python, shell, and Dart scripts'**
  String get homeToolCodeDescription;

  /// No description provided for @homeToolLocal.
  ///
  /// In en, this message translates to:
  /// **'local'**
  String get homeToolLocal;

  /// No description provided for @homeToolCloud.
  ///
  /// In en, this message translates to:
  /// **'cloud'**
  String get homeToolCloud;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your agent companion.\nFully offline until you choose to connect.'**
  String get welcomeSubtitle;

  /// No description provided for @welcomeHint.
  ///
  /// In en, this message translates to:
  /// **'Type a message below or tap /new to start fresh. Connect an agent runtime in Settings for AI responses and agent features.'**
  String get welcomeHint;

  /// No description provided for @messageInputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get messageInputPlaceholder;

  /// No description provided for @messageInputNewChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get messageInputNewChat;

  /// No description provided for @messageInputNoModels.
  ///
  /// In en, this message translates to:
  /// **'No models available'**
  String get messageInputNoModels;

  /// No description provided for @messageInputSelectModel.
  ///
  /// In en, this message translates to:
  /// **'Select model'**
  String get messageInputSelectModel;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get messageCopied;

  /// No description provided for @commonStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// No description provided for @commonRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get commonRestart;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get commonDisable;

  /// No description provided for @commonDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// No description provided for @commonCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategory;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @cronTitle.
  ///
  /// In en, this message translates to:
  /// **'Cron Jobs'**
  String get cronTitle;

  /// No description provided for @cronAddJob.
  ///
  /// In en, this message translates to:
  /// **'Add Job'**
  String get cronAddJob;

  /// No description provided for @cronEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Cron Jobs'**
  String get cronEmptyTitle;

  /// No description provided for @cronEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Create scheduled tasks to automate maintenance'**
  String get cronEmptyMessage;

  /// No description provided for @cronTriggered.
  ///
  /// In en, this message translates to:
  /// **'Triggered: {name}'**
  String cronTriggered(String name);

  /// No description provided for @cronDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Scheduled Job'**
  String get cronDeleteTitle;

  /// No description provided for @cronDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This action cannot be undone.'**
  String cronDeleteConfirm(String name);

  /// No description provided for @cronDeleted.
  ///
  /// In en, this message translates to:
  /// **'Job deleted successfully'**
  String get cronDeleted;

  /// No description provided for @cronDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete job'**
  String get cronDeleteFailed;

  /// No description provided for @cronEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Scheduled Job'**
  String get cronEditTitle;

  /// No description provided for @cronCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Scheduled Job'**
  String get cronCreateTitle;

  /// No description provided for @cronJobName.
  ///
  /// In en, this message translates to:
  /// **'Job Name'**
  String get cronJobName;

  /// No description provided for @cronJobNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Daily Briefing'**
  String get cronJobNameHint;

  /// No description provided for @cronJobNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a job name'**
  String get cronJobNameRequired;

  /// No description provided for @cronSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule Expression / Interval'**
  String get cronSchedule;

  /// No description provided for @cronScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 30m, every 2h, or 0 9 * * *'**
  String get cronScheduleHint;

  /// No description provided for @cronScheduleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a schedule'**
  String get cronScheduleRequired;

  /// No description provided for @cronExecutionMode.
  ///
  /// In en, this message translates to:
  /// **'Execution Mode'**
  String get cronExecutionMode;

  /// No description provided for @cronModeAgent.
  ///
  /// In en, this message translates to:
  /// **'LLM Agent'**
  String get cronModeAgent;

  /// No description provided for @cronModeScript.
  ///
  /// In en, this message translates to:
  /// **'Script Only (Watchdog)'**
  String get cronModeScript;

  /// No description provided for @cronPrompt.
  ///
  /// In en, this message translates to:
  /// **'Agent Instruction / Prompt'**
  String get cronPrompt;

  /// No description provided for @cronPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the task the agent should perform periodically...'**
  String get cronPromptHint;

  /// No description provided for @cronPromptRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter instructions or attach a script'**
  String get cronPromptRequired;

  /// No description provided for @cronScriptRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Script File (Required)'**
  String get cronScriptRequiredLabel;

  /// No description provided for @cronScriptOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Script File (Optional)'**
  String get cronScriptOptionalLabel;

  /// No description provided for @cronScriptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. backup-vault.sh'**
  String get cronScriptHint;

  /// No description provided for @cronScriptHelper.
  ///
  /// In en, this message translates to:
  /// **'Scripts must live under ~/.hermes/scripts/'**
  String get cronScriptHelper;

  /// No description provided for @cronScriptRequired.
  ///
  /// In en, this message translates to:
  /// **'Script file is required in Watchdog mode'**
  String get cronScriptRequired;

  /// No description provided for @cronWorkdir.
  ///
  /// In en, this message translates to:
  /// **'Workspace Directory (Optional)'**
  String get cronWorkdir;

  /// No description provided for @cronWorkdirHint.
  ///
  /// In en, this message translates to:
  /// **'Absolute path to project directory'**
  String get cronWorkdirHint;

  /// No description provided for @cronWorkdirHelper.
  ///
  /// In en, this message translates to:
  /// **'Injects project-level AGENTS.md/CLAUDE.md context'**
  String get cronWorkdirHelper;

  /// No description provided for @cronUpdated.
  ///
  /// In en, this message translates to:
  /// **'Job updated successfully'**
  String get cronUpdated;

  /// No description provided for @cronCreated.
  ///
  /// In en, this message translates to:
  /// **'Job created successfully'**
  String get cronCreated;

  /// No description provided for @cronSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save scheduled job'**
  String get cronSaveFailed;

  /// No description provided for @cronScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get cronScheduleLabel;

  /// No description provided for @cronNextRun.
  ///
  /// In en, this message translates to:
  /// **'Next run'**
  String get cronNextRun;

  /// No description provided for @cronLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last run'**
  String get cronLastRun;

  /// No description provided for @cronMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get cronMode;

  /// No description provided for @cronModeWatchdog.
  ///
  /// In en, this message translates to:
  /// **'Watchdog (No Agent)'**
  String get cronModeWatchdog;

  /// No description provided for @cronWorkdirLabel.
  ///
  /// In en, this message translates to:
  /// **'Workdir'**
  String get cronWorkdirLabel;

  /// No description provided for @cronRunNow.
  ///
  /// In en, this message translates to:
  /// **'Run Now'**
  String get cronRunNow;

  /// No description provided for @skillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsTitle;

  /// No description provided for @skillsRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Register Skill'**
  String get skillsRegisterTitle;

  /// No description provided for @skillsTabRegistry.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get skillsTabRegistry;

  /// No description provided for @skillsTabUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get skillsTabUsage;

  /// No description provided for @skillsTabManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get skillsTabManagement;

  /// No description provided for @skillsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No Skills Registered'**
  String get skillsEmptyTitle;

  /// No description provided for @skillsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Skills will appear here when registered'**
  String get skillsEmptyMessage;

  /// No description provided for @skillsServiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Skill service is unavailable on this platform'**
  String get skillsServiceUnavailable;

  /// No description provided for @skillsRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered skill {name}'**
  String skillsRegistered(String name);

  /// No description provided for @skillsRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to register skill: {error}'**
  String skillsRegisterFailed(String error);

  /// No description provided for @skillsEnabled.
  ///
  /// In en, this message translates to:
  /// **'{name} enabled'**
  String skillsEnabled(String name);

  /// No description provided for @skillsDisabled.
  ///
  /// In en, this message translates to:
  /// **'{name} disabled'**
  String skillsDisabled(String name);

  /// No description provided for @skillsStatUses.
  ///
  /// In en, this message translates to:
  /// **'Uses'**
  String get skillsStatUses;

  /// No description provided for @skillsStatAvgTime.
  ///
  /// In en, this message translates to:
  /// **'Avg Time'**
  String get skillsStatAvgTime;

  /// No description provided for @skillsStatLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last Used'**
  String get skillsStatLastUsed;

  /// No description provided for @skillsUsageByCategory.
  ///
  /// In en, this message translates to:
  /// **'Skill Usage by Category'**
  String get skillsUsageByCategory;

  /// No description provided for @skillsUsesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 use} other{{count} uses}}'**
  String skillsUsesCount(int count);

  /// No description provided for @skillsAvgSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s avg'**
  String skillsAvgSeconds(String seconds);

  /// No description provided for @skillsTopPerforming.
  ///
  /// In en, this message translates to:
  /// **'Top Performing Skills'**
  String get skillsTopPerforming;

  /// No description provided for @skillsGlobalSettings.
  ///
  /// In en, this message translates to:
  /// **'Global Settings'**
  String get skillsGlobalSettings;

  /// No description provided for @skillsAutoDisable.
  ///
  /// In en, this message translates to:
  /// **'Auto-disable slow skills'**
  String get skillsAutoDisable;

  /// No description provided for @skillsAutoDisableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Disable skills that take longer than 5 seconds'**
  String get skillsAutoDisableSubtitle;

  /// No description provided for @skillsCache.
  ///
  /// In en, this message translates to:
  /// **'Cache skill results'**
  String get skillsCache;

  /// No description provided for @skillsCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Store responses for identical requests'**
  String get skillsCacheSubtitle;

  /// No description provided for @skillsDefaultTimeout.
  ///
  /// In en, this message translates to:
  /// **'Default timeout'**
  String get skillsDefaultTimeout;

  /// No description provided for @skillsDefaultTimeoutValue.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get skillsDefaultTimeoutValue;

  /// No description provided for @skillsResourceLimits.
  ///
  /// In en, this message translates to:
  /// **'Resource Limits'**
  String get skillsResourceLimits;

  /// No description provided for @skillsMaxConcurrent.
  ///
  /// In en, this message translates to:
  /// **'Max concurrent skills'**
  String get skillsMaxConcurrent;

  /// No description provided for @skillsMaxConcurrentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum skills running simultaneously'**
  String get skillsMaxConcurrentSubtitle;

  /// No description provided for @skillsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory per skill'**
  String get skillsMemory;

  /// No description provided for @skillsMemorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Maximum RAM allocation per skill'**
  String get skillsMemorySubtitle;

  /// No description provided for @skillsNameDescriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Name and description are required'**
  String get skillsNameDescriptionRequired;

  /// No description provided for @skillsCreatesUnder.
  ///
  /// In en, this message translates to:
  /// **'Creates SKILL.md under {directory}'**
  String skillsCreatesUnder(String directory);

  /// No description provided for @instancesTitle.
  ///
  /// In en, this message translates to:
  /// **'Instances'**
  String get instancesTitle;

  /// No description provided for @instancesRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh instances'**
  String get instancesRefresh;

  /// No description provided for @instancesNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get instancesNotStarted;

  /// No description provided for @instancesUptimeDaysHours.
  ///
  /// In en, this message translates to:
  /// **'{days}d {hours}h'**
  String instancesUptimeDaysHours(int days, int hours);

  /// No description provided for @instancesStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start gateway'**
  String get instancesStartFailed;

  /// No description provided for @instancesStopFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop gateway'**
  String get instancesStopFailed;

  /// No description provided for @instancesRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restart gateway'**
  String get instancesRestartFailed;

  /// No description provided for @instancesNoGatewayState.
  ///
  /// In en, this message translates to:
  /// **'No gateway state available'**
  String get instancesNoGatewayState;

  /// No description provided for @instancesGatewayProcess.
  ///
  /// In en, this message translates to:
  /// **'Gateway Process'**
  String get instancesGatewayProcess;

  /// No description provided for @instancesModelInstances.
  ///
  /// In en, this message translates to:
  /// **'Model Instances'**
  String get instancesModelInstances;

  /// No description provided for @instancesPort.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String instancesPort(String port);

  /// No description provided for @instancesUptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime: {uptime}'**
  String instancesUptime(String uptime);

  /// No description provided for @instancesRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get instancesRequests;

  /// No description provided for @instancesUtilized.
  ///
  /// In en, this message translates to:
  /// **'{percent}% utilized'**
  String instancesUtilized(int percent);

  /// No description provided for @instancesHermesEnabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Hermes Agent enabled — chat will use Hermes'**
  String get instancesHermesEnabledSnack;

  /// No description provided for @instancesHermesDisabledSnack.
  ///
  /// In en, this message translates to:
  /// **'Switched back to default gateway'**
  String get instancesHermesDisabledSnack;

  /// No description provided for @instancesHermesTitle.
  ///
  /// In en, this message translates to:
  /// **'🦞 Hermes Agent'**
  String get instancesHermesTitle;

  /// No description provided for @instancesHermesActive.
  ///
  /// In en, this message translates to:
  /// **'Active — routing chat through Hermes API server'**
  String get instancesHermesActive;

  /// No description provided for @instancesHermesInactive.
  ///
  /// In en, this message translates to:
  /// **'Disabled — using the default Hermes gateway'**
  String get instancesHermesInactive;

  /// No description provided for @instancesHermesEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Hermes Agent'**
  String get instancesHermesEnable;

  /// No description provided for @instancesHermesEnableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Route chat through Hermes for tool use, file ops, web search, and code execution'**
  String get instancesHermesEnableSubtitle;

  /// No description provided for @instancesHermesUrl.
  ///
  /// In en, this message translates to:
  /// **'Hermes API URL'**
  String get instancesHermesUrl;

  /// No description provided for @instancesApiKeyOptional.
  ///
  /// In en, this message translates to:
  /// **'API Key (optional)'**
  String get instancesApiKeyOptional;

  /// No description provided for @instancesApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for local-only use'**
  String get instancesApiKeyHint;

  /// No description provided for @instancesTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get instancesTestConnection;
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
