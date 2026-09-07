import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/theme_extensions.dart';

/// Admin Center styling utilities and constants
/// Provides consistent styling across all admin components
class AdminStyles {
  // Prevent instantiation
  AdminStyles._();

  /// Status badge colors (theme-aware)
  static Map<String, Color> statusColorsOf(AppColorsTheme c) => {
        'active': c.success,
        'inactive': c.textColorLight,
        'suspended': c.warning,
        'deleted': c.danger,
        'pending': c.info,
        'succeeded': c.success,
        'failed': c.danger,
        'refunded': c.warning,
        'canceled': c.textColorLight,
        'past_due': c.danger,
        'trialing': c.info,
      };

  /// Subscription tier colors (theme-aware)
  static Map<String, Color> tierColorsOf(AppColorsTheme c) => {
        'free': c.textColorLight,
        'premium': c.primary,
        'enterprise': c.accent,
      };

  /// Build a status badge widget
  static Widget statusBadge(
    BuildContext context,
    String status, {
    bool showIcon = true,
  }) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);
    final color = statusColorsOf(colors)[status.toLowerCase()] ??
        colors.textColorLight;
    final icon = _getStatusIcon(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            SizedBox(width: AppTheme.spacingXS),
          ],
          Text(
            _formatStatus(status),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build a tier badge widget
  static Widget tierBadge(
    BuildContext context,
    String tier, {
    bool showIcon = true,
  }) {
    final theme = Theme.of(context);
    final colors = AppTheme.colorsOf(context);
    final color =
        tierColorsOf(colors)[tier.toLowerCase()] ?? colors.textColorLight;
    final icon = _getTierIcon(tier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            SizedBox(width: AppTheme.spacingXS),
          ],
          Text(
            _formatTier(tier),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build an action button with consistent styling
  static Widget actionButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
    Color? color,
    bool isDestructive = false,
  }) {
    final effectiveColor = isDestructive
        ? AppTheme.colorsOf(context).danger
        : (color ?? AppTheme.colorsOf(context).primary);

    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: effectiveColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
      ),
    );
  }

  /// Build a text button with consistent styling
  static Widget textButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? color,
  }) {
    final effectiveColor = color ?? AppTheme.colorsOf(context).primary;

    return TextButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : SizedBox.shrink(),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: effectiveColor,
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
      ),
    );
  }

  /// Build a section header with consistent styling
  static Widget sectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Build a divider with consistent styling
  static Widget divider(BuildContext context) {
    return Divider(
      color: AppTheme.borderColor,
      thickness: 1,
      height: AppTheme.spacingL,
    );
  }

  /// Build an info row (label: value)
  static Widget infoRow(
    BuildContext context,
    String label,
    String value, {
    Widget? valueWidget,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.colorsOf(context).textColorLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: valueWidget ??
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.colorsOf(context).textColor,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  /// Build a loading indicator with consistent styling
  static Widget loadingIndicator(BuildContext context, {String? message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: AppTheme.colorsOf(context).primary,
          ),
          if (message != null) ...[
            SizedBox(height: AppTheme.spacingM),
            Text(
              message,
              style: TextStyle(
                color: AppTheme.colorsOf(context).textColorLight,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build an empty state widget
  static Widget emptyState({
    required BuildContext context,
    required String message,
    IconData? icon,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 64,
                color: AppTheme.colorsOf(context).textColorLight.withValues(alpha: 0.5),
              ),
              SizedBox(height: AppTheme.spacingM),
            ],
            Text(
              message,
              style: TextStyle(
                color: AppTheme.colorsOf(context).textColorLight,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: AppTheme.spacingL),
              action,
            ],
          ],
        ),
      ),
    );
  }

  // Helper methods

  static IconData? _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'succeeded':
        return Icons.check_circle;
      case 'inactive':
      case 'canceled':
        return Icons.cancel;
      case 'suspended':
        return Icons.pause_circle;
      case 'deleted':
        return Icons.delete;
      case 'pending':
      case 'trialing':
        return Icons.schedule;
      case 'failed':
      case 'past_due':
        return Icons.error;
      case 'refunded':
        return Icons.undo;
      default:
        return null;
    }
  }

  static IconData? _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
        return Icons.person;
      case 'premium':
        return Icons.star;
      case 'enterprise':
        return Icons.business;
      default:
        return null;
    }
  }

  static String _formatStatus(String status) {
    return status
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String _formatTier(String tier) {
    return tier[0].toUpperCase() + tier.substring(1);
  }
}

/// Hover effect mixin for interactive elements
mixin AdminHoverEffect on StatefulWidget {
  Color get hoverColor => AppTheme.primaryColor.withValues(alpha: 0.1);
}
