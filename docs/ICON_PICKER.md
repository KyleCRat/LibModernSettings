# Icon picker

The picker owns browsing and draft selection. Consumers own persistence, default
artwork and the meaning of Apply. It uses native window chrome and LMS controls;
it does not require LibYvSkins, IconBrowser, or a native macro window.

```lua
local LMS = LibStub("LibModernSettings-1.0")
local history = LMS:CreateIconHistory({
    get = function()
        return MyAccountSettings.icons
    end,
    set = function(value)
        MyAccountSettings.icons = value
    end,
})
local picker = LMS:CreateIconPicker(UIParent, { history = history })

picker:Open({
    addonName = "MyAddon",
    sourceName = "Selected aura",
    value = currentTexture, -- positive file ID, texture path, or nil
    defaultIcon = sourceTexture,
    suggestedIcons = { { texture = sourceTexture, name = sourceName } },
    isValid = function()
        return selectedID == editedID and currentProfile == editedProfile
    end,
    onApply = function(value)
        SaveTexture(editedID, value) -- nil means use the consumer's default
        return true
    end,
})
```

Create and retain a picker per editing owner outside combat. Multiple instances have separate windows and
sessions; the default catalogue is shared. Clicking a window raises it normally.
Creation options `searchIconTexture` and `clearIconTexture` customize the shared
search control's glyphs using file IDs or texture paths. Omit them to use LMS's
bundled search and clear artwork, without a skin-library dependency.
`caretIconTexture` overrides the three filter dropdowns' caret. AirAuras passes
YvSkins assets for these glyphs so their ownership stays with its skin library.
Horizontal resizing snaps to whole icon columns; vertical resizing is continuous.
The grid uses an explicit native stride to avoid losing a column to fractional
frame measurements at different UI scales. Resize work runs only during a gesture.
Call `Close()` immediately when selection/profile ownership changes or its editor
closes. `isValid` is also checked before work and actions; it is not polled while
idle. The picker closes and discards its draft at combat entry and refuses to open
in combat.

## Session and history

`Open` requires non-empty `addonName`, `sourceName`, and an `onApply(value)`
callback. Optional `onClose(applied)` runs once when that session ends.
`onApply` may return `false, message` to keep the session open without saving
history; other returns accept the value. Reentrant callbacks may replace or
close the session without closing a newer one.

`value` accepts a positive integer file ID, a texture path, or nil/empty text for
automatic artwork. Numeric strings are normalized. `defaultIcon` previews the
automatic value, falling back to the question mark; optional `defaultIconColor`
is an RGB/RGBA array for that preview only. Consumers must supply public values.
The library cannot validate whether an arbitrary path actually contains artwork.

`SetValue(value)` changes only the draft. `GetValue()` reads it. `Reset()` clears
it to nil and still requires Apply; `Close()`, X and Escape discard it. Selecting
an icon or accepting a drag does not commit automatically. Left-click selects;
right-click toggles a favorite. Tab/Enter/Space use normal LMS navigation;
keyboard focus and persistent selection remain separate.

`CreateIconHistory({ get, set, maxRecent, maxFavorites })` uses copied
`{ recent = { texture, ... }, favorites = { texture, ... } }` arrays. Both storage
callbacks must be supplied together, or omitted for memory-only history.
Limits default to 30 recent and 120 favorite entries. `GetIcons(kind)` returns a
copy; `Record(icon)` moves it to the front of recents; `ToggleFavorite(icon)`
returns its new membership or `nil, message` if the favorite limit is reached.
Reset does not add a recent icon. Only accepted Apply records a selection;
favorite changes persist immediately, independently of Cancel.

Persist one history in account settings to share it across profiles. Separate
history objects let consumers choose isolation rather than sharing hidden
library-owned SavedVariables.
The picker reads a history snapshot on opening and after edits, reusing it for
selection and shelf resizing. Shared history-object edits are noticed on the next
picker update. Call `picker:Refresh()` after changing its backing storage directly;
idle pickers do not poll storage.

## Catalogue and search

`GetIconCatalogue()` lazily caches the deduplicated native spell/item artwork and
raid-target markers for the session. Markers have readable names, color aliases
and `rt1`–`rt8` keywords, and appear under Symbols and interface → Raid markers.
That type matches only file IDs 137001–137008, excluding weapons, ammunition,
poisons and unrelated targeting artwork.
Numbers 0–9 (file IDs 6033345–6033354) appear under Symbols and interface → Numbers,
with digit names as search aliases.
A bundled, generated icon-name index supplies filename search even
before the player encounters the related items/spells. Current spellbook and carried/equipped item metadata adds useful
names and ID aliases when a default picker opens. Public metadata events refresh
those shortcuts while it remains open; bank contents are not scanned.
Spellbook, equipment and bag changes refresh their respective sources, coalesced
per catalogue across open pickers. Item-info completions retry only known pending
artwork/names. Unchanged scans preserve current results and in-progress searches.
See [icon data and its update script](ICON_DATA.md) for source provenance,
reproducible updates and the boundary for future relationship datasets.

Create a private catalogue with
`CreateIconCatalogue({ icons = entries, getFilename = function(fileID) ... end })`.
Pass it to `CreateIconPicker` as `catalogue`. Private catalogues omit automatic
player metadata unless `includePlayerIcons = true`; the shared default includes
it unless explicitly disabled. History and default/suggested artwork can still
add entries to a private catalogue.

Each entry supplied to `AddIcon` / `AddIcons` contains:

```lua
{
    texture = 123456,
    name = "Readable display name",
    filename = "Interface\\Icons\\INV_Example", -- optional known filename
    keywords = "additional searchable words and identifiers",
    tags = { "encounter:example", "raid" },
}
```

