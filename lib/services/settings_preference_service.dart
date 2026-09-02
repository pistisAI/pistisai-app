import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

enum BackendType { openclaw, hermes }

class SettingsPreferenceService {
  static const String _proModeKey = 'settings_pro_mode';
  static const String _themeKey = 'settings_theme';
  static const String _languageKey = 'settings_language';

  // Privacy Settings
  static const String _analyticsKey = 'settings_analytics_enabled';
  static const String _crashReportingKey = 'settings_crash_reporting_enabled';
  static const String _usageStatsKey = 'settings_usage_stats_enabled';

  // Desktop Settings
  static const String _launchOnStartupKey = 'settings_launch_on_startup';
  static const String _minimizeToTrayKey = 'settings_minimize_to_tray';
  static const String _alwaysOnTopKey = 'settings_always_on_top';
  static const String _rememberWindowPositionKey =
      'settings_remember_window_position';
  static const String _rememberWindowSizeKey = 'settings_remember_window_size';
  static const String _windowPositionXKey = 'settings_window_position_x';
  static const String _windowPositionYKey = 'settings_window_position_y';
  static const String _windowWidthKey = 'settings_window_width';
  static const String _windowHeightKey = 'settings_window_height';
  static const String _gatewayAutoRestartKey = 'settings_gateway_auto_restart';
  static const String _gatewayUrlKey = 'settings_gateway_url';

  // Active Backend
  static const String _activeBackendKey = 'settings_active_backend';

  // Runtime Settings
  static const String _supportProviderKey = 'settings_support_provider';
  static const String _rateLimitKey = 'settings_rate_limit';
  static const String _runtimeTimeoutKey = 'settings_runtime_timeout';

  // Network Settings
  static const String _useProxyKey = 'settings_use_proxy';
  static const String _proxyHostKey = 'settings_proxy_host';
  static const String _proxyPortKey = 'settings_proxy_port';
  static const String _maxRetriesKey = 'settings_max_retries';
  static const String _requestTimeoutKey = 'settings_request_timeout';

  // App Settings
  static const String _encryptLocalDataKey = 'settings_encrypt_local_data';
  static const String _sessionTimeoutMinutesKey = 'settings_session_timeout_minutes';
  static const String _rememberTokensKey = 'settings_remember_tokens';

  // Storage Settings
  static const String _maxConversationHistoryKey = 'settings_max_conversation_history';
  static const String _enableCacheKey = 'settings_enable_cache';
  static const String _cacheSizeMBKey = 'settings_cache_size_mb';
  static const String _autoCleanupKey = 'settings_auto_cleanup';

  // Avatar Settings
  static const String _avatarFormalityKey = 'avatar_formality';
  static const String _avatarHumorKey = 'avatar_humor';
  static const String _avatarEnthusiasmKey = 'avatar_enthusiasm';
  static const String _avatarEmpathyKey = 'avatar_empathy';
  static const String _avatarColorThemeKey = 'avatar_color_theme';
  static const String _avatarAnimationStyleKey = 'avatar_animation_style';
  static const String _avatarTypeKey = 'avatar_type';
  static const String _avatarSizeKey = 'avatar_size';
  static const String _avatarGlowEnabledKey = 'avatar_glow_enabled';
  static const String _avatarColorOverrideKey = 'avatar_color_override';

  // Developer Settings
  static const String _debugModeKey = 'settings_debug_mode';
  static const String _verboseLoggingKey = 'settings_verbose_logging';
  static const String _showDevToolsKey = 'settings_show_dev_tools';

  // Hermes Settings
  static const String _hermesEnabledKey = 'settings_hermes_enabled';
  static const String _hermesUrlKey = 'settings_hermes_url';
  static const String _hermesApiKeyKey = 'settings_hermes_api_key';

  // Mobile Settings
  static const String _biometricAuthKey = 'settings_biometric_auth_enabled';
  static const String _notificationsKey = 'settings_notifications_enabled';
  static const String _notificationSoundKey =
      'settings_notification_sound_enabled';
  static const String _vibrationKey = 'settings_vibration_enabled';

