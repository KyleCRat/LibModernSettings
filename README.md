# LibModernSettings

LibModernSettings provides consistent modern controls for custom World of
Warcraft Settings canvas pages. It owns control construction, Blizzard art,
value synchronization, and enabled or disabled tooltip behavior. The consuming
addon continues to own SavedVariables, category registration, page layout, and
runtime callbacks.

## Embedding

Load LibStub before `embed.xml`, then acquire the library with:

```lua
local ModernSettings = LibStub("LibModernSettings-1.0")
```

## Controls

Every control uses an options table:

- `CreateButton(parent, options)` creates regular or small tertiary buttons.
  Use `text`, `width`, `height`, `variant`, `tooltip`, and `onClick`.
- `CreateCheckbox(parent, options)` creates a 34px tertiary-square checkbox.
  Use `label`, `width`, `value`, `tooltip`, and `onChanged`.
- `CreateDropdown(parent, options)` creates a `WowStyle1DropdownTemplate`
  selector. Use `label`, `width`, `value`, `choices` or `getChoices`,
  `tooltip`, and `onChanged`.
- `CreateSlider(parent, options)` creates a stepped slider with an editable
  compact value field. Its numeric options are described below.
- `CreateText(parent, options)` creates consistently aligned canvas text.
- `SetTooltip(frame, options)` attaches a dynamic tooltip to any frame.

Implemented inputs live in separate files under `Controls/`. See `TODO.md` for
planned control types that are intentionally not part of the public API yet.

Controls expose `SetValue`, `GetValue`, and `SetControlEnabled` where those
operations apply. `SetControlEnabled(false, reason)` disables the complete
input and shows `reason` from every registered tooltip target. Re-enabling the
control restores its normal tooltip.

## Extending the Library

Additional control types register a factory and a method prototype:

```lua
ModernSettings:RegisterControlType("example", factory, methods)
local control = ModernSettings:CreateControl("example", parent, options)
```

Method dispatch remains connected to the library's persistent prototypes, so
existing controls receive compatible method updates when a newer LibStub MINOR
of the same API family loads.

Custom controls should keep persistence and addon-specific callbacks in their
consumer. Register only reusable construction and control behavior with the
library.

## Slider Options

Sliders require `minValue`, `maxValue`, and `step`. Common optional fields are
`value`, `width`, `inputWidth`, `inputFormatter`, `inputParser`, `suffix`,
`tooltip`, and `onChanged`. Format suffixes into the displayed value, such as
`20s` or `100%`. Supply `inputParser` when displayed values use a different
scale from stored values.

## Testing

Run `lua tests/run.lua` from the library root to validate the registry and live
prototype dispatch under Lua 5.1. Blizzard frame templates require the game
client; use the checklist in `tests/README.md` for control validation.
