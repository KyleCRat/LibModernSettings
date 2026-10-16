# Changelog

## [Unreleased]

### Added

- Dropdown choices support native headings, dividers, per-choice tooltips and
  disabled entries. Keyboard navigation skips non-selectable rows while keeping
  a disabled saved selection visible.
- Color inputs support optional `onPreview(value)` callbacks for live drafts,
  with `onPreview(nil)` cleanup on every close path. Apply still commits once
  through `onChanged`; saved values and recent colors remain unchanged until then.

### Fixed

- Scroll-area margins now consume mouse-wheel input and scroll their pane,
  preventing wheel bindings from firing through gaps beside the scrollbar.
- Retain canvas and input anchors during resize/reflow, including scrolling
  content and header controls. Preserve measured section heights when only
  their width changes, without rebuilding controls or discarding pending edits.

## [1.10.0] - 2026-10-12

### Added

- Reusable scroll areas for native lists and canvas layouts, with inset spacing
  presets, compact content spacing, and independent border overrides. Existing
  canvas spacing remains unchanged unless the new options are selected.
- Buttons accept texture-file icons through `iconTexture`, alongside existing
  atlas icons. `SetButtonIcon()` updates either source on retained buttons.
- Canvas columns support vertical alignment to center or bottom-align content
  of different heights.

### Changed

- Square icon buttons automatically clip artwork to the tertiary border's
  corners while preserving icon sizing and aspect ratio.

### Upgrade Notes

- Use LibStub MINOR 11 within the existing `LibModernSettings-1.0` API family.

## [1.9.0] - 2026-10-12

### Added

- Persistent selected states for regular, small, and square buttons via
  `selected`, `SetSelected()`, and `IsSelected()`, using native tertiary artwork.

### Upgrade Notes

- Use LibStub MINOR 10 within the existing `LibModernSettings-1.0` API family.
