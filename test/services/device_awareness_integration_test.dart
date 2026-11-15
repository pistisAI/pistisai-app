import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/device_awareness_service.dart';
import 'package:pistisai/services/tailscale_integration_service.dart';

void main() {
  group('Device Awareness Integration Tests', () {
    late DeviceAwarenessService deviceAwareness;
    late TailscaleIntegrationService tailscale;

    setUp(() {
      deviceAwareness = DeviceAwarenessService.instance;
      tailscale = TailscaleIntegrationService.instance;
    });

    test('Device context includes all required fields', () async {
      await deviceAwareness.initialize();

      final context = await deviceAwareness.getDeviceContext();

      // Verify all fields are populated
      expect(context.deviceType, isNotNull);
      expect(context.osType, isNotEmpty);
      expect(context.osVersion, isNotEmpty);
      expect(context.networkState, isNotNull);
      expect(context.timestamp, isNotNull);
      expect(context.timezone, isNotEmpty);
      expect(context.timeOfDay, isNotNull);

      // Verify JSON serialization round-trip
      final json = context.toJson();
      final restored = DeviceContext.fromJson(json);

      expect(restored.deviceType, context.deviceType);
      expect(restored.osType, context.osType);
      expect(restored.networkState, context.networkState);
    });

    test('Network state transitions are tracked', () async {
      await deviceAwareness.initialize();

      final state1 = await deviceAwareness.getNetworkState();
      expect(state1, isNotNull);

      // Network state should be one of the valid enum values
      final validStates = [
        NetworkState.wifi,
        NetworkState.cellular,
        NetworkState.other,
        NetworkState.offline,
      ];
      expect(validStates, contains(state1));
    });

    test('Device awareness adapts responses based on device type', () async {
      await deviceAwareness.initialize();

      final mobileContext = DeviceContext(
        deviceType: DeviceType.mobile,
        osType: 'Android',
        osVersion: '14.0',
        networkState: NetworkState.cellular,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: true,
        hasCellular: true,
      );

      expect(mobileContext.shouldUseShortenedResponses(), isTrue);
      expect(mobileContext.isOnTheGo(), isTrue);
    });

    test('Tailscale integration provides peer discovery', () async {
      final peers = await tailscale.getTailscalePeers();
      expect(peers, isA<List<TailscalePeer>>());
    });

    test('Tailscale status includes hostname and connectivity', () async {
      final status = await tailscale.getTailscaleStatus();

      if (status != null) {
        expect(status.selfHostname, isNotEmpty);
        expect(status.tailscaleIps, isA<List<String>>());
        expect(status.isOnline, isA<bool>());
      }
    });

    test('Desktop peer discovery works', () async {
      final desktop = await tailscale.findDesktopPeer();

      if (desktop != null) {
        expect(desktop.hostname, isNotEmpty);
        expect(desktop.primaryIp, isNotEmpty);
        expect(desktop.isOnline, isA<bool>());
      }
    });

    test('Hermes API URL construction via Tailscale', () async {
      final url = await tailscale.getHermesApiUrlViaTs();

      if (url != null) {
        expect(url, startsWith('http://'));
        expect(url, contains(':'));
        expect(url, contains('100.'));  // Tailscale IPs start with 100.
      }
    });

    test('Device context JSON schema matches expected format', () async {
      await deviceAwareness.initialize();

      final context = await deviceAwareness.getDeviceContext();
      final json = context.toJson();

      // Verify expected keys
      expect(json.containsKey('device_type'), isTrue);
      expect(json.containsKey('os_type'), isTrue);
      expect(json.containsKey('network_state'), isTrue);
      expect(json.containsKey('timestamp'), isTrue);
      expect(json.containsKey('timezone'), isTrue);
      expect(json.containsKey('time_of_day'), isTrue);
      expect(json.containsKey('device_is_tablet'), isTrue);
      expect(json.containsKey('has_gps'), isTrue);
      expect(json.containsKey('has_cellular'), isTrue);
    });

    test('Tailscale peer JSON schema matches expected format', () {
      final peer = TailscalePeer(
        id: 'peer-123',
        hostname: 'desktop',
        primaryIp: '198.51.100.1',
        addresses: ['198.51.100.1'],
        isOnline: true,
        os: 'linux',
        lastSeen: DateTime.now(),
      );

      final json = peer.toJson();

      expect(json.containsKey('id'), isTrue);
      expect(json.containsKey('hostname'), isTrue);
      expect(json.containsKey('primary_ip'), isTrue);
      expect(json.containsKey('is_online'), isTrue);
      expect(json.containsKey('os'), isTrue);
    });

    test('Mobile device triggers shortened response mode', () async {
      await deviceAwareness.initialize();

      final mobileContext = DeviceContext(
        deviceType: DeviceType.mobile,
        osType: 'iOS',
        osVersion: '18.0',
        networkState: NetworkState.wifi,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: true,
        hasCellular: true,
      );

      // Mobile on WiFi should still use shortened responses
      expect(mobileContext.shouldUseShortenedResponses(), isTrue);
    });

    test('Desktop on WiFi does not trigger shortened responses', () async {
      await deviceAwareness.initialize();

      final desktopContext = DeviceContext(
        deviceType: DeviceType.desktop,
        osType: 'Linux',
        osVersion: 'Ubuntu 24.04',
        networkState: NetworkState.wifi,
        timestamp: DateTime.now(),
        timezone: '+05:00',
        timeOfDay: TimeOfDay.afternoon,
        isTablet: false,
        hasGps: false,
        hasCellular: false,
      );

      expect(desktopContext.shouldUseShortenedResponses(), isFalse);
      expect(desktopContext.isOnTheGo(), isFalse);
    });

    tearDown(() {
      deviceAwareness.dispose();
    });
  });
}
