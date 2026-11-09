# UX Standards

## Interaction Baseline

- Preserve user intent by avoiding destructive placements without secondary action
- Show progress or retry path for every async boundary
- Maintain keyboard access for any clickable interaction
- Announce state changes in UI text, not color alone

## Accessibility Baseline

Target: **WCAG 2.1 AA**

- Normal text minimum contrast: 4.5:1
- Large text minimum contrast: 3:1
- Touch target minimum size: 44x44
- Focus indicator must be system-visible and consistent

## Responsive Breakpoints

- `sm`: 640px
- `md`: 768px
- `lg`: 1024px
- `xl`: 1280px

Layout rules:
- Reflow content before hiding it
- Keep critical actions visible at every breakpoint
- Avoid horizontal scroll in app body

## Dark Mode

- Use tokenized colors only
- Avoid pure black surfaces; use `neutral-950` or equivalent
- Preserve hierarchy through lightness, not color inversion
