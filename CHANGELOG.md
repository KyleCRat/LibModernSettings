# Changelog

## Unreleased

- Advance LibStub MINOR to 8 for cross-addon review of the pending changes,
  taking precedence over older embedded copies without publishing a release.
- Refresh dropdown geometry, selected text, and native arrow state after the
  visible layout pass, preventing blank dropdowns when opening a Settings
  canvas directly. Skip the refresh if the control is hidden in the meantime.
- Show dropdown/slider labels only when non-empty label text is provided;
  retire the `showLabel` override. Use `tooltipTitle` for unlabeled inputs.
- Share stacked label layout between Fields and built-in dropdown/slider
  labels, preserving the approved 7px label gap and compact slider track.
  Fit labeled and unlabeled controls to their content instead of reserving
  fixed-height rows or unused space below dropdowns.
- Default both dropdown side insets to zero, with explicit insets supported.
- Relayout dropdowns, sliders, and Fields on size changes without rebuilding
  controls or disturbing edits. Support explicit height overrides and restoring
  automatic height; preserve already-placed outer dimensions during upgrades
  from older embedded copies.
- Recommend Fields for new separate labels while retaining built-in stacked
  labels. Keep inline labels and custom label geometry exclusive to Fields;
  checkbox captions remain owned by the checkbox. Document input, label-layout,
  and parent-spacing ownership plus existing font-option meanings.
- Increase default canvas H1 titles and yellow H2 section headings so both
  stand apart from ordinary control labels. Explicit font overrides remain
  supported; control-label styling is unchanged.

## [1.6.0] - 2026-09-08

- Add public ownership-aware `RefreshTooltip` and `HideOwnedTooltip` methods
  for dynamic or reused tooltip targets.
- Add a full-width tertiary expandable section header with an optional leading
  atlas icon, an optically aligned borderless yellow down/up state arrow with
  dedicated disabled art, and a user-input expansion callback.
- Allow settings-table rows to grow beneath their fixed-height control cells at
  runtime, reflow following rows, and notify consumers when the table's total
  height changes.

## [1.5.0] - 2026-08-29

- Add reusable fields that compose registered control primitives with stacked
  or inline labels while preserving direct access to the underlying control.
- Cap dropdown menus at three quarters of the UI height and use Blizzard's
  native scrolling menu for longer choice lists. Center scrolling menus
  vertically while retaining their normal horizontal position.
- Highlight focused text inputs and editable slider values with Blizzard's
  neutral depressed tertiary glow.
- Preserve mouse-up button actions when a text or slider input's focus-loss
  commit refreshes its canvas. LMS buttons finalize the pending edit before
  their callbacks, with a post-mouse-up fallback for other click targets.
- Upgrade live sliders and text inputs created by older embedded copies before
  installing current focus behavior, preventing missing focus-texture errors
  in mixed-copy load orders.
