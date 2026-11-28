import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hardware/hardware_parsers.dart';
import 'package:pistisai/services/hardware/hardware_probe.dart';

const int _gib = 1024 * 1024 * 1024;

const String _linuxMeminfo = '''
MemTotal:       32594332 kB
MemFree:         1234567 kB
MemAvailable:   20123456 kB
Buffers:          123456 kB
''';

const String _macVmStat = '''
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               10000.
Pages active:                            200000.
Pages inactive:                           50000.
Pages speculative:                         5000.
''';

/// Records every command and answers from [outputs] keyed by executable.
class _FakeMachine {
  _FakeMachine(this.outputs, {this.files = const {}});

  final Map<String, ProbeCommandOutput?> outputs;
  final Map<String, String> files;
  final List<List<String>> calls = [];

  Future<ProbeCommandOutput?> run(
    String executable,
    List<String> arguments,
    Duration timeout,
  ) async {
    calls.add([executable, ...arguments]);
    if (!outputs.containsKey(executable)) {
      throw StateError('not installed: $executable');
    }
    return outputs[executable];
  }

  Future<String?> read(String path) async => files[path];
}

ProbeCommandOutput _ok(String stdout) =>
    ProbeCommandOutput(exitCode: 0, stdout: stdout);

void main() {
  group('parsers', () {
    test('Linux /proc/meminfo', () {
      final m = parseLinuxMeminfo(_linuxMeminfo);
      expect(m.total, 32594332 * 1024);
      expect(m.available, 20123456 * 1024);
    });

    test('Linux /proc/meminfo without MemAvailable falls back to MemFree', () {
      final m = parseLinuxMeminfo('MemTotal: 2048 kB\nMemFree: 1024 kB\n');
      expect(m.total, 2048 * 1024);
      expect(m.available, 1024 * 1024);
    });

    test('garbage gives nulls, not exceptions', () {
      expect(parseLinuxMeminfo('nope').total, isNull);
      expect(parseSingleInteger(''), isNull);
      expect(parseMacVmStatAvailable('nope'), isNull);
      expect(parseWindowsCimMemory('').total, isNull);
      expect(parseWmicTotalMemory('error'), isNull);
      expect(parseNvidiaSmi('NVIDIA-SMI has failed').memoryBytes, isNull);
    });

    test('macOS sysctl and vm_stat', () {
      expect(parseSingleInteger('17179869184\n'), 17179869184);
      expect(
          parseMacVmStatAvailable(_macVmStat), (10000 + 50000 + 5000) * 16384);
    });

    test('Windows CIM and wmic', () {
      final m = parseWindowsCimMemory('17054408704\r\n8123456\r\n');
      expect(m.total, 17054408704);
      expect(m.available, 8123456 * 1024);
      expect(
        parseWmicTotalMemory('\r\n\r\nTotalPhysicalMemory=17054408704\r\n'),
        17054408704,
      );
    });

    test('nvidia-smi picks the GPU with the most memory', () {
      final g = parseNvidiaSmi(
        'NVIDIA GeForce GTX 1650, 4096\nNVIDIA GeForce RTX 3080, 10240\n',
      );
      expect(g.name, 'NVIDIA GeForce RTX 3080');
      expect(g.memoryBytes, 10240 * 1024 * 1024);
    });

    test('architecture is normalised', () {
      expect(normalizeArchitecture('x86_64\n'), 'x86_64');
      expect(normalizeArchitecture('AMD64'), 'amd64');
      expect(normalizeArchitecture('  '), isNull);
    });
  });

  group('PlatformHardwareProbe', () {
    test('Linux reads /proc/meminfo, uname and nvidia-smi', () async {
      final machine = _FakeMachine(
        {
          'uname': _ok('x86_64\n'),
          'nvidia-smi': _ok('NVIDIA RTX A2000, 6138\n'),
        },
        files: {'/proc/meminfo': _linuxMeminfo},
      );
      final probe = PlatformHardwareProbe(
        operatingSystem: 'linux',
        runCommand: machine.run,
        readFile: machine.read,
      );
      final s = (await probe.read())!;
      expect(s.architecture, 'x86_64');
      expect(s.totalMemoryBytes, 32594332 * 1024);
      expect(s.availableMemoryBytes, 20123456 * 1024);
      expect(s.gpuName, 'NVIDIA RTX A2000');
      expect(s.gpuMemoryBytes, 6138 * 1024 * 1024);
      // Argument lists only, never a shell.
      expect(machine.calls, anyElement(equals(['uname', '-m'])));
      expect(machine.calls.any((c) => c.first == 'sh' || c.first == 'bash'),
          isFalse);
    });

    test('Linux without nvidia-smi still answers', () async {
      final machine = _FakeMachine(
        {'uname': _ok('aarch64\n')},
        files: {'/proc/meminfo': _linuxMeminfo},
      );
      final s = (await PlatformHardwareProbe(
        operatingSystem: 'linux',
        runCommand: machine.run,
        readFile: machine.read,
      ).read())!;
      expect(s.architecture, 'aarch64');
      expect(s.totalMemoryBytes, isNotNull);
      expect(s.gpuMemoryBytes, isNull);
    });

    test('macOS reads sysctl hw.memsize, uname and vm_stat', () async {
      final machine = _FakeMachine({
        'sysctl': _ok('17179869184\n'),
        'uname': _ok('arm64\n'),
        'vm_stat': _ok(_macVmStat),
      });
      final s = (await PlatformHardwareProbe(
        operatingSystem: 'macos',
        runCommand: machine.run,
        readFile: machine.read,
      ).read())!;
      expect(s.architecture, 'arm64');
      expect(s.totalMemoryBytes, 16 * _gib);
      expect(s.availableMemoryBytes, (10000 + 50000 + 5000) * 16384);
      expect(machine.calls, anyElement(equals(['sysctl', '-n', 'hw.memsize'])));
    });

    test('Windows reads PowerShell CIM and the environment', () async {
      final machine = _FakeMachine({
        'powershell': _ok('17054408704\r\n8123456\r\n'),
      });
      final s = (await PlatformHardwareProbe(
        operatingSystem: 'windows',
        runCommand: machine.run,
        readFile: machine.read,
        environment: const {'PROCESSOR_ARCHITECTURE': 'AMD64'},
      ).read())!;
      expect(s.architecture, 'amd64');
      expect(s.totalMemoryBytes, 17054408704);
      expect(s.availableMemoryBytes, 8123456 * 1024);
      final ps = machine.calls.firstWhere((c) => c.first == 'powershell');
      expect(ps.last, PlatformHardwareProbe.windowsMemoryScript);
      expect(machine.calls.any((c) => c.first == 'wmic'), isFalse);
    });

    test('Windows falls back to wmic when PowerShell fails', () async {
      final machine = _FakeMachine({
        'powershell': const ProbeCommandOutput(exitCode: 1, stdout: ''),
        'wmic': _ok('TotalPhysicalMemory=8589934592\r\n'),
      });
      final s = (await PlatformHardwareProbe(
        operatingSystem: 'windows',
        runCommand: machine.run,
        readFile: machine.read,
        environment: const {
          'PROCESSOR_ARCHITECTURE': 'x86',
          'PROCESSOR_ARCHITEW6432': 'ARM64',
        },
      ).read())!;
      expect(s.totalMemoryBytes, 8 * _gib);
      expect(s.architecture, 'arm64');
    });

    test('unsupported platforms return null', () async {
      final machine = _FakeMachine({});
      for (final os in ['android', 'ios', 'fuchsia']) {
        final probe = PlatformHardwareProbe(
          operatingSystem: os,
          runCommand: machine.run,
          readFile: machine.read,
        );
        expect(probe.isSupported, isFalse);
        expect(await probe.read(), isNull);
      }
      expect(machine.calls, isEmpty);
    });

    test('a hanging command is cut off by the probe timeout', () async {
      final never = Completer<ProbeCommandOutput?>();
      final probe = PlatformHardwareProbe(
        operatingSystem: 'macos',
        runCommand: (_, __, ___) => never.future,
        readFile: (_) async => null,
        probeTimeout: const Duration(milliseconds: 20),
      );
      final s = await probe.read();
      expect(s, isNotNull);
      expect(s!.totalMemoryBytes, isNull);
    });
  });
}
