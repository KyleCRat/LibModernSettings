# Changelog

## [1.2.0] - 2026-08-25

- Allow editable slider values to remain below or above the slider track range
  while keeping the thumb clamped to the nearest endpoint.

## [1.1.0] - 2026-08-11

- Add a reusable full-width single-line text input with a seamless, sliced
  tertiary background, safe text insets, commit/cancel behavior, validation
  callbacks, and focus helpers.
- Add centered icon-and-text button content and optional content-fitted widths.
- Constrain native atlas icons to 14px in small buttons while preserving their
  aspect ratio.
- Correct the default small tertiary-button height to the atlas's native 25px
  height.

## [1.0.0] - 2026-08-10

- Add the initial `LibModernSettings-1.0` API family.
- Add modern tertiary buttons, checkboxes, dropdowns, and editable sliders.
- Add shared text and tooltip helpers for custom Blizzard Settings canvases.
- Add measured per-page canvas layouts with full-width and independent
  half-width flows, standard indentation, and modern ScrollBox support.
- Add padded settings tables with fixed or weighted columns and alternating
  row backgrounds.
- Add an extensible control registry with live same-family implementation
  upgrades and optional post-construction initializers.
