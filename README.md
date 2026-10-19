# LibModernSettings

LibModernSettings provides consistent modern controls for custom World of
Warcraft Settings canvas pages and standalone options windows. It owns control
construction, Blizzard art, value synchronization, enabled or disabled tooltip
behavior, and optional canvas layout and table geometry. The consuming addon continues to own
SavedVariables, category registration, page composition, and runtime callbacks.

Release `1.10.0` uses the `LibModernSettings-1.0` API family with LibStub MINOR `11`.

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
  `iconAtlas` or `iconTexture` for a centered icon-and-text command and `fitToContent = true`
  to derive the width from the complete content group. Use regular buttons by
  default; reserve `variant = "small"` for dense rows or constrained layouts.
  Small buttons automatically constrain native atlas icons to 14px while
  preserving aspect ratio. `maxIconSize` changes that cap while preserving the
  atlas ratio; `iconSize` explicitly forces a square size. Use
  `variant = "square"` with either icon source for an icon-only action button. It
  defaults to 34px square with an icon no larger than 16px; custom `width` or
  `height` keeps both dimensions equal. Square buttons automatically mask both
  atlas and texture icons to the inner border without changing their sizing or
  aspect ratio. Regular and small buttons do not mask their icons.
  Buttons retain Blizzard's normal
  mouse-up activation timing and finalize a pending text edit before invoking
  their consumer callback.
  `iconTexture` accepts a texture path or file ID and defaults to 16px square;
  use `iconSize` for another size. `SetButtonIcon({ iconTexture = pathOrID })`
  or `SetButtonIcon({ iconAtlas = atlas })` replaces the source while preserving
  sizing and selection. Pass `{}` to remove a text button's icon; square buttons
  must keep an icon. Texture icons, automatic square masking, and this setter
  require release 1.10.0 or newer.
  For persistent selection, pass `selected = true` or call `SetSelected(boolean)`;
  `IsSelected()` reads the current state. Selection uses each variant's native
  tertiary selected artwork and survives hover, focus, disable/re-enable, and
  appearance refreshes. Clicking does not toggle it automatically or fire a
  separate selection callback. This API requires release 1.9.0 or newer.
  Selected text-button glow artwork extends beyond the control to keep its
  visible body aligned; selection does not change the layout or hit area.
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
  texture inside a fixed-size tertiary square. Use it for custom artwork or
  solid color fills; `CreateButton` already masks its square icons automatically.
  Texture, color and UVs remain caller-owned. Keep button state
  artwork below `OVERLAY` sublevel 1. It returns the attached mask and reuses it
  on later calls, including compatible library upgrades.
