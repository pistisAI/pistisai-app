import 'package:flutter/material.dart';
import '../../../config/theme.dart';
import 'package:pistisai/services/agent_lifecycle_service.dart';

/// Agent List Item widget — renders an [AgentInfo] from the
/// [AgentLifecycleService] with lifecycle-aware status color and icon.
class AgentListItem extends StatelessWidget {
  final AgentInfo agent;
  final VoidCallback? onTap;

  const AgentListItem({super.key, required this.agent, this.onTap});

  Color _statusColor(BuildContext context, AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return AppTheme.colorsOf(context).textColorLight;
      case AgentLifecycleState.starting:
        return AppTheme.colorsOf(context).warning;
      case AgentLifecycleState.running:
        return AppTheme.colorsOf(context).success;
      case AgentLifecycleState.stopping:
        return AppTheme.colorsOf(context).warning.withOpacity(0.7);
      case AgentLifecycleState.error:
        return AppTheme.colorsOf(context).danger;
      case AgentLifecycleState.offline:
        return AppTheme.colorsOf(context).textColorLight.withOpacity(0.6);
    }
  }

  IconData _statusIcon(AgentLifecycleState state) {
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
        return Icons.cloud_off_outlined;
    }
  }

  String _statusLabel(AgentLifecycleState state) {
    switch (state) {
      case AgentLifecycleState.idle:
        return 'Idle';
      case AgentLifecycleState.starting:
        return 'Starting…';
      case AgentLifecycleState.running:
        return 'Running';
      case AgentLifecycleState.stopping:
        return 'Stopping…';
      case AgentLifecycleState.error:
        return 'Error';
      case AgentLifecycleState.offline:
        return 'Offline';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = agent.state;
    final color = _statusColor(context, state);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(
          state == AgentLifecycleState.running
              ? Icons.smart_toy
              : Icons.smart_toy_outlined,
          color: color,
        ),
      ),
      title: Text(agent.name),
      subtitle: Row(
        children: [
          Icon(_statusIcon(state), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(state),
            style: TextStyle(color: color),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
