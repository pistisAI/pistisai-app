import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pistisai/config/app_config.dart';
import 'package:pistisai/utils/logger.dart';
import 'package:pistisai/services/hermes/hermes_bot_install_service.dart';
import 'package:pistisai/services/hermes/hermes_endpoint_resolver.dart';
import 'package:pistisai/services/hermes/hermes_local_agent_api.dart';
import 'package:pistisai/services/provider_discovery_service.dart';
import 'package:pistisai/services/setup_status_service.dart';
import 'package:pistisai/services/provider_configuration_manager.dart';
import 'package:pistisai/models/provider_configuration.dart';
import 'package:pistisai/services/settings_preference_service.dart';

/// Connection method selection
enum ConnectionMethod {
  local,
  tailscale,
  custom,
  hermes,
}

/// Where a Hermes runtime is reachable during setup.
enum HermesLocation {
  local,
  tailscale,
}

/// Setup wizard state
class WizardState {
  static const Object _unset = Object();

  final int currentStep;
  final ConnectionMethod? selectedMethod;
  final HermesLocation? hermesLocation;
  final List<ProviderInfo> discoveredProviders;
  final List<TailscaleDevice> tailscaleDevices;
  final String? customUrl;
  final ProviderInfo? selectedProvider;
  final String? gatewayPassword; // OpenClaw Gateway password/token
  final String? hermesUrl; // Hermes Agent URL
  final String? hermesApiKey; // Hermes API key (auto-discovered)
  final HermesEndpointKind? detectedHermesKind;
  final String? hermesDetectionMessage;
  final bool isLoading;
  final String? errorMessage;
  final HermesBotInstallReport? lastBotInstall;

  const WizardState({
    this.currentStep = 0,
    this.selectedMethod,
    this.hermesLocation,
    this.discoveredProviders = const [],
    this.tailscaleDevices = const [],
    this.customUrl,
    this.selectedProvider,
    this.gatewayPassword,
    this.hermesUrl,
    this.hermesApiKey,
    this.detectedHermesKind,
    this.hermesDetectionMessage,
    this.isLoading = false,
    this.errorMessage,
    this.lastBotInstall,
  });

  WizardState copyWith({
    int? currentStep,
    ConnectionMethod? selectedMethod,
    Object? hermesLocation = _unset,
    List<ProviderInfo>? discoveredProviders,
    List<TailscaleDevice>? tailscaleDevices,
    Object? customUrl = _unset,
    Object? selectedProvider = _unset,
    String? gatewayPassword,
    Object? hermesUrl = _unset,
    Object? hermesApiKey = _unset,
    Object? detectedHermesKind = _unset,
    Object? hermesDetectionMessage = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
    Object? lastBotInstall = _unset,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      hermesLocation: identical(hermesLocation, _unset)
          ? this.hermesLocation
          : hermesLocation as HermesLocation?,
      discoveredProviders: discoveredProviders ?? this.discoveredProviders,
      tailscaleDevices: tailscaleDevices ?? this.tailscaleDevices,
      customUrl:
          identical(customUrl, _unset) ? this.customUrl : customUrl as String?,
      selectedProvider: identical(selectedProvider, _unset)
          ? this.selectedProvider
          : selectedProvider as ProviderInfo?,
      gatewayPassword: gatewayPassword ?? this.gatewayPassword,
      hermesUrl:
          identical(hermesUrl, _unset) ? this.hermesUrl : hermesUrl as String?,
      hermesApiKey:
          identical(hermesApiKey, _unset) ? this.hermesApiKey : hermesApiKey as String?,
      detectedHermesKind: identical(detectedHermesKind, _unset)
          ? this.detectedHermesKind
          : detectedHermesKind as HermesEndpointKind?,
      hermesDetectionMessage: identical(hermesDetectionMessage, _unset)
          ? this.hermesDetectionMessage
          : hermesDetectionMessage as String?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastBotInstall: identical(lastBotInstall, _unset)
          ? this.lastBotInstall
          : lastBotInstall as HermesBotInstallReport?,
    );
  }
}

