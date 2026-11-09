import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum StatusType {
  healthy,
  error,
  active,
  idle,
  running,
  stopped,
  unknown,
}

class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? label;
  final bool showIcon;

  const StatusBadge({
    required this.status,
    this.label,
    this.showIcon = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getStatusConfig(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) Icon(config.icon, size: 12, color: config.color),
          if (showIcon && label != null) const SizedBox(width: 4),
          if (label != null)
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: config.color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(BuildContext context) {
    final colors = AppTheme.colorsOf(context);
    switch (status) {
      case StatusType.healthy:
      case StatusType.running:
      case StatusType.active:
        return _StatusConfig(
          color: colors.success,
          icon: Icons.check_circle,
        );
      case StatusType.error:
        return _StatusConfig(
          color: colors.danger,
          icon: Icons.error,
        );
      case StatusType.idle:
        return _StatusConfig(
          color: colors.info,
          icon: Icons.coffee,
        );
      case StatusType.stopped:
        return _StatusConfig(
          color: colors.textColorLight,
          icon: Icons.stop_circle,
        );
      case StatusType.unknown:
        return _StatusConfig(
          color: colors.textColorLight,
          icon: Icons.help_outline,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;

  _StatusConfig({required this.color, required this.icon});
}
