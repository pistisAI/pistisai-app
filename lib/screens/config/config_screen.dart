/// Configuration screen for gateway, app, and system settings.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as file_selector;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../brand/brand_copy.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../services/app_cache_service.dart';
import '../../services/auto_update_service.dart';
import '../../services/connection_manager_service.dart' as runtime;
import '../../services/settings_preference_service.dart';
import '../../services/settings_import_export_service.dart';
import '../../services/theme_provider.dart';
import '../../utils/file_download_helper.dart';
import '../../di/locator.dart';
import '../../l10n/app_localizations.dart';

class _SettingsPageLink {
  const _SettingsPageLink(this.label, this.subtitle, this.route, this.icon);

  final String label;
  final String subtitle;
  final String route;
  final IconData icon;
}

List<_SettingsPageLink> _settingsPages(AppLocalizations l10n) => [
      _SettingsPageLink(
        l10n.configPageGeneral,
        l10n.configPageGeneralSubtitle,
        '/settings/general',
        Icons.tune,
      ),
      _SettingsPageLink(
        l10n.configPageAppearance,
        l10n.configPageAppearanceSubtitle,
        '/settings/appearance',
        Icons.palette_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageConnection,
        l10n.configPageConnectionSubtitle,
        '/settings/connection',
        Icons.lan_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageLlm,
        l10n.configPageLlmSubtitle,
        '/settings/llm',
        Icons.psychology_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageVision,
        l10n.configPageVisionSubtitle,
        '/settings/vision',
        Icons.visibility_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageAvatar,
        l10n.configPageAvatarSubtitle,
        '/settings/avatar',
        Icons.face_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageAchievements,
        l10n.configPageAchievementsSubtitle,
        '/settings/achievements',
        Icons.emoji_events_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageDesktop,
        l10n.configPageDesktopSubtitle,
        '/settings/desktop',
        Icons.desktop_windows_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageAbout,
        '',
        '/settings/about',
        Icons.info_outline,
      ),
      _SettingsPageLink(
        l10n.configPagePlans,
        l10n.configPagePlansSubtitle,
        '/upgrade',
        Icons.workspace_premium_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageBrain,
        l10n.configPageBrainSubtitle,
        '/brain-insights',
        Icons.bubble_chart_outlined,
      ),
      _SettingsPageLink(
        l10n.configPageRoadmap,
        l10n.configPageRoadmapSubtitle,
        '/construction',
        Icons.construction_outlined,
      ),
    ];

