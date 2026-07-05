import 'package:flutter/material.dart';

/// Design token source of truth for Pistisai UI.
///
/// Tokens are kept as const values so they can be used at compile time,
/// for example inside `ThemeData.copyWith(...)` or widget constructors.
class DesignTokens {
  const DesignTokens._();

  // Brand
  static const Color brand50 = Color(0xFFEEF2FF);
  static const Color brand100 = Color(0xFFE0E7FF);
  static const Color brand500 = Color(0xFF6366F1);
  static const Color brand600 = Color(0xFF4F46E5);
  static const Color brand700 = Color(0xFF4338CA);

  // Neutral
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8FAFC);
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0);
  static const Color neutral400 = Color(0xFF94A3B8);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral800 = Color(0xFF1E293B);
  static const Color neutral900 = Color(0xFF0F172A);
  static const Color neutral950 = Color(0xFF020617);

  // Semantic
  static const Color success500 = Color(0xFF22C55E);
  static const Color warning500 = Color(0xFFF59E0B);
  static const Color danger500 = Color(0xFFEF4444);
  static const Color info500 = Color(0xFF3B82F6);

  // Radius
  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusFull = 9999.0;

  /// Seed ThemeData using the current brand tokens.
  static ThemeData lightTheme() {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: brand500);
    return base.copyWith(
      scaffoldBackgroundColor: neutral0,
      colorScheme: base.colorScheme.copyWith(
        primary: brand500,
        onPrimary: neutral0,
        primaryContainer: brand100,
        onPrimaryContainer: brand700,
        secondary: brand600,
        onSecondary: neutral0,
        surface: neutral0,
        onSurface: neutral900,
        surfaceContainerHighest: neutral100,
        error: danger500,
        onError: neutral0,
      ),
    );
  }
}
