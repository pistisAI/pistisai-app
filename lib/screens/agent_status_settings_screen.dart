/// Agent Status Settings Screen
///
/// Displays agent status and activity information.
library;

import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Agent status settings screen
class AgentStatusSettingsScreen extends StatefulWidget {
  const AgentStatusSettingsScreen({super.key});

  @override
  State<AgentStatusSettingsScreen> createState() =>
      _AgentStatusSettingsScreenState();
}

class _AgentStatusSettingsScreenState extends State<AgentStatusSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Status'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colors = AppTheme.colorsOf(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _StatusRow(
                  label: 'Status',
                  value: 'Active',
                  icon: Icons.check_circle,
                  color: colors.success,
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Last Activity',
                  value: '2 minutes ago',
                  icon: Icons.access_time,
                  color: colors.info,
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: 'Tasks Completed',
                  value: '127',
                  icon: Icons.task_alt,
                  color: colors.accent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Info Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About Agent Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'The agent status page shows the current state and activity of your AI agents. '
                  'This feature is currently in development.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textColorLight,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}
