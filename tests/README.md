# In-Game Validation

Automated tests cover the library's Lua-only registry, live prototype dispatch,
text-input commit/cancel behavior, button content geometry, and compatible
button and dropdown instance upgrades. They also cover old-first and new-first
mixed LibStub MINOR load order. Validate Blizzard-owned templates and
interaction behavior in game:

- Open, close, and reopen every consuming Settings canvas.
- Click enabled and disabled regular, small, and square buttons. Confirm all
  activate on mouse-up.
- Confirm icon-and-text buttons retain their icon, center the complete content
  group, fit their contents, and vertically center the label. Confirm small
  buttons constrain oversized icons without changing their aspect ratio.
  Confirm default square buttons remain 34px with a centered icon no larger
  than 16px.
- Toggle checked, unchecked, disabled, and disabled-checked checkboxes.
- Open labeled and unlabeled dropdowns, change their selections, resize them,
  disable them, and reopen the canvas.
- Move sliders with the thumb and both steppers.
- Type valid, invalid, below-minimum, and above-maximum slider values. Confirm
  valid out-of-range values remain in the input and SavedVariables while the
  slider thumb stays at the nearest endpoint.
- Confirm formatted suffixes and custom parsers round-trip to stored values.
- Confirm full-width text inputs use the single tertiary background without
  visible joins, keep text inside both ends, commit on Enter and focus loss,
  restore rejected input, and cancel edits on Escape.
- Hover every part of each enabled and disabled input and verify its tooltip.
- Restore defaults and confirm visible values update without firing user-change
  callbacks.
- Reload the UI and confirm SavedVariables-owned values remain synchronized.
