import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Device awareness module for mobile connectivity and context detection.
///
/// Captures:
/// - Device type (desktop, mobile, tablet, laptop)
/// - Network state (WiFi, cellular, offline)
/// - Location context (city/region via IP geolocation)
/// - Time of day and timezone for adaptive behavior
class DeviceAwarenessService {
  static DeviceAwarenessService? _instance;

  final Connectivity _connectivity = Connectivity();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  DeviceContext? _cachedContext;
  NetworkState _currentNetworkState = NetworkState.offline;
  DateTime _lastContextRefresh = DateTime.now();

  // Cache for 5 minutes
  static const _contextCacheDuration = Duration(minutes: 5);

  DeviceAwarenessService._();

  static DeviceAwarenessService get instance {
    return _instance ??= DeviceAwarenessService._();
  }

  /// Initialize device awareness
  Future<void> initialize() async {
    debugPrint('📱 [DeviceAwareness] Initializing...');

    // Check initial network state
    await _updateNetworkState();

    // Subscribe to network changes
    _connectivitySubscription = _connectivity.onConnectivityChanged
        .listen(_updateNetworkStateFromConnectivity);

    debugPrint('📱 [DeviceAwareness] Initialized');
  }

  /// Get comprehensive device context (cached for 5 minutes)
  Future<DeviceContext> getDeviceContext() async {
    final now = DateTime.now();

    // Return cached context if fresh
    if (_cachedContext != null &&
        now.difference(_lastContextRefresh) < _contextCacheDuration) {
      return _cachedContext!;
    }

    // Refresh context
    final deviceType = await _detectDeviceType();
    final osInfo = await _getOsInfo();

    _cachedContext = DeviceContext(
      deviceType: deviceType,
      osType: osInfo['os'] as String,
      osVersion: osInfo['version'] as String,
      networkState: _currentNetworkState,
      timestamp: now,
      timezone: _getTimezone(),
      timeOfDay: _classifyTimeOfDay(now),
      isTablet: await _isTabletDevice(),
      hasGps: await _hasGpsCapability(),
      hasCellular: await _hasCellularCapability(),
    );

    _lastContextRefresh = now;
    return _cachedContext!;
  }

  /// Get current network state
  Future<NetworkState> getNetworkState() async {
    await _updateNetworkState();
    return _currentNetworkState;
  }

  /// Check if device is connected to the internet
  Future<bool> isConnected() async {
    final state = await getNetworkState();
    return state != NetworkState.offline;
  }

  /// Check if connected via WiFi
  Future<bool> isWifiConnected() async {
    final state = await getNetworkState();
    return state == NetworkState.wifi;
  }

  /// Check if connected via cellular
  Future<bool> isCellularConnected() async {
    final state = await getNetworkState();
    return state == NetworkState.cellular;
  }

  Future<void> _updateNetworkState() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateNetworkStateFromConnectivity(result);
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to check connectivity: $e');
      _currentNetworkState = NetworkState.offline;
    }
  }

  void _updateNetworkStateFromConnectivity(List<ConnectivityResult> result) {
    if (result.isEmpty || result.contains(ConnectivityResult.none)) {
      _currentNetworkState = NetworkState.offline;
    } else if (result.contains(ConnectivityResult.wifi)) {
      _currentNetworkState = NetworkState.wifi;
    } else if (result.contains(ConnectivityResult.mobile)) {
      _currentNetworkState = NetworkState.cellular;
    } else {
      _currentNetworkState = NetworkState.other;
    }

    debugPrint('📱 [DeviceAwareness] Network state: $_currentNetworkState');
    _cachedContext = null; // Invalidate cache on network change
  }

  Future<DeviceType> _detectDeviceType() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android phones/tablets are detected by screen size in UI layer
        // For now, assume mobile device type
        return DeviceType.mobile;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Check model to distinguish iPhone from iPad
        if (iosInfo.model.toLowerCase().contains('ipad')) {
          return DeviceType.tablet;
        }
        return DeviceType.mobile;
      } else if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        return DeviceType.desktop;
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        return DeviceType.laptop;
      }
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to detect device type: $e');
    }
    return DeviceType.unknown;
  }

  Future<Map<String, String>> _getOsInfo() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await _deviceInfo.androidInfo;
        return {
          'os': 'Android',
          'version': info.version.release ?? 'unknown',
        };
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          'os': 'iOS',
          'version': info.systemVersion ?? 'unknown',
        };
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        return {'os': 'Windows', 'version': Platform.operatingSystemVersion};
      } else if (defaultTargetPlatform == TargetPlatform.linux) {
        return {'os': 'Linux', 'version': Platform.operatingSystemVersion};
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        return {'os': 'macOS', 'version': Platform.operatingSystemVersion};
      }
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to get OS info: $e');
    }
    return {'os': 'unknown', 'version': 'unknown'};
  }

  Future<bool> _isTabletDevice() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _deviceInfo.iosInfo;
        return info.model.toLowerCase().contains('ipad');
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        // Tablets typically have screen diagonal > 7 inches
        // This is a simplified heuristic; real implementation uses MediaQuery
        return false; // Will be refined in UI layer
      }
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to check tablet: $e');
    }
    return false;
  }

  Future<bool> _hasGpsCapability() async {
    try {
      // Check for GPS capability based on platform
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return true; // Mobile devices typically have GPS
      }
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to check GPS: $e');
    }
    return false;
  }

  Future<bool> _hasCellularCapability() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        return true; // Mobile devices typically have cellular
      }
    } catch (e) {
      debugPrint('📱 [DeviceAwareness] Failed to check cellular: $e');
    }
    return false;
  }

  String _getTimezone() {
    return DateTime.now().timeZoneOffset.toString();
  }

  TimeOfDay _classifyTimeOfDay(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) {
      return TimeOfDay.morning;
    } else if (hour >= 12 && hour < 17) {
      return TimeOfDay.afternoon;
    } else if (hour >= 17 && hour < 21) {
      return TimeOfDay.evening;
    } else {
      return TimeOfDay.night;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    debugPrint('📱 [DeviceAwareness] Disposed');
  }
}

