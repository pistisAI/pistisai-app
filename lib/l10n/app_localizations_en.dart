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

  @override
  String get commonStart => 'Start';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonRestart => 'Restart';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonApply => 'Apply';

  @override
  String get cronTitle => 'Cron Jobs';

  @override
  String get cronAddJob => 'Add Job';

  @override
  String get cronEmptyTitle => 'No Cron Jobs';

  @override
  String get cronEmptyMessage =>
      'Create scheduled tasks to automate maintenance';

  @override
  String cronTriggered(String name) {
    return 'Triggered: $name';
  }

  @override
  String get cronDeleteTitle => 'Delete Scheduled Job';

  @override
  String cronDeleteConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"? This action cannot be undone.';
  }

  @override
  String get cronDeleted => 'Job deleted successfully';

  @override
  String get cronDeleteFailed => 'Failed to delete job';

  @override
  String get cronEditTitle => 'Edit Scheduled Job';

  @override
  String get cronCreateTitle => 'Create Scheduled Job';

  @override
  String get cronJobName => 'Job Name';

  @override
  String get cronJobNameHint => 'e.g. Daily Briefing';

  @override
  String get cronJobNameRequired => 'Please enter a job name';

  @override
  String get cronSchedule => 'Schedule Expression / Interval';

  @override
  String get cronScheduleHint => 'e.g. 30m, every 2h, or 0 9 * * *';

  @override
  String get cronScheduleRequired => 'Please enter a schedule';

  @override
  String get cronExecutionMode => 'Execution Mode';

  @override
  String get cronModeAgent => 'LLM Agent';

  @override
  String get cronModeScript => 'Script Only (Watchdog)';

  @override
  String get cronPrompt => 'Agent Instruction / Prompt';

  @override
  String get cronPromptHint =>
      'Describe the task the agent should perform periodically...';

  @override
  String get cronPromptRequired =>
      'Please enter instructions or attach a script';

  @override
  String get cronScriptRequiredLabel => 'Script File (Required)';

  @override
  String get cronScriptOptionalLabel => 'Script File (Optional)';

  @override
  String get cronScriptHint => 'e.g. backup-vault.sh';

  @override
  String get cronScriptHelper => 'Scripts must live under ~/.hermes/scripts/';

  @override
  String get cronScriptRequired => 'Script file is required in Watchdog mode';

  @override
  String get cronWorkdir => 'Workspace Directory (Optional)';

  @override
  String get cronWorkdirHint => 'Absolute path to project directory';

  @override
  String get cronWorkdirHelper =>
      'Injects project-level AGENTS.md/CLAUDE.md context';

  @override
  String get cronUpdated => 'Job updated successfully';

  @override
  String get cronCreated => 'Job created successfully';

  @override
  String get cronSaveFailed => 'Failed to save scheduled job';

  @override
  String get cronScheduleLabel => 'Schedule';

  @override
  String get cronNextRun => 'Next run';

  @override
  String get cronLastRun => 'Last run';

  @override
  String get cronMode => 'Mode';

  @override
  String get cronModeWatchdog => 'Watchdog (No Agent)';

  @override
  String get cronWorkdirLabel => 'Workdir';

  @override
  String get cronRunNow => 'Run Now';

  @override
  String get skillsTitle => 'Skills';

  @override
  String get skillsRegisterTitle => 'Register Skill';

  @override
  String get skillsTabRegistry => 'Registry';

  @override
  String get skillsTabUsage => 'Usage';

  @override
  String get skillsTabManagement => 'Management';

  @override
  String get skillsEmptyTitle => 'No Skills Registered';

  @override
  String get skillsEmptyMessage => 'Skills will appear here when registered';

  @override
  String get skillsServiceUnavailable =>
      'Skill service is unavailable on this platform';

  @override
  String skillsRegistered(String name) {
    return 'Registered skill $name';
  }

  @override
  String skillsRegisterFailed(String error) {
    return 'Failed to register skill: $error';
  }

  @override
  String skillsEnabled(String name) {
    return '$name enabled';
  }

  @override
  String skillsDisabled(String name) {
    return '$name disabled';
  }

  @override
  String get skillsStatUses => 'Uses';

  @override
  String get skillsStatAvgTime => 'Avg Time';

  @override
  String get skillsStatLastUsed => 'Last Used';

  @override
  String get skillsUsageByCategory => 'Skill Usage by Category';

  @override
  String skillsUsesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uses',
      one: '1 use',
    );
    return '$_temp0';
  }

  @override
  String skillsAvgSeconds(String seconds) {
    return '${seconds}s avg';
  }

  @override
  String get skillsTopPerforming => 'Top Performing Skills';

  @override
  String get skillsGlobalSettings => 'Global Settings';

  @override
  String get skillsAutoDisable => 'Auto-disable slow skills';

  @override
  String get skillsAutoDisableSubtitle =>
      'Disable skills that take longer than 5 seconds';

  @override
  String get skillsCache => 'Cache skill results';

  @override
  String get skillsCacheSubtitle => 'Store responses for identical requests';

  @override
  String get skillsDefaultTimeout => 'Default timeout';

  @override
  String get skillsDefaultTimeoutValue => '30 seconds';

  @override
  String get skillsResourceLimits => 'Resource Limits';

  @override
  String get skillsMaxConcurrent => 'Max concurrent skills';

  @override
  String get skillsMaxConcurrentSubtitle =>
      'Maximum skills running simultaneously';

  @override
  String get skillsMemory => 'Memory per skill';

  @override
  String get skillsMemorySubtitle => 'Maximum RAM allocation per skill';

  @override
  String get skillsNameDescriptionRequired =>
      'Name and description are required';

  @override
  String skillsCreatesUnder(String directory) {
    return 'Creates SKILL.md under $directory';
  }

  @override
  String get instancesTitle => 'Instances';

  @override
  String get instancesRefresh => 'Refresh instances';

  @override
  String get instancesNotStarted => 'Not started';

  @override
  String instancesUptimeDaysHours(int days, int hours) {
    return '${days}d ${hours}h';
  }

  @override
  String get instancesStartFailed => 'Failed to start gateway';

  @override
  String get instancesStopFailed => 'Failed to stop gateway';

  @override
  String get instancesRestartFailed => 'Failed to restart gateway';

  @override
  String get instancesNoGatewayState => 'No gateway state available';

  @override
  String get instancesGatewayProcess => 'Gateway Process';

  @override
  String get instancesModelInstances => 'Model Instances';

  @override
  String instancesPort(String port) {
    return 'Port $port';
  }

  @override
  String instancesUptime(String uptime) {
    return 'Uptime: $uptime';
  }

  @override
  String get instancesRequests => 'Requests';

  @override
  String instancesUtilized(int percent) {
    return '$percent% utilized';
  }

  @override
  String get instancesHermesEnabledSnack =>
      'Hermes Agent enabled — chat will use Hermes';

  @override
  String get instancesHermesDisabledSnack => 'Switched back to default gateway';

  @override
  String get instancesHermesTitle => '🦞 Hermes Agent';

  @override
  String get instancesHermesActive =>
      'Active — routing chat through Hermes API server';

  @override
  String get instancesHermesInactive =>
      'Disabled — using the default Hermes gateway';

  @override
  String get instancesHermesEnable => 'Enable Hermes Agent';

  @override
  String get instancesHermesEnableSubtitle =>
      'Route chat through Hermes for tool use, file ops, web search, and code execution';

  @override
  String get instancesHermesUrl => 'Hermes API URL';

  @override
  String get instancesApiKeyOptional => 'API Key (optional)';

  @override
  String get instancesApiKeyHint => 'Leave empty for local-only use';

  @override
  String get instancesTestConnection => 'Test Connection';

  @override
  String get commonBack => 'Back';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonSelect => 'Select';

  @override
  String get avatarStateIdle => 'Idle';

  @override
  String get avatarStateThinking => 'Thinking';

  @override
  String get avatarStateWorking => 'Working';

  @override
  String get avatarStateHappy => 'Happy';

  @override
  String get avatarSizeSmall => 'Small';

  @override
  String get avatarSizeMedium => 'Medium';

  @override
  String get avatarSizeLarge => 'Large';

  @override
  String get avatarGlowEffect => 'Glow Effect';

  @override
  String get avatarGlowSubtitle => 'Enable pulsing glow effect around avatar';

  @override
  String get avatarStageCuriousExplorer => 'Curious Explorer';

  @override
  String get avatarStageCuriousExplorerInitial => 'Curious Explorer (Initial)';

  @override
  String get avatarStageKnowledgeSeeker => 'Knowledge Seeker';

  @override
  String get avatarStageWiseCompanion => 'Wise Companion';

  @override
  String get avatarStageEnlightenedGuide => 'Enlightened Guide';

  @override
  String get avatarSettingsTitle => 'Avatar Settings';

  @override
  String avatarInitFailed(String error) {
    return 'Failed to initialize avatar service: $error';
  }

  @override
  String get avatarSaved => 'Avatar settings saved successfully';

  @override
  String avatarSaveFailed(String error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get avatarEvolutionReasonMissing =>
      'Please provide a reason for evolution';

  @override
  String avatarEvolutionApproved(String stage) {
    return 'Evolution to $stage approved! Your avatar has evolved.';
  }

  @override
  String avatarEvolutionDenied(String reason) {
    return 'Evolution request denied: $reason';
  }

  @override
  String avatarEvolutionFailed(String error) {
    return 'Failed to request evolution: $error';
  }

  @override
  String get avatarSaveSettings => 'Save Settings';

  @override
  String get avatarLivePreview => 'Live Preview';

  @override
  String avatarStageValue(String stage) {
    return 'Stage: $stage';
  }

  @override
  String get avatarConversations => 'Conversations';

  @override
  String get avatarDepthScore => 'Depth Score';

  @override
  String get avatarAgentName => 'Agent Name';

  @override
  String get avatarAgentNameHint => 'Enter agent name';

  @override
  String get avatarAgentNameRequired => 'Please enter an agent name';

  @override
  String get avatarAgentNameTooShort => 'Name must be at least 2 characters';

  @override
  String get avatarAgentNameTooLong => 'Name must be less than 50 characters';

  @override
  String get avatarAgentNameHelp =>
      'This name will be used to address your avatar in conversations.';

  @override
  String get avatarPersonalityTraits => 'Personality Traits';

  @override
  String get avatarPersonalityHelp =>
      'Adjust these sliders to customize your avatar\'s personality. Changes are reflected in the live preview above.';

  @override
  String get avatarFormalityDescription => 'How formal the avatar communicates';

  @override
  String get avatarHumorDescription => 'Frequency and intensity of humor';

  @override
  String get avatarEnthusiasmDescription => 'Energy and excitement levels';

  @override
  String get avatarEmpathyDescription => 'Emotional understanding and support';

  @override
  String get avatarAppearance => 'Appearance';

  @override
  String get avatarAppearanceHelp =>
      'Customize your avatar\'s visual style and animation.';

  @override
  String get avatarColorTheme => 'Color Theme';

  @override
  String get avatarColorPersonality => 'Personality-Derived';

  @override
  String get avatarColorOceanBlue => 'Ocean Blue';

  @override
  String get avatarColorForestGreen => 'Forest Green';

  @override
  String get avatarColorSunsetOrange => 'Sunset Orange';

  @override
  String get avatarColorRoyalPurple => 'Royal Purple';

  @override
  String get avatarColorMonochrome => 'Monochrome';

  @override
  String get avatarAnimationStyle => 'Animation Style';

  @override
  String get avatarAnimationBounce => 'Bounce';

  @override
  String get avatarAnimationPulse => 'Pulse';

  @override
  String get avatarAnimationFloat => 'Float';

  @override
  String get avatarAnimationShake => 'Shake';

  @override
  String get avatarAnimationNone => 'None (Static)';

  @override
  String get avatarSize => 'Avatar Size';

  @override
  String get avatarAdvancedTitle => 'Advanced Visual Customization';

  @override
  String get avatarAdvancedHelp =>
      'Fine-tune your avatar\'s color, type, and effects in the dedicated customization screen.';

  @override
  String get avatarOpenAdvanced => 'Open Advanced Customization';

  @override
  String get avatarAchievements => 'Achievements';

  @override
  String get avatarAchievementsHelp =>
      'View your unlocked achievements and track your progress.';

  @override
  String get avatarViewAchievements => 'View Achievements';

  @override
  String get avatarEvolution => 'Evolution';

  @override
  String get avatarEvolutionHelp =>
      'Evolve your avatar to unlock new personality capabilities.';

  @override
  String get avatarCurrentStage => 'Current Stage:';

  @override
  String get avatarEvolveTo => 'Evolve to Stage';

  @override
  String get avatarEvolutionReason => 'Reason for Evolution';

  @override
  String get avatarEvolutionReasonHint =>
      'Explain why you want to evolve your avatar...';

  @override
  String get avatarEvolutionReasonRequired => 'Please provide a reason';

  @override
  String get avatarRequesting => 'Requesting...';

  @override
  String get avatarRequestEvolution => 'Request Evolution';

  @override
  String get avatarReadyToEvolve => 'Ready to Evolve!';

  @override
  String get avatarEvolutionRequirements => 'Evolution Requirements';

  @override
  String get avatarDeepConversations => 'Deep Conversations';

  @override
  String get avatarAverageNovelty => 'Average Novelty';

  @override
  String avatarRequirementPercent(int current, int required) {
    return '$current% / $required%';
  }

  @override
  String get avatarCustomizationTitle => 'Avatar Customization';

  @override
  String get avatarCustomizationSaved =>
      'Avatar customization saved successfully';

  @override
  String get avatarResetTitle => 'Reset to Defaults';

  @override
  String get avatarResetConfirm =>
      'Are you sure you want to reset all avatar settings to defaults?';

  @override
  String get avatarResetDone => 'Avatar settings reset to defaults';

  @override
  String get avatarResetTooltip => 'Reset to defaults';

  @override
  String get avatarSaveCustomization => 'Save Customization';

  @override
  String get avatarPreview => 'Avatar Preview';

  @override
  String get avatarType => 'Avatar Type';

  @override
  String get avatarTypeEmoji => 'Emoji';

  @override
  String get avatarColor => 'Avatar Color';

  @override
  String get avatarCustomColorSelected => 'Custom color selected';

  @override
  String get avatarUsingPersonalityColors => 'Using personality-derived colors';

  @override
  String get avatarPickColor => 'Pick Color';

  @override
  String get avatarUsePersonalityColors => 'Use personality colors';

  @override
  String get avatarPickColorTitle => 'Pick Avatar Color';

  @override
  String get achievementsTitle => 'Achievements';

  @override
  String achievementsLoadFailed(String error) {
    return 'Failed to load achievements: $error';
  }

  @override
  String get achievementsUnlockedSection => 'Unlocked';

  @override
  String get achievementsLockedSection => 'Locked';

  @override
  String get achievementsNoneUnlocked =>
      'No achievements unlocked yet. Start conversing!';

  @override
  String get achievementsProgress => 'Achievement Progress';

  @override
  String achievementsUnlockedCount(int unlocked, int total) {
    return '$unlocked of $total unlocked';
  }

  @override
  String achievementsPercent(int percent) {
    return '$percent%';
  }

  @override
  String achievementsUnlockedWhen(String when) {
    return 'Unlocked $when';
  }

  @override
  String get achievementsToday => 'today';

  @override
  String get achievementsYesterday => 'yesterday';

  @override
  String get achievementFirstChat => 'First Conversation';

  @override
  String get achievementFirstChatDescription =>
      'Complete your first conversation with the avatar';

  @override
  String get achievementGettingToKnow => 'Getting to Know You';

  @override
  String get achievementDeepThinker => 'Deep Thinker';

  @override
  String get achievementConversationalMaster => 'Conversational Master';

  @override
  String achievementDeepConversationsDescription(int count) {
    return 'Have $count deep conversations';
  }

  @override
  String get achievementNoveltySeeker => 'Novelty Seeker';

  @override
  String get achievementNoveltySeekerDescription =>
      'Maintain high novelty in conversations (60%+)';

  @override
  String achievementEvolveDescription(String stage) {
    return 'Evolve your avatar to the $stage stage';
  }

  @override
  String get configPageGeneral => 'General';

  @override
  String get configPageGeneralSubtitle => 'App preferences';

  @override
  String get configPageAppearance => 'Appearance';

  @override
  String get configPageAppearanceSubtitle => 'Theme and look';

  @override
  String get configPageConnection => 'Connection';

  @override
  String get configPageConnectionSubtitle => 'Daemon, mesh, and account';

  @override
  String get configPageLlm => 'LLM providers';

  @override
  String get configPageLlmSubtitle => 'Model provider settings';

  @override
  String get configPageVision => 'Vision';

  @override
  String get configPageVisionSubtitle => 'Screen and vision tools';

  @override
  String get configPageAvatar => 'Avatar';

  @override
  String get configPageAvatarSubtitle => 'Companion appearance';

  @override
  String get configPageAchievements => 'Achievements';

  @override
  String get configPageAchievementsSubtitle => 'Avatar milestones';

  @override
  String get configPageDesktop => 'Desktop';

  @override
  String get configPageDesktopSubtitle => 'Local desktop tools';

  @override
  String get configPageAbout => 'About';

  @override
  String get configPagePlans => 'Plans';

  @override
  String get configPagePlansSubtitle => 'Subscription options';

  @override
  String get configPageBrain => 'Brain insights';

  @override
  String get configPageBrainSubtitle => 'Local brain activity';

  @override
  String get configPageRoadmap => 'Roadmap';

  @override
  String get configPageRoadmapSubtitle => 'What is in progress';

  @override
  String get configTitle => 'Runtime Settings';

  @override
  String get configBackToChannel => 'Back to runtime channel';

  @override
  String get configTabRuntime => 'Runtime';

  @override
  String get configTabMesh => 'Mesh';

  @override
  String get configTabApp => 'App';

  @override
  String get configTabStorage => 'Storage';

  @override
  String get configTabSystem => 'System';

  @override
  String configLoadFailed(String error) {
    return 'Failed to load config: $error';
  }

  @override
  String get configSaved => 'Configuration saved';

  @override
  String configSaveFailed(String error) {
    return 'Failed to save configuration: $error';
  }

  @override
  String get configResetTitle => 'Reset to Defaults';

  @override
  String get configResetBody =>
      'This resets runtime preferences (theme, language, timeouts, proxy, developer flags) to their defaults.\n\nGateway URLs, API keys, and avatar settings are not affected.';

  @override
  String get configResetDone => 'Configuration reset to defaults';

  @override
  String configResetFailed(String error) {
    return 'Failed to reset configuration: $error';
  }

  @override
  String configExported(String filename) {
    return 'Settings exported to $filename';
  }

  @override
  String configExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get configImported => 'Settings imported successfully';

  @override
  String configImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get configRuntimeNone => 'None';

  @override
  String get configActiveRuntime => 'Active Agent Runtime';

  @override
  String configSecureChannelRuntime(String runtime) {
    return 'Secure channel runtime: $runtime';
  }

  @override
  String get configNoRuntime => 'No runtime selected - choose one below';

  @override
  String get configAgentRuntime => 'Agent Runtime';

  @override
  String get configAgentRuntimeHelper =>
      'Select the runtime used by the secure channel';

  @override
  String configRuntimeSet(String runtime) {
    return 'Active runtime set to $runtime';
  }

  @override
  String get configRuntimeCleared => 'Runtime cleared';

  @override
  String get configSupportProviders => 'Support Model Providers';

  @override
  String get configSupportProvidersSubtitle =>
      'Optional helpers for memory, summaries, OCR cleanup, and background tasks';

  @override
  String get configPreferredSupportProvider => 'Preferred Support Provider';

  @override
  String get configSupportProviderAuto => 'Auto';

  @override
  String get configSupportProvidersNote =>
      'Support providers cannot complete setup or receive desktop-control authority unless wrapped by an agent runtime.';

  @override
  String get configRequestPolicy => 'Runtime Request Policy';

  @override
  String get configConcurrentRequests => 'Concurrent Requests';

  @override
  String get configConcurrentRequestsHint => 'Max concurrent runtime requests';

  @override
  String get configRuntimeTimeout => 'Runtime Timeout (sec)';

  @override
  String get configAutoRestart => 'Auto-restart Runtime on Failure';

  @override
  String get configProxySettings => 'Proxy Settings';

  @override
  String get configUseProxy => 'Use Proxy Server';

  @override
  String get configProxyHost => 'Proxy Host';

  @override
  String get configProxyHostHint => 'e.g., proxy.example.com';

  @override
  String get configProxyPort => 'Proxy Port';

  @override
  String get configConnectionSettings => 'Connection Settings';

  @override
  String get configRequestTimeout => 'Request Timeout (sec)';

  @override
  String get configMaxRetries => 'Max Retries';

  @override
  String get configAppearance => 'Appearance';

  @override
  String get configTheme => 'Theme';

  @override
  String get configLanguage => 'Language';

  @override
  String get configNotifications => 'Notifications';

  @override
  String get configEnableNotifications => 'Enable Notifications';

  @override
  String get configShowTrayIcon => 'Show Tray Icon';

  @override
  String get configSecurity => 'Security';

  @override
  String get configEncryptLocalData => 'Encrypt Local Data';

  @override
  String get configEncryptLocalDataSubtitle =>
      'Encrypt conversation history and settings';

  @override
  String get configBiometric => 'Require Biometric Auth';

  @override
  String get configBiometricSubtitle => 'Require fingerprint/auth to open app';

  @override
  String get configSessionTimeout => 'Session Timeout (min)';

  @override
  String get configSessionTimeoutHint => 'Auto-lock after inactivity';

  @override
  String get configRememberTokens => 'Remember Authentication Tokens';

  @override
  String get configDeveloperOptions => 'Developer Options';

  @override
  String get configDebugMode => 'Debug Mode';

  @override
  String get configDebugModeSubtitle =>
      'Enable additional debugging information';

  @override
  String get configVerboseLogging => 'Verbose Logging';

  @override
  String get configVerboseLoggingSubtitle =>
      'Log detailed diagnostic information';

  @override
  String get configShowDevTools => 'Show Developer Tools';

  @override
  String get configShowDevToolsSubtitle =>
      'Enable development tools and inspectors';

  @override
  String get configDataRetention => 'Data Retention';

  @override
  String get configMaxHistory => 'Max Conversation History';

  @override
  String get configMaxHistoryHint =>
      'Maximum number of conversations to store locally';

  @override
  String get configAutoCleanup => 'Auto-cleanup Old Data';

  @override
  String get configCacheManagement => 'Cache Management';

  @override
  String get configEnableCache => 'Enable Response Cache';

  @override
  String get configCacheSize => 'Cache Size Limit (MB)';

  @override
  String get configClearCacheNow => 'Clear Cache Now';

  @override
  String get configApplication => 'Application';

  @override
  String get configVersion => 'Version';

  @override
  String configVersionValue(String version, String build) {
    return '$version (build $build)';
  }

  @override
  String get configPlatform => 'Platform';

  @override
  String get configDartVersion => 'Dart Version';

  @override
  String get configSettingsPages => 'Settings pages';

  @override
  String get configPaths => 'Paths';

  @override
  String get configAppPath => 'App Path';

  @override
  String get configConfigPath => 'Config Path';

  @override
  String get configDataPath => 'Data Path';

  @override
  String get configWorkingDirectory => 'Working Directory';

  @override
  String get configSoftwareUpdates => 'Software Updates';

  @override
  String get configCheckingUpdates => 'Checking for updates...';

  @override
  String get configDownloadingUpdate => 'Downloading update...';

  @override
  String get configInstallingUpdate => 'Installing update...';

  @override
  String configUpdateAvailable(String version) {
    return 'Update Available: $version';
  }

  @override
  String configCurrentVersion(String version) {
    return 'Current version: $version';
  }

  @override
  String get configDownloadUpdate => 'Download Update';

  @override
  String get configViewChangelog => 'View Changelog';

  @override
  String get configUpdateReady => 'Update Ready to Install';

  @override
  String get configInstallRestart => 'Install & Restart';

  @override
  String get configUpToDate => 'Up to date';

  @override
  String get configCheckNow => 'Check Now';

  @override
  String get configExport => 'Export';

  @override
  String get configImport => 'Import';

  @override
  String get configClearCacheTitle => 'Clear Cache';

  @override
  String get configCacheUnit => 'MB';

  @override
  String configClearCacheConfirmMeasured(String size) {
    return 'Delete generated speech audio and cached images? ($size on disk)';
  }

  @override
  String configCacheClearedFreed(String size) {
    return 'Cache cleared ($size freed)';
  }

  @override
  String configCacheClearFailed(String error) {
    return 'Could not clear the cache: $error';
  }

  @override
  String get configUpdateMajor =>
      'Major version - may include breaking changes';

  @override
  String get configUpdateMinor =>
      'Minor version - new features and improvements';

  @override
  String get configUpdatePatch =>
      'Patch version - bug fixes and security updates';

  @override
  String configWhatsNew(String version) {
    return 'What\'s New in $version';
  }

  @override
  String get configNoChangelog => 'No changelog available';
}
