import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Tailscale VPN integration for secure mobile-to-PC connectivity.
///
/// Manages:
/// - Tailscale daemon status and IP discovery
/// - Secure tunnel establishment between mobile and PC
/// - Hermes API access via Tailscale private IP
class TailscaleIntegrationService {
  static TailscaleIntegrationService? _instance;

  // Tailscale local API typically runs on 127.0.0.1:41112
  static const String _tailscaleLocalApiUrl = 'http://127.0.0.1:41112/localapi';
  static const String _tailscaleStatusEndpoint = '$_tailscaleLocalApiUrl/v0/status';
  static const String _tailscalePeersEndpoint = '$_tailscaleLocalApiUrl/v0/peers';

  // Timeout for Tailscale API calls
  static const _apiTimeout = Duration(seconds: 10);

  TailscaleIntegrationService._();

  static TailscaleIntegrationService get instance {
    return _instance ??= TailscaleIntegrationService._();
  }

  /// Check if Tailscale daemon is running
  Future<bool> isTailscaleDaemonRunning() async {
    try {
      final response = await http.get(
        Uri.parse(_tailscaleStatusEndpoint),
      ).timeout(_apiTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('🌐 [Tailscale] Daemon check failed: $e');
      return false;
    }
  }

  /// Get Tailscale status and device information
  Future<TailscaleStatus?> getTailscaleStatus() async {
    try {
      final response = await http.get(
        Uri.parse(_tailscaleStatusEndpoint),
      ).timeout(_apiTimeout);

      if (response.statusCode != 200) {
        debugPrint('🌐 [Tailscale] Status check failed: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TailscaleStatus.fromJson(json);
    } catch (e) {
      debugPrint('🌐 [Tailscale] Failed to get status: $e');
      return null;
    }
  }

  /// Get list of connected Tailscale peers (other devices on the network)
  Future<List<TailscalePeer>> getTailscalePeers() async {
    try {
      final response = await http.get(
        Uri.parse(_tailscalePeersEndpoint),
      ).timeout(_apiTimeout);

      if (response.statusCode != 200) {
        debugPrint('🌐 [Tailscale] Peers check failed: ${response.statusCode}');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final peers = <TailscalePeer>[];

      if (json['Peers'] is Map) {
        (json['Peers'] as Map).forEach((key, value) {
          if (value is Map) {
            final peer = TailscalePeer.fromJson(key, value.cast<String, dynamic>());
            peers.add(peer);
          }
        });
      }

      return peers;
    } catch (e) {
      debugPrint('🌐 [Tailscale] Failed to get peers: $e');
      return [];
    }
  }

  /// Find the primary desktop PC via Tailscale (looks for hostname pattern)
  Future<TailscalePeer?> findDesktopPeer() async {
    try {
      final peers = await getTailscalePeers();

      // Look for common desktop/PC hostnames
      final desktopPatterns = [
        'desktop',
        'pc',
        'workstation',
        'linux',
        'windows',
        'hermes',
        'pistisai',
      ];

      for (final peer in peers) {
        final hostname = peer.hostname.toLowerCase();
        for (final pattern in desktopPatterns) {
          if (hostname.contains(pattern) && peer.isOnline) {
            debugPrint('🌐 [Tailscale] Found desktop peer: ${peer.hostname} (${peer.primaryIp})');
            return peer;
          }
        }
      }

      // Fallback: return the first online peer
      final onlinePeers = peers.where((p) => p.isOnline).toList();
      if (onlinePeers.isNotEmpty) {
        debugPrint('🌐 [Tailscale] No desktop pattern matched, using first online peer: ${onlinePeers.first.hostname}');
        return onlinePeers.first;
      }
    } catch (e) {
      debugPrint('🌐 [Tailscale] Failed to find desktop peer: $e');
    }

    return null;
  }

  /// Construct a Hermes API URL using Tailscale IP
  Future<String?> getHermesApiUrlViaTs({String hermesPort = '3000'}) async {
    try {
      final desktop = await findDesktopPeer();
      if (desktop == null) {
        debugPrint('🌐 [Tailscale] No desktop peer found');
        return null;
      }

      final url = 'http://${desktop.primaryIp}:$hermesPort';
      debugPrint('🌐 [Tailscale] Hermes API via Tailscale: $url');
      return url;
    } catch (e) {
      debugPrint('🌐 [Tailscale] Failed to construct Hermes URL: $e');
      return null;
    }
  }

  /// Test connectivity to Hermes via Tailscale
  Future<bool> testHermesConnectivityViaTailscale({String hermesPort = '3000'}) async {
    try {
      final url = await getHermesApiUrlViaTs(hermesPort: hermesPort);
      if (url == null) return false;

      final response = await http.get(
        Uri.parse('$url/health'),
      ).timeout(_apiTimeout);

      final isHealthy = response.statusCode == 200;
      if (isHealthy) {
        debugPrint('🌐 [Tailscale] Hermes health check passed');
      }
      return isHealthy;
    } catch (e) {
      debugPrint('🌐 [Tailscale] Hermes connectivity test failed: $e');
      return false;
    }
  }
}

/// Tailscale daemon status
class TailscaleStatus {
  final String selfHostname;
  final String selfTailnetName;
  final List<String> tailscaleIps;
  final bool isOnline;
  final String? dns;
  final String? os;

  TailscaleStatus({
    required this.selfHostname,
    required this.selfTailnetName,
    required this.tailscaleIps,
    required this.isOnline,
    this.dns,
    this.os,
  });

  static TailscaleStatus? fromJson(Map<String, dynamic> json) {
    try {
      final ips = <String>[];
      if (json['TailscaleIPs'] is List) {
        for (final ip in json['TailscaleIPs'] as List) {
          ips.add(ip as String);
        }
      }

      return TailscaleStatus(
        selfHostname: json['Self']?['HostName'] as String? ?? 'unknown',
        selfTailnetName: json['Self']?['TailnetName'] as String? ?? 'unknown',
        tailscaleIps: ips,
        isOnline: json['BackendState'] == 'Running',
        dns: json['DNSConfig']?['Nameservers']?.first as String?,
        os: json['OS'] as String?,
      );
    } catch (e) {
      debugPrint('🌐 [Tailscale] Failed to parse status JSON: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'hostname': selfHostname,
        'tailnet_name': selfTailnetName,
        'tailscale_ips': tailscaleIps,
        'is_online': isOnline,
        'dns': dns,
        'os': os,
      };

  @override
  String toString() {
    return 'TailscaleStatus(hostname=$selfHostname, online=$isOnline, ips=$tailscaleIps)';
  }
}

/// Tailscale peer (device on the network)
class TailscalePeer {
  final String id;
  final String hostname;
  final String primaryIp;
  final List<String> addresses;
  final bool isOnline;
  final String os;
  final DateTime lastSeen;

  TailscalePeer({
    required this.id,
    required this.hostname,
    required this.primaryIp,
    required this.addresses,
    required this.isOnline,
    required this.os,
    required this.lastSeen,
  });

  static TailscalePeer fromJson(String id, Map<String, dynamic> json) {
    final addresses = <String>[];
    if (json['Addresses'] is List) {
      for (final addr in json['Addresses'] as List) {
        if (addr is Map) {
          final ip = addr['IP'] as String?;
          if (ip != null) addresses.add(ip);
        }
      }
    }

    final lastSeenStr = json['LastSeen'] as String?;
    final lastSeen = lastSeenStr != null ? DateTime.parse(lastSeenStr) : DateTime.now();

    return TailscalePeer(
      id: id,
      hostname: json['HostName'] as String? ?? 'unknown',
      primaryIp: addresses.isNotEmpty ? addresses.first : '0.0.0.0',
      addresses: addresses,
      isOnline: json['Online'] == true,
      os: json['OS'] as String? ?? 'unknown',
      lastSeen: lastSeen,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hostname': hostname,
        'primary_ip': primaryIp,
        'addresses': addresses,
        'is_online': isOnline,
        'os': os,
        'last_seen': lastSeen.toIso8601String(),
      };

  @override
  String toString() {
    return 'TailscalePeer(hostname=$hostname, ip=$primaryIp, online=$isOnline)';
  }
}
