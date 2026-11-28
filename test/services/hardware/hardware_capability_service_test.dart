import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hardware/hardware_capability_service.dart';
import 'package:pistisai/services/hardware/hardware_probe.dart';

PlatformHardwareProbe _linuxProbe(int totalKiB, {void Function()? onRun}) {
  return PlatformHardwareProbe(
    operatingSystem: 'linux',
    runCommand: (exe, args, timeout) async {
      onRun?.call();
      if (exe == 'uname') {
        return const ProbeCommandOutput(exitCode: 0, stdout: 'x86_64\n');
      }
      return null; // nvidia-smi not installed
    },
    readFile: (path) async => 'MemTotal: $totalKiB kB\nMemAvailable: 1 kB\n',
  );
}

void main() {
  test('no probe (web) answers unknown without scanning', () async {
    var scanned = false;
    final service = HardwareCapabilityService(
      useDefaultProbe: false,
      scanLocalProviders: () async {
        scanned = true;
        return ['Ollama'];
      },
    );
    final r = await service.check();
    expect(r.capability, LocalModelCapability.unknown);
    expect(r.reason, LocalModelCapabilityReason.unsupportedPlatform);
    expect(scanned, isFalse);
  });

  test('32 GiB Linux machine answers sufficient', () async {
    final service = HardwareCapabilityService(
      probe: _linuxProbe(32 * 1024 * 1024),
      scanLocalProviders: () async => const [],
    );
    final r = await service.check();
    expect(r.capability, LocalModelCapability.sufficient);
    expect(r.snapshot?.architecture, 'x86_64');
  });

  test('12 GiB answers insufficient, then sufficient once Ollama runs',
      () async {
    var providers = <String>[];
    final service = HardwareCapabilityService(
      probe: _linuxProbe(12 * 1024 * 1024),
      scanLocalProviders: () async => providers,
    );
    expect(
        (await service.check()).capability, LocalModelCapability.insufficient);

    providers = ['Ollama'];
    // Cached until refresh.
    expect(
        (await service.check()).capability, LocalModelCapability.insufficient);
    final r = await service.refresh();
    expect(r.capability, LocalModelCapability.sufficient);
    expect(r.localProviderNames, ['Ollama']);
    expect(service.lastResult, same(r));
  });

  test('the result is computed once and shared', () async {
    var runs = 0;
    final service = HardwareCapabilityService(
      probe: _linuxProbe(32 * 1024 * 1024, onRun: () => runs++),
    );
    final a = await service.check();
    final runsAfterFirst = runs;
    final b = await service.check();
    expect(identical(a, b), isTrue);
    expect(runs, runsAfterFirst);
  });

  test('a failing provider scan does not fail the check', () async {
    final service = HardwareCapabilityService(
      probe: _linuxProbe(4 * 1024 * 1024),
      scanLocalProviders: () async => throw StateError('boom'),
    );
    final r = await service.check();
    expect(r.capability, LocalModelCapability.insufficient);
    expect(r.localProviderNames, isEmpty);
  });

  test('a probe that throws everywhere answers unknown', () async {
    final service = HardwareCapabilityService(
      probe: PlatformHardwareProbe(
        operatingSystem: 'linux',
        runCommand: (_, __, ___) async => throw StateError('no process'),
        readFile: (_) async => throw StateError('no file'),
      ),
    );
    final r = await service.check();
    expect(r.capability, LocalModelCapability.unknown);
    expect(r.reason, LocalModelCapabilityReason.probeFailed);
  });
}
