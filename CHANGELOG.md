# Changelog

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

## [1.7.0] - 2026-09-14

### Added

- Add smaller, word-wrapped descriptions to stacked and inline Fields, with
  automatic height, configurable font and spacing, and live `SetDescription`
  updates. Empty descriptions reserve no space.
- Add optional appearance-refresh callbacks for registered control types.
  Retain control options and canvas structure so compatible library upgrades
  can refresh visual defaults without recreating controls or resetting values,
  pending edits, focus, enabled state, callbacks, or explicit overrides.

### Changed

- Standardize stacked Fields and built-in dropdown/slider labels around a 7px
  label gap. Keep inline Fields configurable and canvas sibling spacing at a
  configurable 4px; unlabeled inputs reserve no label space.
- Default dropdown side insets to zero and use a 34px input footprint around
  Blizzard's unstretched 25px button artwork. Preserve explicit sizes and insets.
- Relayout dropdowns, sliders, and Fields when resized, preserving edits and
  supporting explicit heights or a return to automatic content sizing.
  Coalesce affected canvas reflows and defer hidden-page work until shown.
- Increase default H1 page titles and yellow H2 section headings without
  changing ordinary control-label fonts.
- Use LibStub MINOR 8 within the existing `LibModernSettings-1.0` API family.

### Fixed

- Refresh dropdown geometry, selected text, and arrow state after the visible
  layout pass so opening a Settings canvas directly does not leave them blank.
- Ignore settled or insignificant size changes, avoiding redundant reflows and
  repeated re-anchoring that could hide edit-box text.
- Check size-change script support before watching canvas entries; measure
  FontStrings during layout instead of assigning unsupported script handlers.
- Initialize description fonts before assigning text, preventing Settings
  construction failures.
- Initialize each runtime module once per LibStub MINOR, preventing duplicate
  embeds from repeating registrations or appearance updates while preserving
  upgrades from genuinely newer revisions.

### Upgrade Notes

- Dropdowns and sliders infer label visibility from non-empty `label` text.
  The former `showLabel` option is ignored; use `tooltipTitle` to name an
  unlabeled input's tooltip. Prefer Fields for new separate labels; built-in
  stacked labels remain supported and checkbox captions remain control-owned.
- Embeds older than 1.7.0 need a one-time update to retain constructor intent
  and canvas placement metadata for future visual upgrades. Already-built
  layouts from older copies remain preserved rather than guessing which
  dimensions were consumer overrides.
