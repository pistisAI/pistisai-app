import 'package:flutter_test/flutter_test.dart';
import 'package:pistisai/di/locator.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/services/hardware/hardware_capability_service.dart';
import 'package:pistisai/services/provider_discovery_service.dart';

/// Loopback scan stand-in: answers LM Studio without touching the network.
class _FakeDiscovery extends ProviderDiscoveryService {
  int scans = 0;

  @override
  Future<List<ProviderInfo>> scanForSupportModelProviders() async {
    scans++;
    return const [
      ProviderInfo(
        id: 'local_lm_studio',
        name: 'LM Studio',
        type: ProviderType.lmStudio,
        url: 'http://127.0.0.1:1234',
        isLocal: true,
        isAvailable: true,
        role: ProviderRole.supportModelProvider,
      ),
    ];
  }
}

/// The hardware check is registered in the service locator (#1077), so
/// every caller shares one instance and its cached answer.
void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  test('registers one shared HardwareCapabilityService', () {
    registerHardwareCapabilityService();
    registerHardwareCapabilityService(); // safe to call twice

    expect(serviceLocator.isRegistered<HardwareCapabilityService>(), isTrue);
    expect(
      identical(
        serviceLocator.get<HardwareCapabilityService>(),
        serviceLocator.get<HardwareCapabilityService>(),
      ),
      isTrue,
    );
  });

  test('scans loopback through the registered ProviderDiscoveryService',
      () async {
    final discovery = _FakeDiscovery();
    serviceLocator.registerSingleton<ProviderDiscoveryService>(discovery);
    registerHardwareCapabilityService();

    final result =
        await serviceLocator.get<HardwareCapabilityService>().check();

    if (result.reason == LocalModelCapabilityReason.unsupportedPlatform) {
      // No hardware probe on this platform: the scan is skipped.
      expect(discovery.scans, 0);
    } else {
      expect(discovery.scans, 1);
      expect(result.localProviderNames, ['LM Studio']);
    }
  });

  test('works without a ProviderDiscoveryService', () async {
    registerHardwareCapabilityService();

    final result =
        await serviceLocator.get<HardwareCapabilityService>().check();

    expect(result.localProviderNames, isEmpty);
  });
}
