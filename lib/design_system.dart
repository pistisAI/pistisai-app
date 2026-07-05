/// Minimal-style/token mapping for early adoption.
///
/// This file is a staging artifact so CTO can implement components
/// from design tokens without guessing. It is not final Flutter theming.
library design_system;

/// Light theme token values in material-compatible form.
final lightTokens = _TokenSet(
  brand: const Brand(50: 0xFFEEF2FF, 100: 0xFFE0E7FF, 500: 0xFF6366F1, 600: 0xFF4F46E5, 700: 0xFF4338CA),
  neutral: const Neutral(0: 0xFFFFFFFF, 50: 0xFFF8FAFC, 100: 0xFFF1F5F9, 200: 0xFFE2E8F0, 400: 0xFF94A3B8, 600: 0xFF475569, 800: 0xFF1E293B, 900: 0xFF0F172A, 950: 0xFF020617),
  semantic: const Semantic(success500: 0xFF22C55E, warning500: 0xFFF59E0B, danger500: 0xFFEF4444, info500: 0xFF3B82F6),
  radiusSm: 4.0,
  radiusMd: 8.0,
  radiusLg: 12.0,
  radiusFull: 9999.0,
);

final class _TokenSet {
  final _TokenSet({
    required this.brand,
    required this.neutral,
    required this.semantic,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusFull,
  });
  final Brand brand;
  final Neutral neutral;
  final Semantic semantic;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusFull;
  Color get primaryBrand => const Color(0xFF6366F1);
}

final class Brand {
  const Brand({required this.c50, required this.c100, required this.c500, required this.c600, required this.c700});
  final int c50;
  final int c100;
  final int c500;
  final int c600;
  final int c700;
  Color get c50Color => Color(c50);
  Color get c500Color => Color(c500);
}

final class Neutral {
  const Neutral({
    required this.c0,
    required this.c50,
    required this.c100,
    required this.c200,
    required this.c400,
    required this.c600,
    required this.c800,
    required this.c900,
    required this.c950,
  });
  final int c0;
  final int c50;
  final int c100;
  final int c200;
  final int c400;
  final int c600;
  final int c800;
  final int c900;
  final int c950;
  Color get bg => Color(c0);
  Color get surfaceMuted => Color(c100);
  Color get outline => Color(c200);
  Color get onSurfacePrimary => Color(c900);
}

final class Semantic {
  const Semantic({required this.success500, required this.warning500, required this.danger500, required this.info500});
  final int success500;
  final int warning500;
  final int danger500;
  final int info500;
  Color get success => Color(success500);
  Color get warning => Color(warning500);
  Color get danger => Color(danger500);
  Color get info => Color(info500);
}

const Color(0xFF6366F1);
