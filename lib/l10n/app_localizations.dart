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
