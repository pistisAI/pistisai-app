# Design Tokens

Use these tokens as the single source of truth for color, typography, spacing, shadow, and radius values.

## Color

> Implementation source of truth: `lib/config/theme_config.dart` (gold palette, 2026-08).
> Previous indigo/slate tokens were an alternative design that was never wired into the app.

### Brand (Pistisai Gold)
- `brand-primary`: #FFD700
- `brand-highlight`: #FFE44D
- `brand-accent`: #D4A017
- `brand-dark`: #B8960F
- `brand-glow`: #FFE44D (with alpha for glow states)

### Neutral — Dark Mode (default)
- `dark-bg`: #1A1A1A
- `dark-bg-card`: #2A2A2A
- `dark-bg-elevated`: #333333
- `dark-text`: #F5E6C8
- `dark-text-muted`: #B8A88A
- `dark-border`: #3A3A3A

### Neutral — Light Mode
- `light-bg`: #FAFAFA
- `light-bg-card`: #FFFFFF
- `light-bg-elevated`: #F5F5F5
- `light-text`: #2C3E50
- `light-text-muted`: #7F8C8D
- `light-border`: #E0E0E0

### Semantic
- `success`: #27AE60
- `warning`: #F39C12
- `danger`: #E74C3C
- `info`: #3498DB

## Typography

| Token | Value |
|------|------|
| `font-sans` | Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif |
| `font-mono` | ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", monospace |
| `text-xs` | 0.75rem / 1rem |
| `text-sm` | 0.875rem / 1.25rem |
| `text-base` | 1rem / 1.5rem |
| `text-lg` | 1.125rem / 1.75rem |
| `text-xl` | 1.25rem / 1.75rem |
| `text-2xl` | 1.5rem / 2rem |
| `text-3xl` | 1.875rem / 2.25rem |

## Spacing

Base scale: 0.25rem = 1 unit.

- `space-1`: 0.25rem
- `space-2`: 0.5rem
- `space-3`: 0.75rem
- `space-4`: 1rem
- `space-5`: 1.25rem
- `space-6`: 1.5rem
- `space-8`: 2rem
- `space-10`: 2.5rem
- `space-12`: 3rem
- `space-16`: 4rem

## Radius

- `radius-sm`: 0.25rem
- `radius-md`: 0.5rem
- `radius-lg`: 0.75rem
- `radius-full`: 9999px

## Shadow

- `shadow-xs`: 0 1px 2px rgba(0,0,0,0.06)
- `shadow-sm`: 0 1px 3px rgba(0,0,0,0.08)
- `shadow-md`: 0 4px 6px -1px rgba(0,0,0,0.1)
- `shadow-lg`: 0 10px 15px -3px rgba(0,0,0,0.12)
