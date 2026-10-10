# In-Game Validation

Automated tests cover the library's Lua-only registry, live prototype dispatch,
text-input commit/cancel behavior, mouse-safe focus-loss commits, field
composition, button content geometry, and compatible button and dropdown
instance upgrades, including focus-state upgrades for live text inputs and
sliders. Old-first and new-first mixed LibStub MINOR load orders are covered as
well, alongside content-sized controls, Field descriptions, canvas reflows,
retained appearance overrides, and duplicate-module initialization.
Responsive canvas tests cover resizing, stacked and conditional columns,
unchanged-size coalescing, hidden-page updates, nested visibility and retained
control identity, values and pending text edits.
Navigation tests cover focused input, modifier combinations and precedence,
typed values outside the track range, selection boundaries, menu regeneration
with reused rows, selection visibility, viewport retention, native wheel scrolling,
and keyboard release during combat or text entry.
Validate Blizzard-owned templates and interaction behavior in game:

- Open, close, and reopen every consuming Settings canvas.
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
  Press Enter after arrow navigation: confirm the current value, close the menu,
  and keep chat closed without firing a duplicate change callback. Also test
  Enter without arrow navigation and with an empty list. Click a choice or press
  Escape to close. Test long/short list transitions, reopening, and wheel behavior
  in an unrelated Blizzard menu.
- With a dropdown open, enter combat and verify keys pass through normally;
  leave combat and resume selection. Open a text input/chat while the menu is
  open and confirm it retains its arrow keys and Enter. Hide or disable the owning
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
  the bottom. Hide/show individual flows and entire rows, including nested
  columns; check remaining controls fill the width and scroll ranges shrink.
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