Artwork is deduplicated by file ID or case-insensitive normalized path. Metadata
from different sources accumulates aliases/tags on that artwork. Native legacy
filenames resolve to file IDs before insertion while retaining the filename.
An explicit `filename` takes precedence over the catalogue's filename provider.
Arbitrary consumer paths are
not implicitly resolved against the filesystem. `suggestedIcons` uses the same
entry format but scopes the Suggested filter to the current session.

`CreateIconPicker(parent, options)` accepts `extraFilters` to append source-dropdown
records with unique string `value`,
`label`, optional `tooltip`, and `match(entry, catalogue)`; title/divider records
use the ordinary dropdown format. Inspect `entry.tags` for associations supplied
by your provider. Add metadata, then call `picker:Refresh()` to re-evaluate the
current query while retaining its visible artwork where possible.

All query words must match available file IDs, filenames, names or keywords.
Substring matches rank ahead of one-character spelling errors/transpositions;
short words require substring matches. Search is not semantic: a raid name finds
related artwork only if filenames or a provider supply that association.
The generated snapshot contains community filenames, not localized spell/item
names or a complete relationship database. File metadata may be absent, and filenames/keyword families are often English;
localized spell/item names are available for the player's discovered entries.

### Filters

Source, artwork category, type and search combine: for example, choose Favorites,
Equipment and Daggers and knives, then search `red`. A category includes all its
types until narrowed. Filter menus use ordinary responsive LMS dropdown sizing.
Search uses `CreateSearchBox` with its tertiary-square clear button.
Changing category resets only the type. The search X clears
only search text, keeping source/category/type choices. Reopening resets all
filters and search by default. Pass `rememberFilters = true` to `CreateIconPicker`
to retain them between openings of that instance, including after Apply or Cancel.
This is memory-only, independent of icon history, and ends on reload/logout.
Each opening still uses the current owner's icon, suggestions and metadata.
Accepting a cursor drop always clears all filters and search and reveals its selected artwork,
adding it to the catalogue when necessary. History order is retained when no
search text is entered.
Interface icons requires a `UI` filename prefix; the generic word `Icon` in
inventory or decoration filenames is not evidence of interface artwork.

Artwork filters use filename words, including words joined with capital letters
or numbers, independently of the player's discovered spell/item names. This
recognizes modern names such as `RaidEvoker` and `PrimalMount` without matching
`ore` inside `core` or `ice` inside `justice`. Categories may overlap; they are
browsing aids rather than authoritative item classifications. Class artwork
includes named equipment and symbols, magic themes do not establish damage school,
and named colors do not inspect the image. Use My spellbook for the character's
known spell artwork. Unknown filenames remain available without an artwork filter.

`IconPicker/Filters.lua` owns category/type labels, explanations and filename
matchers together. Filters do not infer expansion, raid loot, equippability or
ownership from those names. Providers with actual relationships can attach tags
and supply `extraFilters`; those still combine with the standard artwork filters.

`BeginSearch(query, filter, entries)` also exposes the non-UI search job.
`Step(positiveInteger)` examines at most that many entries and returns true on
completion; `results` then holds the ordered entry references. `Cancel()` stops
the job. Catalogue entries and job results are read-only to consumers; use
`AddIcon` to attach metadata and invalidate cached search text correctly.
`AddIcon` returns the entry and a boolean indicating whether its metadata changed;
repeating identical metadata keeps the normalized search cache.

## Loading and extension boundary

The browser uses native virtualized grid frames and pooled LMS buttons. Rebinding
and selected-icon scrolling finish before visible textures are assigned, with
scroll interpolation disabled for those jumps. It does not queue textures from
earlier catalogue rows or preload every asset.

`Open()` shows the window and loading spinner before preparing results. Input,
filters and cursor drops remain usable during preparation; the latest draft and
query win. Recent/Favorites each reserve one icon row with a non-interactive empty
frame while loading or empty; populating the row does not resize the window.
Native catalogue reads happen on separate updates, with normalization
and deduplication split into bounded batches under a three-millisecond target.
The native read itself cannot be subdivided. Simultaneous default pickers share
this work. Closing all pickers pauses an unfinished build; the next opening
resumes it. Completed catalogues are reused until reload. The public
`GetIconCatalogue()` method remains synchronous and completes any shared build;
consumers do not need to call it before opening a default picker.

Pooled buttons keep their texture references when released, and rebind only
changed artwork, selection, favorites and tooltip data. Artwork swaps reuse the
prepared button dimensions, masks and fonts. Seen icons retain their
decoded metadata and tooltip definitions even after their grid frame is reused.
This is not a permanent GPU cache of every viewed texture: a reused frame must
replace its previous artwork, and Blizzard controls texture streaming and
residency. Blocking texture loads are deliberately avoided because they can stall
the client. Search work is sliced, cancelled when superseded, and stopped on
closure. Idle windows have no update loop.

`GetCursorIcon()` reads public item, spell, pet-action, macro, mount, battle-pet,
equipment-set and outfit cursor artwork without consuming it. The picker clears
the cursor only after accepting supported artwork. This does not move inventory,
change action slots, edit macros or cast spells; unsupported cursor types remain
untouched.

A future AirIcons addon can own native-picker hooks and pass their draft/commit
callbacks into this same browser. That integration does not belong in LMS.
Rich metadata providers can add encounter, loot and spell relationships without
replacing its search, history or presentation.

The Retail 12.1.5.70448 export exposes journal encounters and creature portraits
through `C_EncounterJournal.GetEncountersOnMap` and `EJ_GetCreatureInfo`.
They do not directly provide a complete icon-to-raid relationship index or an
unambiguous current-season preset. A future provider should resolve those
relationships without silently changing the user's selected journal tier.
The initial browser does not ship manually maintained boss IDs or such presets.
