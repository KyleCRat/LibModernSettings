# Changelog

## [Unreleased]

### Added

- Buttons accept texture-file icons through `iconTexture`, alongside existing
  atlas icons. `SetButtonIcon()` updates either source on retained buttons.

### Changed

- Square icon buttons automatically clip artwork to the tertiary border's
  corners while preserving icon sizing and aspect ratio.

## [1.9.0] - 2026-10-12

### Added

- Persistent selected states for regular, small, and square buttons via
  `selected`, `SetSelected()`, and `IsSelected()`, using native tertiary artwork.

### Upgrade Notes

- Use LibStub MINOR 10 within the existing `LibModernSettings-1.0` API family.

## [1.8.0] - 2026-10-12

### Added

- Add `CreateColor` and canvas `color` inputs with RGB/RGBA editing, RGB hex
  entry, RGBA paste, opacity, new/previous samples and Apply/Cancel. Optional
  class/accent shortcuts retain the separate Custom color. Recent colors,
  favorites and class/item-quality presets share `CreateColorPalette`, with
  optional consumer-owned persistence. Validation preserves focus and picker size.
- Add `CreateFlashMessages(owner, options)` for success, info and error feedback
  outside windows or input groups. Messages use modern Blizzard borders, follow
  their owner, fit above it when needed, fade automatically and pause on hover.
  Close buttons, duplicate renewal, bounded stacks and owner cleanup are included.
- Add Tab/Shift+Tab navigation across all inputs and buttons, with Enter/Space
  activation, hidden/disabled-field skipping and automatic scrolling to focused
  fields. `EnableTabNavigation` joins manually composed windows;
  `RegisterControlNavigation` lets custom controls use the same behavior.
- Add mouse-wheel and Up/Down stepping for focused sliders; Shift+wheel moves
  ten steps and Ctrl+wheel moves fifty. Open dropdowns use Up/Down for adjacent
  choices and Enter/Space to confirm while retaining focus; their mouse wheel
  continues scrolling the menu.
- Add responsive canvas resizing with `SetSize`, optional column stacking via
  `minColumnWidth`, and flow visibility via `SetShown`. Full-width `BeginGroup`
  regions support nesting and independent visibility. Reflow retains controls,
  values and pending edits.
- Add `ApplyTertiarySquareArtwork` to fit and mask custom artwork or color fills
  inside tertiary-square buttons. Bundled media follows the selected embed.

### Fixed

- Ignore outdated size notifications so dynamic Fields keep their content height
  and canvas width after hidden-page updates and resizing.
- Keep text inputs focused after rejected Enter or Tab commits so keyboard
  navigation can continue, while preserving focus when clicking another input.
- Keep scrolling dropdown rows ordered and preserve the viewport when callbacks
  update values or choices in an open menu.
- Reject non-finite slider values and restore valid input after invalid edits.
- Give `CreateText` and plain canvas `AddText` calls a default font before
  assigning text, preventing `Font not set` errors when `fontObject` is omitted.

### Upgrade Notes

- Use LibStub MINOR 9 within the existing `LibModernSettings-1.0` API family.
- Include the new `Media` directory at the documented embed path when upgrading.
