# In-Game Validation

Search-box tests cover native placeholder behavior, custom search/clear textures,
live callbacks, silent values, consumer normalization, disable/re-enable,
keyboard focus and both embed load orders. In game, type, clear with the
tertiary-square X, Tab/Shift+Tab and use Enter/Escape. Check focused empty queries,
disabled controls and current query retention after a compatible library upgrade.
With custom glyphs, verify their centering and text clearance at narrow widths.
Search clear and dropdown action squares must have identical size, inset and
glyph sizing, including after library upgrades and with taller search inputs.

Icon-name extraction tests run with `pwsh -NoProfile -File tests/icon_names.ps1`.
They cover deterministic filtering/order/casing, bounded blocks, invalid inputs,
hash checks, freshness rejection and non-writing verification. The Lua suite
round-trips every generated filename and checks cold searches, fallback labels,
lazy decoding and metadata refresh after a compatible embed upgrade.
Use the [update/check commands](../docs/ICON_DATA.md) to verify the real snapshot.
In game, search for artwork outside the current spellbook, bags and equipment
immediately after reload, including filename keywords and artwork-family filters.

Artwork-filter tests exercise every type against the bundled filename index,
word/compound boundaries, aliases versus filenames, overlapping categories and
compatible metadata upgrades. Picker tests combine source/category/type/search,
preserve history order, reset dependent choices, cancel superseded work and
recover from empty results. Plain Frame mocks omit native enabled-state methods;
picker checks verify the dropdown button and tooltip enable together.
In game, combine Favorites with Equipment and a
weapon type, then search a color. Try Class artwork, Magic themes and Named color
variants. Resize to minimum width/height: both filter rows must align and retain
a usable icon grid. Check keyboard navigation and choice/disabled tooltips.
Click the far right of short choices in both artwork menus: rows must span the
whole interior width and follow the resized input. Dropdown tests model native
input-width defaults, min/max-width layout and
pooled rows for radio, checkbox and texture-preview choices.

Icon-picker tests cover copied history, deduplication, lazy metadata, typo ranking,
cancelled searches, cursor identities, Apply/Reset/Cancel, owner invalidation,
combat closure, simultaneous sessions, retained viewport texture requests and
compatible model upgrades. In game, cold-open near the end of the catalogue,
scroll/resize quickly, and search while changing filters. Real textures must load
for the settled viewport without travelling through earlier rows. Check title,
Close, borders, masked icon art, tooltips, favorite stars and window raising.
Picker checks cover larger button/mask dimensions with unchanged grid centers,
window-width snaps and scrollable height. Fixed button-mask insets also cover
rebinds, resizing and compatible upgrades. In game, compare grid/shelf/preview
artwork and check the first/last rows and columns for clipping.
Use spellbook/action-bar/item/macro/mount/pet drops; unsupported cursors must stay
intact. Accepted drops must clear every filter/search and reveal their artwork,
including new catalogue entries and unfinished searches. The search X must clear
text while retaining other filters. Test history persistence, rejected Apply, pending invalid input, Reset
then Cancel, keyboard focus versus selection, and two consumers at once.
Resize tests cover whole columns, fractional effective scales, continuous height,
minimum dimensions and closure during a drag. In game, resize through column
boundaries at different UI scales, after moving the window, and at minimum size.
Keep the top-left corner fixed and the scrollbar gap consistent. Check normal-size,
right-aligned shelf captions and the count beside the compact footer buttons.
Use the development copy first in load order until preparing a release.

Picker performance checks use a 32,768-icon synthetic native catalogue to verify
deferred opening, bounded batches, shared loading, interruption/resumption,
pending filters/drops and the synchronous catalogue API. History shelf checks cover
placeholders during preparation, empty guidance after loading, stable one-row
heights and reuse across reopening or removing favorites. Instrumented pooled
buttons verify zero texture/metadata/tooltip rewrites for unchanged visible
entries, retained bindings on reacquisition and cached metadata on revisits.
Alternating viewports replace artwork without resizing icons or masks, rebinding
mask textures or setting button fonts. Button tests also cover atlas/texture
size changes, crop reset, consumer tint and fit-to-content relayout.
Reported mock timings are not in-game/GPU measurements. In game, cold-open and
close during loading, then drag the scrollbar back and forth across seen artwork.
Check that chrome appears promptly, the spinner stops, and no stale artwork,
selection or tooltip leaks between pooled rows or editing owners.
Refresh checks count source scans, search starts, history reads and shelf layouts.
Unrelated/already-resolved item completions leave searches running; real changes,
pending names, removals and two concurrent pickers update the correct sources.
Selection and height-only resizing reuse history without relayout; width changes
reuse history while updating shelves. Explicit refresh rereads external storage.
The ScrollBox mock performs the native immediate update on provider replacement,
so extra grid layout passes fail the regression check. In game, move/split bag
stacks while searching, swap equipment, learn/change spells, and check cold item
names, history selection and resizing before closing/reopening the picker.