/// Device type classification
enum DeviceType {
  desktop('desktop'),
  laptop('laptop'),
  mobile('mobile'),
  tablet('tablet'),
  unknown('unknown');

  final String value;
  const DeviceType(this.value);
}

/// Network connectivity state
enum NetworkState {
  wifi('wifi'),
  cellular('cellular'),
  other('other'),
  offline('offline');

  final String value;
  const NetworkState(this.value);
}

/// Time of day classification for context
enum TimeOfDay {
  morning('morning'),
  afternoon('afternoon'),
  evening('evening'),
  night('night');

  final String value;
  const TimeOfDay(this.value);
}

/// Comprehensive device context
class DeviceContext {
  final DeviceType deviceType;
  final String osType;
  final String osVersion;
  final NetworkState networkState;
  final DateTime timestamp;
  final String timezone;
  final TimeOfDay timeOfDay;
  final bool isTablet;
  final bool hasGps;
  final bool hasCellular;

  DeviceContext({
    required this.deviceType,
    required this.osType,
    required this.osVersion,
    required this.networkState,
    required this.timestamp,
    required this.timezone,
    required this.timeOfDay,
    required this.isTablet,
    required this.hasGps,
    required this.hasCellular,
  });

  /// Convert context to JSON for transmission
  Map<String, dynamic> toJson() => {
        'device_type': deviceType.value,
        'device_is_tablet': isTablet,
        'os_type': osType,
        'os_version': osVersion,
        'network_state': networkState.value,
        'has_gps': hasGps,
        'has_cellular': hasCellular,
        'timezone': timezone,
        'time_of_day': timeOfDay.value,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Convert JSON back to context
  static DeviceContext fromJson(Map<String, dynamic> json) {
    return DeviceContext(
      deviceType: DeviceType.values.firstWhere(
        (e) => e.value == json['device_type'],
        orElse: () => DeviceType.unknown,
      ),
      osType: json['os_type'] as String? ?? 'unknown',
      osVersion: json['os_version'] as String? ?? 'unknown',
      networkState: NetworkState.values.firstWhere(
        (e) => e.value == json['network_state'],
        orElse: () => NetworkState.offline,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String? ?? DateTime.now().toIso8601String()),
      timezone: json['timezone'] as String? ?? '',
      timeOfDay: TimeOfDay.values.firstWhere(
        (e) => e.value == json['time_of_day'],
        orElse: () => TimeOfDay.afternoon,
      ),
      isTablet: json['device_is_tablet'] as bool? ?? false,
      hasGps: json['has_gps'] as bool? ?? false,
      hasCellular: json['has_cellular'] as bool? ?? false,
    );
  }

  /// Check if device should receive shortened responses
  bool shouldUseShortenedResponses() {
    return deviceType == DeviceType.mobile ||
        deviceType == DeviceType.tablet ||
        networkState == NetworkState.cellular;
  }

  /// Check if device is on the go (not at home)
  bool isOnTheGo() {
    return deviceType == DeviceType.mobile ||
        deviceType == DeviceType.tablet ||
        networkState == NetworkState.cellular;
  }

  @override
  String toString() {
    return 'DeviceContext(type=$deviceType, os=$osType, network=$networkState, timeOfDay=$timeOfDay)';
  }
}