- `CreateDropdown(parent, options)` creates a recessed text-input-style selector
  with an inset tertiary square caret, retaining Blizzard's native menu and selection
  behavior. The input focus glow appears while keyboard-focused or open, not on
  mouse hover alone. Only the caret square uses hover, pressed and disabled art.
  Use `label`, `width`, `value`, `choices` or `getChoices`,
  `tooltip`, and `onChanged`. Choice records use `{ value, label }`, with optional
  `tooltip` text, `tooltipTitle` and `enabled = false`. Add `{ type = "title", label = "Group" }`
  and `{ type = "divider" }` records for native menu headings and separators.
  Headings, dividers and disabled choices are skipped by arrow navigation;
  a disabled saved value can remain selected. `SetChoices()` and `getChoices`
  support the same records, including updated tooltip and enabled state.
  Add `previewTexture = texturePathOrFileID` to a choice to show its texture
  across the row behind an outlined name, leaving selection marks clear.
  Single-select inputs also show the selected texture behind their label;
  checkbox menus retain their text summary in the closed input.
  Previews update with `SetValue()`, `SetChoices()` and regenerated `getChoices`
  results. Supply the texture directly, for example `media:Fetch("statusbar", name)`
  when using LibSharedMedia; LMS has no media-library dependency.
  Optional `menuWidth` sets a fixed menu width in UI units independently of the
  input width, capped to the screen width. It must be a finite positive number.
  Omit it to retain native sizing. For example, use `menuWidth = 300` for a
  compact texture picker even when its input fills a wide settings page.
  Set `multiSelect = true` for native checkboxes. `value`, `SetValue()` and
  `GetValue()` then use a set such as `{ combat = true, mounted = true }`,
  with string, number or boolean choice keys. Nil means an empty set; false
  entries are omitted. Inputs, returned sets and callback values are copied.
  `onChanged(values, changedValue, checked)` runs once per user toggle; the
  menu stays open. Up/Down moves focus without changing checks, Enter/Space
  toggles the focused checkbox, and Escape or Tab closes it. Unknown saved
  keys survive choice-list changes; disabled options are skipped by navigation.
  Both selection modes accept `placeholder` for no selection and
  `selectionText(value, choices)` to format the displayed summary; returning
  nil uses native selected labels. Single-select callbacks remain unchanged.
  A non-empty `label` enables the labeled layout;
  omitting it or passing `""` creates an unlabeled 34px selector whose body artwork
  stays inside its bounds, aligned with regular/square tertiary buttons.
  The inset caret shares the selector's single mouse and keyboard target.
  Both layouts default to zero side
  insets; `leftInset` and `rightInset` override either side independently. A built-in label adds its
  natural height and a 7px gap above the input, with no extra row space below.
  Use `height` only to reserve a different row height; the button stays 34px.
  Stacked labels reserve the full button height, so consumers with fixed labeled
  row heights should review their spacing. Existing `leftInset`/`rightInset`
  options remain supported; old adjustments for native artwork overhang can
  usually be removed.
  Dropdown menus retain their natural height up
  to three quarters of `UIParent`; longer lists use Blizzard's native
  scrolling-menu behavior and are vertically centered on the screen.
  In single-select menus, Up/Down arrows select the previous/next available choice
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
  Values snap to `step` by default. Set `snapToStep = false` to retain exact
  typed/programmatic values, such as fractional positions captured by dragging.
  The native track still uses `step`; keyboard/wheel increments add `step` to the
  current value without removing its fractional part. Outside the track range,
  the thumb stays at the nearest endpoint without replacing the entered value.
  The editable value field
  shows Blizzard's neutral depressed tertiary glow while focused.
  Selecting the track, a stepper or the value field focuses numeric editing.
  While focused, the wheel over the control and Up/Down arrows change that
  editable value by one `step`, including outside the track range. While scrolling,
  hold Shift for ten steps or Ctrl for fifty steps per wheel event; Ctrl takes
  priority when both are held. Unfocused controls leave the wheel available for
  page scrolling.
  Optional `valueLabels = { [-1] = "Inherit" }` names numeric steps; use
  `minValue = -1` to put Inherit at the left endpoint before 0–100, or
  `minValue = 0, valueLabels = { [0] = "Auto" }` for automatic sizing.
  These labels display without a suffix and can be typed regardless of case or
  surrounding spaces. `GetValue`, `SetValue` and `onChanged` still use numbers;
  named values step normally and do not disable the control or impose new limits.
  Consumers own what each value means and any hard bounds. The map is copied on
  construction, with keys following `snapToStep`; each must name a distinct value and
  each label must be non-empty and unique ignoring case/outer spaces.
  Labels take precedence over `inputFormatter`/`inputParser`, which still handle
  other values. The input's `maxLetters` expands to fit the longest label unless
  already unbounded (`0`); use `inputWidth` for longer labels as needed.
- `CreateTextInput(parent, options)` creates a full-width single-line text
  input with the same single-piece sliced tertiary background used by slider
  value inputs. It defaults to 34px high. Use `value`, `width`, `height`,
  `maxLetters`, `textInset`, `onCommit`, and `onError`. Omitting `maxLetters`
  leaves the input unbounded. Focus shows Blizzard's neutral depressed
  tertiary glow without changing the consumer API.