Native-marker tests cover all eight file IDs, names, `rt1`–`rt8`, color aliases,
symbol filtering, deduplication with macro entries and retained catalogue upgrades.
In game, find exactly Star through Skull under Symbols and interface → Raid markers;
search `raid marker`, `red x`, `rt8` and `137008` with other browser addons disabled.
Apply/favorite Skull, reopen and reload: its name and artwork must stay correct.
Interface icons must exclude `INV_Icon_Feather01e` and
`INV_12PH_Folk_801_Parttion_Pillar_Icon` while retaining `UI_Chat` and faction symbols.
Numbered-symbol tests cover 0–9, exact file-ID ranking, word aliases and Numbers
filter membership. In game, browse Symbols and interface → Numbers, then search
`digit nine` or `6033354` and apply/favorite/reopen.

Default-color tests cover optional sources, explicit initial values, remembered
Custom RGBA, dynamic swatches, preview cancellation, Apply, keyboard selection,
disabled inputs and compatible upgrades. In game, compare an input with Default,
Class and Custom against existing inputs without Default. Switch modes, change
the default source, reopen and rebind: preserve the Custom color and selected
mode. Only Custom opens the picker; switching away discards its draft. Check
tooltips, masked swatches and narrow/wide layouts. For untinted artwork, the
consumer must use the mode rather than tinting with the swatch's sample color.

Input-alignment tests cover side-labeled checkboxes/colors, titled and untitled
dropdowns/sliders, top/left Fields, wrapped titles and descriptions, multi-row
value lists, nested flows, custom alignment points, column breakpoints, visibility,
pending edits and both library load orders. In game, mix these controls with
`verticalAlign = "input"`, then resize and hide/show their neighbors. Centers
must follow the input row; stacked or lone controls must have no extra top gap.
Keep the existing right-side captions and verify clicks, tooltips and Tab focus.
Repeat on hidden pages, at different UI scales and with long descriptions;
controls must not flicker, disappear or lose draft values. Existing top, center
and bottom alignment must retain its behavior.

Compare selected and unselected text buttons at narrow and wide widths: the
button body must keep its size and alignment, with only the glow extending
beyond it. Repeat hover, press, focus, disable/re-enable and UI-scale changes.
Toggle a narrow button between a blank label and NOT from its click callback.
The label must remain centered after mouse release and keyboard activation,
including repeated toggles and a consumer refresh during the click.

Canvas artwork overflow tests cover preserved control widths/insets, asymmetric
and bounded margins, zero margins, resizing, hidden pages, copied options and
compatible upgrades. In game, extend a row background beyond its control bounds
with `contentOverflow` enabled: both edges must remain visible while vertical
scroll clipping, wheel input and scrollbar clearance stay correct.

Nested canvas tests cover `onLayout` timing, copied placement options, responsive
columns, multi-level sections, wrapping Fields, hidden flows, delayed native size
notifications, immediate bookmark restoration and both library load orders.
In game, use the callback to size nested sections, then rebind/show the page and
call `RefreshLayout()` after restoring a bookmark. The content must update in place
without blanking or moving through intermediate positions. Try rapid selections,
narrow/wide widths, hidden-page updates, tab changes and closure. Retain draft text,
keyboard focus and normal wheel/scrollbar input.
Child size notifications must request the parent layout, never resize ancestors
inside the callback. Cold-open expanded nested sections with sliders and labels;
all controls must render before any manual resize.

Canvas bookmark tests cover matching between independent forms, live expansion
priority, visual-order fallbacks, missing/hidden/reparented sections, page-top
preservation, hidden destinations, rapid captures before reflow, replaced/pooled
frames, unregistration, copied options, frame-free bookmarks, invalid inputs and
both library load orders. In game, register equivalent sections on two forms with
different content heights. Capture/restore while swapping records and show/hide
sections above the current one: keep the current section in view. Replace a
section's frame under its key and remove/re-register it. Repeat through narrow/wide
layouts and different UI scales; opening/closing headings and manual scrolling
must remain consumer-controlled. Use AirAuras's Display navigation checklist for
the integrated example, including icons, bars and group defaults.

