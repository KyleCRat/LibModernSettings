# Icon-name data

The picker ships a generated filename index from
[wowdev/wow-listfile](https://github.com/wowdev/wow-listfile). It contains only
`Interface/Icons/*.blp` mappings, keyed by numeric FileDataID. It contains no
music, models, texture pixels, item database or addon implementation.
No other icon-browser or media-library addon is required.

## Update

Run this from the library root with PowerShell **7.4 or newer**:

```powershell
pwsh -NoProfile -File ./tools/Update-IconNames.ps1
```

From an AirAuras checkout:

```powershell
pwsh -NoProfile -File ./Libs/LibModernSettings-1.0/tools/Update-IconNames.ps1
```

The script resolves GitHub's latest published listfile release, follows its tag
to a commit, and downloads that commit's `parts/interface.csv`. The upstream
release workflow builds its listfiles from these `parts` files. Reading only the
interface part avoids downloading the entire listfile.

Before generating anything, it verifies the byte count and Git blob hash against
GitHub's commit-specific file metadata. It records a SHA-256 for subsequent
reproduction. Invalid UTF-8, malformed rows, conflicting IDs, an empty extraction
or a hash mismatch fail the import. Latest-release imports also fail if the
release is over 72 hours old; inspect upstream before deliberately overriding
that with `-MaxAgeHours`. There is no fallback to an older extract.

The script updates:

- `IconPicker/NameData.lua`: the runtime index.
- `IconPicker/NameData.source.json`: release date, commit, source hashes and
  extraction count.

It sorts numerically, normalizes path separators, resolves case-only duplicates
deterministically and writes UTF-8 without BOM, LF and a final newline. It does
not record the time of the local run. The same source and library implementation
version produce identical output. Unchanged files are not rewritten. The script
reads the library's current MINOR for its guard; it does not increment versions,
prepare releases, regenerate release notes, commit or publish.

Review the generated diff and run:

```powershell
pwsh -NoProfile -File ./tests/icon_names.ps1
lua tests/run.lua
```

## Reproduce or verify

Use the recorded source instead of moving to the latest release:

```powershell
pwsh -NoProfile -File ./tools/Update-IconNames.ps1 -Pinned
pwsh -NoProfile -File ./tools/Update-IconNames.ps1 -Check
```

`-Check` compares both generated files without writing. Both operations download
the pinned interface file and verify its recorded hashes. For an offline check
against a previously saved copy of that exact file:

```powershell
pwsh -NoProfile -File ./tools/Update-IconNames.ps1 -Check -SourceFile ./interface.csv
```

Pinning is intentional reproduction, so these modes do not impose the latest
release's age limit. They are not a freshness check. Run the default update
command when refreshing the dataset for development or packaging.

## Runtime and data boundaries

WoW uses the bundled snapshot offline. The index augments the client's existing
icon catalogue; it does not add every file from other clients, future builds or
removed content to the browser. Unknown native icons remain browsable and
searchable by file ID. A real client filename is still a fallback, while generic
`FileData ID ...` responses are discarded as names.

The default catalogue also includes Blizzard's eight raid-target markers from
`Interface/TargetingFrame/UI-RaidTargetingIcon_1` through `_8`. `Sources.lua`
resolves those native paths to file IDs and supplies readable labels and search
aliases. They live outside the extracted folder; keep this native metadata
separate from generated files so running the updater cannot remove it.
It also includes the numbered symbols 0–9, file IDs 6033345–6033354, with readable
names and digit aliases. Their `INV_MISC_Number_0` through `_9` filenames are
already in the generated index; the catalogue uses the IDs directly.

Names are stored in sorted blocks of at most 128 entries. Lookups binary-search
the block bounds and decode only a requested block. Decoded names replace that
block's packed text. No texture loading or background work happens because the
data file loaded. Library version guards select a single accepted embed;
compatible upgrades invalidate the default catalogue's cached filenames.

The source is community-maintained filename metadata. Many modern names are
proposed rather than verified original Blizzard paths and can be renamed;
FileDataIDs remain the identity. This does not promise localized item/spell
names, complete coverage or semantic relationships. The picker adds names from
the current character separately.

Future item, spell and encounter datasets should retain their own build/locale
provenance and join through stable IDs. A filename containing a raid name is a
search hint, not evidence that every similarly named item belongs to that raid.
Providers can already attach names, keywords and relationship tags through
`Catalogue:AddIcon`; they need not change the browser or saved selections.
Keep such relationships separate from this filename extraction.

Source attribution is retained in the generated file and manifest. The index
contains factual filename mappings from the upstream listfile; no upstream
scripts or addon code are bundled.