- `CreateValueList(parent, options)` edits an ordered array of small value fields
  that wrap to fit the available width. Use `controlType = "valueList"` in a Field
  or canvas. Pills remain part of one input, with 34px rows and 6px gaps; the control
  grows and shrinks automatically so following content stays below it.
  `value` is a dense array of non-empty strings or finite numbers, defaulting to
  `{}`. `SetValue()` and `GetValue()` copy the array. Blank fields are omitted from
  the saved value, and at least one field remains available.
  Enter commits and advances, adding a field after the last non-empty value.
  **+** adds a field or focuses the existing final blank; **trash** removes the
  last field while more than one is present. Tab/Shift+Tab navigates fields and
  buttons in row order. Actions follow the last pill, sharing its row when they
  fit. Enter and Tab reveal the focused pill in a scrolling canvas; the mouse wheel
  scrolls the page. `width` defaults to 270; `entryWidth` defaults to 64.
  Optional `maxValues` limits the number of fields; there is no limit by default.
  `parseValue(text)` accepts one value, returning a string/number, or `nil, error`
  to reject it. `formatValue(value)` returns its displayed string. Without these,
  values are trimmed text and formatting uses `tostring`. `onChanged(values)`
  receives a copied array only when committed values change. `onError(error)`
  reports rejected edits, which restore the previous value and retain keyboard
  focus on Enter/Tab. Consumer `SetValue()` calls during `onChanged` may echo or
  normalize the accepted list; rebinding cancels old drafts and advancement.
  Use `CommitAndClearFocus()`, `CancelAndClearFocus()`, `FocusValue(index)`
  (default first), `AddEntry()` and `RemoveLastEntry()` for consumer interactions.
  Disabling or hiding discards drafts; call `CommitAndClearFocus()` before hiding
  when those edits should apply. `SetOnChanged()`/`SetOnError()` replace callbacks.
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

Dropdown bodies use the full 34px input footprint, aligned with text inputs and
tertiary square buttons. Their focus glow uses the same small outset as text
inputs. Stacked Fields and built-in labels retain their normal label gap.
Canvas flows still default to a 4px `rowGap`, overridable per canvas or through
individual placement margins; explicit control heights remain supported.

Dropdowns, sliders, and Fields relayout their existing children when their
outer width or height changes, including native `SetWidth`, `SetHeight`, and
`SetSize` calls. They also expose `SetControlWidth(width)` and
`SetControlHeight(height)`; passing `nil` to the latter restores content-sized
height. Explicit heights survive width changes. `RefreshLayout()` remeasures
labels and descriptions after direct font edits. A Field also tracks its child's height.
Child-driven height changes are coalesced after native size callbacks finish.
For immediate measurements outside those callbacks, call the Field's
`RefreshLayout()` first. Keyboard navigation settles pending Field sizes before moving focus.
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

For live rendering, provide `onPreview(value)`. Color changes send a fresh custom
RGBA value without changing `GetValue()` or firing `onChanged`. Hue/saturation,
opacity, swatches and valid committed text edits all preview; unchanged colors
do not repeat the callback. Keep this draft outside saved settings.
Once a preview has started, `onPreview(nil)` clears it when the session ends,
including Cancel, X, Escape, owner hiding/disabling/rebinding, another picker
opening, and Apply. On Apply, that cleanup runs before the single `onChanged`
commit. Restore the saved appearance on nil, and render the committed value in
`onChanged`. Inputs without `onPreview` retain their apply-only behavior.

`GetValue()` returns a fresh RGBA table including mode. Class/accent values also
include `custom`, an RGBA table holding the remembered Custom color; persist the
whole value to retain it across input refreshes and reloads. `SetValue(value)`
cancels any open edit and sets the value without `onChanged`, ending any live
preview. For class/accent
values, `custom` seeds the Custom swatch, falling back to the supplied RGBA when
omitted. `SetOnChanged(callback)` and `SetOnPreview(callback)` replace callbacks;
changing the preview callback first cancels an open picker through its old callback.
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

## Scroll Areas

`CreateScrollArea(parent, options)` creates a native ScrollBox and modern
`MinimalScrollBar` inside an addon-owned pane. The addon keeps ownership of the
pane's border, size, anchors, visibility, headers and footers. LMS owns the
viewport and scrollbar column; Blizzard owns scrolling and list virtualization.
No surrounding window or inset artwork is created.

For forms and free-form control layouts, use `CreateCanvasLayout` with the
`scrollArea` option below. For a native list, configure its view normally and
initialize the area once:

```lua
local area = ModernSettings:CreateScrollArea(insetFrame, {
    preset = "inset",
    contentSpacing = "compact",
})

local view = CreateScrollBoxListLinearView()
view:SetElementExtent(50)
view:SetElementInitializer("MyAddonListRowTemplate", initializeRow)
area:Init(view)
area:GetScrollBox():SetDataProvider(dataProvider)
```

