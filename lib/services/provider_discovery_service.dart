import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/settings_preference_service.dart';

/// Provider Discovery Service
/// Discovers agent runtimes and optional support model providers.

class ProviderDiscoveryService {
  static const Duration _scanTimeout = Duration(seconds: 10);

  final HermesEndpointResolver _hermesResolver;

  ProviderDiscoveryService({HermesEndpointResolver? hermesResolver})
      : _hermesResolver = hermesResolver ?? HermesEndpointResolver();

  /// Scan for all known endpoint types on the network.
  ///
  /// Agent runtimes are valid main-channel targets. Support model providers
  /// are background helpers only and cannot satisfy setup.
  Future<List<ProviderInfo>> scanForProviders() async {
    debugPrint('[ProviderDiscovery] Scanning for providers...');

    final runtimes = await scanForAgentRuntimes();
    final supportProviders = await scanForSupportModelProviders();
    final discovered = <ProviderInfo>[
      ...runtimes,
      ...supportProviders,
    ];

    debugPrint('[ProviderDiscovery] Found ${discovered.length} providers');
    return discovered;
  }

  /// Scan only for agent runtimes that can drive the main secure channel.
  Future<List<ProviderInfo>> scanForAgentRuntimes() async {
    debugPrint('[ProviderDiscovery] Scanning for agent runtimes...');

    final List<ProviderInfo> discovered = [];
    final List<Future<ProviderInfo?>> scans = [
      _scanHermes(),
    ];

    try {
      final results = await Future.wait(scans, eagerError: false);
      for (final result in results) {
        if (result != null) {
          discovered.add(result);
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Runtime scan error: $e');
    }

    debugPrint(
      '[ProviderDiscovery] Found ${discovered.length} agent runtimes',
    );
    return discovered;
  }

  /// Scan for optional local model providers used by memory/helper tasks.
  Future<List<ProviderInfo>> scanForSupportModelProviders() async {
    debugPrint('[ProviderDiscovery] Scanning for support model providers...');

    final List<ProviderInfo> discovered = [];
    final List<Future<ProviderInfo?>> scans = [
      _scanLMStudio(),
      _scanOllama(),
    ];

    try {
      final results = await Future.wait(scans, eagerError: false);
      for (final result in results) {
        if (result != null) {
          discovered.add(result);
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Support provider scan error: $e');
    }

    debugPrint(
      '[ProviderDiscovery] Found ${discovered.length} support model providers',
    );
    return discovered;
  }

  /// Scan for LM Studio on localhost:1234
  Future<ProviderInfo?> _scanLMStudio() async {
    const host = '127.0.0.1'; // LM Studio default - intentionally hardcoded
    const port = 1234;
    final url = Uri.parse('http://$host:$port/v1/models');

    try {
      final response = await http.get(url).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        debugPrint('[ProviderDiscovery] Found LM Studio at $url');
        return ProviderInfo(
          id: 'lmstudio_discovered',
          type: ProviderType.lmStudio,
          name: 'LM Studio',
          url: url.toString(),
          isLocal: true,
          isAvailable: true,
          role: ProviderRole.supportModelProvider,
        );
      }
    } catch (_) {
      // Not available — expected on this machine
    }
    return null;
  }

  /// Scan for Hermes Agent on the saved URL, port 8642, or a live serve port.
  ///
  /// A desktop `/api/health` server is not an agent runtime and is skipped.
  Future<ProviderInfo?> _scanHermes() async {
    final settings = SettingsPreferenceService();
    final configuredUrl = await settings.getHermesUrl();
    final apiKey = await settings.getHermesApiKey();
    final resolution = await _hermesResolver.resolve(
      savedUrl: (configuredUrl?.isNotEmpty ?? false) ? configuredUrl : null,
    );
    if (!resolution.isAgentApi) {
      debugPrint(
        '[ProviderDiscovery] Hermes Agent not available: ${resolution.message}',
      );
      return null;
    }

    final baseUrl = resolution.url;
    try {
      List<String> models = [];
      if (apiKey != null && apiKey.isNotEmpty) {
        models = await _fetchOpenAICompatibleModels(baseUrl, apiKey: apiKey);
      }
      if (models.isEmpty) {
        final envKey = await _discoverHermesApiKeyFromEnv();
        if (envKey != null && envKey.isNotEmpty) {
          models = await _fetchOpenAICompatibleModels(baseUrl, apiKey: envKey);
        }
      }
      final healthUrl = Uri.parse('$baseUrl/health');
      final response = await http.get(healthUrl).timeout(_scanTimeout);
      debugPrint('[ProviderDiscovery] Found Hermes Agent at $baseUrl');
      return ProviderInfo(
        id: 'hermes_discovered',
        type: ProviderType.hermes,
        name: 'Hermes Agent',
        url: baseUrl,
        isLocal: true,
        isAvailable: true,
        version: response.statusCode == 200
            ? _extractVersion(response.body)
            : null,
        availableModels: models,
        role: ProviderRole.agentRuntime,
      );
    } catch (e) {
      debugPrint('[ProviderDiscovery] Hermes Agent not available: $e');
      return ProviderInfo(
        id: 'hermes_discovered',
        type: ProviderType.hermes,
        name: 'Hermes Agent',
        url: baseUrl,
        isLocal: true,
        isAvailable: true,
        role: ProviderRole.agentRuntime,
      );
    }
  }

  /// Auto-discover the Hermes API_SERVER_KEY from the Hermes .env file.
  Future<String?> _discoverHermesApiKeyFromEnv() async {
    try {
      final envPaths = <String>[
        if (Platform.environment.containsKey('HERMES_HOME'))
          '${Platform.environment['HERMES_HOME']}/.env',
        if (Platform.environment.containsKey('LOCALAPPDATA'))
          '${Platform.environment['LOCALAPPDATA']}/hermes/.env',
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
                  '[ProviderDiscovery] Auto-discovered Hermes API key from $envPath');
              return value;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Hermes .env key discovery error: $e');
    }
    return null;
  }

  /// Scan for Ollama on localhost:11434
  Future<ProviderInfo?> _scanOllama() async {
    const host = '127.0.0.1';
    const port = 11434;
    const baseUrl = 'http://$host:$port';
    final tagsUrl = Uri.parse('$baseUrl/api/tags');

    try {
      final response = await http.get(tagsUrl).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        final models = _extractOllamaModels(response.body);
        debugPrint('[ProviderDiscovery] Found Ollama at $baseUrl');
        return ProviderInfo(
          id: 'ollama_discovered',
          type: ProviderType.ollama,
          name: 'Ollama',
          url: baseUrl,
          isLocal: true,
          isAvailable: true,
          availableModels: models,
          role: ProviderRole.supportModelProvider,
        );
      }
    } catch (_) {
      // Not available — expected on this machine
    }
    return null;
  }

  /// Test connectivity to a specific URL.
  ///
  /// A 200 from `GET /` is not a connection. Hermes desktop serves an HTML
  /// page at `/` while the agent API lives at `/health` or `/v1/models`.
  Future<ConnectionTestResult> testConnection(
    String url, {
    String? apiKey,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      debugPrint(
        '[ProviderDiscovery] Classifying $url with a Hermes API key present',
      );
    }
    final resolution = await _hermesResolver.classify(url);
    return ConnectionTestResult(
      isConnected: resolution.isAgentApi,
      url: resolution.url,
      message: resolution.message,
      endpointKind: resolution.kind,
    );
  }

  /// Start periodic scanning for new providers
  Timer? _scanTimer;
  void startPeriodicScanning(
      {Duration interval = const Duration(seconds: 30)}) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(interval, (_) {
      scanForProviders();
    });
    debugPrint('[ProviderDiscovery] Started periodic scanning');
  }

  /// Stop periodic scanning
  void stopPeriodicScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    debugPrint('[ProviderDiscovery] Stopped periodic scanning');
  }

