import 'package:pistisai/models/provider_configuration.dart';
import 'dart:io';

import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/hermes/hermes_local_agent_api.dart';
import 'package:pistisai/services/auth_service.dart';
import 'package:pistisai/services/onboarding/setup_wizard_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:pistisai/services/settings_preference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SetupWizardService P0-1 hardening', () {
    late _FakeProviderDiscoveryService discovery;
    late _FakeSetupStatusService setupStatus;
    late _FakeProviderConfigurationManager configManager;
    late SetupWizardService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      discovery = _FakeProviderDiscoveryService();
      setupStatus = _FakeSetupStatusService();
      configManager = _FakeProviderConfigurationManager();
      service = SetupWizardService(discovery, setupStatus, configManager);
    });

    test('provider scan failure maps message and resets loading', () async {
      discovery.scanError = Exception('socket timeout details');

      await service.scanForProviders();

      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Could not scan for providers. Make sure local services are running and try again.',
      );
      expect(service.state.errorMessage, isNot(contains('socket timeout')));
    });

    test('tailscale discovery failure maps message and resets loading',
        () async {
      discovery.tailscaleError = Exception('tailscale command failed');

      await service.discoverTailscaleDevices();

      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Could not discover Tailscale devices. Make sure Tailscale is running and authenticated, then try again.',
      );
      expect(service.state.errorMessage, isNot(contains('command failed')));
    });

    test('complete setup validation failure is deterministic and not loading',
        () async {
      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Select an agent runtime before completing setup.',
      );
    });

    test('complete setup persistence failure is deterministic and not loading',
        () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl(_customRuntimeProvider().url);
      configManager.throwOnSave = true;

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Setup could not be completed right now. Please verify your settings and try again.',
      );
    });

    test('invalid custom URL is rejected before persistence', () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('not-a-valid-url');

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Enter a valid custom URL that starts with http:// or https://.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('blank custom URL is rejected before persistence in custom mode',
        () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('   ');

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Enter a valid custom URL that starts with http:// or https://.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('stale custom URL does not block Hermes runtime completion', () async {
      service.selectConnectionMethod(ConnectionMethod.custom);
      service.selectProvider(_customRuntimeProvider());
      service.setCustomUrl('not-a-valid-url');

      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.local);
      service.setHermesUrl('http://127.0.0.1:8642');

      final bool success = await service.completeSetup();

      expect(success, isTrue);
      expect(service.state.isLoading, isFalse);
      expect(service.state.errorMessage, isNull);
      expect(configManager.saveProviderCallCount, 1);
      expect(configManager.lastSavedUrl, 'http://127.0.0.1:8642');
    });

    test('local model provider cannot complete runtime setup', () async {
      service.selectConnectionMethod(ConnectionMethod.local);
      service.selectProvider(_localProvider());

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(service.state.isLoading, isFalse);
      expect(
        service.state.errorMessage,
        'Ollama, LM Studio, and raw model providers are support model providers. Select Hermes to complete setup.',
      );
      expect(configManager.saveProviderCallCount, 0);
    });

    test('provider scan selects Hermes and excludes support providers',
        () async {
      discovery.runtimeProviders = [
        _hermesRuntimeProvider(),
      ];

      await service.scanForProviders();

      expect(service.state.discoveredProviders, hasLength(1));
      expect(service.state.selectedProvider?.type, ProviderType.hermes);
    });

    test('deferSetup hides wizard until user completes setup', () async {
      final settings = SettingsPreferenceService();
      service = SetupWizardService(
        discovery,
        setupStatus,
        configManager,
        settings: settings,
      );

      expect(await service.shouldShowWizard(), isTrue);

      await service.deferSetup();

      expect(await service.shouldShowWizard(), isFalse);
      expect(await settings.isSetupWizardDeferred(), isTrue);
    });

    test('Hermes tailscale setup requires API key before completion', () async {
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.tailscale);
      service.setHermesUrl('http://100.64.0.5:8642');
      service.selectProvider(_hermesRuntimeProvider().copyWith(
        url: 'http://100.64.0.5:8642',
        isLocal: false,
      ));

      final bool success = await service.completeSetup();

      expect(success, isFalse);
      expect(
        service.state.errorMessage,
        'Enter the Hermes API key from your Tailscale server.',
      );
    });

    test('Hermes tailscale setup completes with URL and API key', () async {
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.tailscale);
      service.setHermesUrl('http://100.64.0.5:8642');
      service.setHermesApiKey('psk_test_key');
      service.selectProvider(_hermesRuntimeProvider().copyWith(
        url: 'http://100.64.0.5:8642',
        isLocal: false,
      ));

      final bool success = await service.completeSetup();

      expect(success, isTrue);
      expect(configManager.lastSavedUrl, 'http://100.64.0.5:8642');
    });

    test('nextStep stays on the Hermes connection test when the probe failed',
        () async {
      service = SetupWizardService(
        discovery,
        setupStatus,
        configManager,
        hermesResolver: HermesEndpointResolver(
          probe: (Uri uri) async => null,
          listServePorts: () async => <int>[],
        ),
      );
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.local);
      service.setHermesUrl('http://127.0.0.1:8642');
      service.goToStep(3);

      await service.testConnection('http://127.0.0.1:8642');
      service.nextStep();

      expect(service.state.currentStep, 3);
      expect(service.state.errorMessage, hermesUnreachableMessage);
    });

    test('desktop dashboard URL is kept and blocks Next', () async {
      service = SetupWizardService(
        discovery,
        setupStatus,
        configManager,
        hermesResolver: HermesEndpointResolver(
          probe: (Uri uri) async {
            if (uri.port == 51910 && uri.path == '/api/health') {
              return 200;
            }
            return null;
          },
          listServePorts: () async => <int>[51910],
        ),
      );
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.local);

      await service.resolveLocalHermes();

      expect(service.state.hermesUrl, 'http://127.0.0.1:51910');
      expect(service.state.hermesDetectionMessage, contains('51910'));
      expect(service.state.detectedHermesKind,
          HermesEndpointKind.desktopDashboard);

      service.goToStep(3);
      await service.testConnection(service.state.hermesUrl!);
      service.nextStep();

      expect(service.state.currentStep, 3);
      expect(service.state.errorMessage, contains('51910'));
      expect(service.state.errorMessage, contains('agent API'));
    });

    test('local agent API startup replaces the desktop URL and allows Next',
        () async {
      final home = Directory.systemTemp.createTempSync('hermes-wizard-test');
      addTearDown(() => home.deleteSync(recursive: true));
      var started = false;
      final resolver = HermesEndpointResolver(
        probe: (Uri uri) async {
          if (started && uri.port == 8642 && uri.path == '/health') {
            return 200;
          }
          if (uri.port == 51910 && uri.path == '/api/health') {
            return 200;
          }
          return null;
        },
        listServePorts: () async => <int>[51910],
      );
      service = SetupWizardService(
        discovery,
        setupStatus,
        configManager,
        hermesResolver: resolver,
        localAgentApi: HermesLocalAgentApi(
          readHome: () => home.path,
          restartGateway: (String path) async {
            started = true;
            return true;
          },
          generateKey: () => 'psk_0123456789abcdef',
        ),
      );
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.selectHermesLocation(HermesLocation.local);
      service.setHermesUrl('http://127.0.0.1:51910');
      service.goToStep(3);

      await service.testConnection('http://127.0.0.1:51910');
      service.nextStep();

      expect(service.state.hermesUrl, 'http://127.0.0.1:8642');
      expect(service.state.hermesApiKey, 'psk_0123456789abcdef');
      expect(service.state.currentStep, 4);
      expect(service.state.errorMessage, isNull);
    });

    test('nextStep blocks the connection step until Hermes is chosen', () {
      service.goToStep(0);
      service.nextStep();
      expect(service.state.currentStep, 1);

      service.nextStep();

      expect(service.state.currentStep, 1);
      expect(
        service.state.errorMessage,
        'Choose where Hermes is running before continuing.',
      );

      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.nextStep();

      expect(service.state.currentStep, 1);
      expect(service.state.errorMessage, isNotNull);
    });

    test('nextStep blocks Hermes location step until a location is chosen',
        () {
      service.selectConnectionMethod(ConnectionMethod.hermes);
      service.goToStep(1);

      service.nextStep();

      expect(service.state.currentStep, 1);
      expect(
        service.state.errorMessage,
        'Choose where Hermes is running before continuing.',
      );

      service.selectHermesLocation(HermesLocation.local);
      service.nextStep();

      expect(service.state.currentStep, 2);
      expect(service.state.errorMessage, isNull);
    });

    test('auto-discovered runtime does not skip first-run wizard', () async {
      await configManager.setConfiguration(
        HermesProviderConfiguration(
          providerId: 'auto_hermes_discovered',
          baseUrl: 'http://127.0.0.1:8642',
          customSettings: const {
            'role': 'agentRuntime',
            'auto_configured': true,
          },
        ),
      );

      expect(await configManager.getAllAgentRuntimes(), isNotEmpty);
      expect(await service.shouldShowWizard(), isTrue);
    });
  });
}