The parent should describe the entire pane. Do not shrink it by another layer
of scrollbar padding. The native children follow its anchors when it resizes;
LMS never resizes or reanchors the parent. Size-dependent content should read
the area measurements after the parent has a usable size.

Wheel input anywhere in the pane, including its margins and scrollbar gap,
uses the native scrolling handler. It remains consumed at the scroll limits
and when content fits. Child controls such as focused sliders retain their
own wheel behavior; the pane's click, motion and script handling is unchanged.

| Option | Default and meaning |
| --- | --- |
| `preset` | `"inset"`: border clearance of 4px left, 6px right/top, 5px bottom. `"none"` starts with zero border clearance. Neither draws a border. |
| `contentSpacing` | `"regular"`: 16px content margins and scrollbar gap. `"compact"`: 8px content margins and a 4px scrollbar gap for rows that already have internal padding. |
| `borderInsets` | Partial `{ left, right, top, bottom }` overrides for another border. Unspecified edges retain the preset. |
| `contentPadding` | Partial `{ left, top, bottom }` content margins, measured from the parent's edges, not added to the border clearance. A thicker border becomes the minimum safe margin. |
| `scrollbarGap` | Space between the content and the scrollbar column; overrides the spacing preset. |
| `scrollbarWidth` | 17px, reserving the native arrows and hit area as well as the narrower track. |
| `kind` | `"list"` creates `WowScrollBoxList`; `"canvas"` creates `WowScrollBox` for a caller-owned linear view and content frame. |

Numeric overrides must be finite and non-negative; scrollbar width must be
positive. Zero is an explicit override. Options are copied, including the
border/content tables. The scrollbar column stays reserved when content fits,
so overflow never changes the content width.

Areas expose:

- `Init(view)`: connects the appropriate native view once, after configuring
  list rows or creating canvas children. Does not change the view's padding.
- `GetScrollBox()` / `GetScrollBar()`: the native widgets.
- `GetContentWidth()` / `GetViewportHeight()`: current available dimensions.
- `GetContentInsets()`: left, right, top, bottom offsets from the parent. The
  right offset includes the scrollbar reservation, useful for header alignment.
- `GetContentPadding()`: top and bottom padding inside the viewport. Lists
  return zero because their content margins are reserved outside the viewport.
  Canvas callers include this padding in their content height; a canvas layout
  handles it automatically.

For example, `borderInsets = { right = 8 }` adjusts only right-side clearance.
There is no need to recalculate the content width or subtract border offsets
from content padding in addon code.

## Canvas Layouts

`CreateCanvasLayout(parent, options)` measures `options.measurementFrame` and
creates a per-page layout object. Geometry is never stored in shared mutable
library state, so independently embedded addons cannot overwrite one another's
page measurements.

By default, pages reserve the same scrollbar area whether or not they scroll. Default
geometry is 8px left padding, an 8px scrollbar gap, a 17px scrollbar
reservation, a 15px column gap, a 16px indent, and 8px table padding. Override
defaults through `options.style` when a consumer intentionally needs a distinct
visual system.

For a nested non-scrolling layout without `scrollArea`, set `style.paddingLeft`,
`style.scrollbarGap`, and `style.scrollbarWidth` to `0` to use the full parent
width. Scrolling layouts still require a positive scrollbar width.

To use a scroll area's inset spacing, opt in explicitly:

```lua
local layout = ModernSettings:CreateCanvasLayout(insetFrame, {
    scrollable = true,
    scrollArea = {
        preset = "inset",
        contentSpacing = "compact",
        -- borderInsets = { right = 8 }, -- Optional border-specific adjustment.
    },
})
```

With this option, pass the full pane dimensions, including its border clearance.
Omit `contentSpacing` for regular form spacing. A non-scrolling header can use
the same `scrollArea` options to align its horizontal content bounds while
keeping its own `style.paddingTop` and `style.paddingBottom`. Both kinds of
layout expose `GetContentInsets()` (left, right, top, bottom).

