library;

import 'package:flutter/material.dart';

import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../models/instance.dart';
import '../../services/agent_runtime/runtime_status_snapshot.dart';
import '../../services/provider_discovery_service.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../services/connection_manager_service.dart';
import '../../services/hermes/hermes_streaming_service.dart';
import '../../services/settings_preference_service.dart' hide BackendType;
import '../../config/app_config.dart';
import '../../config/theme.dart';

/// Screen displaying the agent runtime the app talks to and the model
/// providers found on this device.
///
/// The runtime card reflects [ConnectionManagerService] (the saved Hermes
/// URL and its latest health check). Starting or stopping the runtime from
/// the app is not wired yet, so no such control is shown (#857).
class InstancesScreen extends StatefulWidget {
  const InstancesScreen({super.key});

  @override
  State<InstancesScreen> createState() => _InstancesScreenState();
}

class _InstancesScreenState extends State<InstancesScreen> {
  /// Loading state indicator
  bool _isLoading = true;

  /// Error message if data loading fails
  String? _errorMessage;

  /// What the app knows about the active agent runtime.
  RuntimeStatusSnapshot _runtime =
      const RuntimeStatusSnapshot(state: RuntimeLinkState.unconfigured);

  /// List of model instances
  List<ModelInstanceState> _modelInstances = [];

  /// Error raised while scanning model providers, shown in that section.
  String? _modelsError;