Canvas scroll-anchor tests cover deferred height changes above a section, collapsed
anchors, negative offsets, rapid replacement, native clamping, manual scrolling,
focus reveals, hidden pages, scaled children, invalid arguments and retained
instances across compatible upgrades. In game, anchor an open section while
rebinding shorter/taller content above it, including nested canvases. Its viewport
position must remain stable; wheel/scrollbar navigation and Tab focus must take
over immediately without a later reflow pulling the page back.

Slider precision tests cover `snapToStep = false`, typed/programmatic fractions,
out-of-range values, keyboard/wheel increments, named values, invalid options
and unchanged default snapping. In game, retain a fractional position captured
by dragging, then focus/blur its slider and use arrows/wheel. The fraction must
survive; the native track and steppers still use their configured step. Compare
ordinary sliders in other consumers to confirm their existing snapping remains.

Value-list tests cover numeric/text parsing, formatting, copied arrays, blank
drafts, Enter/add/remove, field limits, invalid edits, deferred commits, rebinding,
hide/disable cleanup, wrapped Tab order, row breakpoints and compatible upgrades.
Canvas tests cover growing/shrinking Fields, following controls, hidden-page
resizing, retained drafts and deferred size notifications through nested sections.
Measurement-triggered notifications must not resize the parent Field inside its
child's callback. Repeated row-count changes, rapid add/remove and rebinding must
retain label anchors and settle at the latest height without a window resize.
Focus reveals coalesce and cancel after rebinding or hiding. In game, use Enter
and + to wrap onto a second and third row without resizing first, including in
fields taller than the viewport. Remove values back to one row: the label and
pills must remain visible. Then resize through one/two/three rows: keep
the pills together as one input, with actions after the last pill and no overlap
below. Enter/Tab must reveal each focused pill; the mouse wheel must scroll the
page. Invalid input must retain Enter/Tab focus; switching consumers or closing
must not save a stale draft.

Texture-preview tests cover paths/file IDs, live choice updates, absent previews,
disabled choices, narrow inputs, explicit menu widths, mouse/keyboard picks,
consumer normalization, recycled rows, multi-select summaries and compatible
upgrades. In game, open a long bar-texture list and compare previews with the
chosen texture. Scroll, change selection, resize and reopen: outlined names must
remain readable over full-width previews, with selection marks and caret clear.
The closed selection must stay centered within the visible recessed border,
including the atlas's uneven transparent padding.
Check explicit menu widths on wide inputs. Plain choices must restore normal
fonts and never inherit another row's preview.
Native attachment cleanup follows Retail 12.1.5.70391's Blizzard_Menu compositor.

Grid tests cover exact column breakpoints, partial rows, unequal cell heights,
nested visibility, hidden-page resizing, late additions, pending edits, scroll
position, Tab order and retained instances across library upgrades. In game,
resize a checkbox grid through one/two/three columns and check label wrapping,
keyboard order and custom headers using `fillWidth`.

Multi-select dropdown tests cover copied sets, mouse/keyboard toggles, disabled
choices, decorators, scrolling to focus, boundaries, pooled-row highlights,
consumer normalization during picks, empty menus and live upgrades. In game,
verify checks stay open, arrows move only focus, Enter/Space toggles once,
mouse leave retains keyboard focus, and Escape/Tab return input focus normally.
Check `placeholder` and `selectionText` summaries, resize/rebind/hide controls,
and compare existing single-select dropdowns in mixed consumers.

Grouped-dropdown tests cover headings/dividers, disabled saved selections,
tooltips, menu regeneration and keyboard navigation across groups. In game,
hover enabled/disabled choices, navigate long grouped lists with Up/Down, and
confirm with Enter/Space: tooltips must follow their rows, decorators must be
skipped, selected rows must stay in view, and Tab focus must remain on the input.

Color preview tests cover draft callbacks, duplicate suppression, RGB/RGBA,
Apply ordering, all cancellation paths, owner rebinding and callback replacement.
In game, enable `onPreview`, drag hue/saturation/opacity, edit hex/channels and
choose swatches: the consumer must preview without saving. Cancel/X/Escape,
hide/disable/rebind the input or open another picker: restore the saved color.
Apply must save once, add one recent color and preserve keyboard navigation.

