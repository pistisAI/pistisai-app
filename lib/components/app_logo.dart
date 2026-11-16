import 'package:flutter/material.dart';
import '../brand/brand.dart';
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
    final effectiveBackgroundColor =
        backgroundColor ?? AppTheme.colorsOf(context).secondary;
    final effectiveBorderColor =
        borderColor ?? AppTheme.colorsOf(context).primary;
    final borderWidth = size * 0.04;

    // Brand-driven, no brand-id checks. A brand's logo_asset is the base
    // path; upstream pistisai ships size variants next to it, so a size
    // variant is used only when that file is bundled for the brand.
    final String assetPath = _sizedLogoAsset(Brand.current.logoAsset, size);

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
                Brand.current.shortName.isEmpty
                    ? '?'
                    : Brand.current.shortName[0],
                style: TextStyle(fontSize: size * 0.6),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Picks a size variant for the brand's base logo.
///
/// Size variants (`<stem>_64.png`, `<stem>_128.png`) exist only for logos
/// that ship them. `logoSizeVariants` in the brand file declares that. Any
/// brand without the declaration gets its base logo at every size, so no
/// brand can reference a variant it does not bundle.
String _sizedLogoAsset(String base, double size) {
  final variants = Brand.current.logoSizeVariants;
  if (!variants) return base;
  if (!base.endsWith('.png')) return base;
  final stem = base.substring(0, base.length - 4);
  if (size >= 128) return '${stem}_128.png';
  if (size >= 64) return '${stem}_64.png';
  return base;
}