When `scrollArea` is present it owns `paddingLeft`, `scrollbarGap`, and
`scrollbarWidth`, plus top/bottom padding for scrolling layouts. Supplying
competing `style`/top-level values or `viewportMarginTop`/`viewportMarginBottom`
is an error: use the scroll area's border/content options instead. Other style
options, such as column gaps and row spacing, remain independent. Omitting
`scrollArea` preserves all existing canvas defaults and overrides.

For backgrounds or borders extending beyond the controls, a canvas can opt into
`contentOverflow = { left = 8, right = 8 }`. This widens horizontal clipping into
the existing margins without changing control widths, content insets or scrollbar
placement. Each side is capped at the available margin, preserving border clearance
and the scrollbar column. Omitted sides default to zero; values must be finite and
non-negative. The options are copied. Vertical clipping and scrolling are unchanged;
non-scrolling canvases keep their existing placement.

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
`AddSpacer`, and nested `BeginGroup` / `BeginColumns` / `BeginGrid`. An expandable header can be placed with
`AddControl("expandableHeader", options)`. Pass `indent = 1` to a placement
table for standard sub-input indentation. Custom regions keep complex
addon-owned positioning local without returning the whole page to absolute
coordinates. Use `AddCustom(height, { fillWidth = true })` when a custom region
should follow the available width during resize; otherwise it keeps its initial width.

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

For custom frames containing another canvas, pass an `onLayout(frame)` callback
in the placement options for `AddFrame` or `AddCustom`. It runs during reflow,
after width and position are assigned and before the outer flow measures height.
It does not run during initial insertion, so the child can be built before the
outer canvas is finalized:

```lua
local childLayout
local container = root:AddCustom(1, {
    fillWidth = true,
    onLayout = function(frame)
        childLayout:SetSize(frame:GetWidth(), 1)
        childLayout:RefreshLayout()
        frame:SetHeight(childLayout:GetContent():GetHeight())
    end,
})
childLayout = LMS:CreateCanvasLayout(container, { width = container:GetWidth(), height = 1 })
childLayout:GetContent():HookScript("OnSizeChanged", function()
    root.layout:RequestLayout()
end)
-- Build and finalize the child, then finalize the outer canvas.
```

This keeps nested sizes and final scroll positioning in the same pass instead
of waiting for native size notifications. Callbacks must only refresh geometry;
do not rebuild controls, edit values or re-enter the owning canvas. Keep them
idempotent: column alignment can measure a frame more than once. Hidden flow
groups skip their callbacks. Existing placement height overrides still apply.
Child size callbacks should only request the outer layout, as above. Resizing or
re-anchoring ancestors from a child's native size callback can invalidate the
geometry being measured and leave controls invisible until a later resize.

To preserve the section being edited across different records or forms, register
each section once with a stable key, then capture and restore a bookmark:

```lua
-- Register every relevant section on each scrollable canvas when building it.
layout:RegisterScrollSection("appearance", appearanceFrame, {
    isExpanded = function()
        return appearanceHeader:IsExpanded()
    end,
})

-- Around a selection change; these may also be the same canvas.
local bookmark = previousLayout:CaptureScrollBookmark()
-- Update the destination's controls and visibility here.
nextLayout:RestoreScrollBookmark(bookmark)
nextLayout:RefreshLayout()
```

Keys are non-empty strings scoped to each canvas. Use the same key for equivalent
sections on different forms, regardless of their labels. Frames must be descendants
of that canvas's content. `isExpanded` is an optional, read-only callback returning
a boolean; omit it for a section that is always expanded. LMS copies registration
options and reads expansion when capturing, so toggling a header needs no
registration update. Header expansion, tab selection and persistence stay with
the consumer.

`CaptureScrollBookmark()` prefers the expanded section with the most visible area,
or the most visible heading when all visible sections are collapsed. It retains
the section's offset from the viewport top, including negative offsets when its
heading is below that top. The beginning of the page stays at the beginning.
An anchor waiting for reflow takes precedence, so rapid selections do not capture
an intermediate position. Hidden canvases return nil; away from the page beginning,
so do views with no registered section in view. Treat bookmarks as opaque, read-only, temporary values;
they contain no frame or callback references and are not a SavedVariables format.

