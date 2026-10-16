# In-Game Validation

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
