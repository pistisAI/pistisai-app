import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/tailscale_integration_service.dart';

void main() {
  group('TailscaleIntegrationService', () {
    late TailscaleIntegrationService tailscaleService;

    setUp(() {
      tailscaleService = TailscaleIntegrationService.instance;
    });

    test('singleton instance returns the same object', () {
      final instance1 = TailscaleIntegrationService.instance;
      final instance2 = TailscaleIntegrationService.instance;
      expect(instance1, same(instance2));
    });

    test('isTailscaleDaemonRunning returns boolean', () async {
      final isRunning = await tailscaleService.isTailscaleDaemonRunning();
      expect(isRunning, isA<bool>());
    });

    test('getTailscaleStatus returns TailscaleStatus or null', () async {
      final status = await tailscaleService.getTailscaleStatus();
      
      if (status != null) {
        expect(status.selfHostname, isNotEmpty);
        expect(status.tailscaleIps, isA<List<String>>());
        expect(status.isOnline, isA<bool>());
      }
    });

    test('TailscaleStatus.fromJson parses correctly', () {
      final json = {
        'Self': {
          'HostName': 'test-pc',
          'TailnetName': 'example.ts.net',
        },
        'TailscaleIPs': ['198.51.100.1'],
        'BackendState': 'Running',
        'OS': 'linux',
        'DNSConfig': {
          'Nameservers': ['8.8.8.8'],
        },
      };

      final status = TailscaleStatus.fromJson(json);

      expect(status, isNotNull);
      expect(status!.selfHostname, 'test-pc');
      expect(status.selfTailnetName, 'example.ts.net');
      expect(status.tailscaleIps, contains('198.51.100.1'));
      expect(status.isOnline, true);
      expect(status.os, 'linux');
    });

    test('TailscaleStatus.toJson serializes correctly', () {
      final status = TailscaleStatus(
        selfHostname: 'test-pc',
        selfTailnetName: 'example.ts.net',
        tailscaleIps: ['198.51.100.1'],
        isOnline: true,
        dns: '8.8.8.8',
        os: 'linux',
      );

      final json = status.toJson();

      expect(json['hostname'], 'test-pc');
      expect(json['tailnet_name'], 'example.ts.net');
      expect(json['tailscale_ips'], contains('198.51.100.1'));
      expect(json['is_online'], true);
      expect(json['os'], 'linux');
    });

    test('getTailscalePeers returns list of TailscalePeer', () async {
      final peers = await tailscaleService.getTailscalePeers();

      expect(peers, isA<List<TailscalePeer>>());
    });

    test('TailscalePeer.fromJson parses correctly', () {
      final json = {
        'HostName': 'desktop-pc',
        'Addresses': [
          {'IP': '198.51.100.2'},
        ],
        'Online': true,
        'OS': 'linux',
        'LastSeen': DateTime.now().toIso8601String(),
      };

      final peer = TailscalePeer.fromJson('peer-123', json);

      expect(peer.id, 'peer-123');
      expect(peer.hostname, 'desktop-pc');
      expect(peer.primaryIp, '198.51.100.2');
      expect(peer.isOnline, true);
      expect(peer.os, 'linux');
    });

    test('TailscalePeer.toJson serializes correctly', () {
      final peer = TailscalePeer(
        id: 'peer-123',
        hostname: 'desktop-pc',
        primaryIp: '198.51.100.2',
        addresses: ['198.51.100.2'],
        isOnline: true,
        os: 'linux',
        lastSeen: DateTime.now(),
      );

      final json = peer.toJson();

      expect(json['id'], 'peer-123');
      expect(json['hostname'], 'desktop-pc');
      expect(json['primary_ip'], '198.51.100.2');
      expect(json['is_online'], true);
      expect(json['os'], 'linux');
    });

    test('findDesktopPeer returns TailscalePeer or null', () async {
      final desktop = await tailscaleService.findDesktopPeer();

      if (desktop != null) {
        expect(desktop.hostname, isNotEmpty);
        expect(desktop.primaryIp, isNotEmpty);
        expect(desktop.isOnline, isA<bool>());
      }
    });

    test('getHermesApiUrlViaTs returns URL string or null', () async {
      final url = await tailscaleService.getHermesApiUrlViaTs();

      if (url != null) {
        expect(url, startsWith('http://'));
        expect(url, contains(':'));
      }
    });

    test('getHermesApiUrlViaTs constructs correct URL with custom port', () async {
      final url = await tailscaleService.getHermesApiUrlViaTs(hermesPort: '4000');

      if (url != null) {
        expect(url, endsWith(':4000'));
      }
    });

    test('testHermesConnectivityViaTailscale returns boolean', () async {
      final isConnected = await tailscaleService.testHermesConnectivityViaTailscale();

      expect(isConnected, isA<bool>());
    });

    test('TailscaleStatus.toString is non-empty', () {
      final status = TailscaleStatus(
        selfHostname: 'test-pc',
        selfTailnetName: 'example.ts.net',
        tailscaleIps: ['198.51.100.1'],
        isOnline: true,
      );

      final str = status.toString();

      expect(str, isNotEmpty);
      expect(str, contains('test-pc'));
    });

    test('TailscalePeer.toString is non-empty', () {
      final peer = TailscalePeer(
        id: 'peer-123',
        hostname: 'desktop-pc',
        primaryIp: '198.51.100.2',
        addresses: ['198.51.100.2'],
        isOnline: true,
        os: 'linux',
        lastSeen: DateTime.now(),
      );

      final str = peer.toString();

      expect(str, isNotEmpty);
      expect(str, contains('desktop-pc'));
    });
  });
}
