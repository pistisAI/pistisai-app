library;

import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../models/provider_configuration.dart';
import '../../services/provider_discovery_service.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/navigation/popout_button.dart';

/// Screen displaying discovered agent runtimes, support model providers and
/// Tailscale tailnet devices.
///
/// Consumes [ProviderDiscoveryService] (registered via GetIt). The discovery
/// service falls back gracefully to empty state when it is not registered.
class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});
  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  bool _isLoading = true;
  Object? _loadError;
  List<ProviderInfo> _runtimes = <ProviderInfo>[];
  List<ProviderInfo> _supportProviders = <ProviderInfo>[];
  List<TailscaleDevice> _tailnetDevices = <TailscaleDevice>[];
  String? _selectedRuntimeId;

  // Use DI for service access — fall back gracefully when not available.
  ProviderDiscoveryService? get _discovery {
    try {
      return di.serviceLocator<ProviderDiscoveryService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final discovery = _discovery;
      if (discovery == null) {
        setState(() {
          _isLoading = false;
          _runtimes = <ProviderInfo>[];
          _supportProviders = <ProviderInfo>[];
          _tailnetDevices = <TailscaleDevice>[];
        });
        return;
      }
      final providers = await discovery.scanForProviders();
      final tailnet = await discovery.discoverTailscaleDevices();
      if (!mounted) return;
      setState(() {
        _runtimes =
            providers.where((p) => p.canServeAsAgentRuntime).toList();
        _supportProviders =
            providers.where((p) => p.canServeAsSupportModelProvider).toList();
        _tailnetDevices = tailnet;
        // Drop selection if the selected runtime disappeared.
        if (_selectedRuntimeId != null &&
            !_runtimes.any((p) => p.id == _selectedRuntimeId)) {
          _selectedRuntimeId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _isLoading = false;
        _runtimes = <ProviderInfo>[];
        _supportProviders = <ProviderInfo>[];
        _tailnetDevices = <TailscaleDevice>[];
      });
    }
  }

  Future<void> _onRefresh() async => _loadData();

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nodes'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
            const PopOutButton(sectionName: 'nodes', branchIndex: 9),
          ],
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 120)
            : _loadError != null
                ? ErrorState(message: _formatError(_loadError), onRetry: _onRefresh)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRuntimeStatus(context),
                        CardSection(
                          title: 'Agent Runtimes',
                          children: _runtimes.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No agent runtimes discovered'),
                                  ),
                                ]
                              : _buildProviderList(_runtimes, selectable: true),
                        ),
                        CardSection(
                          title: 'Support Providers',
                          children: _supportProviders.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No support providers discovered'),
                                  ),
                                ]
                              : _buildProviderList(_supportProviders,
                                  selectable: false),
                        ),
                        CardSection(
                          title: 'Tailscale Devices',
                          children: _tailnetDevices.isEmpty
                              ? const [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('No Tailscale devices discovered'),
                                  ),
                                ]
                              : _buildTailnetList(),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  String _formatError(Object? error) {
    final raw = error.toString();
    if (raw.contains('Failed to load discovery data')) return raw;
    return 'Failed to load discovery data: $raw';
  }

  /// Status banner showing the currently selected agent runtime (if any).
  Widget _buildRuntimeStatus(BuildContext context) {
    final theme = Theme.of(context);
    ProviderInfo? selected;
    for (final p in _runtimes) {
      if (p.id == _selectedRuntimeId) {
        selected = p;
        break;
      }
    }
    final String text;
    if (selected != null) {
      text = 'Agent runtime: ${selected.name} (${selected.version ?? 'unknown'})';
    } else {
      text = 'No agent runtime selected';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(
            selected != null ? Icons.check_circle : Icons.info_outline,
            size: 16,
            color: selected != null
                ? Colors.green
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProviderList(List<ProviderInfo> providers,
      {required bool selectable}) {
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: providers
              .map((p) => _ProviderCard(
                    provider: p,
                    selected: p.id == _selectedRuntimeId,
                    onTap: selectable ? () => _selectRuntime(p) : null,
                  ))
              .toList(),
        ),
      ),
    ];
  }

  void _selectRuntime(ProviderInfo provider) {
    setState(() {
      _selectedRuntimeId =
          _selectedRuntimeId == provider.id ? null : provider.id;
    });
  }

  List<Widget> _buildTailnetList() {
    return [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _tailnetDevices
              .map((d) => _TailscaleDeviceCard(device: d))
              .toList(),
        ),
      ),
    ];
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderInfo provider;
  final bool selected;
  final VoidCallback? onTap;

  const _ProviderCard({
    required this.provider,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = provider.isAvailable;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isOnline ? Icons.check_circle : Icons.error,
                    color: isOnline ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(provider.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(provider.url, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              if (provider.version != null)
                Text('v${provider.version}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: provider.availableModels
                    .take(3)
                    .map((m) => Chip(
                          label: Text(m,
                              style: theme.textTheme.labelSmall),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TailscaleDeviceCard extends StatelessWidget {
  final TailscaleDevice device;

  const _TailscaleDeviceCard({required this.device});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(device.isOnline ? Icons.wifi : Icons.wifi_off,
                  color: device.isOnline ? Colors.green : Colors.grey,
                  size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(device.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(device.hostname, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(device.ips.join(', '), style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
