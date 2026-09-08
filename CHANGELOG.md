# Changelog

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
