import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/services/hardware/local_model_capability.dart';

const int _gib = LocalModelThresholds.bytesPerGiB;

HardwareSnapshot _snap({
  String? arch = 'x86_64',
  double? totalGiB,
  double? gpuGiB,
}) =>
    HardwareSnapshot(
      architecture: arch,
      totalMemoryBytes: totalGiB == null ? null : (totalGiB * _gib).round(),
      gpuMemoryBytes: gpuGiB == null ? null : (gpuGiB * _gib).round(),
    );

void main() {
  group('evaluateLocalModelCapability', () {
    test('no probe for this platform -> unknown', () {
      final r = evaluateLocalModelCapability(snapshot: null);
      expect(r.capability, LocalModelCapability.unknown);
      expect(r.reason, LocalModelCapabilityReason.unsupportedPlatform);
    });

    test('memory unreadable and no provider -> unknown', () {
      final r = evaluateLocalModelCapability(snapshot: _snap());
      expect(r.capability, LocalModelCapability.unknown);
      expect(r.reason, LocalModelCapabilityReason.probeFailed);
    });

    test('memory unreadable but a local provider runs -> sufficient', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(),
        localProviderNames: const ['Ollama'],
      );
      expect(r.capability, LocalModelCapability.sufficient);
      expect(r.reason, LocalModelCapabilityReason.localProviderReachable);
    });

    test('a "16 GB" machine reporting 15.5 GiB -> sufficient', () {
      final r = evaluateLocalModelCapability(snapshot: _snap(totalGiB: 15.5));
      expect(r.capability, LocalModelCapability.sufficient);
      expect(r.reason, LocalModelCapabilityReason.meetsRecommendedMemory);
    });

    test('32 GiB on arm64 -> sufficient', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(arch: 'arm64', totalGiB: 32),
      );
      expect(r.capability, LocalModelCapability.sufficient);
    });

    test('4 GiB -> insufficient, even with a provider running', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(totalGiB: 4),
        localProviderNames: const ['Ollama'],
      );
      expect(r.capability, LocalModelCapability.insufficient);
      expect(r.reason, LocalModelCapabilityReason.belowMinimumMemory);
    });

    test('middle zone (8 GiB) without provider or GPU -> insufficient', () {
      final r = evaluateLocalModelCapability(snapshot: _snap(totalGiB: 8));
      expect(r.capability, LocalModelCapability.insufficient);
      expect(r.reason, LocalModelCapabilityReason.middleZoneMemory);
    });

    test('middle zone with a reachable local provider -> sufficient', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(totalGiB: 12),
        localProviderNames: const ['LM Studio'],
      );
      expect(r.capability, LocalModelCapability.sufficient);
      expect(r.reason, LocalModelCapabilityReason.middleZoneWithLocalProvider);
      expect(r.localProviderReachable, isTrue);
    });

    test('middle zone with an 8 GiB GPU -> sufficient', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(totalGiB: 12, gpuGiB: 8),
      );
      expect(r.capability, LocalModelCapability.sufficient);
      expect(r.reason, LocalModelCapabilityReason.middleZoneWithGpu);
    });

    test('middle zone with a 4 GiB GPU -> insufficient', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(totalGiB: 12, gpuGiB: 4),
      );
      expect(r.capability, LocalModelCapability.insufficient);
    });

    test('32-bit architecture -> insufficient regardless of memory', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(arch: 'armv7l', totalGiB: 32),
      );
      expect(r.capability, LocalModelCapability.insufficient);
      expect(r.reason, LocalModelCapabilityReason.unsupportedArchitecture);
    });

    test('unknown architecture is not held against the machine', () {
      final r = evaluateLocalModelCapability(
        snapshot: _snap(arch: null, totalGiB: 32),
      );
      expect(r.capability, LocalModelCapability.sufficient);
    });
  });

  test('thresholds keep the documented order', () {
    expect(
      LocalModelThresholds.minimumTotalMemoryGiB,
      lessThan(LocalModelThresholds.recommendedTotalMemoryGiB),
    );
    expect(
      LocalModelThresholds.minimumTotalMemoryBytes,
      lessThan(LocalModelThresholds.recommendedTotalMemoryBytes),
    );
  });
}
