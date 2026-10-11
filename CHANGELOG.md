# Changelog

## [Unreleased]

### Added

- Add `ApplyTertiarySquareArtwork` for matching inset artwork and reusable masks
  on custom tertiary-square buttons. Bundled media follows the selected embed.
- Add reusable `CreateFlashMessages(owner, options)` stacks for success, info and
  error feedback outside windows or input groups, with Blizzard's metal dialog
  border, dark status-colored backgrounds and lighter matching text. Compact
  rows keep equal left/right insets and grow for wrapped text. Messages stack newest last,
  sit directly above the owner when space below is insufficient, follow owner
  movement and scale, fade after a configurable duration, and dismiss with X.
  Hovering a message or its close button pauses its remaining lifetime and fade.
  Repeated messages renew instead of duplicating; stacks reuse frames, bound
  visible messages, clear when the owner hides and stop updating when empty.
- Add `CreateColor` / canvas `color` inputs with tertiary-square swatches and
  optional persistent class/accent selection modes that retain the separate
  Custom color. A compact hue/SV picker places RGB or RGBA, six-digit RGB hex,
  separate opacity controls, and new/previous samples beside the hue strip, with
  compact Favorites, Recent, Class and Quality rows below. Inline labels sit
  close to aligned swatches, with matching horizontal and vertical gaps,
  consistent outer padding and no divider.
  Pasted RRGGBBAA imports opacity and normalizes to the six-digit RGB display;
  hex accepts exactly six or eight digits with an optional # prefix.
  Apply/Cancel sit below the inputs beside the hue strip, with no helper footer.
  Validation uses flash messages without resizing the picker or taking input
  focus; valid edits and field changes preserve their timed lifetime. Failed
  Apply returns focus to the invalid field. Favorites reserve their
  first row even when empty and grow only when another row is needed. Edits are
  staged until Apply/Cancel.
  Color choices join Tab/Enter/Space navigation; closing returns
  focus to the input.
  `CreateColorPalette` supports consumer-owned persistence without a database
  dependency. Changing the input value, hiding it, or disabling it cancels its
  pending picker edit. Larger swatch fills use the matching beveled mask at all
  button sizes and show opacity without a checkerboard texture. Swatch hover
  borders follow the pointer or keyboard focus and stay hidden when idle.
- Navigate text inputs, slider values, dropdowns, checkboxes and expandable
  headers, plus regular, small and square buttons, with Tab and Shift+Tab in
  current visual order. Focused buttons, checkboxes and headers show their hover
  highlight; Enter or Space activates them. Dropdowns stay closed when focused;
  Enter or Space opens them and confirms their selection without losing focus.
  Skip hidden or disabled fields, reveal offscreen fields even inside tall sections,
  and wrap within the canvas. `EnableTabNavigation(parent)` joins inputs in a
  manually composed window, including its canvas pages. Custom control types can
  join through `RegisterControlNavigation(type, options)`, including existing
  instances, without implementing their own keyboard capture or lifecycle hooks.
- Step focused slider values with the mouse wheel and Up/Down arrows. While
  scrolling, Shift moves ten steps and Ctrl moves fifty, with Ctrl taking priority.
  Open dropdowns use Up/Down to select adjacent choices without wrapping or closing,
  keep the selected row in view, and retain normal mouse-wheel scrolling.
  Enter or Space confirms the current selection and closes the menu without
  triggering chat or game actions.
  Sliders retain editable values outside their track range; unfocused controls
  preserve normal page scrolling.
- Add canvas `SetSize(width, height)` for resizing existing pages, optional
  `BeginColumns({ minColumnWidth = ... })` stacking, and flow `SetShown(boolean)`
  to remove conditional columns from layout. Reuse controls and coalesce visible
  reflows; defer hidden canvas work until shown.

### Fixed

- Ignore outdated size notifications so dynamic Fields keep their content height
  and canvas width after hidden-page updates and resizing.
- Keep text inputs focused after rejected Enter or Tab commits so keyboard
  navigation can continue, while preserving focus when clicking another input.
- Keep scrolling dropdown rows ordered and preserve the viewport when callbacks
  update values or choices in an open menu.
- Prevent an error when opening dropdowns by matching Blizzard's menu-open
  callback arguments.
- Reject non-finite slider values and restore valid input after invalid edits.
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
