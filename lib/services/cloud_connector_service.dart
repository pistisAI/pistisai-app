import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import 'device_identity_service.dart';

/// Best-effort platform/device descriptors for cloud registration.
class PlatformInfo {
  static String get platform {
    if (kIsWeb) return 'web';
    final v = defaultTargetPlatform;
    return v.name.toLowerCase();
  }

  static String get deviceName => '${PlatformInfo.platform}-device';
}


/// Runtime location selected in setup — mirrors backend validation.
enum CloudRuntimeLocation { local, privateDevice, tailscaleDevice, manualUrl, pistisaiHosted }

extension CloudRuntimeLocationName on CloudRuntimeLocation {
  String get wireName {
    switch (this) {
      case CloudRuntimeLocation.local:
        return 'local';
      case CloudRuntimeLocation.privateDevice:
        return 'private_device';
      case CloudRuntimeLocation.tailscaleDevice:
        return 'tailscale_device';
      case CloudRuntimeLocation.manualUrl:
        return 'manual_url';
      case CloudRuntimeLocation.pistisaiHosted:
        return 'pistisai_hosted';
    }
  }
}

class CloudDevice {
  final String deviceId;
  final String? deviceName;
  final String? platform;
  final String runtimeLocation;
  final String status;
  final DateTime? lastSeen;
  final bool runtimeAvailable;

  CloudDevice({
    required this.deviceId,
    this.deviceName,
    this.platform,
    required this.runtimeLocation,
    required this.status,
    this.lastSeen,
    this.runtimeAvailable = false,
  });

  factory CloudDevice.fromJson(Map<String, dynamic> json) => CloudDevice(
        deviceId: json['device_id'] as String,
        deviceName: json['device_name'] as String?,
        platform: json['platform'] as String?,
        runtimeLocation: (json['runtime_location'] ?? 'local') as String,
        status: (json['status'] ?? 'offline') as String,
        lastSeen: json['last_seen'] != null
            ? DateTime.tryParse(json['last_seen'] as String)
            : null,
        runtimeAvailable: json['runtime_available'] == true,
      );
}

enum CloudConnectionStatus { disconnected, connecting, connected, error }

/// Flutter client for the per-user cloud connector API (`/cloud`).
///
/// Registers this device with its ED25519-derived identity, sends presence
/// heartbeats while authenticated, and exposes the user's device mesh list.
class CloudConnectorService {
  CloudConnectorService({
    required AuthService authService,
    http.Client? httpClient,
    String? baseUrl,
  })  : _authService = authService,
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final AuthService _authService;
  final http.Client _httpClient;
  final String _baseUrl;

  Timer? _heartbeatTimer;
  bool _registered = false;
  CloudConnectionStatus _status = CloudConnectionStatus.disconnected;
  String? _lastError;
  final _statusController = StreamController<CloudConnectionStatus>.broadcast();

  Stream<CloudConnectionStatus> get statusStream => _statusController.stream;
  CloudConnectionStatus get status => _status;
  String? get lastError => _lastError;

  void _setStatus(CloudConnectionStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  /// Register this device with the cloud connector and start heartbeats.
  Future<bool> registerAndStart({
    CloudRuntimeLocation runtimeLocation = CloudRuntimeLocation.local,
  }) async {
    _setStatus(CloudConnectionStatus.connecting);
    try {
      await DeviceIdentityService.instance.initialize();
      final deviceId = DeviceIdentityService.instance.deviceId;
      final ok = await _register(deviceId, runtimeLocation);
      if (!ok) return false;
      _registered = true;
      _setStatus(CloudConnectionStatus.connected);
      _startHeartbeat(deviceId);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _setStatus(CloudConnectionStatus.error);
      return false;
    }
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _registered = false;
    _setStatus(CloudConnectionStatus.disconnected);
  }

  void _startHeartbeat(String deviceId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => unawaited(_sendHeartbeat(deviceId)),
    );
    unawaited(_sendHeartbeat(deviceId));
  }

  Future<void> _sendHeartbeat(String deviceId) async {
    if (!_registered) return;
    try {
      final response = await _post('/devices/heartbeat', body: {
        'device_id': deviceId,
        'runtime_available': false,
        'metadata': <String, dynamic>{},
      });
      if (response.statusCode == 404) {
        // Device was revoked server-side; re-register on next cycle.
        _registered = false;
      }
    } catch (e) {
      debugPrint('[CloudConnector] Heartbeat failed: $e');
    }
  }

  Future<List<CloudDevice>> listDevices() async {
    final response = await _get('/devices');
    if (response.statusCode != 200) {
      throw Exception('Failed to list devices (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    return data
        .map((d) => CloudDevice.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<bool> revokeDevice(String deviceId) async {
    final token = await _authService.getAccessToken();
    final response = await _httpClient.delete(
      Uri.parse('$_baseUrl/cloud/devices/$deviceId'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode == 200;
  }

  Future<bool> _register(
    String deviceId,
    CloudRuntimeLocation runtimeLocation,
  ) async {
    final response = await _post('/devices', body: {
      'device_id': deviceId,
      'device_name': PlatformInfo.deviceName,
      'platform': PlatformInfo.platform,
      'app_version': AppConfig.appVersion,
      'runtime_location': runtimeLocation.wireName,
      'capabilities': <String, dynamic>{},
    });
    return response.statusCode == 201 || response.statusCode == 200;
  }

  Future<http.Response> _post(String path, {required Map<String, dynamic> body}) async {
    final token = await _authService.getAccessToken();
    return _httpClient.post(
      Uri.parse('$_baseUrl/cloud$path'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }

  Future<http.Response> _get(String path) async {
    final token = await _authService.getAccessToken();
    return _httpClient.get(
      Uri.parse('$_baseUrl/cloud$path'),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  void dispose() {
    stop();
    _statusController.close();
  }
}
