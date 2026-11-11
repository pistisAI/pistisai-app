/// Agent Detail Screen - Shows detailed information about a specific agent
library;

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/agent_lifecycle_service.dart';

/// Agent Detail Screen
class AgentDetailScreen extends StatefulWidget {
  final String agentId;

  const AgentDetailScreen({
    super.key,
    required this.agentId,
  });

  @override
  State<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends State<AgentDetailScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAgentDetails();
  }

  Future<void> _loadAgentDetails() async {
    setState(() => _isLoading = true);
    final service = context.read<AgentLifecycleService>();
    try {
      await service.getAgentStatus(widget.agentId);
    } catch (e) {
      debugPrint('[AgentDetailScreen] Failed to load agent: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startAgent() async {
    final l10n = AppLocalizations.of(context);
    final service = context.read<AgentLifecycleService>();
    final result = await service.startAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? l10n.commonUnknownError),
        backgroundColor: result.success
            ? AppTheme.colorsOf(context).success
            : AppTheme.colorsOf(context).danger,
      ),
    );

    await _loadAgentDetails();
  }

  Future<void> _stopAgent() async {
    final l10n = AppLocalizations.of(context);
    final service = context.read<AgentLifecycleService>();
    final result = await service.stopAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? l10n.commonUnknownError),
        backgroundColor: result.success
            ? AppTheme.colorsOf(context).success
            : AppTheme.colorsOf(context).danger,
      ),
    );

    await _loadAgentDetails();
  }

  Future<void> _restartAgent() async {
    final l10n = AppLocalizations.of(context);
    final service = context.read<AgentLifecycleService>();
    final result = await service.restartAgent(widget.agentId);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? l10n.commonUnknownError),
        backgroundColor: result.success
            ? AppTheme.colorsOf(context).success
            : AppTheme.colorsOf(context).danger,
      ),
    );

    await _loadAgentDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgentLifecycleService>(
      builder: (context, service, child) {
        final l10n = AppLocalizations.of(context);
        final agent = service.getAgent(widget.agentId);

        if (agent == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.agentDetailTitle),
              leading: BackButton(
                onPressed: () {
                  if (GoRouter.of(context).canPop()) {
                    context.pop();
                  } else {
                    context.go('/agents');
                  }
                },
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64,
                      color: AppTheme.colorsOf(context).textColorLight),
                  const SizedBox(height: 16),
                  Text(l10n.agentDetailNotFound),
                  const SizedBox(height: 8),
                  Text(l10n.agentDetailIdValue(widget.agentId)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadAgentDetails,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(agent.name),
            leading: BackButton(
              onPressed: () {
                if (GoRouter.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/agents');
                }
              },
            ),
            actions: [
              IconButton(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: l10n.commonRefresh,
                onPressed: _isLoading ? null : _loadAgentDetails,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              _buildStatusCard(l10n, agent),

              const SizedBox(height: 16),

              // Actions Card
              _buildActionsCard(l10n, agent),

              const SizedBox(height: 16),

              // Information Card
              _buildInformationCard(l10n, agent),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(AppLocalizations l10n, AgentInfo agent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(agent.state),
                  color: _getStatusColor(context, agent.state),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.commonStatus,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        _getStatusText(l10n, agent.state),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: _getStatusColor(context, agent.state),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (agent.activity != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.agentDetailActivity,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(agent.activity!),
            ],
            if (agent.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.commonError,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                agent.errorMessage!,
                style: TextStyle(color: AppTheme.colorsOf(context).danger),
              ),
            ],
            if (agent.lastUpdate != null) ...[
              const SizedBox(height: 16),
              Text(
                l10n.agentDetailLastUpdate,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(_formatDate(l10n, agent.lastUpdate!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(AppLocalizations l10n, AgentInfo agent) {
    final canStart = agent.state == AgentLifecycleState.idle ||
        agent.state == AgentLifecycleState.error ||
        agent.state == AgentLifecycleState.offline;
    final canStop = agent.state == AgentLifecycleState.running ||
        agent.state == AgentLifecycleState.starting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.commonActions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canStart ? _startAgent : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.agentDetailStart),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canStop ? _stopAgent : null,
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.agentDetailStop),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _restartAgent,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.agentDetailRestart),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard(AppLocalizations l10n, AgentInfo agent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.agentDetailInformation,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _infoRow(l10n, l10n.agentDetailId, agent.id),
            const SizedBox(height: 8),
            _infoRow(l10n, l10n.commonName, agent.name),
            const SizedBox(height: 8),
            _infoRow(l10n, l10n.commonType, agent.type),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return AppTheme.colorsOf(context).textColorLight;
      case AgentLifecycleState.starting:
        return AppTheme.colorsOf(context).warning;
      case AgentLifecycleState.running:
        return AppTheme.colorsOf(context).success;
      case AgentLifecycleState.stopping:
        return AppTheme.colorsOf(context).warning.withValues(alpha: 0.3);
      case AgentLifecycleState.error:
        return AppTheme.colorsOf(context).danger;
      case AgentLifecycleState.offline:
        return AppTheme.colorsOf(context).textColorLight;
    }
  }

  IconData _getStatusIcon(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return Icons.pause_circle_outline;
      case AgentLifecycleState.starting:
        return Icons.play_circle_outline;
      case AgentLifecycleState.running:
        return Icons.play_circle_filled;
      case AgentLifecycleState.stopping:
        return Icons.stop_circle;
      case AgentLifecycleState.error:
        return Icons.error_outline;
      case AgentLifecycleState.offline:
        return Icons.cloud_off;
    }
  }

  String _getStatusText(AppLocalizations l10n, AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return l10n.agentStateIdle;
      case AgentLifecycleState.starting:
        return l10n.agentStateStarting;
      case AgentLifecycleState.running:
        return l10n.agentStateRunning;
      case AgentLifecycleState.stopping:
        return l10n.agentStateStopping;
      case AgentLifecycleState.error:
        return l10n.agentStateError;
      case AgentLifecycleState.offline:
        return l10n.agentStateOffline;
    }
  }

  Widget _infoRow(AppLocalizations l10n, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            l10n.commonFieldLabel(label),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDate(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return l10n.timeSecondsAgo(difference.inSeconds);
    } else if (difference.inMinutes < 60) {
      return l10n.timeMinutesAgo(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l10n.timeHoursAgo(difference.inHours);
    } else {
      return date.toLocal().toString();
    }
  }
}
