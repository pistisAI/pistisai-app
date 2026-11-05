import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Custom app logo widget that matches the Pistisai branding
class AppLogo extends StatelessWidget {
  final double size;
  final bool showBorder;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;

  const AppLogo({
    super.key,
    this.size = 40.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Large logo for headers and prominent displays
  const AppLogo.large({
    super.key,
    this.size = 70.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Medium logo for navigation bars
  const AppLogo.medium({
    super.key,
    this.size = 48.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Small logo for compact spaces
  const AppLogo.small({
    super.key,
    this.size = 32.0,
    this.showBorder = true,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  /// Favicon-sized logo
  const AppLogo.favicon({
    super.key,
    this.size = 16.0,
    this.showBorder = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.colorsOf(context).secondary;
    final effectiveBorderColor = borderColor ?? AppTheme.colorsOf(context).primary;
    final borderWidth = size * 0.04;

    // Pistisai logos (4-column stoa portico)
    String assetPath = 'assets/images/lobster_avatar_64.png';
    if (size >= 128) {
      assetPath = 'assets/images/lobster_avatar_128.png';
    } else if (size >= 64) {
      assetPath = 'assets/images/lobster_avatar_64.png';
    } else {
      assetPath = 'assets/images/lobster_avatar.png';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: effectiveBorderColor, width: borderWidth)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.03),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to gold P monogram if image fails
            return Center(
              child: Text(
                'P',
                style: TextStyle(fontSize: size * 0.6),
              ),
            );
          },
        ),
      ),
    );
  }
}
