import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hermes/hermes_bot_install_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesBotInstallService', () {
    late Directory home;
    late List<_HermesCall> calls;

    setUp(() {
      home = Directory.systemTemp.createTempSync('pistisai-hermes-home');
      calls = <_HermesCall>[];
    });

    tearDown(() {
      if (home.existsSync()) {
        home.deleteSync(recursive: true);
      }
    });

    test('installs pistisai paths, enables the plugin, and creates one routine',
        () async {
      final service = _service(home: home, calls: calls);

      final report = await service.install();

      expect(report.succeeded, isTrue);
      expect(report.hasFailures, isFalse);
      expect(
        report.stepNamed(HermesBotInstallService.agentStep)!.status,
        HermesBotInstallStatus.installed,
      );
      expect(
        report.stepNamed(HermesBotInstallService.desktopStep)!.status,
        HermesBotInstallStatus.skipped,
      );
      expect(
        report.stepNamed(HermesBotInstallService.desktopStep)!.detail,
        contains('webview'),
      );
      expect(
        report.stepNamed(HermesBotInstallService.profileStep)!.status,
        HermesBotInstallStatus.installed,
      );
      expect(
        report.stepNamed(HermesBotInstallService.routineStep)!.status,
        HermesBotInstallStatus.installed,
      );

      final plugin = File(_join(home.path, 'plugins/pistisai/plugin.yaml'));
      final hook = File(_join(home.path, 'plugins/pistisai/__init__.py'));
      final soul = File(_join(home.path, 'profiles/aigent-watch/SOUL.md'));
      final scanner =
          File(_join(home.path, 'profiles/aigent-watch/drift_scanner.py'));
      final skill = File(_join(
        home.path,
        'profiles/aigent-watch/skills/drift-scan/SKILL.md',
      ));
      expect(plugin.existsSync(), isTrue);
      expect(hook.existsSync(), isTrue);
      expect(soul.existsSync(), isTrue);
      expect(scanner.existsSync(), isTrue);
      expect(skill.existsSync(), isTrue);
      expect(plugin.readAsStringSync(), contains('name: pistisai'));
      expect(
        Directory(_join(home.path, 'plugins/pistisai'))
            .listSync()
            .any((entity) => entity.path.endsWith('plugin.js')),
        isFalse,
      );

      for (final file in <File>[plugin, hook, soul, scanner, skill]) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains('D:/ZOID')));
        expect(text, isNot(contains('11c4741339fb')));
      }

      expect(calls, isNotEmpty);
      for (final call in calls) {
        expect(call.home, home.path);
      }
      final enable = calls.singleWhere((call) => call.args.first == 'plugins');
      expect(enable.args, <String>[
        'plugins',
        'enable',
        'pistisai',
        '--no-allow-tool-override',
      ]);
      final created = calls.singleWhere(
        (call) => call.args.length > 1 && call.args[1] == 'create',
      );
      expect(created.args, isNot(contains('--schedule')));
      expect(created.args, <String>[
        'cron',
        'create',
        '--name',
        HermesBotInstallService.driftScanCronName,
        '--deliver',
        HermesBotInstallService.driftScanDeliver,
        HermesBotInstallService.driftScanSchedule,
        HermesBotInstallService.driftScanPrompt,
      ]);
    });

    test('a second install skips unchanged files and an existing routine',
        () async {
      final service = _service(home: home, calls: calls);
      await service.install();
      pluginFile(home).writeAsStringSync('name: local-edit\n');

      final again = await service.install();

      expect(
        again.stepNamed(HermesBotInstallService.agentStep)!.status,
        HermesBotInstallStatus.skipped,
      );
      expect(
        again.stepNamed(HermesBotInstallService.agentStep)!.detail,
        contains('left in place'),
      );
      expect(
        again.stepNamed(HermesBotInstallService.profileStep)!.status,
        HermesBotInstallStatus.skipped,
      );
      expect(
        again.stepNamed(HermesBotInstallService.routineStep)!.status,
        HermesBotInstallStatus.skipped,
      );
      expect(pluginFile(home).readAsStringSync(), 'name: local-edit\n');
      expect(
        calls.where((call) => call.args.length > 1 && call.args[1] == 'create'),
        hasLength(1),
      );
    });

    test('a missing hermes binary is a failed step and does not throw',
        () async {
      final service = HermesBotInstallService(
        readHome: () => home.path,
        loadAsset: _loadAsset,
        runHermes: (List<String> args, {required String hermesHome}) async {
          throw const ProcessException('hermes', <String>[]);
        },
      );

      final report = await service.install();

      expect(report.hasFailures, isTrue);
      expect(report.succeeded, isFalse);
      expect(
        report.stepNamed(HermesBotInstallService.enableStep)!.status,
        HermesBotInstallStatus.failed,
      );
      expect(pluginFile(home).existsSync(), isTrue);
    });

    test('web returns an all-skipped report', () async {
      var ran = false;
      final service = HermesBotInstallService(
        readHome: () {
          throw StateError('home should not be read on web');
        },
        loadAsset: (String relativePath) async {
          throw StateError('assets should not load on web');
        },
        runHermes: (List<String> args, {required String hermesHome}) async {
          ran = true;
          throw StateError('hermes should not run on web');
        },
        isWeb: () => true,
      );

      final report = await service.install();

      expect(ran, isFalse);
      expect(report.succeeded, isTrue);
      expect(report.hasFailures, isFalse);
      expect(report.steps, hasLength(5));
      expect(
        report.steps.every(
          (step) => step.status == HermesBotInstallStatus.skipped,
        ),
        isTrue,
      );
    });

    test('the connected Hermes home is used, including outside a Windows default directory',
        () async {
      expect(
        hermesHomeFromProcessText(
          r'C:\tools\custom-hermes\hermes-agent\.hermes\bin\hermes.exe',
        ),
        r'C:\tools\custom-hermes',
      );
      expect(
        hermesHomeFromProcessText(
          r'C:\Users\someone\AppData\Local\hermes\hermes-agent\.hermes\bin\hermes.exe',
        ),
        r'C:\Users\someone\AppData\Local\hermes',
      );
      expect(
        hermesHomeFromProcessText('/Users/someone/.hermes/bin/hermes'),
        '/Users/someone/.hermes',
      );
      expect(
        listeningPidFromNetstat(
          '  TCP    127.0.0.1:8642    0.0.0.0:0    LISTENING    4242\r\n'
          '  TCP    127.0.0.1:18642   0.0.0.0:0    LISTENING    9999\r\n',
          8642,
        ),
        '4242',
      );
      expect(
        listeningPidFromNetstat(
          '  TCP    127.0.0.1:18642   0.0.0.0:0    LISTENING    9999\r\n',
          8642,
        ),
        isNull,
      );

      final connected = Directory.systemTemp.createTempSync('connected-hermes');
      addTearDown(() {
        if (connected.existsSync()) {
          connected.deleteSync(recursive: true);
        }
      });
      final service = HermesBotInstallService(
        loadAsset: _loadAsset,
        processHome: (int port) async {
          expect(port, 8642);
          return connected.path;
        },
        runHermes: (List<String> args, {required String hermesHome}) async {
          expect(hermesHome, connected.path);
          return const HermesCommandResult(exitCode: 0);
        },
      );

      final report = await service.install(agentPort: 8642);

      expect(report.succeeded, isTrue);
      expect(
        File(_join(connected.path, 'plugins/pistisai/plugin.yaml')).existsSync(),
        isTrue,
      );
    });

    test('a missing home fails without searching another directory', () async {
      var ran = false;
      final service = HermesBotInstallService(
        readHome: () => null,
        loadAsset: _loadAsset,
        runHermes: (List<String> args, {required String hermesHome}) async {
          ran = true;
          return const HermesCommandResult(exitCode: 0);
        },
      );

      final report = await service.install();

      expect(ran, isFalse);
      expect(report.hasFailures, isTrue);
      expect(
        report.stepNamed(HermesBotInstallService.agentStep)!.detail,
        'Hermes home was not found.',
      );
      expect(
        report.stepNamed(HermesBotInstallService.desktopStep)!.status,
        HermesBotInstallStatus.skipped,
      );
    });
  });
}

class _HermesCall {
  final List<String> args;
  final String home;

  const _HermesCall(this.args, this.home);
}

HermesBotInstallService _service({
  required Directory home,
  required List<_HermesCall> calls,
}) {
  return HermesBotInstallService(
    readHome: () => home.path,
    loadAsset: _loadAsset,
    runHermes: (List<String> args, {required String hermesHome}) async {
      calls.add(_HermesCall(args, hermesHome));
      if (args.length > 1 && args[1] == 'list') {
        final created = calls.any(
          (call) => call.args.length > 1 && call.args[1] == 'create',
        );
        return HermesCommandResult(
          exitCode: 0,
          stdout: created ? HermesBotInstallService.driftScanCronName : '',
        );
      }
      return const HermesCommandResult(exitCode: 0);
    },
  );
}

Future<List<int>> _loadAsset(String relativePath) {
  return File('assets/pistisai/hermes/$relativePath').readAsBytes();
}

File pluginFile(Directory home) {
  return File(_join(home.path, 'plugins/pistisai/plugin.yaml'));
}

String _join(String root, String relative) {
  return <String>[root, ...relative.split('/')].join(Platform.pathSeparator);
}
