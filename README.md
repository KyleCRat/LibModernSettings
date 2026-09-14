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
- `CreateExpandableHeader(parent, options)` creates a full-width tertiary
  section header with a right-aligned yellow arrow that points down while
  collapsed and up while expanded. Use `text`, `width`, `height`, and
  `expanded`; optionally pass `iconAtlas`, `iconSize`, and `iconDesaturated` for
  a leading atlas icon. No icon spacing is reserved when `iconAtlas` is
  omitted. `onExpandedChanged(header, expanded, button)` runs only for a user
  click; `SetExpanded()` updates the displayed state without invoking it.
  Headers also expose `IsExpanded()`, `SetHeaderText()`, `SetHeaderIcon()`,
  `SetOnExpandedChanged()`, and `SetControlEnabled()`.
- `CreateCheckbox(parent, options)` creates a 34px tertiary-square checkbox.
  Use `label`, `width`, `value`, `tooltip`, and `onChanged`. Its optional
  right-side clickable caption is part of the checkbox, not a separate Field.
- `CreateDropdown(parent, options)` creates a `WowStyle1DropdownTemplate`
  selector. Use `label`, `width`, `value`, `choices` or `getChoices`,
  `tooltip`, and `onChanged`. A non-empty `label` enables the labeled layout;
  omitting it or passing `""` creates an unlabeled selector that fits the native
  25px input frame. Both layouts default to zero side insets; `leftInset` and
  `rightInset` override either side independently. A built-in label adds its
  natural height and a 7px gap above the input, with no extra row space below.
  Use `height` only when intentionally reserving a taller or shorter row.
  Dropdown menus retain their natural height up
  to three quarters of `UIParent`; longer lists use Blizzard's native
  scrolling-menu behavior and are vertically centered on the screen.
- `CreateSlider(parent, options)` creates a stepped slider with an editable
  compact value field. A non-empty `label` retains the labeled layout;
  otherwise the control fits the track/value-box row without reserving label
  space. The native track uses its compact 19px height, with the numeric input
  centered beside it; a built-in label adds a 7px gap above the track.
  The complete control fits its content rather than reserving a fixed labeled
  height. `height` explicitly overrides that automatic height; `inputHeight`
  changes the numeric input's height.
  `minValue` and `maxValue` bound the slider track and
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
  `controlType`, and `controlOptions`. The default `labelPosition = "top"`
  creates a stacked field; choose `labelPosition = "left"` for an inline field.
  `width`, `labelWidth`, `labelHeight`, and `gap` control its geometry. Retrieve
  the primitive with `GetControl()` and enable or disable the complete field
  with `SetControlEnabled()`. The field clones `controlOptions` before assigning
  the resolved control width. Stacked fields use the label's natural height
  and a 7px gap to the input, matching labeled dropdowns and sliders; inline
  fields keep their 8px default gap. Explicit label heights and gaps remain
  supported.
  Controls can expose `GetContentTopInset()` to measure their input's top
  edge within the row. Dropdowns and sliders supply this automatically;
  other controls default to no top inset. A slider's taller numeric input
  determines its row height, while the Field aligns its label to the track.
  This is a geometry measurement, not label spacing: Field owns the gap and
  callers do not need matching options or extra layout calls.
  Optional `description` text sits below the complete label/input row in
  `GameFontHighlightSmall`, wrapping to the Field's full width. The Field grows
  or shrinks with the measured text; empty or nil descriptions reserve no room.
  Use `SetDescription(text)` for dynamic messages and `GetDescription()` to read
  the current text (an empty string when absent). `descriptionGap` defaults to
  4px and `descriptionFontObject` overrides the smaller font. These options do
  not affect the label-to-input gap or the parent layout's gap after the Field.