  ConnectionManagerService? get _connectionManager {
    if (!di.serviceLocator.isRegistered<ConnectionManagerService>()) {
      return null;
    }
    return di.serviceLocator<ConnectionManagerService>();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load all instance data
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _updateRuntimeState();
      await _loadModelInstances();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Run a real health check against the active runtime and read back what
  /// the connection manager reports.
  Future<void> _updateRuntimeState() async {
    final connectionManager = _connectionManager;
    if (connectionManager == null) {
      _runtime =
          const RuntimeStatusSnapshot(state: RuntimeLinkState.unconfigured);
      return;
    }
    if (connectionManager.currentBackend != null) {
      await connectionManager.testConnection();
    }
    _runtime = RuntimeStatusSnapshot.fromConnectionManager(connectionManager);
  }

  Future<void> _loadModelInstances() async {
    try {
      final discovery = di.serviceLocator<ProviderDiscoveryService>();
      final providers = await discovery.scanForProviders();

      final instances = <ModelInstanceState>[];
      for (final p in providers) {
        final status = p.isAvailable ? 'running' : 'offline';
        final models = p.availableModels.isEmpty
            ? const <String>['unknown']
            : p.availableModels;
        for (final model in models) {
          instances.add(ModelInstanceState(
            provider: p.name.toLowerCase(),
            model: model,
            status: status,
            // Providers report no concurrency or tier data; these fields
            // are not shown.
            activeRequests: 0,
            maxConcurrent: 0,
            tier: '',
            rateLimited: false,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _modelInstances = instances;
          _modelsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _modelInstances = [];
          _modelsError = e.toString();
        });
      }
    }
  }

  /// Get status badge type from model status string
  StatusType _getModelStatusType(String status) {
    switch (status.toLowerCase()) {
      case 'running':
      case 'active':
        return StatusType.running;
      case 'idle':
        return StatusType.idle;
      case 'error':
        return StatusType.error;
      case 'stopped':
        return StatusType.stopped;
      default:
        return StatusType.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.instancesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.instancesRefresh,
            onPressed: _isLoading ? null : _loadData,
          ),
          const PopOutButton(
            sectionName: 'instances',
            branchIndex: 3,
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadData,
        errorMessage: _errorMessage,
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 120,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: l10n.commonErrorDetails(_errorMessage!),
        onRetry: _loadData,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          // Agent runtime section
          CardSection(
            title: l10n.instancesRuntimeSection,
            children: [
              _RuntimeStateCard(runtime: _runtime),
            ],
          ),

          // Hermes Agent Section
          const _HermesSettingsCard(),

          // Model Instances Section
          CardSection(
            title: l10n.instancesModelInstances,
            children: [
              if (_modelsError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.instancesModelsLoadFailed(_modelsError!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (_modelInstances.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.instancesNoModels),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _modelInstances.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final instance = _modelInstances[index];
                    return _ModelInstanceCard(
                      instance: instance,
                      getStatusType: _getModelStatusType,
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card showing the active agent runtime as the connection manager sees it.
class _RuntimeStateCard extends StatelessWidget {
  final RuntimeStatusSnapshot runtime;

  const _RuntimeStateCard({required this.runtime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final (StatusType statusType, String label) = switch (runtime.state) {
      RuntimeLinkState.connected => (
          StatusType.running,
          l10n.runtimeStatusConnected
        ),
      RuntimeLinkState.disconnected => (
          StatusType.error,
          l10n.runtimeStatusUnreachable
        ),
      RuntimeLinkState.unconfigured => (
          StatusType.unknown,
          l10n.runtimeStatusNotConfigured
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusBadge(status: statusType, label: label.toUpperCase()),
              const SizedBox(width: 16),
              if (runtime.runtimeName != null)
                Flexible(
                  child: Text(
                    runtime.runtimeName!,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              if (runtime.port != null) ...[
                const SizedBox(width: 16),
                Icon(Icons.cable, size: 16, color: muted),
                const SizedBox(width: 4),
                Text(
                  l10n.instancesPort('${runtime.port}'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (runtime.state == RuntimeLinkState.unconfigured)
            Text(l10n.instancesRuntimeNoRuntime)
          else if (runtime.endpoint != null)
            SelectableText(
              l10n.instancesRuntimeEndpoint(runtime.endpoint!),
              style: theme.textTheme.bodyMedium,
            ),
          if (runtime.lastError != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      runtime.lastError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.instancesRuntimeControlUnavailable,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card widget for displaying a single model reported by a provider.
///
/// Providers do not report concurrency, rate limits or tiers, so only the
/// model, its provider and whether the provider answered are shown.
class _ModelInstanceCard extends StatelessWidget {
  final ModelInstanceState instance;
  final StatusType Function(String) getStatusType;

  const _ModelInstanceCard({
    required this.instance,
    required this.getStatusType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusType = getStatusType(instance.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Provider icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  instance.provider.isNotEmpty
                      ? instance.provider.substring(0, 1).toUpperCase()
                      : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Model name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    instance.model,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    instance.provider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            StatusBadge(
              status: statusType,
              label: instance.status.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Hermes Agent Settings Card
// =============================================================================

class _HermesSettingsCard extends StatefulWidget {
  const _HermesSettingsCard();

  @override
  State<_HermesSettingsCard> createState() => _HermesSettingsCardState();
}

class _HermesSettingsCardState extends State<_HermesSettingsCard> {
  final SettingsPreferenceService _settings = SettingsPreferenceService();

  bool _hermesEnabled = false;
  bool _isLoading = true;
  bool _isTesting = false;
  bool? _connectionStatus;
  String _url = AppConfig.defaultHermesUrl;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await _settings.isHermesEnabled();
    final url = await _settings.getHermesUrl();
    final apiKey = await _settings.getHermesApiKey();
    if (mounted) {
      setState(() {
        _hermesEnabled = enabled;
        _url = url ?? AppConfig.defaultHermesUrl;
        _apiKey = apiKey ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTesting = true);
    try {
      final service = HermesStreamingService(
        baseUrl: _url,
        apiKey: _apiKey.isNotEmpty ? _apiKey : null,
      );
      final ok = await service.testConnection();
      service.dispose();
      if (mounted) {
        setState(() {
          _connectionStatus = ok;
          _isTesting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _connectionStatus = false;
          _isTesting = false;
        });
      }
    }
  }

  Future<void> _saveAndApply() async {
    final l10n = AppLocalizations.of(context);
    await _settings.setHermesEnabled(_hermesEnabled);
    await _settings.setHermesUrl(_url);
    await _settings.setHermesApiKey(_apiKey);

    // Update connection manager
    try {
      final connectionManager = di.serviceLocator<ConnectionManagerService>();
      if (_hermesEnabled) {
        connectionManager.configureHermesRuntime(
          url: _url,
          apiKey: _apiKey,
        );
        connectionManager.setPreferredConnectionType(ConnectionType.hermes);
      } else {
        connectionManager.setPreferredConnectionType(ConnectionType.local);
      }
    } catch (_) {
      // Connection manager may not be available in all contexts
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hermesEnabled
              ? l10n.instancesHermesEnabledSnack
              : l10n.instancesHermesDisabledSnack),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return CardSection(
        title: l10n.instancesHermesTitle,
        children: const [
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return CardSection(
      title: l10n.instancesHermesTitle,
      subtitle: _hermesEnabled
          ? l10n.instancesHermesActive
          : l10n.instancesHermesInactive,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable toggle
              SwitchListTile(
                title: Text(l10n.instancesHermesEnable),
                subtitle: Text(l10n.instancesHermesEnableSubtitle),
                value: _hermesEnabled,
                onChanged: (v) => setState(() => _hermesEnabled = v),
                contentPadding: EdgeInsets.zero,
              ),

              const SizedBox(height: 16),

              // URL field
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.instancesHermesUrl,
                  hintText: AppConfig.defaultHermesUrl,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _connectionStatus == true
                      ? Icon(Icons.check_circle,
                          color: AppTheme.colorsOf(context).success)
                      : _connectionStatus == false
                          ? Icon(Icons.error,
                              color: AppTheme.colorsOf(context).danger)
                          : null,
                ),
                controller: TextEditingController(text: _url),
                onChanged: (v) => _url = v,
                enabled: _hermesEnabled,
              ),

              const SizedBox(height: 12),

              // API key field
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.instancesApiKeyOptional,
                  hintText: l10n.instancesApiKeyHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.key),
                ),
                controller: TextEditingController(text: _apiKey),
                onChanged: (v) => _apiKey = v,
                obscureText: true,
                enabled: _hermesEnabled,
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _hermesEnabled && !_isTesting ? _testConnection : null,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(l10n.instancesTestConnection),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _saveAndApply,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.commonApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
