import 'package:flutter/material.dart';

/// Widget for displaying inline error messages in admin forms
class AdminErrorMessage extends StatelessWidget {
  final String? errorMessage;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const AdminErrorMessage({
    super.key,
    this.errorMessage,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage == null || errorMessage!.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultBackgroundColor = theme.colorScheme.errorContainer;
    final defaultTextColor = theme.colorScheme.onErrorContainer;

    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.error_outline,
            color: textColor ?? defaultTextColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor ?? defaultTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