`RestoreScrollBookmark(bookmark)` matches a shown section with the same key.
If absent or hidden, it uses the nearest surviving section in the source's visual
order, preferring the following section on a tie, and shows its heading. With no
match it returns to the top. The request survives deferred layouts; native scroll
limits still apply. A hidden destination can accept a bookmark before showing.
Passing nil clears a pending anchor without moving the current scroll position.

Registering an existing key replaces its frame/options and transfers any active
anchor to the replacement. A frame cannot have two keys in one canvas.
`UnregisterScrollSection(key)` releases the registration and its active anchor,
returning true if found or false if already absent. Unregister sections before
returning their frames to a pool. Hidden or reparented sections are excluded from
matching. Capture uses visual order, so rearranging retained sections does not
require registering them again.

For direct control of an anchor without section registration, use
`layout:SetScrollAnchor(frame, offset)` on a scrollable canvas. The frame must
belong to `layout:GetContent()` (the content itself is also allowed). `offset`
defaults to zero and measures down from the frame's top to the viewport's top,
in canvas units; a negative offset leaves the heading below the viewport's top.
The request applies on the next layout and survives subsequent deferred reflows.
If the frame shrinks past the requested offset, its top is shown instead. Native
scroll limits still apply. Hidden anchors wait until visible; reparenting outside
the content clears the request.

`layout:GetScrollAnchor()` returns the requested frame and offset, or nil when
inactive. Scroll notifications outside the canvas's own reflow (including the
start of an interpolated wheel gesture) and keyboard focus reveals release the
anchor. Use
`layout:SetScrollAnchor(nil)` to clear it explicitly before rebinding or hiding a
page, or when a new interaction should own the position, such as manually expanding
a different section. Canvases without an anchor keep their existing absolute-scroll
behavior. Bookmark matching uses this same anchoring path without rebuilding controls.

After rebinding and showing a destination, call `RefreshLayout()` in the same
selection handler to apply its bookmark before the next rendered frame. Nested
custom sections should use `onLayout` as above so their final heights are measured
in that pass. This does not alter page alpha, visibility, focus or input enablement.

Use `layout:SetSize(width, height)` when a containing viewport changes size.
It updates the canvas parent, content width and viewport height, and requests
the same coalesced reflow. Dimensions must be finite, positive and leave room
after the configured content insets and viewport margins. This can be called
from the parent's `OnSizeChanged`; unchanged dimensions do no work.
Read the frame's current dimensions in that callback rather than replaying its
possibly queued width/height arguments. Only changed axes are resized: a width
change preserves a content-sized parent's measured height instead of resetting
it to the canvas's original minimum height.

`BeginColumns({ minColumnWidth = 260 })` stacks its flows in declaration order
when their equal-width columns would be narrower than that minimum. Omit the
option to retain fixed columns. Use a separate column region for each logical
row when narrow layouts should read left-to-right, then top-to-bottom.

Use `BeginGrid` for a list of cells that should wrap through intermediate column
counts. `minColumnWidth` is required; `maxColumns` optionally caps the count.
Cells retain their controls and flow left-to-right, then top-to-bottom:

```lua
local grid = root:BeginGrid({ minColumnWidth = 220, maxColumns = 3 })
for _, choice in ipairs(choices) do
    local cell = grid:AddCell()
    cell:AddControl("checkbox", choice)
end
grid:Finish()
```

Each cell is a normal flow supporting nested groups/columns/grids and `SetShown`.
Hidden cells take no space; each row uses its tallest visible cell. Grids fall
back to one column when the available width is below the minimum, and keep equal
cell widths on partial rows. `columnGap` defaults to the canvas style; `rowGap`
adds space between rows beyond their cells' normal control margins (default 0).
`indent` and `marginTop` apply to the region; `Finish({ marginBottom = ... })`
sets its bottom margin and requests layout. Call `Finalize()` after construction;
later additions, visibility changes and resizing reflow without recreating inputs.
Grids require a tracked canvas.

`BeginColumns({ verticalAlign = "center" })` vertically centers shorter flows
beside the tallest column; `"bottom"` aligns their bottoms. The default is
`"top"`. Alignment follows measured content, including wrapping and nested
groups, and does not add space when responsive columns stack.

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
`value`, `width`, `inputWidth`, `snapToStep`, `inputFormatter`, `inputParser`, `suffix`,
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
