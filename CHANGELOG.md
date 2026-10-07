# Changelog

## [Unreleased]

### Fixed

- Give `CreateText` and plain canvas `AddText` calls a default font before
  assigning text, preventing `Font not set` errors when `fontObject` is omitted.
  Explicit font overrides remain supported.

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

## [1.6.0] - 2026-09-08

- Add public ownership-aware `RefreshTooltip` and `HideOwnedTooltip` methods
  for dynamic or reused tooltip targets.
- Add a full-width tertiary expandable section header with an optional leading
  atlas icon, an optically aligned borderless yellow down/up state arrow with
  dedicated disabled art, and a user-input expansion callback.
- Allow settings-table rows to grow beneath their fixed-height control cells at
  runtime, reflow following rows, and notify consumers when the table's total
  height changes.
