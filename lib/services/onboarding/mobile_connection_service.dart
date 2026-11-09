import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/brand/brand_copy.dart';
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/services/hermes/hermes_streaming_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How this phone reaches the user's agent.
enum MobileConnectionMode {
  tailscaleHub,
  pistisaiApp,
}

class MobileHubProbeResult {
  const MobileHubProbeResult({
    required this.success,
    required this.hermesUrl,
    required this.message,
    this.foundPrimaryHub = false,
  });

  final bool success;
  final String hermesUrl;
  final String message;
  final bool foundPrimaryHub;
}

typedef MobileHubHttpGet = Future<http.Response> Function(Uri uri);

/// Mobile-only connection to the primary desktop hub or pistisai.app.
class MobileConnectionService extends ChangeNotifier {
  static const String modeKey = 'mobile_connection_mode';
  static const String completeKey = 'mobile_connection_complete';

  MobileConnectionService({
    SettingsPreferenceService? settings,
    HermesStreamingService? hermesStreamingService,
    MobileHubHttpGet? httpGet,
    this.hubPort = AppConfig.defaultRouterPort,
    this.hermesPort = AppConfig.defaultHermesPort,
  })  : _settings = settings ?? SettingsPreferenceService(),
        _hermesStreamingService = hermesStreamingService,
        _httpGet = httpGet;

  final SettingsPreferenceService _settings;
  final HermesStreamingService? _hermesStreamingService;
  final MobileHubHttpGet? _httpGet;
  final int hubPort;
  final int hermesPort;

  MobileConnectionMode? _mode;
  bool _complete = false;
  bool _loaded = false;
  bool _isLoading = false;
  String? _errorMessage;

  MobileConnectionMode? get mode => _mode;
  bool get isComplete => _complete;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get requireCloudLogin => _mode == MobileConnectionMode.pistisaiApp;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _mode = parseMode(prefs.getString(modeKey));
    _complete = prefs.getBool(completeKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<bool> shouldShowConnectionScreen() async {
    await load();
    return !_complete;
  }

  /// Accepts a Tailscale MagicDNS name, CGNAT address, or full HTTP URL.
  static String? normalizeHubHost(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.contains('://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) {
        return null;
      }
      return uri.host;
    }
    final withoutPath = trimmed.split('/').first;
    final host = withoutPath.split(':').first.trim();
    return host.isEmpty ? null : host;
  }

  /// Loopback / emulator bridge hosts allowed only in Android test-rig builds.
  @visibleForTesting
  static bool isAndroidTestRigLoopbackHost(String host) {
    switch (host.trim().toLowerCase()) {
      case '10.0.2.2':
      case '127.0.0.1':
      case 'localhost':
      case 'host.docker.internal':
        return true;
      default:
        return false;
    }
  }

  /// Tailscale MagicDNS (`*.ts.net`) or CGNAT (`100.64.0.0/10`) only.
  ///
  /// With `--dart-define=PISTISAI_ANDROID_TEST_RIG=true`, also allows emulator
  /// and local Docker hub targets (see [isAndroidTestRigLoopbackHost]).
  static bool isAllowedTailscaleHubHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    const androidTestRig = bool.fromEnvironment(
      'PISTISAI_ANDROID_TEST_RIG',
      defaultValue: false,
    );
    if (androidTestRig && isAndroidTestRigLoopbackHost(normalized)) {
      return true;
    }
    if (normalized.endsWith('.ts.net') && normalized != '.ts.net') {
      return true;
    }
    final parts = normalized.split('.');
    if (parts.length != 4) {
      return false;
    }
    final octets = <int>[];
    for (final part in parts) {
      final value = int.tryParse(part);
      if (value == null || value < 0 || value > 255) {
        return false;
      }
      octets.add(value);
    }
    return octets[0] == 100 && octets[1] >= 64 && octets[1] <= 127;
  }

  Future<MobileHubProbeResult> probeHub(String rawHost) async {
    final host = normalizeHubHost(rawHost);
    if (host == null) {
      return const MobileHubProbeResult(
        success: false,
        hermesUrl: '',
        message: 'Enter the Tailscale MagicDNS name of your desktop hub.',
      );
    }
    if (!isAllowedTailscaleHubHost(host)) {
      return const MobileHubProbeResult(
        success: false,
        hermesUrl: '',
        message:
            'Use a Tailscale MagicDNS name ending in .ts.net, or a 100.x address on your tailnet.',
      );
    }

    final hermesUrl = 'http://$host:$hermesPort';
    final hubUri = Uri.parse('http://$host:$hubPort${AppConfig.hubPath}');
    try {
      final hubResponse = await _get(hubUri);
      if (hubResponse.statusCode == 200 && _isPrimaryHub(hubResponse.body)) {
        return MobileHubProbeResult(
          success: true,
          hermesUrl: hermesUrl,
          foundPrimaryHub: true,
          message: 'Connected to the primary desktop hub.',
        );
      }
    } catch (e) {
      debugPrint('[MobileConnection] Hub probe failed: $e');
    }

    final healthUri = Uri.parse('$hermesUrl/health');
    try {
      final health = await _get(healthUri);
      if (health.statusCode == 200) {
        return MobileHubProbeResult(
          success: true,
          hermesUrl: hermesUrl,
          message: 'Reached Hermes on the desktop through Tailscale.',
        );
      }
    } catch (e) {
      debugPrint('[MobileConnection] Hermes probe failed: $e');
    }

    return MobileHubProbeResult(
      success: false,
      hermesUrl: hermesUrl,
      message: BrandCopy.hubUnreachable(host),
    );
  }

  Future<MobileHubProbeResult> connectViaTailscaleHub(String rawHost) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await probeHub(rawHost);
      if (!result.success) {
        _errorMessage = result.message;
        return result;
      }
      await _settings.setHermesEnabled(true);
      await _settings.setHermesUrl(result.hermesUrl);
      _hermesStreamingService?.updateBaseUrl(result.hermesUrl);
      await _persist(
        mode: MobileConnectionMode.tailscaleHub,
        complete: true,
      );
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectViaPistisaiApp() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _persist(
        mode: MobileConnectionMode.pistisaiApp,
        complete: true,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persist({
    required MobileConnectionMode mode,
    required bool complete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modeKey, encodeMode(mode));
    await prefs.setBool(completeKey, complete);
    _mode = mode;
    _complete = complete;
  }

  Future<http.Response> _get(Uri uri) {
    final get = _httpGet;
    if (get != null) {
      return get(uri);
    }
    return http.get(uri).timeout(const Duration(seconds: 5));
  }

  static bool _isPrimaryHub(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map) {
        return decoded['role'] == 'primary_hub';
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  static MobileConnectionMode? parseMode(String? raw) {
    switch (raw) {
      case 'tailscale_hub':
        return MobileConnectionMode.tailscaleHub;
      case 'pistisai_app':
        return MobileConnectionMode.pistisaiApp;
      default:
        return null;
    }
  }

  static String encodeMode(MobileConnectionMode mode) {
    switch (mode) {
      case MobileConnectionMode.tailscaleHub:
        return 'tailscale_hub';
      case MobileConnectionMode.pistisaiApp:
        return 'pistisai_app';
    }
  }
}
