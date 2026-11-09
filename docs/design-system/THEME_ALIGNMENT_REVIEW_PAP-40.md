# Theme / Token Alignment Review — PAP-40

Deliverable: concrete design review checklist + diagnosed drift between docs, `ThemeConfig`, and app theme usage.

## 1) Canonical source of truth (current)

- App theme implementation: `lib/config/theme_config.dart`
- Backwards-compat wrapper: `lib/config/theme.dart`
- Theme extensions: `lib/config/theme_extensions.dart`
- Design tokens doc: `docs/design-system/tokens.md`
- Unified theme docs: `docs/architecture/frontend/THEME_CONFIG.md`
- Docs site theme: `mkdocs.yml`

## 2) Diagnosed mismatches

### Brand palette
- `design_system.dart` and `design-system/tokens.md` use indigo/slate brand tokens:
  - `brand-500: #6366F1`
  - `brand-600: #4F46E5`
  - `brand-700: #4338CA`
- `ThemeConfig` / `theme_extensions` / docs text use gold brand tokens:
  - primary: `#FFD700`
  - secondary: `#FFE44D`
  - accent: `#D4A017`
- `THEME_CONFIG.md` lists a third palette:
  - primary: `#a777e3`
  - secondary: `#6e8efb`
  - accent: `#00c58e`
→ **Result:** three conflicting brand systems. One is the implementation truth.

### Dark text color drift
- Implementation:
  - `darkTextColor`: `#F5E6C8`
  - `darkTextColorLight`: `#B8A88A`
- Docs/tokens/general text mention older `#f1f1f1` / `#b0b0b0` variants.
→ **Result:** docs reflect stale text colors.

### Docs-site palette vs app palette
- `mkdocs.yml` uses indigo `primary`/`accent` with `default`/`slate` schemes.
- App uses gold brand and custom light backgrounds.
→ **Result:** docs do not match app visual language.

## 3) Alignment review checklist

Use this checklist when validating the repo or handing off fixes.

- [ ] Confirm one canonical brand palette in code:
  - primary: `#FFD700`
  - secondary: `#FFE44D`
  - accent: `#D4A017`
- [ ] Sync `docs/design-system/tokens.md` to the app palette or mark it as legacy/deprecated with a migration note.
- [ ] Update `docs/architecture/frontend/THEME_CONFIG.md` brand section to match implemented values exactly.
- [ ] Replace any remaining `#f1f1f1` / `#b0b0b0` references with implemented `#F5E6C8` / `#B8A88A` equivalents.
- [ ] Align `mkdocs.yml` palette tokens or document that docs site intentionally uses an independent palette.
- [ ] Run `flutter analyze` and theme tests to confirm no regression after token/doc changes.
- [ ] Add a `docs/architecture/frontend/THEME_DRIFT.md` note so future reviewers have a single discovery doc.

## 4) Recommended next action

Status: design artifact complete.
Next: hand off to CTO for implementation/docs alignment review.
Files:
- `docs/design-system/THEME_ALIGNMENT_REVIEW_PAP-40.md`
- `docs/design-system/tokens.md`
- `docs/architecture/frontend/THEME_CONFIG.md`
- `lib/config/theme_config.dart`

## 5) CEO disposition — heartbeat 2026-07-05

- Reviewed completed design artifact from UXDesigner.
- Delegate owner: CTO for implementation/docs alignment review and token reconciliation.
- Review checklist acceptance path: implement checklist items in section 3, then update this doc and `docs/architecture/frontend/THEME_DRIFT.md`.
- Verification: `flutter analyze`, checkout build, theme smoke run, update docs to match implementation.