  // Pro Mode
  Future<bool> isProMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proModeKey) ?? false;
  }

  Future<void> setProMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proModeKey, value);
  }

  // Theme Preference
  /// Get the saved theme preference ('light', 'dark', or 'system')
  Future<String> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }

  /// Save the theme preference
  Future<void> setTheme(String theme) async {
    if (!['light', 'dark', 'system'].contains(theme)) {
      throw ArgumentError('Invalid theme: $theme');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  // Language Preference
  /// Get the saved language preference (language code like 'en', 'es', etc.)
  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  /// Save the language preference
  Future<void> setLanguage(String language) async {
    if (!['en', 'es', 'fr', 'de', 'ja', 'zh'].contains(language)) {
      throw ArgumentError('Invalid language: $language');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  // Privacy Settings
  /// Get analytics enabled preference
  Future<bool> isAnalyticsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_analyticsKey) ?? true;
  }

  /// Set analytics enabled preference
  Future<void> setAnalyticsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsKey, value);
  }

  /// Get crash reporting enabled preference
  Future<bool> isCrashReportingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_crashReportingKey) ?? true;
  }

  /// Set crash reporting enabled preference
  Future<void> setCrashReportingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashReportingKey, value);
  }

  /// Get usage statistics enabled preference
  Future<bool> isUsageStatsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_usageStatsKey) ?? true;
  }

  /// Set usage statistics enabled preference
  Future<void> setUsageStatsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_usageStatsKey, value);
  }

  /// Clear all stored preferences
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Desktop Settings

  /// Get launch on startup preference
  Future<bool> isLaunchOnStartupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_launchOnStartupKey) ?? false;
  }

  /// Set launch on startup preference
  Future<void> setLaunchOnStartupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_launchOnStartupKey, value);
  }

  /// Get minimize to tray preference
  Future<bool> isMinimizeToTrayEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_minimizeToTrayKey) ?? false;
  }

  /// Set minimize to tray preference
  Future<void> setMinimizeToTrayEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  /// Get always on top preference
  Future<bool> isAlwaysOnTopEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_alwaysOnTopKey) ?? false;
  }

  /// Set always on top preference
  Future<void> setAlwaysOnTopEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alwaysOnTopKey, value);
  }

  /// Get remember window position preference
  Future<bool> isRememberWindowPositionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberWindowPositionKey) ?? true;
  }

  /// Set remember window position preference
  Future<void> setRememberWindowPositionEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberWindowPositionKey, value);
  }

  /// Get remember window size preference
  Future<bool> isRememberWindowSizeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberWindowSizeKey) ?? true;
  }

  /// Set remember window size preference
  Future<void> setRememberWindowSizeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberWindowSizeKey, value);
  }

  /// Get saved window position
  Future<Map<String, double>> getWindowPosition() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'x': prefs.getDouble(_windowPositionXKey) ?? 0.0,
      'y': prefs.getDouble(_windowPositionYKey) ?? 0.0,
    };
  }

  /// Save window position
  Future<void> setWindowPosition(double x, double y) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowPositionXKey, x);
    await prefs.setDouble(_windowPositionYKey, y);
  }

  /// Get saved window size
  Future<Map<String, double>> getWindowSize() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'width': prefs.getDouble(_windowWidthKey) ?? 1280.0,
      'height': prefs.getDouble(_windowHeightKey) ?? 720.0,
    };
  }

  /// Save window size
  Future<void> setWindowSize(double width, double height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowWidthKey, width);
    await prefs.setDouble(_windowHeightKey, height);
  }

  // Mobile Settings

  /// Get biometric authentication enabled preference
  Future<bool> isBiometricAuthEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricAuthKey) ?? false;
  }

  /// Set biometric authentication enabled preference
  Future<void> setBiometricAuthEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricAuthKey, value);
  }

  /// Get notifications enabled preference
  Future<bool> isNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsKey) ?? true;
  }

  /// Set notifications enabled preference
  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  /// Get notification sound enabled preference
  Future<bool> isNotificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationSoundKey) ?? true;
  }

  /// Set notification sound enabled preference
  Future<void> setNotificationSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundKey, value);
  }

  /// Get vibration enabled preference
  Future<bool> isVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey) ?? true;
  }

  /// Set vibration enabled preference
  Future<void> setVibrationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationKey, value);
  }

  // Gateway Settings

  /// Get gateway auto-restart enabled preference
  Future<bool?> getGatewayAutoRestart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_gatewayAutoRestartKey);
  }

  /// Set gateway auto-restart enabled preference
  Future<void> setGatewayAutoRestart(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_gatewayAutoRestartKey, value);
  }

  /// Get configured gateway URL (returns null if using default)
  Future<String?> getGatewayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gatewayUrlKey);
  }

  /// Set gateway URL (set to empty string to use default)
  Future<void> setGatewayUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_gatewayUrlKey);
    } else {
      await prefs.setString(_gatewayUrlKey, value);
    }
  }

  // ==========================================================================
  // Active Backend Selection
  // ==========================================================================

  /// Get the active backend type. Returns null if no backend is selected.
  Future<BackendType?> getActiveBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_activeBackendKey);
    if (value == null) return null;
    return BackendType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BackendType.openclaw,
    );
  }

  /// Set the active backend type. Pass null to clear (no backend selected).
  Future<void> setActiveBackend(BackendType? type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == null) {
      await prefs.remove(_activeBackendKey);
    } else {
      await prefs.setString(_activeBackendKey, type.name);
    }
  }

  // ==========================================================================
  // Hermes Agent Settings
  // ==========================================================================

  /// Whether Hermes Agent backend is enabled
  Future<bool> isHermesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hermesEnabledKey) ?? false;
  }

  Future<void> setHermesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hermesEnabledKey, value);
  }

  /// Hermes API server URL (default: http://127.0.0.1:8642)
  Future<String?> getHermesUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hermesUrlKey);
    if (stored == null || stored.isEmpty) {
      return stored;
    }
    return AppConfig.normalizeHermesUrl(stored);
  }

  Future<void> setHermesUrl(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_hermesUrlKey);
    } else {
      await prefs.setString(_hermesUrlKey, AppConfig.normalizeHermesUrl(value));
    }
  }

  /// Hermes API key (optional — Hermes doesn't require auth by default)
  Future<String?> getHermesApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_hermesApiKeyKey);
    if (key != null && key.isNotEmpty) {
      return key;
    }
    // Fallback: auto-discover the key from the Hermes .env file so the
    // wizard "just works" without manual configuration.
    return await _discoverHermesApiKeyFromEnv();
  }

  /// Auto-discover the Hermes API_SERVER_KEY from the Hermes .env file.
  /// On Windows: %HERMES_HOME%\.env or %LOCALAPPDATA%\hermes\.env
  /// On Linux:   $HERMES_HOME/.env or ~/.hermes/.env
  Future<String?> _discoverHermesApiKeyFromEnv() async {
    if (kIsWeb) return null;
    try {
      final envPaths = <String>[
        // HERMES_HOME env var (highest priority)
        if (Platform.environment.containsKey('HERMES_HOME'))
          '${Platform.environment['HERMES_HOME']}/.env',
        // Windows default
        if (Platform.environment.containsKey('LOCALAPPDATA'))
          '${Platform.environment['LOCALAPPDATA']}/hermes/.env',
        // Linux/macOS default
        if (Platform.environment.containsKey('HOME'))
          '${Platform.environment['HOME']}/.hermes/.env',
        if (Platform.environment.containsKey('USERPROFILE'))
          '${Platform.environment['USERPROFILE']}/.hermes/.env',
      ];

      for (final envPath in envPaths) {
        final file = File(envPath);
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        for (final line in content.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('API_SERVER_KEY=')) {
            final value = trimmed.substring('API_SERVER_KEY='.length).trim();
            if (value.isNotEmpty) {
              debugPrint(
                  '[SettingsPreference] Auto-discovered Hermes API key from $envPath');
              // Persist it so future reads don't need the file scan
              final p = await SharedPreferences.getInstance();
              await p.setString(_hermesApiKeyKey, value);
              return value;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[SettingsPreference] Hermes .env discovery error: $e');
    }
    return null;
  }

  Future<void> setHermesApiKey(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.isEmpty) {
      await prefs.remove(_hermesApiKeyKey);
    } else {
      await prefs.setString(_hermesApiKeyKey, value);
    }
  }

  // ==========================================================================
  // Runtime Settings
  // ==========================================================================

  /// Get the preferred support model provider
  Future<String> getSupportProvider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_supportProviderKey) ?? 'Auto';
  }

  /// Set the preferred support model provider
  Future<void> setSupportProvider(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supportProviderKey, value);
  }

  /// Get the rate limit (max concurrent requests)
  Future<int> getRateLimit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_rateLimitKey) ?? 1;
  }

  /// Set the rate limit (max concurrent requests)
  Future<void> setRateLimit(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rateLimitKey, value);
  }

  /// Get the runtime timeout in seconds
  Future<int> getRuntimeTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_runtimeTimeoutKey) ?? 30;
  }

  /// Set the runtime timeout in seconds
  Future<void> setRuntimeTimeout(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_runtimeTimeoutKey, value);
  }

  // ==========================================================================
  // Network Settings
  // ==========================================================================

  /// Get whether proxy is enabled
  Future<bool> isProxyEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useProxyKey) ?? false;
  }

  /// Set whether proxy is enabled
  Future<void> setProxyEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useProxyKey, value);
  }

  /// Get the proxy host
  Future<String> getProxyHost() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proxyHostKey) ?? '';
  }

  /// Set the proxy host
  Future<void> setProxyHost(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proxyHostKey, value);
  }

  /// Get the proxy port
  Future<int> getProxyPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_proxyPortKey) ?? 8080;
  }

  /// Set the proxy port
  Future<void> setProxyPort(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_proxyPortKey, value);
  }

  /// Get max retries
  Future<int> getMaxRetries() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxRetriesKey) ?? 3;
  }

  /// Set max retries
  Future<void> setMaxRetries(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxRetriesKey, value);
  }

  /// Get request timeout in seconds
  Future<int> getRequestTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_requestTimeoutKey) ?? 60;
  }

  /// Set request timeout in seconds
  Future<void> setRequestTimeout(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_requestTimeoutKey, value);
  }

  // ==========================================================================
  // App Settings (additional)
  // ==========================================================================

  /// Get encrypt local data preference
  Future<bool> isEncryptLocalDataEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_encryptLocalDataKey) ?? true;
  }

  /// Set encrypt local data preference
  Future<void> setEncryptLocalDataEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_encryptLocalDataKey, value);
  }

  /// Get session timeout in minutes
  Future<int> getSessionTimeoutMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sessionTimeoutMinutesKey) ?? 30;
  }

  /// Set session timeout in minutes
  Future<void> setSessionTimeoutMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionTimeoutMinutesKey, value);
  }

  /// Get remember tokens preference
  Future<bool> isRememberTokensEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberTokensKey) ?? true;
  }

  /// Set remember tokens preference
  Future<void> setRememberTokensEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberTokensKey, value);
  }

  // ==========================================================================
  // Storage Settings
  // ==========================================================================

  /// Get max conversation history limit
  Future<int> getMaxConversationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxConversationHistoryKey) ?? 1000;
  }

  /// Set max conversation history limit
  Future<void> setMaxConversationHistory(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxConversationHistoryKey, value);
  }

  /// Get enable cache preference
  Future<bool> isCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableCacheKey) ?? true;
  }

  /// Set enable cache preference
  Future<void> setCacheEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableCacheKey, value);
  }

  /// Get cache size limit in MB
  Future<int> getCacheSizeMB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cacheSizeMBKey) ?? 500;
  }

  /// Set cache size limit in MB
  Future<void> setCacheSizeMB(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_cacheSizeMBKey, value);
  }

  /// Get auto cleanup preference
  Future<bool> isAutoCleanupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCleanupKey) ?? true;
  }

  /// Set auto cleanup preference
  Future<void> setAutoCleanupEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCleanupKey, value);
  }

  // ==========================================================================
  // Avatar Settings
  // ==========================================================================

  /// Get avatar formality trait
  Future<double> getAvatarFormality() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_avatarFormalityKey) ?? 0.5;
  }

  /// Set avatar formality trait
  Future<void> setAvatarFormality(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_avatarFormalityKey, value);
  }

  /// Get avatar humor trait
  Future<double> getAvatarHumor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_avatarHumorKey) ?? 0.5;
  }

  /// Set avatar humor trait
  Future<void> setAvatarHumor(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_avatarHumorKey, value);
  }

  /// Get avatar enthusiasm trait
  Future<double> getAvatarEnthusiasm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_avatarEnthusiasmKey) ?? 0.5;
  }

  /// Set avatar enthusiasm trait
  Future<void> setAvatarEnthusiasm(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_avatarEnthusiasmKey, value);
  }

  /// Get avatar empathy trait
  Future<double> getAvatarEmpathy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_avatarEmpathyKey) ?? 0.5;
  }

  /// Set avatar empathy trait
  Future<void> setAvatarEmpathy(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_avatarEmpathyKey, value);
  }

  /// Get avatar color theme
  Future<String> getAvatarColorTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarColorThemeKey) ?? 'personality';
  }

  /// Set avatar color theme
  Future<void> setAvatarColorTheme(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarColorThemeKey, value);
  }

  /// Get avatar animation style
  Future<String> getAvatarAnimationStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarAnimationStyleKey) ?? 'bounce';
  }

  /// Set avatar animation style
  Future<void> setAvatarAnimationStyle(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarAnimationStyleKey, value);
  }

  /// Get avatar type
  Future<String> getAvatarType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarTypeKey) ?? 'emoji';
  }

  /// Set avatar type
  Future<void> setAvatarType(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarTypeKey, value);
  }

  /// Get avatar size
  Future<String> getAvatarSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarSizeKey) ?? 'medium';
  }

  /// Set avatar size
  Future<void> setAvatarSize(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarSizeKey, value);
  }

  /// Get avatar glow enabled
  Future<bool> isAvatarGlowEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_avatarGlowEnabledKey) ?? true;
  }

  /// Set avatar glow enabled
  Future<void> setAvatarGlowEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_avatarGlowEnabledKey, value);
  }

  /// Get avatar color override (null = use personality-derived)
  Future<Color?> getAvatarColorOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final colorHex = prefs.getString(_avatarColorOverrideKey);
    if (colorHex == null) return null;
    return Color(int.parse(colorHex.substring(2), radix: 16));
  }

  /// Set avatar color override (null = use personality-derived)
  Future<void> setAvatarColorOverride(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(_avatarColorOverrideKey);
    } else {
      final colorHex = '#${color.toARGB32().toRadixString(16).substring(2)}';
      await prefs.setString(_avatarColorOverrideKey, colorHex);
    }
  }

  // ==========================================================================
  // Developer Settings
  // ==========================================================================

  /// Get debug mode preference
  Future<bool> isDebugModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_debugModeKey) ?? false;
  }

  /// Set debug mode preference
  Future<void> setDebugModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_debugModeKey, value);
  }

  /// Get verbose logging preference
  Future<bool> isVerboseLoggingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_verboseLoggingKey) ?? false;
  }

  /// Set verbose logging preference
  Future<void> setVerboseLoggingEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_verboseLoggingKey, value);
  }

  /// Get show dev tools preference
  Future<bool> isShowDevToolsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showDevToolsKey) ?? false;
  }

  /// Set show dev tools preference
  Future<void> setShowDevToolsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showDevToolsKey, value);
  }
}
