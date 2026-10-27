# Changelog

## [1.11.0] - 2026-10-27

### Added

- `SetOnInteraction(control, callback)` observes mouse activation, keyboard focus
  and color-picker opening, including compound controls. Value refreshes remain
  silent; consumers can coordinate editing previews without replacing input scripts.
- Dropdowns accept `menuDirection = "up"` or `"down"` for their preferred opening
  direction. Long menus retain the normal height limit and screen centering.
- Reusable resizable icon picker with masked tertiary-square icons, recent and
  favorite history adapters, native cursor drops, Apply/Reset/Cancel and explicit
  consumer ownership. Share a deduplicated catalogue, search a bundled icon-name
  index and known spell/item names with typo tolerance, and extend metadata/filters without
  replacing the browser. Open before preparing the catalogue, with loading
  feedback and shared incremental work. Retain pooled textures and cached
  tooltips, update changed artwork only, and settle selection before requesting
  textures. Cancel superseded searches and stop work when closed or idle. Drops clear filters and
  reveal the artwork. Use shared search controls, responsive filter menus,
  whole-column resizing, right-aligned shelf captions, a clean header without
  decorative streaks and a compact footer.
  Recent/Favorites reserve an icon row with empty frames while loading or empty.
  Coalesce source-specific player metadata scans across open pickers and preserve
  searches when nothing changes. Cache history separately from shelf layout and
  selection painting; use native provider updates without redundant layout passes.
  Larger icon buttons expose more artwork with tighter gaps while preserving
  grid spacing, window widths and scrolling.
- Square buttons accept `iconMaskInset` for a fixed artwork clipping inset,
  retained across icon changes, resizing and compatible library upgrades.
- Add `CreateSearchBox` / `searchBox` with a tertiary-square clear button,
  configurable search/clear textures, live change callbacks, native placeholders
  and standard LMS focus, enabled-state and keyboard navigation. Clear buttons
  match dropdown action squares in size, inset and glyph sizing.
  Programmatic `SetValue` is silent; icon pickers accept the same artwork options.
- Combine source, artwork category and type filters with search. Browse equipment
  slots, consumables, professions, classes, magic themes and named color variants
  from filename words, without depending on session-cached spell/item names.
  Type choices enable after selecting an artwork category. Native raid-target
  markers include readable names, color aliases and `rt1`–`rt8` search terms.
  Raid markers matches only those eight IDs; Interface icons requires a UI
  filename prefix. Symbols also includes a Numbers type with the 0–9 artwork.
  Pickers can opt into `rememberFilters` to retain filters and search between
  openings in memory; separate instances stay independent and drops still clear them.
- Generate the compact icon-name index from wowdev's latest listfile with a
  standalone PowerShell updater, pinned provenance, verified input and
  reproducible output. Decode names on demand without a media-library dependency.
- Color inputs accept an optional `defaultColor` source and explicit Default
  mode alongside Class, Accent and Custom. Preserve the remembered Custom color;
  consumers decide whether Default restores native artwork or a baseline color.
- Canvas columns accept `verticalAlign = "input"` to align checkboxes and color
  controls with neighboring input rows rather than their titles. Fields and
  compound inputs expose `GetInputAlignmentOffset()` for custom layouts. Wrapped
  labels, descriptions, hidden flows and stacked columns retain normal spacing.
- Canvas layouts accept `contentOverflow` to show backgrounds and borders in
  existing side margins while retaining control alignment, border clearance and
  the scrollbar column.
- Canvas layouts support registered sections and capture/restore bookmarks across
  forms, choosing the visible expanded section and matching stable keys or nearby
  fallbacks. Section-relative anchors survive deferred reflows and yield to scrolling
  or keyboard focus. Support retained/replaced sections and explicit unregistration.
- Canvas placements accept `onLayout` callbacks to resolve nested custom content
  before measuring its height. Synchronous page refreshes can restore bookmarks
  without showing intermediate positions or blanking the controls.
- Sliders accept `snapToStep = false` to retain fractional typed/programmatic
  values while keeping stepped track and keyboard/wheel controls.
- Add `CreateValueList` / `valueList`: compact value pills wrapping within one
  input, with Enter-to-advance, add/remove buttons, parsing/formatting, copied arrays
  and standard keyboard navigation. Blank fields are not saved; growing rows
  reflow following content and keep keyboard-focused pills visible without resizing.
