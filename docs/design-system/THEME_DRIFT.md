# Theme Drift Discovery

**Date**: 2026-09-07
**Source**: PAP-40 design review (2026-07-05) + codebase audit
**Status**: Docs aligned; code migration deferred

## Summary

Three conflicting brand palettes existed across code and docs. The implementation truth (`lib/config/theme_config.dart`) uses a gold palette from the 2026-08 rebrand, while docs referenced earlier indigo/slate and purple/blue/green palettes. This doc records the drift and the alignment action taken.

## Drift Map

| Source | Palette | Problem | Resolution |
|--------|---------|---------|------------|
| `docs/design-system/tokens.md` | Indigo/slate brand + neutral scale | Stale — never updated after gold rebrand | Synced to gold palette |
| `docs/architecture/frontend/THEME_CONFIG.md` | Purple `#a777e3` / Blue / Green | Stale — conflicting palette | Synced to gold palette |
| `lib/config/theme.dart` (`AppTheme`) | Text `#f1f1f1` / `#b0b0b0` | Doesn't match `theme_config.dart` (`#F5E6C8`/`#B8A88A`) | Flagged — needs decision |
| `lib/config/theme_config.dart` | Gold `#FFD700` | Implementation truth — canonical | No change |
| `lib/design_system.dart` | Indigo `#6366F1` | Dead code — never imported | Kept (may serve as future token foundation) |
| `mkdocs.yml` | Indigo primary/accent | Independent docs-site theme | Left as-is (intentional) |

## Code-Level Note

`AppTheme` provides static color constants (e.g., `AppTheme.textColor`) used across many files. These bypass the theme system — always rendering the same value regardless of light/dark mode. Migration to `AppTheme.colorsOf(context).*` is the proper long-term fix for full light-mode support. Deferred pending broader theme refactor decision.

## Canonical Brand Palette (Gold)

| Token | Hex | Usage |
|-------|-----|-------|
| Primary | `#FFD700` | Brand gold — buttons, accents, logo |
| Highlight | `#FFE44D` | Bright gold — glows, hover states |
| Accent | `#D4A017` | Dark gold — secondary emphasis |
| Dark BG | `#1A1A1A` | Dark mode background |
| Dark Card | `#2A2A2A` | Dark mode card surface |
| Dark Text | `#F5E6C8` | Dark mode primary text (warm cream) |
| Dark Muted | `#B8A88A` | Dark mode secondary text |
| Light BG | `#FAFAFA` | Light mode background |
| Light Card | `#FFFFFF` | Light mode card surface |
| Light Text | `#2C3E50` | Light mode primary text |
| Light Muted | `#7F8C8D` | Light mode secondary text |

## Prevention

- Implementation source of truth is `lib/config/theme_config.dart`. Future palette changes start there.
- `AppTheme` static color constants are dark-mode defaults. New code should prefer `AppTheme.colorsOf(context).*` for theme-aware colors.
- Docs should be synced when palette values change.
