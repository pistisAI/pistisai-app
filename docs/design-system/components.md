# Component Spec v0.1

Minimum component contract for implementation.

## Button

Variants: `primary`, `secondary`, `ghost`, `danger`
Sizes: `sm`, `md`, `lg`
States: `default`, `hover`, `active`, `focus`, `disabled`, `loading`

Required behavior:
- Visible focus ring using `brand-500` on focus
- Disabled state reduces opacity to 0.6 and blocks interaction
- Loading state replaces label with spinner and keeps width stable

## Input

Variants: `text`, `search`, `password`
States: `default`, `hover`, `focus`, `error`, `disabled`

Required behavior:
- Label above input, explicit association via `for`/`id`
- Error message shown in `danger-500` under control
- Placeholder never replaces label

## Card

Variants: `default`, `outlined`, `elevated`
Structure: header, body, optional footer

Required behavior:
- Consistent padding from spacing scale
- Visible hierarchy between header, body, and optional actions

## Nav

Frameworks: top nav, side nav, tab bar

Required behavior:
- Active route has clear visual indicator
- Collapsed side nav keeps labels accessible