  /// Check if a specific provider type is available
  Future<bool> isProviderTypeAvailable(ProviderType type) async {
    final providers = await scanForProviders();
    return providers.any((p) => p.type == type);
  }

  /// Discover Tailscale devices on the tailnet
  /// This requires Tailscale to be installed and authenticated
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async {
    debugPrint('[ProviderDiscovery] Discovering Tailscale devices...');

    try {
      // Try to run 'tailscale status --json'
      final result = await Process.run('tailscale', ['status', '--json']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return _parseTailscaleStatus(output);
      } else {
        debugPrint(
            '[ProviderDiscovery] Tailscale not available or not authenticated');
        return [];
      }
    } catch (e) {
      debugPrint(
          '[ProviderDiscovery] Failed to discover Tailscale devices: $e');
      return [];
    }
  }

  List<TailscaleDevice> _parseTailscaleStatus(String jsonOutput) {
    try {
      final dynamic data = jsonDecode(jsonOutput);
      final List<TailscaleDevice> devices = [];

      if (data is Map && data.containsKey('Peer')) {
        final peers = data['Peer'] as Map;
        peers.forEach((key, peer) {
          if (peer is Map) {
            final ips = _extractIPs(peer);

            // Filter out localhost devices to prevent duplicates
            // when the same machine is both localhost and on tailnet
            if (ips.any((ip) =>
                ip == '127.0.0.1' || ip == '::1' || ip == 'localhost')) {
              debugPrint(
                  '[ProviderDiscovery] Skipping localhost Tailscale device: ${peer['HostName']}');
              return;
            }

            final device = TailscaleDevice(
              name: peer['HostName']?.toString() ?? key.toString(),
              hostname: peer['DNSName']?.toString() ?? '',
              ips: ips,
              isOnline: peer['Online'] == true,
            );
            devices.add(device);
          }
        });
      }

      debugPrint(
          '[ProviderDiscovery] Found ${devices.length} Tailscale devices');
      return devices;
    } catch (e) {
      debugPrint('[ProviderDiscovery] Failed to parse Tailscale status: $e');
      return [];
    }
  }

