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
}