- `CreateText(parent, options)` creates consistently aligned canvas text.
- `SetTooltip(frame, options)` attaches a dynamic tooltip to any frame.
  After changing its contents, call `RefreshTooltip(owner, target)` to redraw
  it only when `target` currently owns the visible tooltip; `target` defaults
  to `owner`. `HideOwnedTooltip(target)` hides the tooltip only when that
  target owns it. Both ownership-aware methods return whether they acted.

Implemented inputs live in separate files under `Controls/`. Additional
control types are intentionally not part of the public API until a consumer
defines their required behavior.

Controls expose `SetValue`, `GetValue`, and `SetControlEnabled` where those
operations apply. `SetControlEnabled(false, reason)` disables the complete
input and shows `reason` from every registered tooltip target. Re-enabling the
control restores its normal tooltip.

Fields intentionally do not proxy value, focus, or control-specific methods.
Call those methods on `field:GetControl()` so primitives remain independently
usable and fields remain responsible for label/description layout and complete-field
enabled state.

Use Fields for new separate label/input combinations. Leave `label` out of
the dropdown or slider's `controlOptions` so only the Field owns the label.
Built-in dropdown and slider labels remain supported stacked conveniences and
match an equivalent default stacked Field. Only Fields support inline labels
and custom label widths, heights, or gaps. Label visibility depends solely on
non-empty label text; the former `showLabel` option is ignored. To name an
unlabeled input's tooltip, use `tooltipTitle`, not a hidden label.
Checkbox captions are an intentional exception: their right-side placement
and clickable area remain owned by the checkbox itself.

Inputs own their content bounds and internal artwork; label layouts own the
label-to-input gap; the containing flow or addon owns spacing between controls.
Default controls do not reserve external margins. Gaps reference input frames,
not visible atlas pixels. Each input type stays consistent between built-in
labels and Fields without trying to make different input artwork identical.

Dropdowns use a 34px input footprint around Blizzard's unstretched 25px button
so inline rows leave room for its border and shadow. Stacked Fields and built-in
labels retain their label gap and include the same lower artwork allowance.
Canvas flows still default to a 4px `rowGap`, overridable per canvas or through
individual placement margins; explicit control heights remain supported.

Dropdowns, sliders, and Fields relayout their existing children when their
outer width or height changes, including native `SetWidth`, `SetHeight`, and
`SetSize` calls. They also expose `SetControlWidth(width)` and
`SetControlHeight(height)`; passing `nil` to the latter restores content-sized
height. Explicit heights survive width changes. `RefreshLayout()` remeasures
labels and descriptions after direct font edits. A Field also tracks its child's height.
Values, pending text, focus, and callbacks are not reset by layout changes.
LMS canvas flows handle sibling reflow automatically. A manually positioned
consumer still owns its surrounding layout.

Font options retain their control-specific meanings: dropdown/slider
`fontObject` styles the built-in label, slider `inputFontObject` styles its
numeric value, and text-input `fontObject` styles the entered text. A Field's
`labelFontObject` styles only its separate label; input fonts stay in
`controlOptions`.

### Compatible Visual Upgrades

Compatibility preserves APIs and behavior, not an old copy's default appearance.
Controls retain their constructor options, and canvases retain their placement
definitions. A newer compatible embed updates library-owned sizing and fonts,
then reflows existing rows and columns without rebuilding controls. Explicit
options and tracked native size/font changes remain overrides; values, pending
edits, focus, enabled state, and callbacks are not reinitialized.

Each runtime module initializes only once per LibStub MINOR. Loading another
identical embed does not repeat registrations, appearance refreshes, or canvas
reflows; genuinely newer revisions still upgrade existing controls and pages.
Canvas size watchers ignore negligible floating-point rounding without turning
automatic widths into explicit overrides.

This guarantee applies to copies that retain this metadata. Earlier embeds
discarded option intent and canvas placement definitions, so their already-built
pages remain preserved rather than guessing which sizes were custom. Those
addons need a one-time embed update to participate in future visual upgrades.
A higher MINOR still updates their methods; it cannot recover discarded layout
information or retroactively rerun their page constructors.

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
the mouse is released. Moving directly to another LMS edit box preserves that
new focus while the previous value finalizes. Consumers should update
value-only state in place instead of rebuilding unrelated focused controls.

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

