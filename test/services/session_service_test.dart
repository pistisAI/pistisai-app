import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/session_service.dart';

/// Writes a fake `hermes` executable that echoes its args and exits with
/// [exitCode], returning the path. Used to exercise SessionService without a
/// real Hermes runtime.
Future<String> _writeFakeHermes({
  required int exitCode,
  String stdout = '',
  String stderr = '',
}) async {
  final dir = await Directory.systemTemp.createTemp('fake-hermes-');
  final file = File('${dir.path}/hermes');
  await file.writeAsString(
    '#!/bin/sh\n'
    'echo "$stdout"\n'
    'echo "$stderr" >&2\n'
    'exit $exitCode\n',
  );
  await Process.run('chmod', ['+x', file.path]);
  return file.path;
}

void main() {
  group('SessionService.terminate', () {
    test('returns true when the CLI exits cleanly', () async {
      final hermes = await _writeFakeHermes(exitCode: 0, stdout: 'ok');
      addTearDown(() => Directory(hermes).parent.delete(recursive: true));

      final service = SessionService(hermesPath: hermes);
      expect(await service.terminate('abc123'), isTrue);
    });

    test('returns false when the CLI reports failure', () async {
      final hermes =
          await _writeFakeHermes(exitCode: 1, stderr: 'session not found');
      addTearDown(() => Directory(hermes).parent.delete(recursive: true));

      final service = SessionService(hermesPath: hermes);
      expect(await service.terminate('missing'), isFalse);
    });

    test('returns false when the hermes binary is unavailable', () async {
      final service = SessionService(hermesPath: 'definitely-not-hermes-xyz');
      expect(await service.terminate('abc123'), isFalse);
    });
  });
}
