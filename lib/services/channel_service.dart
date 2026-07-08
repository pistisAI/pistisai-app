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
      : _hermesPath = hermesPath ?? 'hermes';

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
      return _parse(result.stdout as String);
    } catch (e) {
      debugPrint('[ChannelService] Error: $e');
      return [];
    }
  }

  List<GatewayChannel> _parse(String output) {
    final channels = <GatewayChannel>[];
    final lines = output.split('\n');

    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;

      // Example gateway list line:
      //   ✓ default (current)        — PID 35213
      // or a connected platform row. We treat each listed gateway profile as a
      // channel and surface its connection status.
      final nameMatch = RegExp(r'([✓✗★])\s*([\w-]+)\s*(\(current\))?')
          .firstMatch(t);
      if (nameMatch == null) continue;

      final marker = nameMatch.group(1)!;
      final name = nameMatch.group(2)!;
      final isCurrent = nameMatch.group(3) != null;
      final connected = marker == '✓' || marker == '★';

      channels.add(
        GatewayChannel(
          id: 'gw-$name',
          name: name,
          platform: 'gateway',
          description: isCurrent
              ? 'Active gateway profile (current)'
              : 'Gateway profile',
          messageCount: 0,
          lastActivity: connected ? DateTime.now() : null,
          unreadCount: 0,
        ),
      );
    }

    if (channels.isEmpty) {
      // Fallback: if `gateway list` produced no parseable rows, report a single
      // unknown channel so the UI can still show the gateway status line.
      channels.add(
        GatewayChannel(
          id: 'gw-unknown',
          name: 'gateway',
          platform: 'gateway',
          description: 'Agent messaging gateway',
          messageCount: 0,
          lastActivity: null,
          unreadCount: 0,
        ),
      );
    }

    return channels;
  }
}