Scroll-area tests cover legacy canvas spacing, inset/compact presets, independent
border overrides, header alignment, native lists, resizing, invalid geometry,
and retained native widgets across library upgrades. Wheel tests cover full-pane
coverage, native handler forwarding, initialization, nested owners and upgrades.
In game, scroll in every margin and the scrollbar gap on long/short panes and
at both scroll limits: game wheel bindings must not fire. Verify focused slider
stepping, nested panes, scrollbar dragging and parent click/drag handling.
Compare both LibChangelog panes with their approved spacing, scroll long notes, resize a
native list, and check existing settings pages with no `scrollArea` option.

Automated tests cover the library's Lua-only registry, live prototype dispatch,
text-input commit/cancel behavior, focus retention after rejected Enter/Tab edits,
mouse-safe focus-loss commits, field
composition, button content geometry, and compatible button and dropdown
instance upgrades, including focus-state upgrades for live text inputs and
sliders. Old-first and new-first mixed LibStub MINOR load orders are covered as
well, alongside content-sized controls, Field descriptions, canvas reflows,
retained appearance overrides, and duplicate-module initialization.
Responsive canvas tests cover resizing, stacked and conditional columns,
unchanged-size coalescing, hidden-page updates, nested visibility and retained
control identity, values and pending text edits. Vertical column alignment is
checked across changing heights, nested groups, hiding and responsive stacking.
Resize regressions include retained anchors in headers, inputs and the native
scroll target, scroll-position preservation/clamping, hidden-page return,
content-sized section heights, and upgrades of existing native canvas views.
Full-width group tests cover immediate construction widths, nested groups/columns, margins, visibility,
dynamic content heights, additions to finalized canvases and compatible upgrades.
Navigation tests cover focused input, modifier combinations and precedence,
typed values outside the track range, selection boundaries, menu regeneration
with reused rows, selection visibility, viewport retention, native wheel scrolling,
and keyboard release during combat or text entry.
Tab tests also cover forward/reverse wrapping, hidden and disabled fields,
responsive visual order, offscreen focus, grouped windows, commit-driven changes,
dropdown transitions and compatible upgrades. Dropdown tests also cover closed
focus, explicit opening, focus transfer before the native menu hides, and outside
clicks in either callback order. Button navigation covers hover focus, Enter/Space
activation for each variant, callbacks, nested controls, focus release and combat
suspension; tall-section tests cover revealing the focused control.
Navigation contract tests register independent composite and native-edit control
types. They cover existing/new instances, shared action context, descriptor and
prototype updates, rejected releases, invalid registrations and single hook
installation without changing the traversal or keyboard handlers.
Color tests cover conversion, alpha-aware history, palette ownership and limits,
class/accent/custom modes, saved Custom colors across callback refreshes and new
instances, RGB hex with independent opacity and RGBA import, staged commits, invalid edits, cancellation,
owner replacement, focus restoration after failed mouse Apply, continued Tab
navigation, RGB/RGBA visibility and compatible upgrades.
Preset tests exclude non-playable class tokens, verify item-quality colors and
opacity preservation, and check favorites resizing only at row boundaries.
Flash-message tests cover states, ordering, duplicate renewal, expiration,
hover pause/resume during the hold and fade, close-button hover,
manual dismissal, frame reuse, owner isolation, screen-edge fallback, scaled
placement and lifecycle cleanup without affecting picker size or input focus.
Picker feedback keeps its lifetime through Tab, valid submissions, color
changes and palette refreshes.
Validate Blizzard-owned templates and interaction behavior in game:

- Check selected regular, small, and square buttons with mouse hover, keyboard
  focus, pressing, disabling/re-enabling, and changing the selected entry. Native
  selected artwork should persist until the consumer clears selection. With
  1.8.0 and 1.9.0 embeds enabled together, confirm the selection API is available
  regardless of load order, including on buttons created before the upgrade.
