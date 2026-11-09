import 'package:flutter/material.dart';

import 'active_brand.g.dart';
import 'brand_config.dart';

extension BrandView on BrandConfig {
  Color get primary => Color(primaryArgb);
  Color get secondary => Color(secondaryArgb);
  Color get accent => Color(accentArgb);
  Color get background => Color(backgroundArgb);
  Color get textColor => Color(textArgb);

  /// Device locale stays in effect unless the brand locks one.
  Locale? get materialLocale {
    if (!lockLocale || defaultLocale.isEmpty) {
      return null;
    }
    final parts = defaultLocale.split(RegExp(r'[_-]'));
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}

/// The brand baked by `tool/brand.sh`, unless a test overrides it.
class Brand {
  Brand._();

  static BrandConfig? _override;

  static BrandConfig get current => _override ?? activeBrand;

  /// `--dart-define=BRAND=` must match the brand `tool/brand.sh` wrote.
  /// A define on its own does not swap copy; the script rewrites the baked brand.
  static void assertCompileDefineMatches() {
    const requested = String.fromEnvironment('BRAND', defaultValue: 'pistisai');
    if (requested != activeBrand.id) {
      throw StateError(
        'BRAND=$requested does not match the brand baked by tool/brand.sh '
        '(${activeBrand.id}). Run tool/brand.sh $requested before this build.',
      );
    }
  }

  @visibleForTesting
  static void debugOverride(BrandConfig? value) {
    _override = value;
  }
}
