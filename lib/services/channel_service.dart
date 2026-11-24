import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pistisai/models/channel.dart';

/// Channel service — enumerates communication channels from the connected
/// agent gateway (Hermes `gateway list`/`status`).
///
/// Mirrors [SessionService]: shells out to the local `hermes` CLI, parses the
/// connected gateway platforms, and maps them to [GatewayChannel] models. No
/// backend route required, so the screen works offline and degrades to an
/// empty state when the gateway is unreachable.
class ChannelService {
  final String _hermesPath;

  ChannelService({String? hermesPath})
      : _hermesPath = hermesPath ?? 'hermes' {
    assert(_validateHermesPath(_hermesPath),
        'Invalid hermes path: $_hermesPath');
  }

  /// Validate that the hermes path is safe to use with Process.run.
  /// Accepts 'hermes' (PATH lookup) or an absolute path without shell
  /// metacharacters.
  static bool _validateHermesPath(String path) {
    if (path == 'hermes') return true;
    if (!path.startsWith('/')) return false;
    // Reject paths with shell metacharacters
    return !path.contains(RegExp(r'[;&|`$(){}!<>~\n\r\s]'));
  }

  /// List all communication channels currently connected to the gateway.
  Future<List<GatewayChannel>> listChannels() async {
    try {
      final result = await Process.run(
        _hermesPath,
        ['gateway', 'list'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (result.exitCode != 0) return [];
      return parseGatewayList(result.stdout as String);
    } catch (e) {
      debugPrint('[ChannelService] Error: $e');
      return [];
    }
  }

  /// Parse `hermes gateway list` output into channels.
  ///
  /// Only rows the gateway actually printed become channels. When nothing
  /// parses, the result is empty (no placeholder channel), and fields the
  /// output does not carry (message counts, last activity) stay `null`
  /// rather than being invented (#859).
  @visibleForTesting
  static List<GatewayChannel> parseGatewayList(String output) {
    final channels = <GatewayChannel>[];

    for (final line in output.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;

      // Example gateway list line:
      //   ✓ default (current)        — PID 35213
      final nameMatch =
          RegExp(r'^([✓✗★])\s*([\w-]+)\s*(\(current\))?').firstMatch(t);
      if (nameMatch == null) continue;

      final marker = nameMatch.group(1)!;
      final name = nameMatch.group(2)!;

      channels.add(
        GatewayChannel(
          id: 'gw-$name',
          name: name,
          platform: 'gateway',
          connected: marker == '✓' || marker == '★',
          isCurrent: nameMatch.group(3) != null,
        ),
      );
    }

    return channels;
  }
}
