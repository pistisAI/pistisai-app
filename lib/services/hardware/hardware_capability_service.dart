import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../di/locator.dart' show serviceLocator;
import '../provider_discovery_service.dart';
import 'hardware_probe.dart';
import 'hardware_probe_default_stub.dart'
    if (dart.library.io) 'hardware_probe_default_io.dart';
import 'local_model_capability.dart';

export 'local_model_capability.dart';

/// Lists local model providers (Ollama / LM Studio) reachable on loopback.
typedef LocalProviderScan = Future<List<String>> Function();

/// Answers whether this computer can host a local model (#1077).
///
/// Combines the hardware probe with a loopback scan for a local model
/// provider through [ProviderDiscoveryService]. No cloud call is made. The
/// result is cached, so onboarding and later setup logic share one answer;
/// call [refresh] to probe again. [check] never throws: any failure answers
/// `unknown`.
class HardwareCapabilityService {
  HardwareCapabilityService({
    PlatformHardwareProbe? probe,
    LocalProviderScan? scanLocalProviders,
    bool useDefaultProbe = true,
    this.overallTimeout = const Duration(seconds: 15),
    this.providerScanTimeout = const Duration(seconds: 12),
  })  : _probe = probe ?? (useDefaultProbe ? _defaultProbe() : null),
        _scanLocalProviders = scanLocalProviders;

  /// Builds the service with the registered [ProviderDiscoveryService] when
  /// there is one.
  ///
  /// TODO(#1077): register this service in `lib/di/locator.dart` and read it
  /// with `serviceLocator.get<HardwareCapabilityService>()` instead.
  factory HardwareCapabilityService.fromServiceLocator() {
    ProviderDiscoveryService? discovery;
    try {
      if (serviceLocator.isRegistered<ProviderDiscoveryService>()) {
        discovery = serviceLocator.get<ProviderDiscoveryService>();
      }
    } catch (_) {
      discovery = null;
    }
    return HardwareCapabilityService(
      scanLocalProviders:
          discovery == null ? null : scanWithDiscovery(discovery),
    );
  }

  static HardwareCapabilityService? _shared;

  /// One instance per app run, so every caller reuses the cached result.
  static HardwareCapabilityService get shared =>
      _shared ??= HardwareCapabilityService.fromServiceLocator();

  /// Uses [ProviderDiscoveryService.scanForSupportModelProviders], which only
  /// probes loopback ports of Ollama and LM Studio.
  static LocalProviderScan scanWithDiscovery(
    ProviderDiscoveryService discovery,
  ) {
    return () async {
      final providers = await discovery.scanForSupportModelProviders();
      return [
        for (final p in providers)
          if (p.isLocal && p.isAvailable) p.name,
      ];
    };
  }

  static PlatformHardwareProbe? _defaultProbe() {
    if (kIsWeb) return null;
    try {
      return createDefaultHardwareProbe();
    } catch (_) {
      return null;
    }
  }

  final PlatformHardwareProbe? _probe;
  final LocalProviderScan? _scanLocalProviders;
  final Duration overallTimeout;

  /// Kept below [overallTimeout] so a slow scan still leaves the hardware
  /// answer (the discovery scan itself gives up after 10 seconds).
  final Duration providerScanTimeout;

  Future<LocalModelCapabilityResult>? _pending;
  LocalModelCapabilityResult? _last;

  /// The last answer, or null before the first [check] finished.
  LocalModelCapabilityResult? get lastResult => _last;

  /// The cached answer, computing it on first use.
  Future<LocalModelCapabilityResult> check() => _pending ??= _compute();

  /// Discards the cached answer and probes again.
  Future<LocalModelCapabilityResult> refresh() {
    _pending = null;
    return check();
  }

  Future<LocalModelCapabilityResult> _compute() async {
    final probe = _probe;
    if (probe == null || !probe.isSupported) {
      return _last = LocalModelCapabilityResult.unsupportedPlatform;
    }
    try {
      final result = await _probeAndEvaluate(probe).timeout(overallTimeout);
      return _last = result;
    } catch (e) {
      debugPrint('[HardwareCapability] check failed: $e');
      return _last = const LocalModelCapabilityResult(
        capability: LocalModelCapability.unknown,
        reason: LocalModelCapabilityReason.probeFailed,
      );
    }
  }

  Future<LocalModelCapabilityResult> _probeAndEvaluate(
    PlatformHardwareProbe probe,
  ) async {
    final results = await Future.wait<Object?>([
      _safeRead(probe),
      _safeScan(),
    ]);
    final result = evaluateLocalModelCapability(
      snapshot: results[0] as HardwareSnapshot?,
      localProviderNames: results[1] as List<String>,
    );
    debugPrint('[HardwareCapability] $result');
    return result;
  }

  Future<HardwareSnapshot?> _safeRead(PlatformHardwareProbe probe) async {
    try {
      return await probe.read() ?? const HardwareSnapshot();
    } catch (_) {
      return const HardwareSnapshot();
    }
  }

  Future<List<String>> _safeScan() async {
    final scan = _scanLocalProviders;
    if (scan == null) return const [];
    try {
      return await scan().timeout(providerScanTimeout);
    } catch (_) {
      return const [];
    }
  }
}
