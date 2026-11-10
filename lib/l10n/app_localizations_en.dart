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

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonClose => 'Close';

  @override
  String get commonClear => 'Clear';

  @override
  String commonErrorDetails(String error) {
    return 'Error: $error';
  }

  @override
  String get nodesTitle => 'Nodes';

  @override
  String get nodesAgentRuntimes => 'Agent Runtimes';

  @override
  String get nodesNoAgentRuntimes => 'No agent runtimes discovered';

  @override
  String get nodesSupportProviders => 'Support Providers';

  @override
  String get nodesNoSupportProviders => 'No support providers discovered';

  @override
  String get nodesTailscaleDevices => 'Tailscale Devices';

  @override
  String get nodesNoTailscaleDevices => 'No Tailscale devices discovered';

  @override
  String nodesLoadError(String error) {
    return 'Failed to load discovery data: $error';
  }

  @override
  String nodesSelectedRuntime(String name, String version) {
    return 'Agent runtime: $name ($version)';
  }

  @override
  String get nodesVersionUnknown => 'unknown';

  @override
  String get nodesNoRuntimeSelected => 'No agent runtime selected';

  @override
  String get channelDetailsTitle => 'Channel Details';

  @override
  String get channelNotFound => 'Channel not found';

  @override
  String get channelBadgeNew => 'New';

  @override
  String get channelBadgeRead => 'Read';

  @override
  String get channelStatistics => 'Statistics';

  @override
  String get channelMessages => 'Messages';

  @override
  String get channelPlatform => 'Platform';

  @override
  String get channelPlatformUnknown => 'Unknown';

  @override
  String get channelLastActivity => 'Last Activity';

  @override
  String get channelNever => 'Never';

  @override
  String get channelControls => 'Controls';

  @override
  String get channelStart => 'Start Channel';

  @override
  String get channelStop => 'Stop Channel';

  @override
  String get channelReconnect => 'Reconnect';

  @override
  String get channelViewLogs => 'View Logs';

  @override
  String channelActionPerformed(String action, String channelId) {
    return 'Action $action performed for channel $channelId';
  }

  @override
  String get channelJustNow => 'Just now';

  @override
  String channelMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String channelHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String channelDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get usageTitle => 'Usage';

  @override
  String get usageToday => 'Today';

  @override
  String get usageWeek => 'Week';

  @override
  String get usageMonth => 'Month';

  @override
  String get usageActiveConcurrency => 'Active Concurrency';

  @override
  String usageOfLimit(int limit) {
    return 'of $limit';
  }

  @override
  String get usageConcurrencySubtitle => 'Concurrent requests in flight';

  @override
  String get usageConcurrencyUtilization => 'Concurrency utilization';

  @override
  String get usageRequestRate => 'Request Rate';

  @override
  String get usageRequestsPerMinuteUnit => 'req/min';

  @override
  String get usageRequestRateSubtitle => 'Requests per minute across models';

  @override
  String get usageRpmUtilization => 'RPM utilization';

  @override
  String get usageTokenRate => 'Token Rate';

  @override
  String get usageTokensPerMinuteUnit => 'tok/min';

  @override
  String get usageTokenRateSubtitle => 'Tokens per minute across models';

  @override
  String get usageTpmUtilization => 'TPM utilization';

  @override
  String get usageChartTokenUsage => 'Token Usage Over Time';

  @override
  String get usageChartRequestVolume => 'Request Volume';

  @override
  String get usageChartResourceTrends => 'Resource Trends';

  @override
  String get usageChartPlaceholder => 'Chart placeholder';

  @override
  String get usageNoActiveModels => 'No active models';

  @override
  String get usagePerModelConcurrency => 'Per-model concurrency';

  @override
  String get usageNoRateData => 'No rate data';

  @override
  String get usageTopModelsByRpm => 'Top models by RPM';

  @override
  String get usageNoTokenData => 'No token data';

  @override
  String get usageTopModelsByTpm => 'Top models by TPM';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsExport => 'Export Logs';

  @override
  String get logsServiceUnavailable => 'Log service unavailable';

  @override
  String logsExportedTo(String path) {
    return 'Logs exported to $path';
  }

  @override
  String get logsCopied => 'Logs copied to clipboard';

  @override
  String get logsNoneFound => 'No logs found';

  @override
  String get logsAdjustFilters => 'Try adjusting your filters';

  @override
  String get logsNoneAvailable => 'No logs available';

  @override
  String get logsSearchHint => 'Search logs...';

  @override
  String get logsSeverity => 'Severity';

  @override
  String get logsSource => 'Source';

  @override
  String get logsClearAll => 'Clear All';

  @override
  String get logsViewDetails => 'View details';

  @override
  String get logsDetailsTitle => 'Log Details';

  @override
  String get logsTimestamp => 'Timestamp';

  @override
  String get logsMessage => 'Message';

  @override
  String get logsError => 'Error';

  @override
  String get logsStackTrace => 'Stack Trace';

  @override
  String get logsFilterBySource => 'Filter by Source';

  @override
  String logsDetailLabel(String label) {
    return '$label:';
  }

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSave => 'Save';

  @override
  String get commonUnknownError => 'Unknown error';

  @override
  String commonFieldLabel(String label) {
    return '$label:';
  }

  @override
  String get commonStatus => 'Status';

  @override
  String get commonError => 'Error';

  @override
  String get commonActions => 'Actions';

  @override
  String get commonName => 'Name';

  @override
  String get commonType => 'Type';

  @override
  String get commonMessages => 'Messages';

  @override
  String get commonNever => 'Never';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeSecondsAgo(int seconds) {
    return '${seconds}s ago';
  }

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeDaysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get agentsTitle => 'Agents';

  @override
  String get agentsAdd => 'Add Agent';

  @override
  String get agentsTabRegistry => 'Registry';

  @override
  String get agentsTabMonitor => 'Monitor';

  @override
  String get agentsTabConfig => 'Config';

  @override
  String get agentsEmptyTitle => 'No Agents Registered';

  @override
  String get agentsEmptyMessage => 'Agents will appear here when registered';

  @override
  String get agentsNoTask => 'No task assigned';

  @override
  String agentsActivityCompleted(String task) {
    return 'Completed: $task';
  }

  @override
  String agentsActivityFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String agentsActivityStarted(String task) {
    return 'Started: $task';
  }

  @override
  String get agentsActivityTaskFallback => 'task';

  @override
  String get agentsActivityErrorFallback => 'unknown error';

  @override
  String get agentsRegistryUnavailable =>
      'Agent registry is unavailable until the API backend is connected';

  @override
  String get agentsRegisterFailed => 'Failed to register agent';

  @override
  String agentsRegistered(String name) {
    return 'Registered $name';
  }

  @override
  String agentsEditTitle(String name) {
    return 'Edit $name';
  }

  @override
  String agentsUpdateFailed(String name) {
    return 'Failed to update $name';
  }

  @override
  String agentsUpdated(String name) {
    return 'Updated $name';
  }

  @override
  String agentsRemoveFailed(String name) {
    return 'Failed to remove $name';
  }

  @override
  String agentsRemoved(String name) {
    return '$name removed';
  }

  @override
  String get agentsStatTasks => 'Tasks';

  @override
  String get agentsStatAvgLatency => 'Avg Latency';

  @override
  String get agentsStatLastActive => 'Last Active';

  @override
  String get agentsStatusOnline => 'ONLINE';

  @override
  String get agentsStatusBusy => 'BUSY';

  @override
  String get agentsStatusOffline => 'OFFLINE';

  @override
  String get agentsStatusError => 'ERROR';

  @override
  String get agentsTotal => 'Total Agents';

  @override
  String get agentsTasksToday => 'Tasks Today';

  @override
  String get agentsErrors => 'Errors';

  @override
  String get agentsNoActivityTitle => 'No Recent Activity';

  @override
  String get agentsNoActivityMessage => 'Agent activity will appear here';

  @override
  String get agentsPoolSettings => 'Agent Pool Settings';

  @override
  String get agentsAutoScale => 'Auto-scale agents';

  @override
  String get agentsAutoScaleSubtitle =>
      'Automatically add agents based on load';

  @override
  String get agentsMin => 'Min agents';

  @override
  String get agentsMinSubtitle => 'Minimum number of active agents';

  @override
  String get agentsMax => 'Max agents';

  @override
  String get agentsMaxSubtitle => 'Maximum number of concurrent agents';

  @override
  String get agentsTimeoutSettings => 'Timeout Settings';

  @override
  String get agentsRequestTimeout => 'Request timeout';

  @override
  String get agentsRequestTimeoutSubtitle =>
      'Maximum time to wait for agent response';

  @override
  String get agentsQueueTimeout => 'Queue timeout';

  @override
  String get agentsQueueTimeoutSubtitle =>
      'Maximum time in queue before rejection';

  @override
  String get agentsPause => 'Pause Agent';

  @override
  String get agentsResume => 'Resume Agent';

  @override
  String get agentsRestart => 'Restart Agent';

  @override
  String get agentsEditConfig => 'Edit Configuration';

  @override
  String get agentsRemove => 'Remove Agent';

  @override
  String agentsRemoveConfirm(String name) {
    return 'Are you sure you want to remove $name?';
  }

  @override
  String get agentsRegisterTitle => 'Register Agent';

  @override
  String get agentsRegister => 'Register';

  @override
  String get agentsIdsRequired =>
      'Subagent ID and parent agent ID are required';

  @override
  String get agentsSubagentId => 'Subagent ID';

  @override
  String get agentsParentId => 'Parent Agent ID';

  @override
  String get agentsDisplayLabel => 'Display Label';

  @override
  String get agentsTaskDescription => 'Task Description';

  @override
  String get agentDetailTitle => 'Agent Details';

  @override
  String get agentDetailNotFound => 'Agent not found';

  @override
  String agentDetailIdValue(String id) {
    return 'ID: $id';
  }

  @override
  String get agentDetailActivity => 'Activity';

  @override
  String get agentDetailLastUpdate => 'Last Update';

  @override
  String get agentDetailStart => 'Start';

  @override
  String get agentDetailStop => 'Stop';

  @override
  String get agentDetailRestart => 'Restart';

  @override
  String get agentDetailInformation => 'Information';

  @override
  String get agentDetailId => 'ID';

  @override
  String get agentStateIdle => 'Idle';

  @override
  String get agentStateStarting => 'Starting...';

  @override
  String get agentStateRunning => 'Running';

  @override
  String get agentStateStopping => 'Stopping...';

  @override
  String get agentStateError => 'Error';

  @override
  String get agentStateOffline => 'Offline';

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsTabWebSocket => 'WebSocket';

  @override
  String get sessionsTabConversations => 'Conversations';

  @override
  String get sessionsTabUsers => 'Users';

  @override
  String get sessionsRefresh => 'Refresh sessions';

  @override
  String get sessionsEmptyTitle => 'No Sessions';

  @override
  String get sessionsEmptyMessage => 'No active sessions for this category.';

  @override
  String get sessionsDetailsTitle => 'Session Details';

  @override
  String get sessionsId => 'Session ID';

  @override
  String get sessionsUserOrAgent => 'User/Agent';

  @override
  String get sessionsStarted => 'Started';

  @override
  String get sessionsDuration => 'Duration';

  @override
  String get sessionsTokens => 'Tokens';

  @override
  String sessionsDurationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String sessionsDurationMinutesSeconds(int minutes, int seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String sessionsDurationSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get sessionsTerminateTitle => 'Terminate Session';

  @override
  String sessionsTerminateConfirm(String id, String who) {
    return 'Are you sure you want to terminate session $id?\n\nThis will disconnect $who and cannot be undone.';
  }

  @override
  String get sessionsServiceUnavailable => 'Session service unavailable';

  @override
  String sessionsTerminated(String id) {
    return 'Session $id terminated';
  }

  @override
  String sessionsTerminateFailed(String id) {
    return 'Failed to terminate session $id';
  }

  @override
  String get sessionsTerminate => 'Terminate';

  @override
  String get sessionsViewDetails => 'View details';

  @override
  String get sessionsTerminateTooltip => 'Terminate session';

  @override
  String get channelsTitle => 'Channels';

  @override
  String get channelsRefresh => 'Refresh channels';

  @override
  String channelsLoadError(String error) {
    return 'Failed to load channels: $error';
  }

  @override
  String get channelsEmptyTitle => 'No Channels';

  @override
  String get channelsEmptyMessage =>
      'No communication channels are currently available.';

  @override
  String channelsMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeNoAgentTitle => 'No Agent Connected';

  @override
  String get homeNoAgentBanner =>
      'Configure an agent runtime in Settings to enable AI responses and desktop control.';

  @override
  String get homeStatusConfigured => 'Configured';

  @override
  String get homeStatusOffline => 'Offline';

  @override
  String get homeNoAgentStandalone =>
      'Configure an agent runtime in Settings to get started, or use the avatar and local features while offline.';

  @override
  String get homeOpenSettings => 'Open Settings';

  @override
  String get homeConfigureManually => 'Configure connection manually';

  @override
  String homeMessagePlaceholder(String name) {
    return 'Message $name...';
  }

  @override
  String get homePillarAvatar => 'Avatar';

  @override
  String get homePillarTools => 'Tools';

  @override
  String get homePillarMood => 'Mood';

  @override
  String homeMoodTitle(String possessive, String name) {
    return '$possessive Mood';
  }

  @override
  String get homeMoodNotReady => 'Personality engine not ready yet.';

  @override
  String homeMoodAgent(String name) {
    return 'Agent: $name';
  }

  @override
  String get homeTraitFormality => 'Formality';

  @override
  String get homeTraitHumor => 'Humor';

  @override
  String get homeTraitEnthusiasm => 'Enthusiasm';

  @override
  String get homeTraitEmpathy => 'Empathy';

  @override
  String homeMoodEvolution(String stage) {
    return 'Evolution: $stage';
  }

  @override
  String homeToolsTitle(String name) {
    return 'What $name Can Do';
  }

  @override
  String get homeToolsSubtitle => 'Available offline • Connect to unlock more';

  @override
  String get homeToolDesktop => 'Desktop Control';

  @override
  String get homeToolDesktopDescription =>
      'Click, type, scroll, drag on your PC';

  @override
  String get homeToolVision => 'Vision';

  @override
  String get homeToolVisionDescription => 'See and analyze your screen';

  @override
  String get homeToolVoice => 'Voice';

  @override
  String get homeToolVoiceDescription => 'Speak and listen';

  @override
  String get homeToolWebSearch => 'Web Search';

  @override
  String get homeToolWebSearchDescription => 'Search and extract web content';

  @override
  String get homeToolRequiresAgent => 'Requires agent connection';

  @override
  String get homeToolCode => 'Code Execution';

  @override
  String get homeToolCodeDescription => 'Run Python, shell, and Dart scripts';

  @override
  String get homeToolLocal => 'local';

  @override
  String get homeToolCloud => 'cloud';

  @override
  String get welcomeSubtitle =>
      'Your agent companion.\nFully offline until you choose to connect.';

  @override
  String get welcomeHint =>
      'Type a message below or tap /new to start fresh. Connect an agent runtime in Settings for AI responses and agent features.';

  @override
  String get messageInputPlaceholder => 'Type your message...';

  @override
  String get messageInputNewChat => 'New Chat';

  @override
  String get messageInputNoModels => 'No models available';

  @override
  String get messageInputSelectModel => 'Select model';

  @override
  String get messageCopied => 'Copied to clipboard';
}
