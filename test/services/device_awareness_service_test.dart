import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/device_awareness_service.dart';

void main() {
  group('DeviceAwarenessService', () {
    late DeviceAwarenessService deviceAwareness;

    setUp(() {
      deviceAwareness = DeviceAwarenessService.instance;
    });

    test('singleton instance returns the same object', () {
      final instance1 = DeviceAwarenessService.instance;
      final instance2 = DeviceAwarenessService.instance;
      expect(instance1, same(instance2));
    });

    test('getDeviceContext returns DeviceContext with all fields', () async {
      await deviceAwareness.initialize();

      final context = await deviceAwareness.getDeviceContext();

      expect(context, isNotNull);
      expect(context.deviceType, isNotNull);
      expect(context.osType, isNotEmpty);
      expect(context.osVersion, isNotEmpty);
      expect(context.networkState, isNotNull);
      expect(context.timestamp, isNotNull);
      expect(context.timezone, isNotEmpty);
      expect(context.timeOfDay, isNotNull);
    });

    test('DeviceContext.toJson() serializes correctly', () async {
      await deviceAwareness.initialize();

      final context = await deviceAwareness.getDeviceContext();
      final json = context.toJson();

      expect(json, isA<Map<String, dynamic>>());
      expect(json['device_type'], isNotNull);
      expect(json['os_type'], isNotEmpty);
      expect(json['network_state'], isNotNull);
      expect(json['timestamp'], isNotNull);
    });

    test('DeviceContext.fromJson() deserializes correctly', () {
      final json = {
        'device_type': 'mobile',
        'device_is_tablet': false,
        'os_type': 'Android',
        'os_version': '14.0',
        'network_state': 'wifi',
        'has_gps': true,
        'has_cellular': true,
        'timezone': '+05:00',
        'time_of_day': 'afternoon',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final context = DeviceContext.fromJson(json);

      expect(context.deviceType, DeviceType.mobile);
      expect(context.osType, 'Android');
      expect(context.osVersion, '14.0');
      expect(context.networkState, NetworkState.wifi);
      expect(context.isTablet, false);
      expect(context.hasGps, true);
      expect(context.hasCellular, true);
    });

    test('getNetworkState returns current network state', () async {
      await deviceAwareness.initialize();

      final state = await deviceAwareness.getNetworkState();

      expect(state, isNotNull);
      expect(
        state,
        isIn([
          NetworkState.wifi,
          NetworkState.cellular,
          NetworkState.other,
          NetworkState.offline,
        ]),
      );
    });

    test('isConnected returns boolean for current connectivity', () async {
      await deviceAwareness.initialize();

      final connected = await deviceAwareness.isConnected();

      expect(connected, isA<bool>());
    });

    test('isWifiConnected checks WiFi connectivity', () async {
      await deviceAwareness.initialize();

      final wifiConnected = await deviceAwareness.isWifiConnected();

      expect(wifiConnected, isA<bool>());
    });

    test('isCellularConnected checks cellular connectivity', () async {
      await deviceAwareness.initialize();

      final cellularConnected = await deviceAwareness.isCellularConnected();

      expect(cellularConnected, isA<bool>());
    });

    test('shouldUseShortenedResponses returns true for mobile', () {
      final context = DeviceContext(
        deviceType: DeviceType.mobile,
        osType: 'Android',
        osVersion: '14.0',
        networkState: NetworkState.wifi,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: true,
        hasCellular: true,
      );

      expect(context.shouldUseShortenedResponses(), true);
    });

    test('shouldUseShortenedResponses returns true for cellular', () {
      final context = DeviceContext(
        deviceType: DeviceType.desktop,
        osType: 'Windows',
        osVersion: '11',
        networkState: NetworkState.cellular,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: false,
        hasCellular: false,
      );

      expect(context.shouldUseShortenedResponses(), true);
    });

    test('shouldUseShortenedResponses returns false for desktop on WiFi', () {
      final context = DeviceContext(
        deviceType: DeviceType.desktop,
        osType: 'Windows',
        osVersion: '11',
        networkState: NetworkState.wifi,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: false,
        hasCellular: false,
      );

      expect(context.shouldUseShortenedResponses(), false);
    });

    test('isOnTheGo returns true for mobile on cellular', () {
      final context = DeviceContext(
        deviceType: DeviceType.mobile,
        osType: 'iOS',
        osVersion: '18.0',
        networkState: NetworkState.cellular,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: true,
        hasCellular: true,
      );

      expect(context.isOnTheGo(), true);
    });

    test('DeviceType enum has expected values', () {
      expect(DeviceType.desktop.value, 'desktop');
      expect(DeviceType.laptop.value, 'laptop');
      expect(DeviceType.mobile.value, 'mobile');
      expect(DeviceType.tablet.value, 'tablet');
      expect(DeviceType.unknown.value, 'unknown');
    });

    test('NetworkState enum has expected values', () {
      expect(NetworkState.wifi.value, 'wifi');
      expect(NetworkState.cellular.value, 'cellular');
      expect(NetworkState.other.value, 'other');
      expect(NetworkState.offline.value, 'offline');
    });

    test('TimeOfDay enum has expected values', () {
      expect(TimeOfDay.morning.value, 'morning');
      expect(TimeOfDay.afternoon.value, 'afternoon');
      expect(TimeOfDay.evening.value, 'evening');
      expect(TimeOfDay.night.value, 'night');
    });

    test('context caching returns same object for 5 minutes', () async {
      await deviceAwareness.initialize();

      final context1 = await deviceAwareness.getDeviceContext();
      final context2 = await deviceAwareness.getDeviceContext();

      expect(context1, same(context2));
    });

    tearDown(() {
      deviceAwareness.dispose();
    });
  });
}