`AddHeader` uses `GameFontNormalHuge` for H1 page titles; `AddSection` uses
`GameFontNormalLarge` for yellow H2 headings. Ordinary control labels retain
their normal size. Override these with `titleOptions.fontObject` on the header
or `fontObject` on the section when a consumer needs different typography.

Flows provide `AddControl`, `AddText`, `AddSection`, `AddCustom`, `AddFrame`,
`AddSpacer`, and nested `BeginColumns`. An expandable header can be placed with
`AddControl("expandableHeader", options)`. Pass `indent = 1` to a placement
table for standard sub-input indentation. Custom regions keep complex
addon-owned positioning local without returning the whole page to absolute
coordinates.

Spacing follows CSS-style terminology: `padding*` is internal container space,
`marginTop` and `marginBottom` surround one placed element, and `rowGap` or
`columnGap` separate sibling items or tracks. `Columns:Finish()` accepts
`marginBottom` when the completed column region needs additional space below it.

Scrollable layouts use `WowScrollBox` with `MinimalScrollBar`. `Finalize()`
derives the content height from the completed flow and refreshes the ScrollBox.
Flows retain frames, nested columns, spacers, and explicit placement options.
Changes to a placed frame's size automatically queue one reflow for a visible
canvas; hidden canvases wait until shown. `layout:RequestLayout()` requests that
same coalesced pass after changes such as editing a FontString directly.
`layout:RefreshLayout()` performs it synchronously. Both reuse existing controls
and recalculate content height without replaying consumer construction code.

## Settings Tables

`CreateSettingsTable(parent, options)` creates a fixed table scaffold with 8px
left and right padding and alternating row backgrounds. Columns can use fixed
`width` values or divide the remaining space with `weight` values. The table
owns header, row, cell, padding, and stripe geometry; the addon owns row data,
tooltips, callbacks, and setting persistence.

Use `AddHeaderText`, `AddRow`, `row:AddText`, `row:AddControl`, and
`row:GetCell` to populate it. Add the completed table frame to a flow with
`flow:AddFrame(tableView:GetFrame())`.

Rows can grow beneath their original fixed-height cell band with
`row:SetHeight(height)`. Added and resized rows reflow following rows and the
table frame automatically. LMS canvas flows track that frame's size and reflow
automatically. For other surrounding layouts, register
`tableView:SetOnHeightChanged(function(tableView, newHeight, oldHeight) ... end)`
(or pass `onHeightChanged` when creating the table) when the surrounding canvas
or container must recompute its own height. `row:GetHeight()` and
`tableView:GetHeight()` return the current dimensions.

## Extending the Library

Additional control types register a factory, method prototype, optional
initializer, and optional appearance refresh:

```lua
ModernSettings:RegisterControlType("example", factory, methods, initializer, refreshAppearance)
local control = ModernSettings:CreateControl("example", parent, options)
```

Method dispatch remains connected to the library's persistent prototypes, so
existing controls receive compatible method updates when a newer LibStub MINOR
of the same API family loads.

When a compatible update adds or changes non-method frame state, the control
module must idempotently reconfigure its existing tracked instances. Method
dispatch alone cannot add textures, child frames, or replace scripts.

The factory constructs the frame before dispatch methods are installed.
`refreshAppearance(control, options)` runs after those methods are installed,
both for new controls and existing controls with retained options when their
type is upgraded. Keep it limited to appearance; do not restore initial values,
replace callbacks, clear focus, or overwrite enabled state. The options are a
shallow copy of the constructor options, with explicit control sizing updates
retained. Nested option tables are not deep-copied.

The initializer applies values or state only when a control is first created,
after its appearance refresh. Appearance upgrades do not rerun it.

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
