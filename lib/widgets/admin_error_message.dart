import 'package:flutter/material.dart';
import '../config/theme.dart';

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

/// Widget for displaying success messages in admin forms
class AdminSuccessMessage extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const AdminSuccessMessage({
    super.key,
    this.message,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultBackgroundColor = AppTheme.colorsOf(context).success.withValues(alpha: 0.1);
    final defaultTextColor = AppTheme.colorsOf(context).success;

    return Container(
      padding: padding ?? EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.colorsOf(context).success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.check_circle_outline,
            color: textColor ?? defaultTextColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
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

/// Widget for displaying warning messages in admin forms
class AdminWarningMessage extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const AdminWarningMessage({
    super.key,
    this.message,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultBackgroundColor = AppTheme.colorsOf(context).warning.withValues(alpha: 0.1);
    final defaultTextColor = AppTheme.colorsOf(context).warning;

    return Container(
      padding: padding ?? EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.colorsOf(context).warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.warning_amber_outlined,
            color: textColor ?? defaultTextColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
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

/// Widget for displaying info messages in admin forms
class AdminInfoMessage extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const AdminInfoMessage({
    super.key,
    this.message,
    this.padding,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final defaultBackgroundColor = AppTheme.colorsOf(context).info.withValues(alpha: 0.1);
    final defaultTextColor = AppTheme.colorsOf(context).info;

    return Container(
      padding: padding ?? EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? defaultBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.colorsOf(context).info.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline,
            color: textColor ?? defaultTextColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
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

/// Snackbar helper for showing error messages
class AdminSnackBar {
  /// Show error snackbar
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.colorsOf(context).textColor),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: AppTheme.colorsOf(context).textColor,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.colorsOf(context).textColor),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.colorsOf(context).success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning snackbar
  static void showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: AppTheme.colorsOf(context).textColor),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.colorsOf(context).warning,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar
  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.colorsOf(context).textColor),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.colorsOf(context).info,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
