# Texture picker

`CreateTexturePicker(parent, options)` creates a separate resizable window with
Circles, Shapes, Bars, Alerts, Runes and Atlases tabs, plus manual texture-path,
file-ID or atlas entry. Circles opens first; later openings retain the last tab
for that picker instance. Ring labels such as 10px describe their thickness in
the original 256px artwork, not a fixed screen-space border after scaling.

Unmasked previews retain known file/atlas proportions and native dimensions,
scaling down when needed. Unknown files have no public dimension query; they
use a complete, uncropped square preview. Picking artwork does not change the
consumer's saved display dimensions.

The texture browser has no recent/favorite shelves or search. It shares LMS's
native window, scroll-area, input and action controls. Top categories use
`CreateTab` with LMS's bundled header artwork. Only visible grid entries own
textures. Curated metadata is shared per media directory; the full native atlas
list is collected once, when first requested. Hidden tabs stop geometry updates.

The bundled shapes are unchanged WeakAuras artwork with their own
[GPL-2.0 license and attribution](../Media/Textures/WeakAuras/README.md).
Blizzard artwork is referenced from the game. WeakAuras and LibYvSkins are not
required at runtime.

```lua
local picker = ModernSettings:CreateTexturePicker(UIParent, {
    mediaPath = "Interface\\AddOns\\MyAddon\\Libs\\LibModernSettings-1.0\\Media\\Textures\\",
    iconPickerOptions = { rememberFilters = true },
})
picker:Open({
    addonName = "MyAddon",
    sourceName = "My aura",
    value = currentTexture,
    defaultTexture = "Interface\\Buttons\\WHITE8X8",
    isValid = function()
        return editorStillOwnsThisAura()
    end,
    onApply = function(value)
        saveTexture(value) -- nil means reset to the consumer's default.
    end,
})
```

`mediaPath` is optional and defaults to the selected library implementation's
texture directory. Consumers that persist texture paths should pass their own
shipped LMS texture directory, as above, so removing a different addon cannot
remove their chosen artwork. Both slash styles and an omitted trailing slash
are accepted. The directory must contain the library's bundled media.

Optional `styleCategoryTab(tab, window)` applies presentation to each existing
LMS tab. The picker retains anchors, input behavior, tooltips and selection,
including rejection of invalid pending paths. For LibYvSkins, call
`context:StyleSettingsTab(tab, { geometryRoot = window })`. The same context
can serve editor and picker without adding a mandatory dependency to LMS.

`Open` requires nonempty `addonName` and `sourceName`, plus `onApply`.
`onApply(value)` can reject with `false, message`. Optional `onClose(applied)`
runs once per session. `isValid()` must reflect current editor/profile ownership.
Close immediately when that ownership changes. Combat closes either browser.

`SetValue(value)` updates the draft; `GetValue()` reads the active browser's
draft. `Reset()` clears it to nil, and `Apply()` submits it. `Close()`, Escape
and the window X discard it. No selection writes persistence until Apply.

`SetCategory("circles" | "shapes" | "bars" | "alerts" | "runes" | "atlases")`
changes the texture grid without changing its draft or the selected preview.
It commits a pending path first; invalid input blocks the tab change. It returns
false when closed or in the icon browser. Unknown category IDs raise an error.

`SetBrowser("textures" | "icons")` commits the active path input and transfers
the draft without applying it. Invalid input blocks switching. The Icons tab
uses its own ordinary icon-picker instance, configured by `iconPickerOptions`;
its existing features stay intact. Texture paths, atlas names and icon IDs are
retained even when absent from a browser's catalogue. Cancellation in either
browser cancels the shared session. Merely switching tabs writes no history.

The coordinator owns both frames. It accesses the existing icon browser's frame
and LMS path input only to attach tabs, transfer window position and commit a
pending path before switching; its implementation and callbacks stay unchanged.