ProviderInfo _customRuntimeProvider() {
  return const ProviderInfo(
    id: 'custom_provider',
    name: 'Custom Runtime',
    type: ProviderType.custom,
    url: 'https://example.com',
    isLocal: false,
    isAvailable: true,
    role: ProviderRole.agentRuntime,
  );
}

ProviderInfo _localProvider() {
  return const ProviderInfo(
    id: 'local_lm_studio',
    name: 'LM Studio',
    type: ProviderType.lmStudio,
    url: 'http://127.0.0.1:1234',
    isLocal: true,
    isAvailable: true,
    role: ProviderRole.supportModelProvider,
  );
}

ProviderInfo _hermesRuntimeProvider() {
  return const ProviderInfo(
    id: 'hermes_runtime',
    name: 'Hermes Agent',
    type: ProviderType.hermes,
    url: 'http://127.0.0.1:8642',
    isLocal: true,
    isAvailable: true,
    role: ProviderRole.agentRuntime,
  );
}

class _FakeProviderDiscoveryService extends ProviderDiscoveryService {
  Object? scanError;
  Object? tailscaleError;
  List<ProviderInfo> runtimeProviders = <ProviderInfo>[];

  @override
  Future<List<ProviderInfo>> scanForAgentRuntimes() async {
    if (scanError != null) {
      throw scanError!;
    }
    return runtimeProviders;
  }

  @override
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async {
    if (tailscaleError != null) {
      throw tailscaleError!;
    }
    return <TailscaleDevice>[];
  }
}

class _FakeProviderConfigurationManager extends ProviderConfigurationManager {
  bool throwOnSave = false;
  int saveProviderCallCount = 0;
  String? lastSavedUrl;

  @override
  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
    ProviderRole? role,
  }) async {
    saveProviderCallCount += 1;
    lastSavedUrl = url;
    if (throwOnSave) {
      throw Exception('save failed');
    }
  }

  @override
  Future<List<ProviderInfo>> getAllProviders() async {
    return <ProviderInfo>[];
  }
}

class _FakeSetupStatusService extends SetupStatusService {
  _FakeSetupStatusService()
      : super(
          authService: _FakeAuthService(),
          storage: InMemorySetupStatusStorage(),
        );

  @override
  Future<void> markSetupComplete(String userId) async {}
}

class _FakeAuthService extends ChangeNotifier implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
