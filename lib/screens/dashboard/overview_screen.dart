import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../brand/brand_copy.dart';
import '../../config/theme.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../services/agent_runtime/runtime_status_snapshot.dart';
import '../../services/connection_manager_service.dart';
import '../../services/voice/voice_conversation_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../widgets/voice/open_voice_ui_control_panel.dart';
import '../../widgets/voice/voice_conversation_status_card.dart';

/// Overview of the active agent runtime.
///
/// Every value comes from [ConnectionManagerService] via
/// [RuntimeStatusSnapshot]; nothing here is a placeholder (#857).
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  /// When this screen last finished a health check.
  DateTime? _lastChecked;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final connService = context.read<ConnectionManagerService>();
    setState(() => _isChecking = true);
    try {
      await connService.testConnection();
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _lastChecked = DateTime.now();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.overviewTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.overviewSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.colorsOf(context).textColorLight,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<ConnectionManagerService>(
                    builder: (context, connService, child) {
                      final snapshot =
                          RuntimeStatusSnapshot.fromConnectionManager(
                              connService);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            context,
                            l10n.overviewVoiceTitle,
                            BrandCopy.voiceCompanionBody,
                            di.serviceLocator
                                    .isRegistered<VoiceConversationService>()
                                ? const Column(
                                    children: [
                                      VoiceConversationStatusCard(),
                                      SizedBox(height: 16),
                                      OpenVoiceUIControlPanel(),
                                    ],
                                  )
                                : _buildVoiceUnavailableCard(context, l10n),
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            context,
                            l10n.overviewAccessTitle,
                            l10n.overviewAccessDescription,
                            _buildAccessCard(l10n, snapshot),
                          ),
                          const SizedBox(height: 24),
                          _buildSection(
                            context,
                            l10n.overviewSnapshotTitle,
                            l10n.overviewSnapshotDescription,
                            _buildSnapshotCard(context, l10n, snapshot),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, String description, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
              ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildAccessCard(
      AppLocalizations l10n, RuntimeStatusSnapshot snapshot) {
    final configured = snapshot.state != RuntimeLinkState.unconfigured;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormField(
              l10n.overviewRuntime,
              configured
                  ? (snapshot.runtimeName ?? l10n.runtimeStatusNotConfigured)
                  : l10n.overviewNoRuntime,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              l10n.overviewRuntimeUrl,
              snapshot.endpoint ?? l10n.runtimeStatusNotConfigured,
            ),
            const SizedBox(height: 16),
            _buildFormField(
              l10n.overviewApiKey,
              snapshot.apiKeySet
                  ? l10n.overviewApiKeySet
                  : l10n.overviewApiKeyNotSet,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isChecking ? null : _loadData,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(l10n.overviewCheckConnection),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(BuildContext context, AppLocalizations l10n,
      RuntimeStatusSnapshot snapshot) {
    final status = switch (snapshot.state) {
      RuntimeLinkState.connected => l10n.runtimeStatusConnected,
      RuntimeLinkState.disconnected => l10n.runtimeStatusUnreachable,
      RuntimeLinkState.unconfigured => l10n.runtimeStatusNotConfigured,
    };
    final lastChecked = _lastChecked;
    final lastCheckedText = lastChecked == null
        ? l10n.overviewNotCheckedYet
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(lastChecked),
            alwaysUse24HourFormat:
                MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false,
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSnapshotRow(context, l10n.overviewStatus, status),
            _buildSnapshotRow(
                context, l10n.overviewLastChecked, lastCheckedText),
            if (snapshot.state == RuntimeLinkState.connected)
              _buildSnapshotRow(context, l10n.overviewModelsReported,
                  '${snapshot.modelCount}'),
            if (snapshot.lastError != null)
              _buildSnapshotRow(
                  context, l10n.overviewLastError, snapshot.lastError!),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceUnavailableCard(
      BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          l10n.overviewVoiceUnavailable,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
              ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.colorsOf(context).textColorLight,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
