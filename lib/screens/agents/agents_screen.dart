/// Screen for managing AI agents with monitoring and configuration
library;

import 'package:flutter/material.dart';
import '../../services/subagent_registry_service.dart';
import '../../di/locator.dart' as di;
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
  final String description;
  final AgentStatus status;
  final int taskCount;
  final double avgLatency;
  final DateTime lastActive;

  const Agent({
    required this.id,
    required this.name,
    required this.description,
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

/// Activity event for monitoring
class ActivityEvent {
  final String agentId;
  final String agentName;
  final String action;
  final DateTime timestamp;
  final bool success;

  const ActivityEvent({
    required this.agentId,
    required this.agentName,
    required this.action,
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
                description: s.task ?? 'No task assigned',
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
                action: s.status == SubagentStatus.completed
                    ? 'Completed: ${s.task ?? "task"}'
                    : s.status == SubagentStatus.failed
                        ? 'Failed: ${s.errorMessage ?? "unknown error"}'
                        : 'Started: ${s.task ?? "task"}',
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
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(
        'Agent registry is unavailable until the API backend is connected',
      );
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
      _showUnavailable('Failed to register agent');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registered ${result.label ?? result.subagentId}',
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _showEditAgentDialog(Agent agent) async {
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(
        'Agent registry is unavailable until the API backend is connected',
      );
      return;
    }

    final updated = await showDialog<_AgentDraft>(
      context: context,
      builder: (context) => _AgentFormDialog(
        title: 'Edit ${agent.name}',
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
      _showUnavailable('Failed to update ${agent.name}');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated ${updated.label ?? agent.id}')),
    );
    await _loadData();
  }

  Future<void> _setAgentStatus(Agent agent, SubagentStatus status) async {
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(
        'Agent registry is unavailable until the API backend is connected',
      );
      return;
    }

    final ok = await registry.updateStatus(agent.id, status: status);
    if (!mounted) return;
    if (!ok) {
      _showUnavailable('Failed to update ${agent.name}');
      return;
    }
    await _loadData();
  }

  Future<void> _removeAgent(Agent agent) async {
    final registry = _subagentRegistry;
    if (registry == null) {
      _showUnavailable(
        'Agent registry is unavailable until the API backend is connected',
      );
      return;
    }

    final deleted = await registry.deleteSubagent(agent.id);
    if (!mounted) return;
    if (!deleted) {
      _showUnavailable('Failed to remove ${agent.name}');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${agent.name} removed')),
    );
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agents'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddAgentDialog,
              tooltip: 'Add Agent',
            ),
            PopOutButton(sectionName: 'agents', branchIndex: 7),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registry', icon: Icon(Icons.people_outline)),
              Tab(text: 'Monitor', icon: Icon(Icons.monitor_heart)),
              Tab(text: 'Config', icon: Icon(Icons.settings)),
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
                      _buildRegistryTab(),
                      _buildMonitorTab(),
                      _buildConfigTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab() {
    if (_agents.isEmpty) {
      return const EmptyState(
        icon: Icons.people,
        title: 'No Agents Registered',
        message: 'Agents will appear here when registered',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _agents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final agent = _agents[index];
        return _buildAgentCard(agent);
      },
    );
  }

  Widget _buildAgentCard(Agent agent) {
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
                  backgroundColor:
                      _getStatusColor(agent.status).withValues(alpha: 0.1),
                  child: Icon(
                    _getStatusIcon(agent.status),
                    color: _getStatusColor(agent.status),
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
                            label: agent.status.name.toUpperCase(),
                            showIcon: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        agent.description,
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
                _buildStat(
                    Icons.check_circle, agent.taskCount.toString(), 'Tasks'),
                _buildStat(Icons.speed, '${agent.avgLatency}s', 'Avg Latency'),
                _buildStat(Icons.access_time,
                    _formatLastActive(agent.lastActive), 'Last Active'),
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

  Widget _buildMonitorTab() {
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
                Icons.people,
                'Total Agents',
                '${_agents.length}',
                Colors.blue,
              ),
              _buildSummaryCard(
                Icons.check_circle,
                'Tasks Today',
                '${_agents.fold<int>(0, (sum, a) => sum + a.taskCount)}',
                Colors.green,
              ),
              _buildSummaryCard(
                Icons.speed,
                'Avg Latency',
                '${(_agents.fold<double>(0, (sum, a) => sum + a.avgLatency) / _agents.length).toStringAsFixed(1)}s',
                Colors.orange,
              ),
              _buildSummaryCard(
                Icons.error,
                'Errors',
                '${_agents.where((a) => a.status == AgentStatus.error).length}',
                Colors.red,
              ),
            ],
          ),
        ),
        const Divider(),
        // Activity feed
        Expanded(
          child: _activityFeed.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No Recent Activity',
                  message: 'Agent activity will appear here',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _activityFeed.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final event = _activityFeed[index];
                    return _buildActivityCard(event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      IconData icon, String title, String value, Color color) {
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

  Widget _buildActivityCard(ActivityEvent event) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: event.success
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
          child: Icon(
            event.success ? Icons.check : Icons.close,
            color: event.success ? Colors.green : Colors.red,
            size: 20,
          ),
        ),
        title: Text(event.action),
        subtitle:
            Text('${_formatTimestamp(event.timestamp)} • ${event.agentName}'),
        trailing: event.success
            ? null
            : Icon(Icons.error_outline,
                color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildConfigTab() {
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
                      Text('Agent Pool Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto-scale agents'),
                    subtitle:
                        const Text('Automatically add agents based on load'),
                    value: true,
                    onChanged: (value) {},
                  ),
                  ListTile(
                    title: const Text('Min agents'),
                    subtitle: const Text('Minimum number of active agents'),
                    trailing: const Text('2'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Max agents'),
                    subtitle: const Text('Maximum number of concurrent agents'),
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
                      Text('Timeout Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Request timeout'),
                    subtitle:
                        const Text('Maximum time to wait for agent response'),
                    trailing: const Text('30s'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Queue timeout'),
                    subtitle:
                        const Text('Maximum time in queue before rejection'),
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
                  ? 'Pause Agent'
                  : 'Resume Agent'),
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
              title: const Text('Restart Agent'),
              onTap: () {
                Navigator.pop(context);
                _setAgentStatus(agent, SubagentStatus.pending);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Configuration'),
              onTap: () {
                Navigator.pop(context);
                _showEditAgentDialog(agent);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove Agent'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Agent'),
        content: Text('Are you sure you want to remove ${agent.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeAgent(agent);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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

  Color _getStatusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.online:
        return Colors.green;
      case AgentStatus.offline:
        return Colors.grey;
      case AgentStatus.busy:
        return Colors.blue;
      case AgentStatus.error:
        return Colors.red;
    }
  }

  String _formatLastActive(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
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
    this.title = 'Register Agent',
    this.initial,
    this.lockIds = false,
  });

  final String title;
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
    final subagentId = _subagentIdController.text.trim();
    final agentId = _agentIdController.text.trim();
    if (subagentId.isEmpty || agentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subagent ID and parent agent ID are required'),
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
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _subagentIdController,
              enabled: !widget.lockIds,
              decoration: const InputDecoration(
                labelText: 'Subagent ID',
                hintText: 'research-bot-1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _agentIdController,
              enabled: !widget.lockIds,
              decoration: const InputDecoration(
                labelText: 'Parent Agent ID',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Display Label',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(
                labelText: 'Task Description',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.lockIds ? 'Save' : 'Register'),
        ),
      ],
    );
  }
}