- Attach flash stacks to a window and a group inside a scroll frame. Show success,
  info and error messages, including wrapped text. Verify the neutral Blizzard
  metal border, dark green/blue/red backgrounds and lighter matching text. Corners
  must join cleanly in compact rows, and text and X must sit centered inside the
  border with equal left/right margins. Check short messages after wrapped ones:
  the middle side edges must return only when there is room between the corners.
  Verify newest-last ordering, six-second hold followed by fading, and immediate X
  dismissal without losing edit-box focus. Hover the message body and its X:
  that message's hold or fade must pause while other timers continue. Leave it
  to resume its remaining time; dismiss it or hide its owner while paused.
  Repeat a message and exceed the stack
  limit; duplicates must renew, and oldest messages must be replaced. Move,
  resize and scale the owner near screen edges: the stack belongs below it when
  it fits and directly above the owner otherwise, without scroll clipping.
  Above-frame stacks must keep their newest message closest to the frame as
  messages are added or dismissed; moving the owner must move the stack with it.
  Hide the owner or its parent while messages are visible, then reopen it: old
  messages must not return. Check simultaneous stacks on separate windows.
- Open RGB and RGBA color inputs. Drag the hue strip and saturation/brightness
  square, enter hex and channel values, and adjust opacity. Check new/previous
  swatches, Apply versus Cancel/X/Escape, class/item-quality colors, right-click favorites,
  recent ordering and persistence through the consumer's storage adapter.
  Class/accent shortcuts must stay selected until another mode is chosen without
  changing the Custom swatch. Custom must restore its previous color, including
  opacity, after switching modes or reloading; canceling edits keeps that color
  selected. Hex must remain six RGB digits when opacity changes. Six-digit edits
  preserve opacity; eight-digit RRGGBBAA imports it and returns to six digits on
  commit. Test both with/without #, zero alpha, rejected seven-digit input, and
  RGB-only inputs discarding imported alpha. Swatches must have no checkerboard;
  masked fills must fit the bevel in normal, hover and selected states on inputs,
  samples and compact palettes. Check the compact
  Favorites, Recent, Class and Quality rows: labels sit close to aligned swatches,
  row gaps match swatch gaps, and there is no divider. Check action buttons beneath
  the right-hand inputs. Invalid fields must show external flash messages without
  changing the picker's size or scale. Change fields, submit valid values, adjust
  opacity and choose swatches: existing messages must keep their original timer
  until fading or manual dismissal. Closing the picker clears them.
  Reject hex/channel edits with Enter, Tab, Shift+Tab and mouse Apply: the invalid
  field must stay focused or regain focus, and subsequent Tab navigation must work.
  Clicking another input must preserve the newly selected input's focus.
  Check favorites empty, with one color, with a full first row and with one extra:
  only the extra color should add height. Tab through
  all quick choices and the picker; close it and continue forward/backward in the
  original form. Hide, disable, rebind or replace the owning input while editing.
  Test small screens and UI scales with filled palette rows.
- Open, close, and reopen every consuming Settings canvas.
- Tab and Shift+Tab through text inputs, slider values, dropdowns, checkboxes and
  expandable headers, plus regular, small and square buttons. Verify wrapping,
  committed edits, selection highlighting and scrolling newly focused fields into
  view. Dropdowns must stay closed on focus, open with Enter/Space, retain arrow
  navigation and close on Tab without passing Tab to game bindings. Hide or disable fields,
  stack responsive columns, and repeat with a pending edit or rejected commit.
  Confirm hidden pages and separate windows stay outside the focus cycle.
- Activate focused buttons, checkboxes and headers with Enter and Space, checking one
  callback per press, retained hover highlights and no chat/jump action. Tab into
  an expanded section and skip its controls after collapsing it. Check Advanced
  toggles remain independently reachable. Click elsewhere, focus an edit box,
  hide/disable the control, close the page or press Escape to release focus.
  Enter combat and verify keys pass through; repeat after leaving combat.
- Click enabled and disabled regular, small, and square buttons. Confirm all
  activate on mouse-up.
- Confirm icon-and-text buttons retain their icon, center the complete content
  group, fit their contents, and vertically center the label. Confirm small
  buttons constrain oversized icons without changing their aspect ratio.
  Confirm default square buttons remain 34px with a centered icon no larger
  than 16px.
- Toggle checked, unchecked, disabled, and disabled-checked checkboxes.
- Open labeled and unlabeled dropdowns, including asymmetric and flush-inset
  dropdowns; change their selections, resize them, disable them, and reopen the
  canvas. Open a dropdown with enough choices to exceed the screen height and
  confirm it caps near three quarters of the UI, scrolls to the final choice,
  remains vertically centered, and remains usable at 4K and common UI scales.
