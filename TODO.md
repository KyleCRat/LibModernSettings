# TODO

## Planned Controls

These are placeholders only. They are not registered or included in the public
API until a real addon consumer defines their required behavior.

- [ ] Standalone compact numeric input.
- [ ] Multi-line text input with scrolling and a character limit.
- [ ] Color picker with optional alpha support.
- [ ] Radio-button group for small mutually exclusive choice sets.
- [ ] Keybinding capture input with conflict reporting and clearing.
- [ ] Search input with clear-button and change callback behavior.
- [ ] Square tertiary icon button.
- [ ] Multi-select dropdown.
- [ ] Range slider with independently editable minimum and maximum values.

## Compatibility Follow-up

- [ ] Once Interface 120100 is the live minimum, replace the slider tooltip
  script hooks with `Slider:SetTooltipFunc` and `Settings.InitTooltip`. Confirm
  the live template contract before removing the Interface 120007 fallback.

## Validation

- [ ] Exercise the library from a second addon before the first stable release.
- [ ] Test old-first, new-first, and instance-before-upgrade embedded load order.
- [ ] Tag the first reviewed release with unprefixed SemVer and pin consumers to
  that release for packaging.
