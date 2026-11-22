import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the user asked the avatar to look (Settings → Avatar → Customize).
@immutable
class AvatarAppearance {
  const AvatarAppearance({
    this.sizeMultiplier = 1.0,
    this.glowEnabled = true,
    this.colorOverride,
  });

  /// 0.8 (small), 1.0 (medium) or 1.3 (large).
  final double sizeMultiplier;
  final bool glowEnabled;

  /// Colour chosen by the user, or null to use the personality colour.
  final Color? colorOverride;

  static const Map<String, double> sizeMultipliers = {
    'small': 0.8,
    'medium': 1.0,
    'large': 1.3,
  };

  static const String sizeKey = 'avatar_size';
  static const String glowKey = 'avatar_glow_enabled';
  static const String colorKey = 'avatar_color_override';

  /// Parses a colour saved as `#RRGGBB` (or `AARRGGBB`); null when invalid.
  static Color? parseColor(String? stored) {
    if (stored == null) return null;
    final hex = stored.replaceFirst('#', '').trim();
    if (hex.length != 6 && hex.length != 8) return null;
    final value = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? null : Color(value);
  }

  factory AvatarAppearance.fromPreferences(SharedPreferences prefs) {
    return AvatarAppearance(
      sizeMultiplier: sizeMultipliers[prefs.getString(sizeKey)] ?? 1.0,
      glowEnabled: prefs.getBool(glowKey) ?? true,
      colorOverride: parseColor(prefs.getString(colorKey)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarAppearance &&
      other.sizeMultiplier == sizeMultiplier &&
      other.glowEnabled == glowEnabled &&
      other.colorOverride == colorOverride;

  @override
  int get hashCode => Object.hash(sizeMultiplier, glowEnabled, colorOverride);
}

/// The saved appearance, shared by every avatar in the app. Call [reload]
/// after saving so the chat avatar follows the settings, not only the preview.
final ValueNotifier<AvatarAppearance> avatarAppearance =
    ValueNotifier<AvatarAppearance>(const AvatarAppearance());

Future<void> reloadAvatarAppearance() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    avatarAppearance.value = AvatarAppearance.fromPreferences(prefs);
  } catch (e) {
    debugPrint('[AvatarAppearance] Could not load: $e');
  }
}