enum _WizardOperation {
  providerScan,
  tailscaleDiscovery,
  connectionTest,
  completeSetup,
}

enum _HermesStepKind {
  welcome,
  location,
  tailscaleDiscovery,
  hermesUrl,
  connectionTest,
  hermesBot,
  completion,
}

/// Service managing the setup wizard flow
class SetupWizardService extends ChangeNotifier {
  final ProviderDiscoveryService _discovery;
  final SetupStatusService _setupStatus;
  final ProviderConfigurationManager _configManager;
  final SettingsPreferenceService? _settings;
  final HermesEndpointResolver _hermesResolver;
  final HermesLocalAgentApi? _localAgentApi;
  final HermesBotInstallService? _botInstaller;

  WizardState _state = const WizardState(selectedMethod: ConnectionMethod.hermes);
  Timer? _testTimeoutTimer;
  bool _setupCompleted = false; // Track if setup was completed this session
  bool _hermesAgentApiConnected = false;

  SetupWizardService(
    this._discovery,
    this._setupStatus,
    this._configManager, {
    SettingsPreferenceService? settings,
    HermesEndpointResolver? hermesResolver,
    HermesLocalAgentApi? localAgentApi,
    HermesBotInstallService? botInstaller,
  })  : _settings = settings,
        _hermesResolver = hermesResolver ?? HermesEndpointResolver(),
        _localAgentApi = localAgentApi,
        _botInstaller = botInstaller;

  WizardState get state => _state;
  bool get isSetupCompleted => _setupCompleted;

  /// True on the Hermes connection-test step, which already renders [WizardState.errorMessage].
  bool get isHermesConnectionTestStep {
    if (_state.selectedMethod != ConnectionMethod.hermes) {
      return false;
    }
    final steps = _hermesStepKinds();
    final index = _state.currentStep;
    if (index < 0 || index >= steps.length) {
      return false;
    }
    return steps[index] == _HermesStepKind.connectionTest;
  }

  /// True on the local-only pistisai package step.
  bool get isHermesBotStep {
    if (_state.hermesLocation != HermesLocation.local) {
      return false;
    }
    final steps = _hermesStepKinds();
    final index = _state.currentStep;
    if (index < 0 || index >= steps.length) {
      return false;
    }
    return steps[index] == _HermesStepKind.hermesBot;
  }

  /// The package step is shown only for a Hermes install on this machine.
  bool get showsLocalHermesBotStep =>
      _state.hermesLocation == HermesLocation.local;

  /// Toggle loading state while the UI step runs the package install, so the
  /// wizard's Complete button stays disabled until it finishes (avoids a
  /// concurrent second install).
  void setBotInstallRunning(bool running) {
    _state = _state.copyWith(isLoading: running);
    notifyListeners();
  }

  /// Record a package install that ran in the UI step so [completeSetup]
  /// does not run it a second time.
  void recordBotInstall(HermesBotInstallReport report) {
    _state = _state.copyWith(lastBotInstall: report);
    notifyListeners();
  }

  int? _localHermesPort() {
    final uri = Uri.tryParse(_state.hermesUrl?.trim() ?? '');
    if (uri != null && uri.hasPort && uri.port > 0) {
      return uri.port;
    }
    return AppConfig.defaultHermesPort;
  }

  /// Initialize the wizard - check if first run
  Future<bool> shouldShowWizard() async {
    try {
      // If setup was just completed, don't show wizard again
      if (_setupCompleted) {
        debugPrint('[SetupWizard] Setup already completed this session');
        return false;
      }

      final settings = _settings;
      if (settings != null && await settings.isSetupWizardDeferred()) {
        debugPrint('[SetupWizard] Setup deferred by user');
        return false;
      }

      // Force wizard in test mode
      if (AppConfig.forceSetupWizard) {
        debugPrint('[SetupWizard] Force setup wizard enabled, showing wizard');
        return true;
      }

      const userId = 'local_user';
      final setupComplete = await _setupStatus.hasCompletedSetup(userId);
      if (setupComplete) {
        debugPrint('[SetupWizard] Setup already completed for $userId');
        return false;
      }

      // If Hermes is already configured from a previous install (e.g. the
      // old Flatpak used FlutterSecureStorage which silently failed on Linux,
      // so setup completion was never persisted), treat it as done.
      if (settings != null) {
        final hermesUrl = await settings.getHermesUrl();
        final hermesEnabled = await settings.isHermesEnabled();
        if (hermesEnabled && hermesUrl != null && hermesUrl.isNotEmpty) {
          debugPrint(
              '[SetupWizard] Hermes already configured at $hermesUrl — marking setup complete');
          await _setupStatus.markSetupComplete(userId);
          return false;
        }
      }

      debugPrint('[SetupWizard] Setup not completed — showing wizard');
      return true;
    } catch (e) {
      debugPrint('[SetupWizard] Error checking wizard status: $e');
      return true; // Show wizard on error
    }
  }

