# LibModernSettings

LibModernSettings provides consistent modern controls for custom World of
Warcraft Settings canvas pages. It owns control construction, Blizzard art,
value synchronization, enabled or disabled tooltip behavior, and optional
canvas layout and table geometry. The consuming addon continues to own
SavedVariables, category registration, page composition, and runtime callbacks.

## Embedding

Load LibStub before `embed.xml`, then acquire the library with:

```lua
local ModernSettings = LibStub("LibModernSettings-1.0")
```

## Controls

Every control uses an options table:

- `CreateButton(parent, options)` creates regular, small, or square tertiary
  buttons.
  Use `text`, `width`, `height`, `variant`, `tooltip`, and `onClick`. Pass
  `iconAtlas` for a centered icon-and-text command and `fitToContent = true`
  to derive the width from the complete content group. Use regular buttons by
  default; reserve `variant = "small"` for dense rows or constrained layouts.
  Small buttons automatically constrain native atlas icons to 14px while
  preserving aspect ratio. `maxIconSize` changes that cap while preserving the
  atlas ratio; `iconSize` explicitly forces a square size. Use
  `variant = "square"` with `iconAtlas` for an icon-only action button. It
  defaults to 34px square with an icon no larger than 16px; custom `width` or
  `height` keeps both dimensions equal. Buttons retain Blizzard's normal
  mouse-up activation timing and finalize a pending text edit before invoking
  their consumer callback.
- `CreateCheckbox(parent, options)` creates a 34px tertiary-square checkbox.
  Use `label`, `width`, `value`, `tooltip`, and `onChanged`.
- `CreateDropdown(parent, options)` creates a `WowStyle1DropdownTemplate`
  selector. Use `label`, `width`, `value`, `choices` or `getChoices`,
  `tooltip`, and `onChanged`. Pass `showLabel = false` for a compact 34px
  unlabeled selector. Set `leftInset` and `rightInset` independently to
  non-negative numbers when the consumer needs to replace either default 8px
  inset; set both to `0` to make the native dropdown fill the control width.
  Call `SetControlWidth(width)` when a responsive layout changes its width; the
  method updates the wrapper, semantic label, and native dropdown together
  while preserving both insets. Dropdown menus retain their natural height up
  to three quarters of `UIParent`; longer lists use Blizzard's native
  scrolling-menu behavior and are vertically centered on the screen.
- `CreateSlider(parent, options)` creates a stepped slider with an editable
  compact value field. `minValue` and `maxValue` bound the slider track and
  steppers, while typed values and `SetValue` may remain outside that range.
  Out-of-range values still snap to `step`; the thumb stays at the nearest
  track endpoint without replacing the entered value. The editable value field
  shows Blizzard's neutral depressed tertiary glow while focused.
- `CreateTextInput(parent, options)` creates a full-width single-line text
  input with the same single-piece sliced tertiary background used by slider
  value inputs. It defaults to 34px high. Use `value`, `width`, `height`,
  `maxLetters`, `textInset`, `onCommit`, and `onError`. Omitting `maxLetters`
  leaves the input unbounded. Focus shows Blizzard's neutral depressed
  tertiary glow without changing the consumer API.
- `CreateField(parent, options)` composes a semantic label with a registered
  control without changing the underlying control primitive. Use `label`,
  `controlType`, and `controlOptions`, then choose `labelPosition = "top"`
  for a stacked field or `labelPosition = "left"` for a compact inline field.
  `width`, `labelWidth`, `labelHeight`, and `gap` control its geometry. Retrieve
  the primitive with `GetControl()` and enable or disable the complete field
  with `SetControlEnabled()`. The field clones `controlOptions` before assigning
  the resolved control width.
- `CreateText(parent, options)` creates consistently aligned canvas text.
- `SetTooltip(frame, options)` attaches a dynamic tooltip to any frame.

Implemented inputs live in separate files under `Controls/`. Additional
control types are intentionally not part of the public API until a consumer
defines their required behavior.

Controls expose `SetValue`, `GetValue`, and `SetControlEnabled` where those
operations apply. `SetControlEnabled(false, reason)` disables the complete
input and shows `reason` from every registered tooltip target. Re-enabling the
control restores its normal tooltip.

Fields intentionally do not proxy value, focus, or control-specific methods.
Call those methods on `field:GetControl()` so primitives remain independently
usable and fields remain responsible only for label layout and complete-field
enabled state.