- Dropdown choices accept `previewTexture` paths/file IDs as full-width texture
  previews behind outlined names, including a selection centered in the recessed border and live
  choice updates. Optional `menuWidth` sizes menus independently of their inputs.
- Canvas grids wrap retained cells across a configurable number of columns,
  with minimum widths, measured row heights and independent cell visibility.
- Dropdowns support optional checkbox multi-selection, copied value sets,
  custom summary text and empty-selection placeholders. Arrow keys move focus;
  Enter/Space toggles checks without closing, with native scrolling and tooltips.
- Sliders support `valueLabels` for numeric states such as Auto or Inherit,
  including case-insensitive input, normal stepping and numeric callbacks.
- Dropdown choices support native headings, dividers, per-choice tooltips and
  disabled entries. Keyboard navigation skips non-selectable rows while keeping
  a disabled saved selection visible.
- Color inputs support optional `onPreview(value)` callbacks for live drafts,
  with `onPreview(nil)` cleanup on every close path. Apply still commits once
  through `onChanged`; saved values and recent colors remain unchanged until then.

### Changed

- Standardize Lua formatting and include standalone StyLua/Selene configuration
  for contributors.
- Bundle default up/down carets, search/clear glyphs and the value-list plus
  without requiring LibYvSkins. Accept per-control texture overrides for each,
  including icon-picker filter carets. Defaults follow the copy selected by
  LibStub during compatible upgrades; consumer overrides remain independent.
- Dropdowns use a 34px recessed text-input body and focus glow with an inset
  square caret. Only the caret presses down; native menus and navigation remain.
  Review fixed labeled-row heights and old dropdown edge compensations;
  existing controls adopt the artwork during compatible upgrades.

### Fixed

- Share square-button artwork, selection and navigation with color swatches.
  Selected choices retain their border with additive hover/focus feedback,
  including after Apply/Cancel.
- `SetButtonIcon()` reuses prepared button geometry, masks and fonts when swapping
  artwork; adding/removing icons or changing their dimensions still relayouts.
- Keep fixed-width dropdown choices clickable across the full menu row,
  including short labels, texture previews and checkbox choices.
- Keep regular and small button bodies aligned when selected by allowing room
  for the selected atlas's glow, without changing layout or hit areas.
- Keep button labels centered when click callbacks update their text or
  selection, without a second text shift on mouse release.
- Non-scrolling canvases can set `scrollbarWidth = 0` to remove the right inset
  from nested sections. Scrolling canvases still require a positive width.
- Scroll-area margins now consume mouse-wheel input and scroll their pane,
  preventing wheel bindings from firing through gaps beside the scrollbar.
- Retain canvas and input anchors during resize/reflow, including scrolling
  content and header controls. Preserve measured section heights when only
  their width changes, without rebuilding controls or discarding pending edits.
  Defer child-driven Field resizing until native size callbacks finish, keeping
  wrapped inputs and labels measurable when adding or removing rows.

### Upgrade Notes

- Use LibStub MINOR 12 within the existing `LibModernSettings-1.0` API family.
- Include the library's `Media` directory. Consumers using a skin library should
  continue passing its glyph overrides; bundled defaults require no skin library.

## [1.10.0] - 2026-10-12

### Added

- Reusable scroll areas for native lists and canvas layouts, with inset spacing
  presets, compact content spacing, and independent border overrides. Existing
  canvas spacing remains unchanged unless the new options are selected.
- Buttons accept texture-file icons through `iconTexture`, alongside existing
  atlas icons. `SetButtonIcon()` updates either source on retained buttons.
- Canvas columns support vertical alignment to center or bottom-align content
  of different heights.

### Changed

- Square icon buttons automatically clip artwork to the tertiary border's
  corners while preserving icon sizing and aspect ratio.

### Upgrade Notes

- Use LibStub MINOR 11 within the existing `LibModernSettings-1.0` API family.

## [1.9.0] - 2026-10-12

### Added

- Persistent selected states for regular, small, and square buttons via
  `selected`, `SetSelected()`, and `IsSelected()`, using native tertiary artwork.

### Upgrade Notes

- Use LibStub MINOR 10 within the existing `LibModernSettings-1.0` API family.