  List<String> _extractIPs(Map<dynamic, dynamic> peer) {
    final List<String> ips = [];

    if (peer.containsKey('TailscaleIPs')) {
      final tailnetIps = peer['TailscaleIPs'];
      if (tailnetIps is List) {
        for (final ip in tailnetIps) {
          if (ip is String) {
            ips.add(ip);
          }
        }
      }
    }

    return ips;
  }

  Future<List<String>> _fetchOpenAICompatibleModels(String baseUrl, {String? apiKey}) async {
    try {
      final headers = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final response =
          await http.get(Uri.parse('$baseUrl/v1/models'), headers: headers).timeout(_scanTimeout);
      if (response.statusCode != 200) {
        return const [];
      }
      final data = jsonDecode(response.body);
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((model) => model['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint(
          '[ProviderDiscovery] Failed to fetch models from $baseUrl: $e');
    }
    return const [];
  }

  List<String> _extractOllamaModels(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data['models'] is List) {
        return (data['models'] as List)
            .whereType<Map>()
            .map((model) =>
                model['name']?.toString() ?? model['model']?.toString())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
      }
    } catch (e) {
      // Ignore parse errors; provider availability matters more than model list.
    }
    return const [];
  }

  String? _extractVersion(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data.containsKey('version')) {
        return data['version']?.toString();
      }
    } catch (e) {
      // Ignore parse errors
    }
    return null;
  }
}

/// Result of a connection test
class ConnectionTestResult {
  final bool isConnected;
  final String url;
  final int? statusCode;
  final String message;
  final HermesEndpointKind endpointKind;

  ConnectionTestResult({
    required this.isConnected,
    required this.url,
    this.statusCode,
    required this.message,
    this.endpointKind = HermesEndpointKind.unreachable,
  });
}

/// Represents a Tailscale device on the tailnet
class TailscaleDevice {
  final String name;
  final String hostname;
  final List<String> ips;
  final bool isOnline;

  TailscaleDevice({
    required this.name,
    required this.hostname,
    required this.ips,
    required this.isOnline,
  });

  /// Get the primary IP address (first available)
  String? get primaryIP => ips.isNotEmpty ? ips.first : null;

  @override
  String toString() =>
      'TailscaleDevice(name: $name, hostname: $hostname, ips: $ips, online: $isOnline)';
}