/// Configuration screen with tabbed organization for better UX.
/// Settings are persisted via SettingsPreferenceService and ConnectionManagerService.
class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Runtime Settings
  String _selectedSupportProvider = 'Auto';
  int _rateLimit = 1;
  bool _autoRestart = true;
  int _runtimeTimeout = 30;

  // Network Settings
  bool _useProxy = false;
  String _proxyHost = '';
  int _proxyPort = 8080;
  int _maxRetries = 3;
  int _requestTimeout = 60;

  // App Settings
  /// Stored theme code: 'system', 'light' or 'dark'.
  String _selectedTheme = 'system';

  /// Stored language code: 'en', 'es', 'fr' or 'de'.
  String _selectedLanguage = 'en';

  /// Language names shown in their own language, so they need no translation.
  static const _languageNames = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'de': 'Deutsch',
  };
  bool _notificationsEnabled = true;
  bool _trayIconEnabled = true;

  // Storage Settings
  int _maxConversationHistory = 1000;
  bool _enableCache = true;
  int _cacheSizeMB = 500;
  bool _autoCleanup = true;

  // Security Settings
  bool _encryptLocalData = true;
  bool _biometricAuth = false;
  int _sessionTimeoutMinutes = 30;
  bool _rememberTokens = true;

  // Developer Settings
  bool _debugMode = false;
  bool _verboseLogging = false;
  bool _showDevTools = false;

  // System Info
  final String _buildNumber = '3';
  String _appPath = '';
  String _configPath = '';
  String _dataPath = '';

  // Active Backend
  BackendType? _activeBackend;
  final _settingsService = serviceLocator<SettingsPreferenceService>();
  final _importExportService = serviceLocator<SettingsImportExportService>();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Error raised while loading, formatted in build so the message follows
  /// the current locale.
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSystemInfo();
    _loadActiveBackend();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSystemInfo() async {
    try {
      _appPath = kIsWeb ? '/' : Directory.current.path;
      final home = _getHomeDirectory() ?? '~';
      _configPath = '$home/.config/pistisai';
      _dataPath = '$home/.local/share/pistisai';
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading system info: $e');
    }
  }

  Future<void> _loadActiveBackend() async {
    final backend = await _settingsService.getActiveBackend();
    if (mounted) setState(() => _activeBackend = backend);
  }

  Future<void> _applyRuntimeSelection(BackendType? backend) async {
    final connectionManager = context.read<runtime.ConnectionManagerService>();
    if (backend == BackendType.hermes) {
      connectionManager.switchBackend(runtime.BackendType.hermes);
      await connectionManager.testConnection();
      return;
    }
    connectionManager.clearActiveRuntime();
  }

  String _runtimeLabel(AppLocalizations l10n, BackendType? backend) {
    return switch (backend) {
      BackendType.hermes => 'Hermes Agent',
      _ => l10n.configRuntimeNone,
    };
  }

  String? _getHomeDirectory() {
    if (kIsWeb) {
      return null;
    }

    try {
      return Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
    } catch (e) {
      debugPrint('Error reading home directory from environment: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final theme = await _settingsService.getTheme();
      _selectedTheme = switch (theme) {
        'light' || 'dark' => theme,
        _ => 'system',
      };

      final lang = await _settingsService.getLanguage();
      _selectedLanguage = _languageNames.containsKey(lang) ? lang : 'en';

      _notificationsEnabled = await _settingsService.isNotificationsEnabled();
      _trayIconEnabled = await _settingsService.isMinimizeToTrayEnabled();
      _biometricAuth = await _settingsService.isBiometricAuthEnabled();
      final autoRestart = await _settingsService.getGatewayAutoRestart();
      if (autoRestart != null) _autoRestart = autoRestart;

      // Load Runtime Settings
      _selectedSupportProvider = await _settingsService.getSupportProvider();
      _rateLimit = await _settingsService.getRateLimit();
      _runtimeTimeout = await _settingsService.getRuntimeTimeout();

      // Load Network Settings
      _useProxy = await _settingsService.isProxyEnabled();
      _proxyHost = await _settingsService.getProxyHost();
      _proxyPort = await _settingsService.getProxyPort();
      _maxRetries = await _settingsService.getMaxRetries();
      _requestTimeout = await _settingsService.getRequestTimeout();

      // Load App Settings
      _encryptLocalData = await _settingsService.isEncryptLocalDataEnabled();
      _sessionTimeoutMinutes =
          await _settingsService.getSessionTimeoutMinutes();
      _rememberTokens = await _settingsService.isRememberTokensEnabled();

      // Load Storage Settings
      _maxConversationHistory =
          await _settingsService.getMaxConversationHistory();
      _enableCache = await _settingsService.isCacheEnabled();
      _cacheSizeMB = await _settingsService.getCacheSizeMB();
      _autoCleanup = await _settingsService.isAutoCleanupEnabled();

      // Load Developer Settings
      _debugMode = await _settingsService.isDebugModeEnabled();
      _verboseLogging = await _settingsService.isVerboseLoggingEnabled();
      _showDevTools = await _settingsService.isShowDevToolsEnabled();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _saveConfig() async {
    final l10n = _l10n;
    setState(() => _isSaving = true);
    try {
      final themeString = _selectedTheme;
      await _settingsService.setTheme(themeString);
      // Keep ThemeProvider in sync so the live UI and persistence agree.
      if (mounted) {
        unawaited(
          context.read<ThemeProvider>().setThemeModeFromString(themeString),
        );
      }

      await _settingsService.setLanguage(_selectedLanguage);

      await _settingsService.setNotificationsEnabled(_notificationsEnabled);
      await _settingsService.setMinimizeToTrayEnabled(_trayIconEnabled);
      await _settingsService.setBiometricAuthEnabled(_biometricAuth);
      await _settingsService.setGatewayAutoRestart(_autoRestart);

      // Save Runtime Settings
      await _settingsService.setSupportProvider(_selectedSupportProvider);
      await _settingsService.setRateLimit(_rateLimit);
      await _settingsService.setRuntimeTimeout(_runtimeTimeout);

      // Save Network Settings
      await _settingsService.setProxyEnabled(_useProxy);
      await _settingsService.setProxyHost(_proxyHost);
      await _settingsService.setProxyPort(_proxyPort);
      await _settingsService.setMaxRetries(_maxRetries);
      await _settingsService.setRequestTimeout(_requestTimeout);

      // Save App Settings
      await _settingsService.setEncryptLocalDataEnabled(_encryptLocalData);
      await _settingsService.setSessionTimeoutMinutes(_sessionTimeoutMinutes);
      await _settingsService.setRememberTokensEnabled(_rememberTokens);

      // Save Storage Settings
      await _settingsService.setMaxConversationHistory(_maxConversationHistory);
      await _settingsService.setCacheEnabled(_enableCache);
      await _settingsService.setCacheSizeMB(_cacheSizeMB);
      await _settingsService.setAutoCleanupEnabled(_autoCleanup);

      // Save Developer Settings
      await _settingsService.setDebugModeEnabled(_debugMode);
      await _settingsService.setVerboseLoggingEnabled(_verboseLogging);
      await _settingsService.setShowDevToolsEnabled(_showDevTools);

      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(l10n.configSaved, isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnackBar(l10n.configSaveFailed('$e'), isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final l10n = _l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.configResetTitle),
        content: Text(l10n.configResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonReset),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _settingsService.clearRuntimePreferences();
      if (!mounted) return;
      await _loadData();
      if (mounted) {
        _showSnackBar(l10n.configResetDone, isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l10n.configResetFailed('$e'), isError: true);
      }
    }
  }

  Future<void> _exportSettings() async {
    final l10n = _l10n;
    try {
      final jsonString = await _importExportService.exportSettingsToJson();
      final filename = _importExportService.generateExportFilename();

      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        downloadFile(bytes, filename, 'application/json');
      } else {
        final saveLocation = await file_selector.getSaveLocation(
          acceptedTypeGroups: [
            file_selector.XTypeGroup(label: 'JSON', extensions: ['json']),
          ],
          suggestedName: filename,
        );
        // The user closed the dialog: nothing was written, so say nothing.
        if (saveLocation == null) return;
        await File(saveLocation.path).writeAsString(jsonString);
      }

      if (mounted) {
        _showSnackBar(l10n.configExported(filename), isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l10n.configExportFailed('$e'), isError: true);
      }
    }
  }

  Future<void> _importSettings() async {
    final l10n = _l10n;
    try {
      final file = await file_selector.openFile(
        acceptedTypeGroups: [
          file_selector.XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
          ),
        ],
      );
      if (file == null) return;

      final content = await file.readAsString();
      final settings =
          await _importExportService.importSettingsFromJson(content);
      await _importExportService.applyImportedSettings(settings);
      if (mounted) {
        await _loadData();
        _showSnackBar(l10n.configImported, isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l10n.configImportFailed('$e'), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final errorMessage = _loadError != null
        ? l10n.configLoadFailed('$_loadError')
        : _errorMessage;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chat'),
          tooltip: l10n.configBackToChannel,
        ),
        title: Text(l10n.configTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: l10n.commonRefresh,
          ),
          IconButton(
            onPressed: _isSaving ? null : _saveConfig,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: l10n.commonSave,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.configTabRuntime, icon: const Icon(Icons.hub)),
            Tab(text: l10n.configTabMesh, icon: const Icon(Icons.wifi)),
            Tab(text: l10n.configTabApp, icon: const Icon(Icons.smartphone)),
            Tab(text: l10n.configTabStorage, icon: const Icon(Icons.storage)),
            Tab(text: l10n.configTabSystem, icon: const Icon(Icons.info)),
          ],
        ),
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: errorMessage,
        child: _isLoading
            ? const LoadingSkeleton(itemCount: 3)
            : errorMessage != null
                ? ErrorState(message: errorMessage, onRetry: _loadData)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGatewayTab(l10n),
                      _buildNetworkTab(l10n),
                      _buildAppTab(l10n),
                      _buildStorageTab(l10n),
                      _buildSystemTab(l10n),
                    ],
                  ),
      ),
    );
  }

  Widget _buildGatewayTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: l10n.configActiveRuntime,
          subtitle: _activeBackend != null
              ? l10n.configSecureChannelRuntime(
                  _runtimeLabel(l10n, _activeBackend))
              : l10n.configNoRuntime,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButtonFormField<BackendType?>(
                initialValue: _activeBackend,
                decoration: InputDecoration(
                  labelText: l10n.configAgentRuntime,
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  helperText: l10n.configAgentRuntimeHelper,
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.configRuntimeNone),
                  ),
                  const DropdownMenuItem(
                    value: BackendType.hermes,
                    child: Text('Hermes Agent'),
                  ),
                ],
                onChanged: (value) async {
                  setState(() => _activeBackend = value);
                  await _settingsService.setActiveBackend(value);
                  await _applyRuntimeSelection(value);
                  if (mounted) {
                    _showSnackBar(
                      value != null
                          ? l10n.configRuntimeSet(_runtimeLabel(l10n, value))
                          : l10n.configRuntimeCleared,
                      isError: false,
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configSupportProviders,
          subtitle: l10n.configSupportProvidersSubtitle,
          children: [
            _dropdown(
              l10n.configPreferredSupportProvider,
              {
                'Auto': l10n.configSupportProviderAuto,
                'Ollama': 'Ollama',
                'LM Studio': 'LM Studio',
                'OpenAI-compatible': 'OpenAI-compatible',
              },
              _selectedSupportProvider,
              (v) async {
                final val = v!;
                setState(() => _selectedSupportProvider = val);
                await _settingsService.setSupportProvider(val);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(l10n.configSupportProvidersNote),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configRequestPolicy,
          children: [
            _field(l10n.configConcurrentRequests, '$_rateLimit', (v) async {
              final l = int.tryParse(v);
              if (l != null && l > 0) {
                setState(() => _rateLimit = l);
                await _settingsService.setRateLimit(l);
              }
            }, numeric: true, hint: l10n.configConcurrentRequestsHint),
            _field(l10n.configRuntimeTimeout, '$_runtimeTimeout', (v) async {
              final l = int.tryParse(v);
              if (l != null && l > 0) {
                setState(() => _runtimeTimeout = l);
                await _settingsService.setRuntimeTimeout(l);
              }
            }, numeric: true),
            _switch(l10n.configAutoRestart, _autoRestart, (v) async {
              setState(() => _autoRestart = v);
              await _settingsService.setGatewayAutoRestart(v);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildNetworkTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: l10n.configProxySettings,
          children: [
            _switch(l10n.configUseProxy, _useProxy, (v) async {
              setState(() => _useProxy = v);
              await _settingsService.setProxyEnabled(v);
            }),
            if (_useProxy) ...[
              _field(l10n.configProxyHost, _proxyHost, (v) async {
                setState(() => _proxyHost = v);
                await _settingsService.setProxyHost(v);
              }, hint: l10n.configProxyHostHint),
              _field(l10n.configProxyPort, '$_proxyPort', (v) async {
                final p = int.tryParse(v);
                if (p != null && p > 0 && p < 65536) {
                  setState(() => _proxyPort = p);
                  await _settingsService.setProxyPort(p);
                }
              }, numeric: true),
            ],
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configConnectionSettings,
          children: [
            _field(l10n.configRequestTimeout, '$_requestTimeout', (v) async {
              final t = int.tryParse(v);
              if (t != null && t > 0) {
                setState(() => _requestTimeout = t);
                await _settingsService.setRequestTimeout(t);
              }
            }, numeric: true),
            _field(l10n.configMaxRetries, '$_maxRetries', (v) async {
              final r = int.tryParse(v);
              if (r != null && r >= 0) {
                setState(() => _maxRetries = r);
                await _settingsService.setMaxRetries(r);
              }
            }, numeric: true),
          ],
        ),
      ],
    );
  }

  Widget _buildAppTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: l10n.configAppearance,
          children: [
            _dropdown(
                l10n.configTheme,
                {
                  'system': l10n.themeSystem,
                  'light': l10n.themeLight,
                  'dark': l10n.themeDark,
                },
                _selectedTheme, (v) async {
              final val = v!;
              setState(() => _selectedTheme = val);
              await _settingsService.setTheme(val);
            }),
            _dropdown(l10n.configLanguage, _languageNames, _selectedLanguage,
                (v) async {
              final val = v!;
              setState(() => _selectedLanguage = val);
              await _settingsService.setLanguage(val);
            }),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configNotifications,
          children: [
            _switch(l10n.configEnableNotifications, _notificationsEnabled,
                (v) async {
              setState(() => _notificationsEnabled = v);
              await _settingsService.setNotificationsEnabled(v);
            }),
            if (!kIsWeb)
              _switch(l10n.configShowTrayIcon, _trayIconEnabled, (v) async {
                setState(() => _trayIconEnabled = v);
                await _settingsService.setMinimizeToTrayEnabled(v);
              }),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configSecurity,
          children: [
            _switch(l10n.configEncryptLocalData, _encryptLocalData, (v) async {
              setState(() => _encryptLocalData = v);
              await _settingsService.setEncryptLocalDataEnabled(v);
            }, subtitle: l10n.configEncryptLocalDataSubtitle),
            if (!kIsWeb)
              _switch(l10n.configBiometric, _biometricAuth, (v) async {
                setState(() => _biometricAuth = v);
                await _settingsService.setBiometricAuthEnabled(v);
              }, subtitle: l10n.configBiometricSubtitle),
            _field(l10n.configSessionTimeout, '$_sessionTimeoutMinutes',
                (v) async {
              final t = int.tryParse(v);
              if (t != null && t > 0) {
                setState(() => _sessionTimeoutMinutes = t);
                await _settingsService.setSessionTimeoutMinutes(t);
              }
            }, numeric: true, hint: l10n.configSessionTimeoutHint),
            _switch(l10n.configRememberTokens, _rememberTokens, (v) async {
              setState(() => _rememberTokens = v);
              await _settingsService.setRememberTokensEnabled(v);
            }),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configDeveloperOptions,
          children: [
            _switch(l10n.configDebugMode, _debugMode, (v) async {
              setState(() => _debugMode = v);
              await _settingsService.setDebugModeEnabled(v);
            }, subtitle: l10n.configDebugModeSubtitle),
            _switch(l10n.configVerboseLogging, _verboseLogging, (v) async {
              setState(() => _verboseLogging = v);
              await _settingsService.setVerboseLoggingEnabled(v);
            }, subtitle: l10n.configVerboseLoggingSubtitle),
            _switch(l10n.configShowDevTools, _showDevTools, (v) async {
              setState(() => _showDevTools = v);
              await _settingsService.setShowDevToolsEnabled(v);
            }, subtitle: l10n.configShowDevToolsSubtitle),
          ],
        ),
      ],
    );
  }

  Widget _buildStorageTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: l10n.configDataRetention,
          children: [
            _field(l10n.configMaxHistory, '$_maxConversationHistory',
                (v) async {
              final h = int.tryParse(v);
              if (h != null && h >= 0) {
                setState(() => _maxConversationHistory = h);
                await _settingsService.setMaxConversationHistory(h);
              }
            }, numeric: true, hint: l10n.configMaxHistoryHint),
            _switch(l10n.configAutoCleanup, _autoCleanup, (v) async {
              setState(() => _autoCleanup = v);
              await _settingsService.setAutoCleanupEnabled(v);
            }),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configCacheManagement,
          children: [
            _switch(l10n.configEnableCache, _enableCache, (v) async {
              setState(() => _enableCache = v);
              await _settingsService.setCacheEnabled(v);
            }),
            if (_enableCache)
              _field(l10n.configCacheSize, '$_cacheSizeMB', (v) async {
                final c = int.tryParse(v);
                if (c != null && c > 0) {
                  setState(() => _cacheSizeMB = c);
                  await _settingsService.setCacheSizeMB(c);
                }
              }, numeric: true),
            if (_enableCache)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.cleaning_services, size: 18),
                  label: Text(l10n.configClearCacheNow),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemTab(AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CardSection(
          title: l10n.configApplication,
          children: [
            _readOnly(l10n.configVersion,
                l10n.configVersionValue(AppConfig.appVersion, _buildNumber)),
            _readOnly(l10n.configPlatform,
                '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'),
            _readOnly(
                l10n.configDartVersion, Platform.version.split(' ').first),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configSettingsPages,
          children: [
            for (final page in _settingsPages(l10n))
              ListTile(
                leading: Icon(page.icon),
                title: Text(page.label),
                subtitle: Text(
                  page.route == '/settings/about'
                      ? BrandCopy.settingsAboutSubtitle
                      : page.subtitle,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(page.route),
              ),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configPaths,
          children: [
            if (_appPath.isNotEmpty) _readOnly(l10n.configAppPath, _appPath),
            if (_configPath.isNotEmpty)
              _readOnly(l10n.configConfigPath, _configPath),
            if (_dataPath.isNotEmpty) _readOnly(l10n.configDataPath, _dataPath),
            _readOnly(l10n.configWorkingDirectory, Directory.current.path),
          ],
        ),
        const SizedBox(height: 16),
        CardSection(
          title: l10n.configSoftwareUpdates,
          children: [
            Consumer<AutoUpdateService>(
              builder: (context, updateService, child) {
                final status = updateService.status;
                final updateInfo = updateService.updateInfo;

                if (status == UpdateStatus.checking) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.configCheckingUpdates),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.downloading) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.configDownloadingUpdate),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.installing) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(l10n.configInstallingUpdate),
                        ],
                      ),
                    ),
                  );
                }

                if (status == UpdateStatus.updateAvailable &&
                    updateInfo != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.new_releases,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.configUpdateAvailable(
                                    updateInfo.latestVersion),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.configCurrentVersion(updateInfo.currentVersion),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getUpdateTypeLabel(l10n, updateInfo.type),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => updateService.downloadUpdate(),
                              icon: const Icon(Icons.download, size: 18),
                              label: Text(l10n.configDownloadUpdate),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _showChangelogDialog(context, updateInfo),
                              icon: const Icon(Icons.description, size: 18),
                              label: Text(l10n.configViewChangelog),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                if (status == UpdateStatus.downloaded) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppTheme.colorsOf(context).success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.configUpdateReady,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppTheme.colorsOf(context).success,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => updateService.installUpdate(),
                          icon: const Icon(Icons.restart_alt, size: 18),
                          label: Text(l10n.configInstallRestart),
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.configUpToDate,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => updateService.checkForUpdates(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(l10n.configCheckNow),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restore),
                  label: Text(l10n.configResetTitle),
                ),
                OutlinedButton.icon(
                  onPressed: _exportSettings,
                  icon: const Icon(Icons.download),
                  label: Text(l10n.configExport),
                ),
                OutlinedButton.icon(
                  onPressed: _importSettings,
                  icon: const Icon(Icons.upload),
                  label: Text(l10n.configImport),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _clearCache() async {
    final l10n = _l10n;
    // The size shown and the result reported are measured, not assumed.
    final cache = kIsWeb ? null : AppCacheService();
    final sizeBefore = await cache?.sizeInBytes() ?? 0;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.configClearCacheTitle),
        content: Text(
          l10n.configClearCacheConfirmMeasured(
            AppCacheService.formatMegabytes(sizeBefore, unit: l10n.configCacheUnit),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      final freed = await cache?.clear() ?? 0;
      if (mounted) {
        _showSnackBar(
          l10n.configCacheClearedFreed(AppCacheService.formatMegabytes(freed, unit: l10n.configCacheUnit)),
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(l10n.configCacheClearFailed('$e'), isError: true);
      }
    }
  }

  /// Dropdown over [items], a map from stored value to displayed label.
  Widget _dropdown(String label, Map<String, String> items, String value,
      ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged,
      {bool numeric = false, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        keyboardType: numeric ? TextInputType.number : null,
        onChanged: onChanged,
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged,
      {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile(
        title: Text(label),
        subtitle: subtitle != null
            ? Text(subtitle, style: const TextStyle(fontSize: 12))
            : null,
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _readOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        enabled: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }

  String _getUpdateTypeLabel(AppLocalizations l10n, UpdateType type) {
    switch (type) {
      case UpdateType.major:
        return l10n.configUpdateMajor;
      case UpdateType.minor:
        return l10n.configUpdateMinor;
      case UpdateType.patch:
        return l10n.configUpdatePatch;
      case UpdateType.none:
        return '';
    }
  }

  void _showChangelogDialog(BuildContext context, UpdateInfo info) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.configWhatsNew(info.latestVersion)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.changelog != null && info.changelog!.isNotEmpty)
                  MarkdownBody(data: info.changelog!)
                else
                  Text(l10n.configNoChangelog),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