  /// Set connection method
  void selectConnectionMethod(ConnectionMethod method) {
    ProviderInfo? updatedProvider = _state.selectedProvider;
    String? updatedCustomUrl = _state.customUrl;
    String? updatedHermesUrl = _state.hermesUrl;
    HermesLocation? updatedHermesLocation = _state.hermesLocation;

    if (method != ConnectionMethod.custom) {
      updatedCustomUrl = null;
      if (updatedProvider?.type == ProviderType.custom) {
        updatedProvider = null;
      }
    }

    if (method != ConnectionMethod.hermes) {
      updatedHermesUrl = null;
      updatedHermesLocation = null;
      if (updatedProvider?.type == ProviderType.hermes) {
        updatedProvider = null;
      }
    }

    _state = _state.copyWith(
      selectedMethod: method,
      selectedProvider: updatedProvider,
      customUrl: updatedCustomUrl,
      hermesUrl: updatedHermesUrl,
      hermesLocation: updatedHermesLocation,
      errorMessage: null,
    );

    // If current step is beyond the new total, reset to step 0 (WelcomeStep)
    // This can happen if user goes back and changes method after progressing
    final totalSteps = _getTotalSteps();
    if (_state.currentStep >= totalSteps) {
      _state = _state.copyWith(currentStep: 0);
    }

    notifyListeners();
  }

  /// Set custom URL
  void setCustomUrl(String url) {
    final trimmedUrl = url.trim();
    _state = _state.copyWith(
      customUrl: trimmedUrl,
      errorMessage: null,
    );

    // If we have a selected provider, update its URL to the custom one
    if (_state.selectedProvider != null) {
      final updatedProvider = ProviderInfo(
        id: _state.selectedProvider!.id,
        type: _state.selectedProvider!.type,
        name: _state.selectedProvider!.name,
        url: trimmedUrl,
        isLocal: _state.selectedProvider!.isLocal,
        isAvailable: _state.selectedProvider!.isAvailable,
      );
      _state = _state.copyWith(selectedProvider: updatedProvider);
    }

    notifyListeners();
  }

  /// Record whether Hermes is local or on a Tailscale-reachable device/VPS.
  void selectHermesLocation(HermesLocation location) {
    _state = _state.copyWith(
      hermesLocation: location,
      hermesUrl: location == HermesLocation.local ? _state.hermesUrl : null,
      hermesApiKey:
          location == HermesLocation.local ? _state.hermesApiKey : null,
      selectedProvider:
          location == HermesLocation.local ? _state.selectedProvider : null,
      tailscaleDevices: location == HermesLocation.local
          ? const []
          : _state.tailscaleDevices,
      errorMessage: null,
      lastBotInstall: null,
    );
    final totalSteps = _getTotalSteps();
    if (_state.currentStep >= totalSteps) {
      _state = _state.copyWith(currentStep: 1);
    }

    notifyListeners();
  }

