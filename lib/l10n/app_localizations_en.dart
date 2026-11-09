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

  @override
  String get commonBackToSettings => 'Back to Settings';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get desktopSettingsTitle => 'Desktop Settings';

  @override
  String get desktopHeading => 'Desktop';

  @override
  String get desktopDescription =>
      'Desktop-specific settings and file operations.';

  @override
  String get desktopFileOperations => 'File Operations';

  @override
  String get desktopFileOperationsSubtitle =>
      'Manage file operations and permissions';

  @override
  String get desktopGuiAutomation => 'GUI Automation';

  @override
  String get desktopGuiAutomationSubtitle => 'Configure desktop automation';

  @override
  String get llmProviderSettingsTitle => 'LLM Provider Settings';

  @override
  String get llmProviderHermesDescription =>
      'This application uses Hermes Agent as the primary runtime. Chat and related features go through your local Hermes install.';

  @override
  String get llmProviderOpenConfig => 'Open Config';

  @override
  String get llmProviderSystemStatus => 'System Status';

  @override
  String get llmProviderPrimaryRuntime => 'Primary agent runtime';

  @override
  String get llmProviderSupportProviders => 'Support model providers';

  @override
  String get llmProviderSupportProvidersSubtitle =>
      'Optional helpers such as Ollama or LM Studio';

  @override
  String get visionSettingsTitle => 'Vision Settings';

  @override
  String get visionServiceStatus => 'Service Status';

  @override
  String get visionMainService => 'Main Vision Service';

  @override
  String get visionRegionCaptureService => 'Region Capture Service';

  @override
  String get visionCameraCaptureService => 'Camera Capture Service';

  @override
  String get visionOcrService => 'OCR Engine Service';

  @override
  String get visionInitialized => 'Initialized';

  @override
  String get visionNotInitialized => 'Not initialized';

  @override
  String get visionCameraPreview => 'Camera Preview';

  @override
  String get visionCameraPreviewNote =>
      'Local-only preview (v4l2/ffmpeg). Frames are not saved or sent.';

  @override
  String get visionTestResults => 'Test Results';

  @override
  String get visionInitializeAll => 'Initialize All Services';

  @override
  String get visionInitializing => 'Initializing services...';

  @override
  String get visionInitComplete => 'Initialization complete';

  @override
  String visionInitFailed(String error) {
    return 'Initialization failed: $error';
  }

  @override
  String visionResultInitialized(String service) {
    return '✅ $service initialized';
  }

  @override
  String visionResultError(String service, String error) {
    return '❌ $service: $error';
  }

  @override
  String visionLinuxCameraStarted(String device) {
    return '✅ Linux camera capture started ($device)';
  }

  @override
  String visionLinuxCameraError(String error) {
    return '❌ Linux camera: $error';
  }

  @override
  String visionFatalError(String error) {
    return '❌ Fatal error: $error';
  }

  @override
  String get meshTitle => 'Device Mesh';

  @override
  String get meshRevokeTitle => 'Revoke device?';

  @override
  String meshRevokeBody(String device) {
    return 'Revoke $device? The device will need to re-register to reconnect.';
  }

  @override
  String get meshRevoke => 'Revoke';

  @override
  String get meshRevoked => 'Device revoked';

  @override
  String get meshRevokeFailed => 'Failed to revoke device';

  @override
  String get meshThisDevice => 'This device';

  @override
  String get meshRegisteredDevices => 'Registered devices';

  @override
  String get meshLoadFailed => 'Failed to load devices';

  @override
  String get meshNoDevices => 'No other devices registered.';

  @override
  String get meshStatusConnected => 'Connected to cloud connector';

  @override
  String get meshStatusConnecting => 'Connecting…';

  @override
  String get meshStatusError => 'Connection error';

  @override
  String get meshStatusDisconnected => 'Disconnected';

  @override
  String get meshUnknownPlatform => 'unknown platform';

  @override
  String get meshNever => 'never';

  @override
  String get meshOnline => 'online';

  @override
  String meshLastSeen(String time) {
    return 'last seen $time';
  }

  @override
  String get meshRuntimeAvailable => 'runtime available';

  @override
  String get commonConnected => 'Connected';

  @override
  String get commonDisconnected => 'Disconnected';

  @override
  String get connectionSettingsTitle => 'Connection Settings';

  @override
  String get connectionHeading => 'Connection';

  @override
  String get connectionDescription => 'Manage tunnel and daemon connections.';

  @override
  String get connectionDaemonSettings => 'Daemon Settings';

  @override
  String get connectionDaemonSubtitle => 'Configure system tray daemon';

  @override
  String get connectionDeviceMeshSubtitle =>
      'Registered devices and cloud presence';

  @override
  String get connectionStatusTitle => 'Connection Status';

  @override
  String get connectionStatusSubtitle => 'View current connection status';

  @override
  String get connectionRerunWizard => 'Re-run Setup Wizard';

  @override
  String get connectionRerunWizardSubtitle =>
      'Configure gateway connection again';

  @override
  String get connectionRerunWizardBody =>
      'This will clear your saved setup configuration and restart the setup wizard. You will need to reconfigure your gateway connection.\n\nContinue?';

  @override
  String get connectionClearAndRerun => 'Clear & Re-run';

  @override
  String connectionClearFailed(String error) {
    return 'Failed to clear setup data: $error';
  }

  @override
  String get daemonSettingsTitle => 'System Tray Daemon Settings';

  @override
  String get daemonHeading => 'System Tray Configuration';

  @override
  String get daemonDescription =>
      'Configure the system tray daemon behavior and appearance';

  @override
  String get daemonSaved => 'Daemon settings saved successfully';

  @override
  String daemonSaveFailed(String error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get daemonRestarting => 'Restarting system tray daemon...';

  @override
  String get daemonRestarted => 'System tray daemon restarted successfully';

  @override
  String daemonRestartFailed(String error) {
    return 'Failed to restart daemon: $error';
  }

  @override
  String get daemonRealtimeStatus => 'Real-time Connection Status';

  @override
  String get daemonConnectionType => 'Connection Type';

  @override
  String get daemonVersion => 'Version';

  @override
  String get daemonAvailableModels => 'Available Models';

  @override
  String daemonModelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count models',
      one: '1 model',
    );
    return '$_temp0';
  }

  @override
  String get daemonError => 'Error';

  @override
  String daemonLastUpdated(String time) {
    return 'Last updated: $time';
  }

  @override
  String get daemonLoadingStatus => 'Loading connection status...';

  @override
  String get daemonEnableTray => 'Enable System Tray';

  @override
  String get daemonStartMinimized => 'Start Minimized';

  @override
  String get daemonStartMinimizedSubtitle =>
      'Start application minimized to system tray';

  @override
  String get daemonEnableNotifications => 'Enable Notifications';

  @override
  String get daemonEnableNotificationsSubtitle =>
      'Show system notifications for important events';

  @override
  String get daemonAutoStart => 'Auto-start Daemon';

  @override
  String get daemonAutoStartSubtitle =>
      'Automatically start tray daemon with system';

  @override
  String get daemonTrayIconTheme => 'Tray Icon Theme';

  @override
  String get daemonTrayIconThemeSubtitle => 'Choose icon style for system tray';

  @override
  String get themeMonochrome => 'Monochrome';

  @override
  String get daemonConnectionTimeout => 'Connection Timeout';

  @override
  String get daemonConnectionTimeoutSubtitle =>
      'Timeout for daemon connections (seconds)';

  @override
  String get daemonHealthCheckInterval => 'Health Check Interval';

  @override
  String get daemonHealthCheckIntervalSubtitle =>
      'Interval for daemon health checks (seconds)';

  @override
  String get daemonActions => 'Actions';

  @override
  String get daemonSaveSettings => 'Save Settings';

  @override
  String get daemonRestart => 'Restart Daemon';
}