- Move sliders with the thumb and both steppers.
- Align dropdowns beside regular/square tertiary buttons and text inputs.
  Check the 34px recessed body, inset square caret, centered selection text and
  long-text tooltip. Only the caret presses down. The body uses text-input focus
  glow while focused/open, with no glow for mouse hover alone; losing focus while
  hovered must clear it. Check disabled states. Click both text and caret:
  each must open/close the same menu once and be one Tab stop. Recheck controls
  created before a compatible library upgrade.
- Select a slider by clicking its track, a stepper or numeric field. Wheel
  over each part and press Up/Down: each action must change one step, including
  decimal/suffixed values and pending text. Hold Shift while scrolling for ten
  steps or Ctrl for fifty in either direction. Hold both and confirm Ctrl wins;
  release Ctrl to return to ten steps, then Shift to return to one. Confirm
  consumer limits still apply. Click elsewhere and confirm the wheel scrolls
  the page again. Disabled controls must ignore navigation.
- In short and scrolling dropdown menus, use Up/Down repeatedly. Each press
  selects the adjacent choice, keeps it visible, and stops at either boundary.
  Wheel-scroll tall menus without changing selection, then resume arrow keys.
  Rows must remain ordered and evenly spaced after callbacks update values or
  rebuild choices; an already-visible selection must not reset the viewport.
  Press Enter or Space after arrow navigation: confirm the current value, close the menu,
  and keep focus on the input without firing a duplicate change callback or opening
  chat. Tab and Shift+Tab must still move on; Enter/Space must reopen the menu.
  Also test both keys without arrow navigation and with an empty list. Click a
  choice or press Escape to close; Escape on the closed input must release focus.
  Test long/short list transitions, reopening, and wheel behavior
  in an unrelated Blizzard menu.
- With a dropdown open, enter combat and verify keys pass through normally;
  leave combat and resume selection. Open a text input/chat while the menu is
  open and confirm it retains its arrow keys, Enter and typed spaces. Hide or disable the owning
  control and confirm the menu closes and keyboard capture ends.
- Type valid, invalid, below-minimum, and above-maximum slider values. Confirm
  valid out-of-range values remain in the input and SavedVariables while the
  slider thumb stays at the nearest endpoint.
- Confirm formatted suffixes and custom parsers round-trip to stored values.
- Give sliders named values such as `[-1] = "Inherit"` or `[0] = "Auto"`.
  Check complete label display, typed names/numbers, thumb/stepper changes,
  Up/Down, Shift/Ctrl-wheel, and Enter/Tab/focus-loss commits. The first numeric
  step must follow the named endpoint; labels omit numeric suffixes. Invalid
  input must restore the previous value. Verify old sliders without labels and
  consumer bounds still behave as before, including out-of-track numeric values.
- Confirm full-width text inputs use the single tertiary background without
  visible joins, keep text inside both ends, commit on Enter and focus loss,
  restore rejected input, and cancel edits on Escape. While editing, click LMS
  action buttons and non-LMS click targets once; confirm the edit commits and
  the target action still occurs on that first click.
- Confirm stacked and inline fields align their labels consistently, give the
  wrapped control the remaining width, and disable the label and control as one
  field without changing the primitive's normal behavior.
- Compare stacked Fields with built-in dropdown/slider labels, and verify
  unlabeled controls have no label space. Check the default 4px sibling gap,
  zero dropdown side insets, larger H1/H2 headings, and explicit overrides.
- Resize Fields with descriptions through single-line and wrapped layouts;
  change, clear, and restore descriptions while the canvas is visible and
  hidden. Confirm only the affected canvas reflows and input text remains visible.
- Resize canvas viewports through the minimum column width while scrolled to
  the top, middle and bottom. Hide/show individual flows and entire rows,
  including nested groups and columns; check full-width groups fit from the
  first opening, remaining controls fill the width and hidden groups leave no space.
  Repeat with pending edits, checked controls, long labels and hidden canvases.
- Open a Settings subcategory directly from its addon button on a cold login;
  confirm dropdown selection text and arrows appear without switching pages.
- Load old and new embeds in both orders. Confirm controls created by 1.7.0
  or later adopt compatible visual defaults without losing values or focus,
  while pre-metadata layouts and explicit consumer overrides remain preserved.
- Hover every part of each enabled and disabled input and verify its tooltip.
- Restore defaults and confirm visible values update without firing user-change
  callbacks.
- Reload the UI and confirm SavedVariables-owned values remain synchronized.