  /// Select a Hermes runtime on a Tailscale device (VPS, home server, etc.).
  void selectHermesTailscaleDevice(TailscaleDevice device) {
    final ip = device.primaryIP;
    if (ip == null || ip.isEmpty) {
      return;
    }

    final url = 'http://$ip:${AppConfig.defaultHermesPort}';
    _state = _state.copyWith(
      hermesUrl: url,
      selectedProvider: ProviderInfo(
        id: 'hermes_tailscale_${device.hostname}',
        type: ProviderType.hermes,
        name: 'Hermes (${device.name})',
        url: url,
        isLocal: false,
        isAvailable: device.isOnline,
        role: ProviderRole.agentRuntime,
      ),
      errorMessage: null,
    );
    notifyListeners();
  }

  bool get isHermesTailscaleSetup =>
      _state.selectedMethod == ConnectionMethod.hermes &&
      _state.hermesLocation == HermesLocation.tailscale;

  /// Returns a user-visible error when Next should be blocked, or null if OK.
  String? validateCurrentStep() {
    final steps = _hermesStepKinds();
    if (_state.currentStep < 0 || _state.currentStep >= steps.length) {
      return null;
    }

    switch (steps[_state.currentStep]) {
      case _HermesStepKind.location:
        if (_state.hermesLocation == null) {
          return 'Choose where Hermes is running before continuing.';
        }
        return null;
      case _HermesStepKind.tailscaleDiscovery:
        if (_state.hermesUrl == null || _state.hermesUrl!.trim().isEmpty) {
          return 'Select a Tailscale device running Hermes.';
        }
        return null;
      case _HermesStepKind.connectionTest:
        if (_state.selectedMethod == ConnectionMethod.hermes &&
            _hermesAgentApiConnected) {
          return null;
        }
        if (_state.selectedMethod != ConnectionMethod.hermes) {
          return 'Choose Hermes Agent before continuing.';
        }
        return _state.errorMessage ?? hermesUnreachableMessage;
      default:
        return null;
    }
  }

