# In-Game Validation

Automated tests cover the library's Lua-only registry and live prototype
dispatch. Validate Blizzard-owned templates and interaction behavior in game:

- Open, close, and reopen every consuming Settings canvas.
- Click enabled and disabled regular and small buttons.
- Toggle checked, unchecked, disabled, and disabled-checked checkboxes.
- Open a dropdown, change its selection, disable it, and reopen the canvas.
- Move sliders with the thumb and both steppers.
- Type valid, invalid, below-minimum, and above-maximum slider values.
- Confirm formatted suffixes and custom parsers round-trip to stored values.
- Hover every part of each enabled and disabled input and verify its tooltip.
- Restore defaults and confirm visible values update without firing user-change
  callbacks.
- Reload the UI and confirm SavedVariables-owned values remain synchronized.
