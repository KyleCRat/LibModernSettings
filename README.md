# LibModernSettings

LibModernSettings provides consistent modern controls for custom World of
Warcraft Settings canvas pages and standalone options windows. It owns control
construction, Blizzard art, value synchronization, enabled or disabled tooltip
behavior, and optional canvas layout and table geometry. The consuming addon continues to own
SavedVariables, category registration, page composition, and runtime callbacks.

Release `1.9.0` uses the `LibModernSettings-1.0` API family with LibStub MINOR `10`.

## Embedding

Load LibStub before `embed.xml`, then acquire the library with:

```lua
local ModernSettings = LibStub("LibModernSettings-1.0")
```

Embed the library at `Libs/LibModernSettings-1.0`, including its `Media` directory.
Bundled textures resolve from the copy selected by LibStub, so every consumer
uses that copy's media.

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
  For persistent selection, pass `selected = true` or call `SetSelected(boolean)`;
  `IsSelected()` reads the current state. Selection uses each variant's native
  tertiary selected artwork and survives hover, focus, disable/re-enable, and
  appearance refreshes. Clicking does not toggle it automatically or fire a
  separate selection callback. This API requires release 1.9.0 or newer.
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
- `CreateColor(parent, options)` creates tertiary-square color choices with a
  right-side `label`. It supports optional class/accent modes and a shared picker
  with hex/RGB(A) entry, recent colors, favorites, and class/item-quality swatches. See
  [Color inputs](#color-inputs) for value, persistence and cancellation contracts.
- `ApplyTertiarySquareArtwork(button, texture, buttonSize)` fits and masks an existing
  texture inside a fixed-size tertiary square. Use it for spell/item artwork or
  solid color fills; texture, color and UVs remain caller-owned. Keep button state
  artwork below `OVERLAY` sublevel 1. It returns the attached mask and reuses it
  on later calls, including compatible library upgrades.
- `CreateDropdown(parent, options)` creates a `WowStyle1DropdownTemplate`
  selector. Use `label`, `width`, `value`, `choices` or `getChoices`,
  `tooltip`, and `onChanged`. A non-empty `label` enables the labeled layout;
  omitting it or passing `""` creates an unlabeled selector with a 34px footprint
  around the native 25px button artwork. Both layouts default to zero side
  insets; `leftInset` and `rightInset` override either side independently. A built-in label adds its
  natural height and a 7px gap above the input, with no extra row space below.
  Use `height` only when intentionally reserving a taller or shorter row.
  Dropdown menus retain their natural height up
  to three quarters of `UIParent`; longer lists use Blizzard's native
  scrolling-menu behavior and are vertically centered on the screen.
  While a menu is open, Up/Down arrows select the previous/next available choice
  without wrapping or closing the menu. The selected row is scrolled into view;
  the mouse wheel scrolls the list without changing selection. Enter or Space
  confirms the current selection and closes the menu without triggering chat or
  game actions. Focus returns to the dropdown input for continued Tab navigation.
  Escape closes an open menu; a second press releases focus. Clicking a choice
  behaves normally.
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
  Selecting the track, a stepper or the value field focuses numeric editing.
  While focused, the wheel over the control and Up/Down arrows change that
  editable value by one `step`, including outside the track range. While scrolling,
  hold Shift for ten steps or Ctrl for fifty steps per wheel event; Ctrl takes
  priority when both are held. Unfocused controls leave the wheel available for
  page scrolling.
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
- `CreateText(parent, options)` creates consistently aligned canvas text using
  `GameFontHighlight` by default. Set `fontObject` to override it. The font is
  initialized before assigning text, including empty labels and plain `AddText`
  calls on canvas flows.
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

This guarantee applies to copies from 1.7.0 onward that retain this metadata.
Earlier embeds discarded option intent and canvas placement definitions, so their already-built
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
an optional error value to restore the previous value. Rejected Enter or Tab
commits keep that value focused and selected unless the callback moves focus.
`CommitAndClearFocus`,
`CancelAndClearFocus`, and `FocusValue` are available for consumer-owned
selection workflows. A mouse-caused focus loss defers its commit until the
click reaches its target; this prevents a commit-driven canvas rebuild from
consuming the button click. Clicking an LMS button flushes that edit before
the button's callback, while clicks outside LMS finalize it immediately after
the mouse is released. Moving directly to another LMS edit box preserves that
new focus while the previous value finalizes. Consumers should update
value-only state in place instead of rebuilding unrelated focused controls.

Canvas text inputs, slider value boxes, dropdowns, checkboxes, expandable headers
and buttons support Tab and Shift+Tab in visual row order, wrapping within the page.
Hidden and disabled inputs are skipped, responsive columns follow their current
positions, and focusing an offscreen field scrolls it into view. Moving focus
commits pending text first; a rejected text commit keeps focus on that input. Dropdowns
highlight without opening on focus. Enter or Space opens the menu; confirming
selection closes it while retaining focus. Tab closes an open menu and moves on.
Checkboxes, headers and all button variants retain their hover highlight while
focused; Enter or Space invokes their normal click behavior. Escape releases
focus unless a dropdown menu is open, in which case it closes the menu first.
Clicking elsewhere, disabling or hiding the control, or focusing another LMS edit
box releases focus as well. Dropdowns, checkboxes, headers and buttons are skipped
during combat, when their keyboard navigation is unavailable.

For manually composed windows, call `ModernSettings:EnableTabNavigation(parent)`
on an ordinary UI container. Its descendant LMS inputs share a cycle, including
any canvas pages inside it; hidden pages are excluded. This can join a toolbar
input and the active editor page. Nested explicit navigation roots keep
their own cycles. Outside a canvas or explicit root, edit boxes retain Blizzard's
`nextEditBox`/`previousEditBox` behavior.

## Flash Messages

Create one stack for an ordinary window or input-group frame and reuse it:

```lua
local messages = ModernSettings:CreateFlashMessages(frame)

local input = ModernSettings:CreateTextInput(frame, {
    onCommit = validateValue,
    onError = function(message)
        messages:Show(message or "Enter a valid value.", "error")
    end,
})

local notice = messages:Show("Changes saved.", "success")
messages:Dismiss(notice) -- Optional early dismissal; each message also has an X.
```

`Show(message, state)` accepts `success`, `info` (the default), or `error` and
returns a message ID, or `nil` when the owner is hidden. `Dismiss(id)` returns
whether that message was active; `Clear()` dismisses the entire stack. These
operations do not change input values, validation state, focus or owner size.
Consumers should keep validation state separate from transient feedback.

Messages use Blizzard's metal dialog border with dark status-colored backgrounds
and lighter matching text.

Messages stack downward below the owner, newest last. If the stack will not fit
below it, it sits directly above the owner, with the newest message closest to
the frame. It stays horizontally aligned and clamped inside the screen edges.
The overlay follows movement and effective
scale and escapes scroll clipping. Hiding the owner clears its messages; call
`Clear()` when switching the data being edited without hiding the owner.

Options are `width` (360 owner UI units), `duration` (6 seconds before fading),
`fadeDuration` (0.35 seconds), and `maxMessages` (4). Repeated message/state pairs
restart their lifetime at the bottom of the stack; excess messages replace the
oldest. Hovering a message or its close button pauses its timer, including a fade
already in progress; leaving resumes the remaining time. Other messages keep
their own timers. Frames are reused, and empty stacks stop updating. Use ordinary addon
frames as owners, not protected or secret-bearing Blizzard widgets.

## Color Inputs

```lua
local palette = ModernSettings:CreateColorPalette({
    get = function()
        return uiDB:Get("colorPalette") -- defaults: { recent = {}, favorites = {} }
    end,
    set = function(value)
        uiDB:Set("colorPalette", value)
    end,
})

local input = ModernSettings:CreateColor(parent, {
    label = "Border color",
    value = { r = 1, g = 1, b = 1, a = 1, mode = "custom" },
    hasOpacity = true,
    classColor = true,
    accentColor = function()
        return theme.accent
    end,
    palette = palette,
    onChanged = function(value)
        settings:Set("borderColor", value)
    end,
})
```

Canvas `AddControl("color", options)` accepts the same options. Channels are
numbers from 0 to 1; omitted alpha defaults to 1. The default RGB picker hides
alpha controls and returns opaque colors. `hasOpacity = true` enables RGBA,
an opacity slider and an A percentage field. Hex displays six `RRGGBB` digits;
committing six digits preserves opacity, while `RRGGBBAA` imports alpha and
normalizes the field back to RGB. Both formats accept an optional `#` prefix;
other digit counts are rejected. RGB-only inputs discard imported alpha.
Swatches render their color and opacity
over the button background without a checkerboard.

Optional `classColor` and `accentColor` accept an RGB(A) table or a function
returning one. `classColor = true` uses Blizzard's current player-class color.
Enabled shortcuts precede Custom in class/accent/custom order. `value.mode`
is `"custom"` by default, or `"class"` / `"accent"` when that shortcut is enabled.
Mode is explicit: choosing the same RGB manually still selects Custom. Quick
choices apply immediately through `onChanged(value)` without replacing the saved
Custom color or its swatch. Opening Custom restores that color and selects its
mode. Picker edits stay pending until Apply.
Cancel/X restores the opening color while keeping Custom selected. Only Apply
adds a recent color; explicit favorite changes survive cancellation.
The built-in class palette uses playable classes only. Class and item-quality
swatches change RGB while preserving the draft's opacity; saved palettes retain RGBA.

`GetValue()` returns a fresh RGBA table including mode. Class/accent values also
include `custom`, an RGBA table holding the remembered Custom color; persist the
whole value to retain it across input refreshes and reloads. `SetValue(value)`
cancels any open edit and sets the value without a callback. For class/accent
values, `custom` seeds the Custom swatch, falling back to the supplied RGBA when
omitted. `SetOnChanged(callback)`,
`SetControlEnabled(enabled, tooltip)`, `OpenPicker()`, and `ClosePicker()` are also
available. Hide, disable, rebind, or close an input when its data owner changes;
closing discards its draft. Apply/Cancel returns keyboard focus to Custom.
`RefreshColors()` refreshes dynamic class/accent swatches without a callback;
`GetValue()` resolves their current colors. Consumers own runtime theming and
should persist the mode and resolve its source when rendering outside the UI.

Share a palette object across related inputs. Its `get` and `set` callbacks
must be supplied together; LMS copies palette data and never mutates a table
returned by `get`. Without an adapter the object retains colors for the session;
omitting `palette` shares the library's session palette. `maxRecent` defaults to
13 and `maxFavorites` to 26. Recent colors deduplicate at RGBA byte precision;
favorites never silently evict a saved color when full. Palette objects expose
`GetColors("recent" | "favorites")`, `Record(color)` and `ToggleFavorite(color)`.
The latter returns the new favorite state, or `nil, message` when full.

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
`AddSpacer`, and nested `BeginGroup` / `BeginColumns`. An expandable header can be placed with
`AddControl("expandableHeader", options)`. Pass `indent = 1` to a placement
table for standard sub-input indentation. Custom regions keep complex
addon-owned positioning local without returning the whole page to absolute
coordinates.

Spacing follows CSS-style terminology: `padding*` is internal container space,
`marginTop` and `marginBottom` surround one placed element, and `rowGap` or
`columnGap` separate sibling items or tracks. `Columns:Finish()` accepts
`marginBottom` when the completed column region needs additional space below it.

Use `BeginGroup()` for a full-width region with independent visibility. It
returns a child flow with the same operations, including nested groups and
responsive columns. Its width is available immediately during construction.
Call `Finish()` before adding the next sibling to the parent flow:

```lua
local details = root:BeginGroup({ marginTop = 4 })
details:AddText({ text = "Additional settings" })
details:AddControl("slider", sliderOptions)
details:Finish({ marginBottom = 4 })
details:SetShown(showDetails)
```

`BeginGroup` accepts `indent` and `marginTop`; its `Finish` accepts
`marginBottom` and requests a reflow, including when appending to a finalized
canvas. Hidden groups remove their contents and both margins. Groups require
a tracked canvas and own their controls' visibility through `SetShown`.

Scrollable layouts use `WowScrollBox` with `MinimalScrollBar`. `Finalize()`
derives the content height from the completed flow and refreshes the ScrollBox.
Flows retain frames, nested groups and columns, spacers, and explicit placement options.
Changes to a placed frame's size automatically queue one reflow for a visible
canvas; hidden canvases wait until shown. `layout:RequestLayout()` requests that
same coalesced pass after changes such as editing a FontString directly.
`layout:RefreshLayout()` performs it synchronously. Both reuse existing controls
and recalculate content height without replaying consumer construction code.

Use `layout:SetSize(width, height)` when a containing viewport changes size.
It updates the canvas parent, content width and viewport height, and requests
the same coalesced reflow. Dimensions must be finite, positive and leave room
after the configured content insets and viewport margins. This can be called
from the parent's `OnSizeChanged`; unchanged dimensions do no work.

`BeginColumns({ minColumnWidth = 260 })` stacks its flows in declaration order
when their equal-width columns would be narrower than that minimum. Omit the
option to retain fixed columns. Use a separate column region for each logical
row when narrow layouts should read left-to-right, then top-to-bottom.

`flow:SetShown(false)` hides that flow's frames and removes its space, including
column gaps. Remaining columns fill the available width; an entirely hidden
column region occupies no space. `SetShown(true)` restores its controls without
recreating them or setting their values. Nested flows retain their own hidden
state. This API owns the visibility of all frames added to the flow; use it on
tracked canvases and commit pending edits before hiding their controls.

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

Call `RegisterControlNavigation(controlType, options)` after registering a control
type to opt it into the shared navigation behavior. Registration updates existing
instances and applies to future instances; re-registering updates callbacks without
duplicating hooks or clearing focus. The options and action map are copied.

| Option | Contract |
| --- | --- |
| `mode` | `"keyboard"` (default) uses shared keyboard capture outside combat; `"editBox"` keeps native text editing. |
| `input(control)` | Returns the control's stable input widget; defaults to the control itself. It must support visibility/enabled checks and belong to the control. Keep its identity and mode stable across upgrades. |
| `actions` | Maps `activate`, `previous`, `next`, `navigate`, or `dismiss` to functions receiving `(control, context)`. Return `true` to consume the action. Tab traversal and dismissal have defaults. |
| `focus(control)` | Optional override for acquiring focus. Defaults to native edit focus with text selection, or shared keyboard focus. |
| `release(control)` | Runs for Tab traversal, default dismissal, and keyboard-input hide/disable cleanup. Return `false` to stop Tab traversal. The default clears native edit focus and flushes pending LMS commits; shared keyboard focus is released before the callback. |
| `highlight(control, focused)` | Optional keyboard-focus visual update. |
| `hover(control, highlighted)` | Optional combined mouse/keyboard hover update; disabled inputs receive `false`. |

Action context includes `source`, `direction` (`-1` for previous, `1` for next),
and a `modifiers` snapshot with `shift`, `control`, `alt`, and `meta`. Numeric
controls can interpret previous/next differently from list order.
For native editors, navigation owns `OnTabPressed` and routes `OnArrowPressed`
when previous/next actions exist. It hooks focus acquisition to release shared
keyboard capture. The control retains its Enter/Escape, text, and commit behavior;
Space remains a text character. Put any construction or script reconfiguration
before navigation registration. Existing public control methods are unaffected.

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

Sliders require finite `minValue`, `maxValue`, and a positive `step`, with
`maxValue` greater than `minValue`. Typed and programmatic values must also be
finite; consumers enforce any domain limits in `onChanged`. Common optional fields are
`value`, `width`, `inputWidth`, `inputFormatter`, `inputParser`, `suffix`,
`tooltip`, and `onChanged`. Format suffixes into the displayed value, such as
`20s` or `100%`. Supply `inputParser` when displayed values use a different
scale from stored values.

## Validation

Run the automated suite from the library root with Lua 5.1:

```sh
lua tests/run.lua
```

Blizzard frame templates and the layout builders require the game client.
Follow [the validation checklist](tests/README.md) and smoke-test consumer
settings pages in game before updating a pinned library release.