  /// Go to next step
  void nextStep() {
    final validationError = validateCurrentStep();
    if (validationError != null) {
      _state = _state.copyWith(errorMessage: validationError);
      notifyListeners();
      return;
    }

    final totalSteps = _getTotalSteps();
    if (_state.currentStep < totalSteps - 1) {
      _state = _state.copyWith(
        currentStep: _state.currentStep + 1,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Go to previous step
  void previousStep() {
    if (_state.currentStep > 0) {
      _state = _state.copyWith(
        currentStep: _state.currentStep - 1,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Jump to specific step
  void goToStep(int step) {
    if (step >= 0 && step < _getTotalSteps()) {
      _state = _state.copyWith(
        currentStep: step,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Skip setup for now — user can configure an agent runtime later.
  Future<void> deferSetup() async {
    _setupCompleted = true;
    final settings = _settings;
    if (settings != null) {
      await settings.setSetupWizardDeferred(true);
    }
    notifyListeners();
  }

  /// Scan for local providers
  Future<void> scanForProviders() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      var providers = await _discovery.scanForAgentRuntimes();

      // Fallback: if the discovery service didn't find anything, try a
      // direct health check against the default Hermes URL.  The discovery
      // service's _scanHermes can fail due to timeout, network stack
      // differences, or API key issues during the /v1/models fetch — but
      // the /health endpoint is unauthenticated and always responds fast.
      if (providers.isEmpty) {
        final fallback = await _directHermesHealthCheck();
        if (fallback != null) {
          providers = [fallback];
          appLogger.info(
            '[SetupWizard] Discovery service found nothing, but direct health check succeeded',
          );
        }
      }

      final selectedRuntime = _selectPreferredRuntime(providers);

      _state = _state.copyWith(
        discoveredProviders: providers,
        selectedProvider: selectedRuntime,
        isLoading: false,
        errorMessage: null,
      );
      notifyListeners();

      appLogger.info(
        '[SetupWizard] Provider scan completed with ${providers.length} providers',
      );
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Provider scan failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.providerScan),
      );
      notifyListeners();
    }
  }

  /// Direct health check against the default Hermes URL.
  /// Used as a fallback when the discovery service's scan fails.
  Future<ProviderInfo?> _directHermesHealthCheck() async {
    try {
      final baseUrl = AppConfig.defaultHermesUrl;
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        appLogger.info('[SetupWizard] Direct health check found Hermes at $baseUrl');
        return ProviderInfo(
          id: 'hermes_discovered',
          type: ProviderType.hermes,
          name: 'Hermes Agent',
          url: baseUrl,
          isLocal: true,
          isAvailable: true,
          version: null,
          availableModels: const [],
          role: ProviderRole.agentRuntime,
        );
      }
    } catch (e) {
      appLogger.info('[SetupWizard] Direct health check failed: $e');
    }
    return null;
  }

  /// Discover Tailscale devices
  Future<void> discoverTailscaleDevices() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final devices = await _discovery.discoverTailscaleDevices();
      _state = _state.copyWith(
        tailscaleDevices: devices,
        isLoading: false,
        errorMessage: null,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Tailscale discovery failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.tailscaleDiscovery),
      );
      notifyListeners();
    }
  }

  /// Look up a local Hermes endpoint and prefill the wizard URL.
  ///
  /// An agent API is stored as connected. A desktop dashboard URL is stored
  /// with [WizardState.hermesDetectionMessage] and is not a successful connection.
  Future<void> resolveLocalHermes() async {
    if (_state.hermesLocation == HermesLocation.tailscale) {
      return;
    }

    var resolution = await _hermesResolver.resolve(
      savedUrl: _state.hermesUrl,
    );
    if (!resolution.isAgentApi && _localAgentApi != null) {
      final ready = await _localAgentApi.ensure(
        _hermesResolver,
        preferredKey: _state.hermesApiKey,
      );
      resolution = ready.resolution;
      final key = ready.apiKey;
      if (key != null && key.isNotEmpty) {
        _state = _state.copyWith(hermesApiKey: key);
      }
    }
    _applyHermesResolution(resolution, replaceUrl: true);
    notifyListeners();
  }

  /// Test connection to provider
  Future<ConnectionTestResult?> testConnection(String url) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final apiKey = _state.selectedMethod == ConnectionMethod.hermes
          ? _state.hermesApiKey
          : null;
      final ConnectionTestResult result;
      if (_state.selectedMethod == ConnectionMethod.hermes) {
        var resolution = await _hermesResolver.classify(url);
        if (!resolution.isAgentApi &&
            _state.hermesLocation != HermesLocation.tailscale &&
            _localAgentApi != null) {
          final ready = await _localAgentApi.ensure(
            _hermesResolver,
            preferredKey: _state.hermesApiKey,
          );
          resolution = ready.resolution;
          final key = ready.apiKey;
          if (key != null && key.isNotEmpty) {
            _state = _state.copyWith(hermesApiKey: key);
          }
        }
        _applyHermesResolution(
          resolution,
          replaceUrl: resolution.isAgentApi,
        );
        result = ConnectionTestResult(
          isConnected: resolution.isAgentApi,
          url: resolution.url,
          message: resolution.isAgentApi || resolution.isDesktopDashboard
              ? resolution.message
              : _mapUserSafeError(_WizardOperation.connectionTest),
          endpointKind: resolution.kind,
        );
        _state = _state.copyWith(
          isLoading: false,
          errorMessage: result.isConnected ? null : result.message,
        );
      } else {
        result = await _discovery.testConnection(
          url,
          apiKey: apiKey,
        );
        _state = _state.copyWith(
          isLoading: false,
          errorMessage: result.isConnected
              ? null
              : _mapUserSafeError(_WizardOperation.connectionTest),
        );
      }
      notifyListeners();
      return result;
    } catch (e, stackTrace) {
      _hermesAgentApiConnected = false;
      appLogger.error(
        '[SetupWizard] Connection test failed for $url',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.connectionTest),
      );
      notifyListeners();
      return null;
    }
  }

  void _applyHermesResolution(
    HermesEndpointResolution resolution, {
    required bool replaceUrl,
  }) {
    _hermesAgentApiConnected = resolution.isAgentApi;
    final detectionMessage =
        resolution.isDesktopDashboard ? resolution.message : null;
    final provider = ProviderInfo(
      id: 'hermes_wizard',
      type: ProviderType.hermes,
      name: _state.hermesLocation == HermesLocation.tailscale
          ? 'Hermes Agent (remote)'
          : 'Hermes Agent',
      url: resolution.url,
      isLocal: _state.hermesLocation != HermesLocation.tailscale,
      isAvailable: resolution.isAgentApi,
      role: ProviderRole.agentRuntime,
    );
    _state = _state.copyWith(
      hermesUrl: replaceUrl ? resolution.url : _state.hermesUrl,
      selectedProvider: provider,
      detectedHermesKind: resolution.kind,
      hermesDetectionMessage: detectionMessage,
    );
  }

  /// Select a provider
  void selectProvider(ProviderInfo provider) {
    _state = _state.copyWith(
      selectedProvider: provider,
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Set the Hermes API key in wizard state (used when a key is generated
  /// during the wizard so _persistRuntimeSelection saves it).
  void setHermesApiKey(String key) {
    _state = _state.copyWith(
      hermesApiKey: key.trim(),
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Set Hermes Agent URL
  void setHermesUrl(String url) {
    final trimmedUrl = url.trim();
    final isLocal = _state.hermesLocation != HermesLocation.tailscale;
    _hermesAgentApiConnected = false;
    _state = _state.copyWith(
      hermesUrl: trimmedUrl,
      detectedHermesKind: null,
      hermesDetectionMessage: null,
      errorMessage: null,
      lastBotInstall: null,
    );
    final hermesProvider = ProviderInfo(
      id: 'hermes_wizard',
      type: ProviderType.hermes,
      name: isLocal ? 'Hermes Agent' : 'Hermes Agent (remote)',
      url: trimmedUrl.isNotEmpty ? trimmedUrl : AppConfig.defaultHermesUrl,
      isLocal: isLocal,
      isAvailable: false,
      role: ProviderRole.agentRuntime,
    );
    _state = _state.copyWith(selectedProvider: hermesProvider);

    notifyListeners();
  }

  /// Auto-discover the Hermes API key from the local .env file
  Future<String?> discoverHermesApiKey() async {
    if (_settings == null) return null;

    final key = await _settings.getHermesApiKey();
    if (key != null && key.isNotEmpty) {
      _state = _state.copyWith(
        hermesApiKey: key,
      );
      notifyListeners();
      appLogger.info('[SetupWizard] Auto-discovered Hermes API key');
      return key;
    }

    if (_state.hermesLocation == HermesLocation.tailscale) {
      appLogger.info(
        '[SetupWizard] Remote Hermes — API key must be entered manually',
      );
      return null;
    }

    appLogger.info(
        '[SetupWizard] No Hermes API key found — generating a new one');
    final generated = _generateApiKey();
    _state = _state.copyWith(hermesApiKey: generated);
    notifyListeners();
    return generated;
  }

  /// Generate a cryptographically random API key (64 hex chars, 'psk_' prefix).
  static String _generateApiKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return 'psk_${values.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Write the API key to the Hermes .env file so the Hermes API server
  /// accepts it. Creates the file if missing, updates the existing
  /// API_SERVER_KEY line if present, otherwise appends it.
  Future<bool> writeApiKeyToHermesEnv(String key) async {
    if (kIsWeb) return false;
    try {
      final home = hermesHomeDirectory();
      final envPath = home != null
          ? '$home${Platform.pathSeparator}.env'
          : Platform.environment['HERMES_HOME'] != null
              ? '${Platform.environment['HERMES_HOME']}${Platform.pathSeparator}.env'
              : '${Platform.environment['HOME']}${Platform.pathSeparator}.hermes${Platform.pathSeparator}.env';
      final file = File(envPath);

      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        var replaced = false;
        final updated = lines.map((line) {
          if (line.trim().startsWith('API_SERVER_KEY=')) {
            replaced = true;
            return 'API_SERVER_KEY=$key';
          }
          return line;
        }).toList();
        if (!replaced) updated.add('API_SERVER_KEY=$key');
        await file.writeAsString(updated.join('\n'));
      } else {
        await file.parent.create(recursive: true);
        await file.writeAsString('API_SERVER_KEY=$key\n');
      }
      appLogger.info('[SetupWizard] API key written to $envPath');
      return true;
    } catch (e) {
      appLogger.warning('[SetupWizard] Failed to write API key to .env: $e');
      return false;
    }
  }

  /// Complete setup and save configuration
  Future<bool> completeSetup() async {
    final validationError = _validateCompleteSetupInput();
    if (validationError != null) {
      _state = _state.copyWith(isLoading: false, errorMessage: validationError);
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final method = _state.selectedMethod;
      // Use custom URL if provided, otherwise use provider's discovered URL
      final customUrl = _state.customUrl?.trim();
      final hermesUrl = _state.hermesUrl?.trim();
      final providerUrl = (method == ConnectionMethod.hermes &&
              hermesUrl != null &&
              hermesUrl.isNotEmpty)
          ? hermesUrl
          : (_shouldUseCustomUrl() && customUrl != null && customUrl.isNotEmpty)
              ? customUrl
              : _state.selectedProvider!.url;

      // Save provider configuration
      await _configManager.saveProvider(
        name: _state.selectedProvider!.name,
        type: _state.selectedProvider!.type,
        url: providerUrl,
        isLocal: _state.selectedProvider!.isLocal,
        isDefault: true,
        role: ProviderRole.agentRuntime,
      );

      await _persistRuntimeSelection(providerUrl);


      // Mark setup as complete
      // Hardcoded local_user as auth service is not currently integrated in wizard
      final userId = 'local_user';
      await _setupStatus.markSetupComplete(userId);

      // Mark setup as completed in this session
      _setupCompleted = true;
      await _settings?.setSetupWizardDeferred(false);
      appLogger.info('[SetupWizard] Setup completed successfully');

      HermesBotInstallReport? botReport;
      if (_state.hermesLocation == HermesLocation.local &&
          _state.lastBotInstall?.succeeded == true) {
        botReport = _state.lastBotInstall;
      }
      if (botReport == null && _state.hermesLocation == HermesLocation.local) {
        try {
          botReport = await (_botInstaller ?? HermesBotInstallService())
              .install(agentPort: _localHermesPort());
        } catch (error, stackTrace) {
          appLogger.error(
            '[SetupWizard] PistisAI package install failed',
            error: error,
            stackTrace: stackTrace,
          );
          botReport = HermesBotInstallReport(<HermesBotInstallStep>[
            HermesBotInstallStep(
              name: HermesBotInstallService.agentStep,
              status: HermesBotInstallStatus.failed,
              detail: '$error',
            ),
          ]);
        }
      }

      _state = _state.copyWith(
        isLoading: false,
        errorMessage: null,
        lastBotInstall: botReport,
      );
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Setup completion failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.completeSetup),
      );
      notifyListeners();
      return false;
    }
  }


  /// Clear error message
  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  /// Reset wizard state
  void reset() {
    _state = const WizardState(selectedMethod: ConnectionMethod.hermes);
    notifyListeners();
  }

  int _getTotalSteps() {
    return _hermesStepKinds().length;
  }

  List<_HermesStepKind> _hermesStepKinds() {
    final kinds = <_HermesStepKind>[
      _HermesStepKind.welcome,
      _HermesStepKind.location,
    ];
    if (_state.hermesLocation == HermesLocation.tailscale) {
      kinds.add(_HermesStepKind.tailscaleDiscovery);
    }
    kinds.addAll([
      _HermesStepKind.hermesUrl,
      _HermesStepKind.connectionTest,
    ]);
    if (_state.hermesLocation == HermesLocation.local) {
      kinds.add(_HermesStepKind.hermesBot);
    }
    kinds.add(_HermesStepKind.completion);
    return kinds;
  }

  ProviderInfo? _selectPreferredRuntime(List<ProviderInfo> providers) {
    if (providers.isEmpty) {
      return null;
    }

    for (final type in [
      ProviderType.hermes,
      ProviderType.custom,
    ]) {
      final matches = providers.where((provider) => provider.type == type);
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }

    return providers.firstWhere(
      (provider) => provider.canServeAsAgentRuntime,
      orElse: () => providers.first,
    );
  }

  String? _validateCompleteSetupInput() {
    if (_state.selectedProvider == null) {
      return 'Select an agent runtime before completing setup.';
    }

    if (!_state.selectedProvider!.canServeAsAgentRuntime) {
      return 'Ollama, LM Studio, and raw model providers are support model providers. Select Hermes to complete setup.';
    }

    // Hermes-specific validation
    if (_state.selectedMethod == ConnectionMethod.hermes) {
      if (_state.selectedProvider!.type != ProviderType.hermes) {
        return 'Select a Hermes Agent runtime to complete Hermes setup.';
      }
      final hermesUrl = _state.hermesUrl?.trim() ?? '';
      if (hermesUrl.isEmpty) {
        return 'Enter a Hermes Agent URL.';
      }
      final uri = Uri.tryParse(hermesUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Enter a valid Hermes URL that starts with http:// or https://.';
      }
      if (_state.hermesLocation == HermesLocation.tailscale) {
        final key = _state.hermesApiKey?.trim() ?? '';
        if (key.isEmpty) {
          return 'Enter the Hermes API key from your Tailscale server.';
        }
      }
      return null;
    }

    if (_shouldUseCustomUrl()) {
      final requireCustomUrl = _state.selectedMethod == ConnectionMethod.custom;
      final customUrlValidationError = _validateCustomUrl(
        _state.customUrl,
        requireValue: requireCustomUrl,
      );
      if (customUrlValidationError != null) {
        return customUrlValidationError;
      }
    }

    return null;
  }

  Future<void> _persistRuntimeSelection(String runtimeUrl) async {
    final settings = _settings;
    if (settings == null) {
      return;
    }

    switch (_state.selectedProvider!.type) {
      case ProviderType.hermes:
        await settings.setHermesEnabled(true);
        await settings.setHermesUrl(runtimeUrl);
        await settings.setActiveBackend(BackendType.hermes);
        // Use the key discovered in the wizard step, or fall back to
        // auto-discovery from .env if it wasn't loaded yet.
        final key = _state.hermesApiKey?.isNotEmpty == true
            ? _state.hermesApiKey
            : await settings.getHermesApiKey();
        if (key != null && key.isNotEmpty) {
          await settings.setHermesApiKey(key);
        }
        break;
      case ProviderType.pistisaiHub:
        await settings.setHermesEnabled(true);
        await settings.setHermesUrl(runtimeUrl);
        await settings.setActiveBackend(BackendType.hermes);
        break;
      case ProviderType.custom:
        await settings.setActiveBackend(null);
        break;
      case ProviderType.ollama:
      case ProviderType.lmStudio:
      case ProviderType.openAICompatible:
        break;
    }
  }

  bool _shouldUseCustomUrl() {
    final selectedMethod = _state.selectedMethod;
    if (selectedMethod != null) {
      return selectedMethod == ConnectionMethod.custom;
    }

    return _state.selectedProvider?.type == ProviderType.custom;
  }

  String? _validateCustomUrl(String? url, {bool requireValue = false}) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (requireValue) {
        return 'Enter a valid custom URL that starts with http:// or https://.';
      }
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    final hasValidScheme = uri?.scheme == 'http' || uri?.scheme == 'https';
    final hasHost = uri?.host.isNotEmpty == true;

    if (uri == null || !hasValidScheme || !hasHost) {
      return 'Enter a valid custom URL that starts with http:// or https://.';
    }

    return null;
  }

  String _mapUserSafeError(_WizardOperation operation) {
    switch (operation) {
      case _WizardOperation.providerScan:
        return 'Could not scan for providers. Make sure local services are running and try again.';
      case _WizardOperation.tailscaleDiscovery:
        return 'Could not discover Tailscale devices. Make sure Tailscale is running and authenticated, then try again.';
      case _WizardOperation.connectionTest:
        return 'Connection test failed. Verify your connection settings and try again.';
      case _WizardOperation.completeSetup:
        return 'Setup could not be completed right now. Please verify your settings and try again.';
    }
  }

  @override
  void dispose() {
    _testTimeoutTimer?.cancel();
    super.dispose();
  }
}
