/// Screen for managing AI agents with monitoring and configuration
library;

import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/subagent_registry_service.dart';
import '../../di/locator.dart' as di;
import '../../l10n/app_localizations.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

/// Agent model for displaying in the registry
class Agent {
  final String id;
  final String name;

  /// Task given to the agent, or null when none is assigned.
  final String? description;
  final AgentStatus status;
  final int taskCount;
  final double avgLatency;
  final DateTime lastActive;

  const Agent({
    required this.id,
    required this.name,
    this.description,
    required this.status,
    this.taskCount = 0,
    this.avgLatency = 0.0,
    required this.lastActive,
  });
}

/// Agent status enum
enum AgentStatus {
  online,
  offline,
  busy,
  error,
}

/// What happened in an [ActivityEvent].
enum ActivityKind { started, completed, failed }

/// Activity event for monitoring
class ActivityEvent {
  final String agentId;
  final String agentName;
  final ActivityKind kind;

  /// Task for started/completed events, error message for failed ones.
  final String? detail;
  final DateTime timestamp;
  final bool success;

  const ActivityEvent({
    required this.agentId,
    required this.agentName,
    required this.kind,
    this.detail,
    required this.timestamp,
    required this.success,
  });
}

/// Screen displaying agents management with three tabs
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  List<Agent> _agents = [];
  List<ActivityEvent> _activityFeed = [];

  // Real services from DI
  SubagentRegistryService? get _subagentRegistry {
    try {
      return di.serviceLocator<SubagentRegistryService>();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final registry = _subagentRegistry;
    if (registry == null) {
      // No service available — skip loading, show empty state
      _agents = [];
      _activityFeed = [];
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final subagents = await registry.listSubagents();

      _agents = subagents
          .map((s) => Agent(
                id: s.subagentId,
                name: s.label ?? s.subagentId,
                description: s.task,
                status: _mapStatus(s.status),
                taskCount: 0,
                avgLatency: 0.0,
                lastActive: s.completedAt ?? s.startedAt ?? s.createdAt,
              ))
          .toList();

      _activityFeed = subagents
          .where((s) => s.completedAt != null || s.startedAt != null)
          .map((s) => ActivityEvent(
                agentId: s.subagentId,
                agentName: s.label ?? s.subagentId,
                kind: s.status == SubagentStatus.completed
                    ? ActivityKind.completed
                    : s.status == SubagentStatus.failed
                        ? ActivityKind.failed
                        : ActivityKind.started,
                detail:
                    s.status == SubagentStatus.failed ? s.errorMessage : s.task,
                timestamp: s.completedAt ?? s.startedAt ?? s.createdAt,
                success: s.status != SubagentStatus.failed,
              ))
          .toList();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _agents = [];
          _activityFeed = [];
        });
      }
    }
  }

  AgentStatus _mapStatus(SubagentStatus status) {
    switch (status) {
      case SubagentStatus.running:
        return AgentStatus.busy;
      case SubagentStatus.completed:
        return AgentStatus.online;
      case SubagentStatus.failed:
        return AgentStatus.error;
      case SubagentStatus.pending:
        return AgentStatus.offline;
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  void _showUnavailable(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddAgentDialog() async {
    final l10n = AppLocalizations.of(context);
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(l10n.agentsRegistryUnavailable);
      return;
    }

    final created = await showDialog<_AgentDraft>(
      context: context,
      builder: (context) => const _AgentFormDialog(),
    );
    if (created == null) return;

    final result = await registry.registerSubagent(
      subagentId: created.subagentId,
      agentId: created.agentId,
      label: created.label,
      task: created.task,
    );

    if (!mounted) return;
    if (result == null) {
      _showUnavailable(l10n.agentsRegisterFailed);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.agentsRegistered(result.label ?? result.subagentId),
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _showEditAgentDialog(Agent agent) async {
    final l10n = AppLocalizations.of(context);
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(l10n.agentsRegistryUnavailable);
      return;
    }

    final updated = await showDialog<_AgentDraft>(
      context: context,
      builder: (context) => _AgentFormDialog(
        title: l10n.agentsEditTitle(agent.name),
        initial: _AgentDraft(
          subagentId: agent.id,
          agentId: 'main',
          label: agent.name,
          task: agent.description,
        ),
        lockIds: true,
      ),
    );
    if (updated == null) return;

    final ok = await registry.updateMetadata(
      agent.id,
      label: updated.label,
      task: updated.task,
    );

    if (!mounted) return;
    if (!ok) {
      _showUnavailable(l10n.agentsUpdateFailed(agent.name));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.agentsUpdated(updated.label ?? agent.id))),
    );
    await _loadData();
  }

  Future<void> _setAgentStatus(Agent agent, SubagentStatus status) async {
    final l10n = AppLocalizations.of(context);
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(l10n.agentsRegistryUnavailable);
      return;
    }

    final ok = await registry.updateStatus(agent.id, status: status);
    if (!mounted) return;
    if (!ok) {
      _showUnavailable(l10n.agentsUpdateFailed(agent.name));
      return;
    }
    await _loadData();
  }

  Future<void> _removeAgent(Agent agent) async {
    final l10n = AppLocalizations.of(context);
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(l10n.agentsRegistryUnavailable);
      return;
    }

    final deleted = await registry.deleteSubagent(agent.id);
    if (!mounted) return;
    if (!deleted) {
      _showUnavailable(l10n.agentsRemoveFailed(agent.name));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.agentsRemoved(agent.name))),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.agentsTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
              tooltip: l10n.commonRefresh,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddAgentDialog,
              tooltip: l10n.agentsAdd,
            ),
            PopOutButton(sectionName: 'agents', branchIndex: 7),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                  text: l10n.agentsTabRegistry,
                  icon: const Icon(Icons.people_outline)),
              Tab(
                  text: l10n.agentsTabMonitor,
                  icon: const Icon(Icons.monitor_heart)),
              Tab(text: l10n.agentsTabConfig, icon: const Icon(Icons.settings)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 200)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRegistryTab(l10n),
                      _buildMonitorTab(l10n),
                      _buildConfigTab(l10n),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab(AppLocalizations l10n) {
    if (_agents.isEmpty) {
      return EmptyState(
        icon: Icons.people,
        title: l10n.agentsEmptyTitle,
        message: l10n.agentsEmptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _agents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return _buildAgentCard(context, l10n, agent);
      },
    );
  }

  Widget _buildAgentCard(
      BuildContext context, AppLocalizations l10n, Agent agent) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(context, agent.status)
                      .withValues(alpha: 0.1),
                  child: Icon(
                    _getStatusIcon(agent.status),
                    color: _getStatusColor(context, agent.status),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            agent.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            status: agent.status == AgentStatus.online
                                ? StatusType.active
                                : agent.status == AgentStatus.busy
                                    ? StatusType.running
                                    : agent.status == AgentStatus.offline
                                        ? StatusType.stopped
                                        : StatusType.error,
                            label: _statusLabel(l10n, agent.status),
                            showIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        agent.description ?? l10n.agentsNoTask,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    _showAgentMenu(agent);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStat(Icons.check_circle, agent.taskCount.toString(),
                    l10n.agentsStatTasks),
                _buildStat(Icons.speed, '${agent.avgLatency}s',
                    l10n.agentsStatAvgLatency),
                _buildStat(
                    Icons.access_time,
                    _formatLastActive(l10n, agent.lastActive),
                    l10n.agentsStatLastActive),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildMonitorTab(AppLocalizations l10n) {
    return Column(
      children: [
        // Summary cards
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryCard(
                context,
                Icons.people,
                l10n.agentsTotal,
                '${_agents.length}',
                AppTheme.colorsOf(context).info,
              ),
              _buildSummaryCard(
                context,
                Icons.check_circle,
                l10n.agentsTasksToday,
                '${_agents.fold<int>(0, (sum, a) => sum + a.taskCount)}',
                AppTheme.colorsOf(context).success,
              ),
              _buildSummaryCard(
                context,
                Icons.speed,
                l10n.agentsStatAvgLatency,
                '${(_agents.fold<double>(0, (sum, a) => sum + a.avgLatency) / _agents.length).toStringAsFixed(1)}s',
                AppTheme.colorsOf(context).warning,
              ),
              _buildSummaryCard(
                context,
                Icons.error,
                l10n.agentsErrors,
                '${_agents.where((a) => a.status == AgentStatus.error).length}',
                AppTheme.colorsOf(context).danger,
              ),
            ],
          ),
        ),
        const Divider(),
        // Activity feed
        Expanded(
          child: _activityFeed.isEmpty
              ? EmptyState(
                  icon: Icons.history,
                  title: l10n.agentsNoActivityTitle,
                  message: l10n.agentsNoActivityMessage,
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activityFeed.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = _activityFeed[index];
                    return _buildActivityCard(context, l10n, event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, IconData icon, String title,
      String value, Color color) {
    return Card(
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(
      BuildContext context, AppLocalizations l10n, ActivityEvent event) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.success
              ? AppTheme.colorsOf(context).success.withValues(alpha: 0.1)
              : AppTheme.colorsOf(context).danger.withValues(alpha: 0.1),
          child: Icon(
            event.success ? Icons.check : Icons.close,
            color: event.success
                ? AppTheme.colorsOf(context).success
                : AppTheme.colorsOf(context).danger,
            size: 20,
          ),
        ),
        title: Text(_activityText(l10n, event)),
        subtitle:
            Text('${_formatTimestamp(event.timestamp)} • ${event.agentName}'),
        trailing: event.success
            ? null
            : Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildConfigTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.agentsPoolSettings,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(l10n.agentsAutoScale),
                    subtitle: Text(l10n.agentsAutoScaleSubtitle),
                    value: true,
                    onChanged: (value) {},
                  ),
                  ListTile(
                    title: Text(l10n.agentsMin),
                    subtitle: Text(l10n.agentsMinSubtitle),
                    trailing: const Text('2'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: Text(l10n.agentsMax),
                    subtitle: Text(l10n.agentsMaxSubtitle),
                    trailing: const Text('10'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 20),
                      const SizedBox(width: 8),
                      Text(l10n.agentsTimeoutSettings,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(l10n.agentsRequestTimeout),
                    subtitle: Text(l10n.agentsRequestTimeoutSubtitle),
                    trailing: const Text('30s'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: Text(l10n.agentsQueueTimeout),
                    subtitle: Text(l10n.agentsQueueTimeoutSubtitle),
                    trailing: const Text('60s'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAgentMenu(Agent agent) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(agent.status == AgentStatus.busy
                  ? Icons.pause
                  : Icons.play_arrow),
              title: Text(agent.status == AgentStatus.busy
                  ? l10n.agentsPause
                  : l10n.agentsResume),
              onTap: () {
                Navigator.pop(context);
                _setAgentStatus(
                  agent,
                  agent.status == AgentStatus.busy
                      ? SubagentStatus.pending
                      : SubagentStatus.running,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.agentsRestart),
              onTap: () {
                Navigator.pop(context);
                _setAgentStatus(agent, SubagentStatus.pending);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.agentsEditConfig),
              onTap: () {
                Navigator.pop(context);
                _showEditAgentDialog(agent);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.agentsRemove),
              onTap: () {
                Navigator.pop(context);
                _confirmRemoveAgent(agent);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveAgent(Agent agent) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.agentsRemove),
        content: Text(l10n.agentsRemoveConfirm(agent.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeAgent(agent);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.commonRemove),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return l10n.agentsStatusOnline;
      case AgentStatus.offline:
        return l10n.agentsStatusOffline;
      case AgentStatus.busy:
        return l10n.agentsStatusBusy;
      case AgentStatus.error:
        return l10n.agentsStatusError;
    }
  }

  String _activityText(AppLocalizations l10n, ActivityEvent event) {
    switch (event.kind) {
      case ActivityKind.completed:
        return l10n.agentsActivityCompleted(
            event.detail ?? l10n.agentsActivityTaskFallback);
      case ActivityKind.failed:
        return l10n.agentsActivityFailed(
            event.detail ?? l10n.agentsActivityErrorFallback);
      case ActivityKind.started:
        return l10n.agentsActivityStarted(
            event.detail ?? l10n.agentsActivityTaskFallback);
    }
  }

  IconData _getStatusIcon(AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return Icons.check_circle;
      case AgentStatus.offline:
        return Icons.offline_bolt;
      case AgentStatus.busy:
        return Icons.sync;
      case AgentStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(BuildContext context, AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return AppTheme.colorsOf(context).success;
      case AgentStatus.offline:
        return AppTheme.colorsOf(context).textColorLight;
      case AgentStatus.busy:
        return AppTheme.colorsOf(context).info;
      case AgentStatus.error:
        return AppTheme.colorsOf(context).danger;
    }
  }

  String _formatLastActive(AppLocalizations l10n, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return l10n.timeMinutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return l10n.timeHoursAgo(diff.inHours);
    } else {
      return l10n.timeDaysAgo(diff.inDays);
    }
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AgentDraft {
  const _AgentDraft({
    required this.subagentId,
    required this.agentId,
    this.label,
    this.task,
  });

  final String subagentId;
  final String agentId;
  final String? label;
  final String? task;
}

class _AgentFormDialog extends StatefulWidget {
  const _AgentFormDialog({
    this.title,
    this.initial,
    this.lockIds = false,
  });

  /// Dialog title; defaults to the localized "Register Agent".
  final String? title;
  final _AgentDraft? initial;
  final bool lockIds;

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  late final TextEditingController _subagentIdController;
  late final TextEditingController _agentIdController;
  late final TextEditingController _labelController;
  late final TextEditingController _taskController;

  @override
  void initState() {
    super.initState();
    _subagentIdController =
        TextEditingController(text: widget.initial?.subagentId ?? '');
    _agentIdController =
        TextEditingController(text: widget.initial?.agentId ?? 'main');
    _labelController = TextEditingController(text: widget.initial?.label ?? '');
    _taskController = TextEditingController(text: widget.initial?.task ?? '');
  }

  @override
  void dispose() {
    _subagentIdController.dispose();
    _agentIdController.dispose();
    _labelController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final subagentId = _subagentIdController.text.trim();
    final agentId = _agentIdController.text.trim();
    if (subagentId.isEmpty || agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.agentsIdsRequired),
        ),
      );
      return;
    }

    final label = _labelController.text.trim();
    final task = _taskController.text.trim();
    Navigator.pop(
      context,
      _AgentDraft(
        subagentId: subagentId,
        agentId: agentId,
        label: label.isEmpty ? null : label,
        task: task.isEmpty ? null : task,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title ?? l10n.agentsRegisterTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subagentIdController,
              enabled: !widget.lockIds,
              decoration: InputDecoration(
                labelText: l10n.agentsSubagentId,
                hintText: 'research-bot-1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agentIdController,
              enabled: !widget.lockIds,
              decoration: InputDecoration(
                labelText: l10n.agentsParentId,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                labelText: l10n.agentsDisplayLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: l10n.agentsTaskDescription,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.lockIds ? l10n.commonSave : l10n.agentsRegister),
        ),
      ],
    );
  }
}
