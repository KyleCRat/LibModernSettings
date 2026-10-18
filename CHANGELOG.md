# Changelog

## [Unreleased]

### Added

- Sliders accept `snapToStep = false` to retain fractional typed/programmatic
  values while keeping stepped track and keyboard/wheel controls.
- Add `CreateValueList` / `valueList`: compact value pills wrapping within one
  input, with Enter-to-advance, add/remove buttons, parsing/formatting, copied arrays
  and standard keyboard navigation. Blank fields are not saved; growing rows
  reflow following content and keep keyboard-focused pills visible without resizing.
- Dropdown choices accept `previewTexture` paths/file IDs as full-width texture
  previews behind outlined names, including a selection centered in the recessed border and live
  choice updates. Optional `menuWidth` sizes menus independently of their inputs.
- Canvas grids wrap retained cells across a configurable number of columns,
  with minimum widths, measured row heights and independent cell visibility.
- Dropdowns support optional checkbox multi-selection, copied value sets,
  custom summary text and empty-selection placeholders. Arrow keys move focus;
  Enter/Space toggles checks without closing, with native scrolling and tooltips.
- Sliders support `valueLabels` for numeric states such as Auto or Inherit,
  including case-insensitive input, normal stepping and numeric callbacks.
- Dropdown choices support native headings, dividers, per-choice tooltips and
  disabled entries. Keyboard navigation skips non-selectable rows while keeping
  a disabled saved selection visible.
- Color inputs support optional `onPreview(value)` callbacks for live drafts,
  with `onPreview(nil)` cleanup on every close path. Apply still commits once
  through `onChanged`; saved values and recent colors remain unchanged until then.

### Changed

- Dropdowns use a 34px recessed text-input body and focus glow with an inset
  square caret. Only the caret presses down; native menus and navigation remain.
  Review fixed labeled-row heights and old dropdown edge compensations;
  existing controls adopt the artwork during compatible upgrades.

### Fixed

- Non-scrolling canvases can set `scrollbarWidth = 0` to remove the right inset
  from nested sections. Scrolling canvases still require a positive width.
- Scroll-area margins now consume mouse-wheel input and scroll their pane,
  preventing wheel bindings from firing through gaps beside the scrollbar.
- Retain canvas and input anchors during resize/reflow, including scrolling
  content and header controls. Preserve measured section heights when only
  their width changes, without rebuilding controls or discarding pending edits.
  Defer child-driven Field resizing until native size callbacks finish, keeping
  wrapped inputs and labels measurable when adding or removing rows.

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
