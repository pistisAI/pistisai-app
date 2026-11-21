import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/session_service.dart';

/// Writes a fake `hermes` executable that exits with [exitCode], returning the
/// path. Uses `hermes.cmd` on Windows and a `#!/bin/sh` script elsewhere so the
/// test can exercise [SessionService] without a real Hermes runtime.
Future<String> _writeFakeHermes({
  required int exitCode,
  String stdout = '',
  String stderr = '',
}) async {
  final dir = await Directory.systemTemp.createTemp('fake-hermes-');
  if (Platform.isWindows) {
    final file = File('${dir.path}${Platform.pathSeparator}hermes.cmd');
    await file.writeAsString(
      '@echo off\r\n'
      'echo $stdout\r\n'
      'echo $stderr 1>&2\r\n'
      'exit /b $exitCode\r\n',
    );
    return file.path;
  }

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

  group('SessionService.listSessions', () {
    const table = '''
Title                         Preview                 Last Active   ID
──────────────────────────────────────────────────────────────────────
Morning planning · Nov 20     Here is your agenda     5m ago        20261120_ab12
Daily briefing                Summary sent            2h ago        cron_daily_1
''';

    test('parses title, preview, last active and id from the CLI table', () {
      final sessions = SessionService.parseSessionList(table);
      expect(sessions, hasLength(2));
      expect(sessions[0].id, '20261120_ab12');
      expect(sessions[0].type, 'agent');
      expect(sessions[0].userOrAgent, 'Morning planning · Nov 20');
      expect(sessions[0].preview, 'Here is your agenda');
      expect(sessions[0].lastActive, '5m ago');
      expect(sessions[1].type, 'cron');
    });

    test('does not invent values the CLI does not give', () {
      final s = SessionService.parseSessionList(table).first;
      expect(s.startTime, isNull);
      expect(s.tokenUsage, isNull);
      expect(s.messageCount, isNull);
      expect(s.status, isNull);
    });

    test('throws when hermes fails instead of returning an empty list',
        () async {
      final service = SessionService(
        processRunner: (_, __) async =>
            ProcessResult(0, 2, '', 'no such command'),
      );
      await expectLater(
        service.listSessions(),
        throwsA(isA<SessionServiceException>()
            .having((e) => e.message, 'message', contains('no such command'))),
      );
    });

    test('throws when hermes cannot be started', () async {
      final service = SessionService(
        processRunner: (_, __) async =>
            throw const ProcessException('hermes', ['sessions', 'list']),
      );
      await expectLater(
          service.listSessions(), throwsA(isA<SessionServiceException>()));
    });
  });
}
