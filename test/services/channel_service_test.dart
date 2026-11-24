import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/channel_service.dart';

/// Regression tests for #859: the Channels screen must show only channels the
/// gateway actually reports, never a placeholder channel or invented values.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('channel_service_test');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  /// Writes a fake `hermes` executable that prints [stdout] and exits with
  /// [exitCode], and returns its absolute path.
  Future<String> fakeHermes(String stdout, {int exitCode = 0}) async {
    final out = File('${tempDir.path}/out.txt');
    await out.writeAsString(stdout);
    final script = File('${tempDir.path}/hermes');
    await script
        .writeAsString('#!/bin/sh\ncat "${out.path}"\nexit $exitCode\n');
    await Process.run('chmod', ['+x', script.path]);
    return script.path;
  }

  final skipOnWindows = Platform.isWindows ? 'needs a POSIX shell' : null;

  group('ChannelService.listChannels', () {
    test('returns no channels when the gateway lists none', () async {
      final service = ChannelService(
        hermesPath: await fakeHermes('No gateway profiles found.\n'),
      );

      final channels = await service.listChannels();

      expect(channels, isEmpty,
          reason: 'no placeholder "gateway" channel may be invented');
    }, skip: skipOnWindows);

    test('returns only the profiles the gateway printed', () async {
      final service = ChannelService(
        hermesPath: await fakeHermes(
          'Gateway profiles:\n'
          '  ✓ default (current)        — PID 35213\n'
          '  ✗ work\n',
        ),
      );

      final channels = await service.listChannels();

      expect(channels.map((c) => c.name), ['default', 'work']);
    }, skip: skipOnWindows);

    test('returns no channels when the command fails', () async {
      final service = ChannelService(
        hermesPath: await fakeHermes('', exitCode: 1),
      );

      expect(await service.listChannels(), isEmpty);
    }, skip: skipOnWindows);
  });

  group('ChannelService.parseGatewayList', () {
    test('does not invent last activity or message counts', () {
      final channels = ChannelService.parseGatewayList(
        '  ✓ default (current)        — PID 35213\n',
      );

      expect(channels, hasLength(1));
      final c = channels.single;
      expect(c.id, 'gw-default');
      expect(c.lastActivity, isNull,
          reason: '`gateway list` reports no activity time');
      expect(c.messageCount, isNull);
      expect(c.unreadCount, isNull);
      expect(c.connected, isTrue);
      expect(c.isCurrent, isTrue);
    });

    test('maps the stopped marker to disconnected', () {
      final c = ChannelService.parseGatewayList('✗ work\n').single;
      expect(c.connected, isFalse);
      expect(c.isCurrent, isFalse);
    });

    test('ignores lines that are not gateway rows', () {
      expect(ChannelService.parseGatewayList('Gateway profiles:\n\n'), isEmpty);
    });
  });
}