```lua
local nameField = ModernSettings:CreateField(parent, {
    label = "Name",
    labelPosition = "left",
    labelWidth = 48,
    controlType = "textInput",
    controlOptions = {
        onCommit = commitName,
    },
})
local nameInput = nameField:GetControl()
```

Text inputs commit on Enter or focus loss and cancel on Escape. `onCommit`
receives the edited text and returns the accepted string, or `nil`/`false` plus
an optional error value to restore the previous value. `CommitAndClearFocus`,
`CancelAndClearFocus`, and `FocusValue` are available for consumer-owned
selection workflows. A mouse-caused focus loss defers its commit until the
click reaches its target; this prevents a commit-driven canvas rebuild from
consuming the button click. Clicking an LMS button flushes that edit before
the button's callback, while clicks outside LMS finalize it immediately after
the mouse is released.

## Canvas Layouts

`CreateCanvasLayout(parent, options)` measures `options.measurementFrame` and
creates a per-page layout object. Geometry is never stored in shared mutable
library state, so independently embedded addons cannot overwrite one another's
page measurements.

Every page reserves the same scrollbar area, whether or not it scrolls. Default
geometry is 8px left padding, an 8px scrollbar gap, a 17px scrollbar
reservation, a 15px column gap, a 16px indent, and 8px table padding. Override
defaults through `options.style` when a consumer intentionally needs a distinct
visual system.

The root flow is full width. `BeginColumns()` creates independent half-width
flows, allowing one column to contain more controls without inserting empty
rows into the other:

```lua
local layout = ModernSettings:CreateCanvasLayout(pageFrame, {
    measurementFrame = SettingsPanel:GetSettingsCanvas(),
    scrollable = true,
})
local root = layout:GetRootFlow()

layout:AddHeader("Example", "Example settings page.")
root:AddControl("checkbox", {
    label = "Full-width setting",
    onChanged = onChanged,
})

local columns = root:BeginColumns()

columns.left:AddSection("Left")
columns.left:AddControl("slider", sliderOptions)
columns.right:AddSection("Right")
columns.right:AddControl("dropdown", dropdownOptions)
columns:Finish()

layout:Finalize()
```

Flows provide `AddControl`, `AddText`, `AddSection`, `AddCustom`, `AddFrame`,
`AddSpacer`, and nested `BeginColumns`. Pass `indent = 1` to a placement table
for standard sub-input indentation. Custom regions keep complex addon-owned
positioning local without returning the whole page to absolute coordinates.

Spacing follows CSS-style terminology: `padding*` is internal container space,
`marginTop` and `marginBottom` surround one placed element, and `rowGap` or
`columnGap` separate sibling items or tracks. `Columns:Finish()` accepts
`marginBottom` when the completed column region needs additional space below it.

Scrollable layouts use `WowScrollBox` with `MinimalScrollBar`. `Finalize()`
derives the content height from the completed flow and refreshes the ScrollBox.

## Settings Tables

`CreateSettingsTable(parent, options)` creates a fixed table scaffold with 8px
left and right padding and alternating row backgrounds. Columns can use fixed
`width` values or divide the remaining space with `weight` values. The table
owns header, row, cell, padding, and stripe geometry; the addon owns row data,
tooltips, callbacks, and setting persistence.

Use `AddHeaderText`, `AddRow`, `row:AddText`, `row:AddControl`, and
`row:GetCell` to populate it. Add the completed table frame to a flow with
`flow:AddFrame(tableView:GetFrame())`.

## Extending the Library

Additional control types register a factory, method prototype, and optional
initializer:

```lua
ModernSettings:RegisterControlType("example", factory, methods, initializer)
local control = ModernSettings:CreateControl("example", parent, options)
```

Method dispatch remains connected to the library's persistent prototypes, so
existing controls receive compatible method updates when a newer LibStub MINOR
of the same API family loads.

The factory constructs the frame before dispatch methods are installed. The
optional initializer then applies values or state through those methods.

Custom controls should keep persistence and addon-specific callbacks in their
consumer. Register only reusable construction and control behavior with the
library.

## Slider Options

Sliders require `minValue`, `maxValue`, and `step`. Common optional fields are
`value`, `width`, `inputWidth`, `inputFormatter`, `inputParser`, `suffix`,
`tooltip`, and `onChanged`. Format suffixes into the displayed value, such as
`20s` or `100%`. Supply `inputParser` when displayed values use a different
scale from stored values.

## Validation

Blizzard frame templates and the layout builders require the game client.
Consumers should smoke-test their settings pages in game before updating a
pinned library release.
