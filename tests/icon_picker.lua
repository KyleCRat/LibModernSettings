return function(lib, makeFrame, inputState)
    local originalProfileStop = debugprofilestop
    local profileTime = 0

    function debugprofilestop()
        profileTime = profileTime + 4
        return profileTime
    end

    dofile("tests/icon_model.lua")(lib)
    dofile("tests/icon_names.lua")(lib)
    local setCursor = dofile("tests/icon_sources.lua")(lib, inputState)
    dofile("tests/icon_filters.lua")(lib)
    local originalCreateFrame, originalScrollUtil = CreateFrame, ScrollUtil
    local originalCursorPosition = GetCursorPosition
    local cursorX, cursorY = 1000, 500

    function GetCursorPosition()
        return cursorX, cursorY
    end

    local originalHideOwnedTooltip = lib.HideOwnedTooltip

    function lib:HideOwnedTooltip(owner)
        owner.tooltipHidden = true
    end

    function CreateFrame(frameType, name, parent, template)
        local frame = originalCreateFrame(frameType, name, parent, template)

        function frame:SetResizable(value)
            self.resizable = value
        end

        function frame:SetResizeBounds(width, height)
            self.minWidth, self.minHeight = width, height
        end

        function frame:StartSizing()
            self.sizing = true
        end

        function frame:Raise()
            self.raised = true
        end

        function frame:UnregisterAllEvents()
            self.registeredEvents = {}
        end

        return frame
    end

    function CreateScrollBoxListGridView(
        _,
        _,
        _,
        _,
        _,
        horizontalSpacing,
        verticalSpacing
    )
        local view = {
            horizontalSpacing = horizontalSpacing,
            verticalSpacing = verticalSpacing,
        }

        function view:SetElementSize(width, height)
            self.width, self.height = width, height
        end

        function view:SetStrideExtent(value)
            self.strideExtent = value
        end

        function view:SetStride(value)
            self.stride = value
        end

        function view:SetElementInitializer(_, callback)
            self.initialize = callback
        end

        function view:SetElementResetter(callback)
            self.reset = callback
        end

        return view
    end

    function CreateIndexRangeDataProvider(count)
        return count
    end

    ScrollUtil = {
        InitScrollBoxListWithScrollBar = function(box, _, view)
            box.frames, box.view = {}, view

            function box:SetDataProvider(count)
                self.count = count
                self.first = 1
                -- Native provider replacement dispatches OnDataChanged and an
                -- immediate FullUpdate before returning to the caller.
                self:FullUpdate()
            end

            function box:GetDataIndexBegin()
                return self.first
            end

            function box:FullUpdate()
                self.fullUpdates = (self.fullUpdates or 0) + 1

                for index = 1, 6 do
                    local wrapper = self.frames[index]

                    if not wrapper then
                        wrapper = makeFrame("Frame", self)
                        self.frames[index] = wrapper
                    end

                    if self.first + index - 1 <= self.count then
                        view.initialize(wrapper, self.first + index - 1)
                    elseif wrapper.button then
                        view.reset(wrapper)
                    end
                end
            end

            function box:ScrollToElementDataIndex(
                index,
                alignment,
                _,
                noInterpolation
            )
                assert(
                    noInterpolation == ScrollBoxConstants.NoScrollInterpolation,
                    "catalogue changes must jump directly to the settled viewport"
                )
                self.first = math.max(
                    1,
                    index
                        - (
                            alignment == ScrollBoxConstants.AlignCenter
                                and 2
                            or 0
                        )
                )
                self:FullUpdate()
            end

            function box:ForEachFrame(callback)
                for _, wrapper in ipairs(self.frames) do
                    if wrapper.button then callback(wrapper) end
                end
            end
        end,
    }
    ScrollBoxConstants.UpdateImmediately = 1
    ScrollBoxConstants.AlignBegin = "begin"
    ScrollBoxConstants.AlignCenter = "center"
    dofile("Layouts/ScrollArea.lua")
    dofile("IconPicker/Browser.lua")
    dofile("IconPicker/Picker.lua")

    local entries = {}

    for index = 1, 1000 do
        entries[index] = { texture = index, name = "Artwork " .. index }
    end

    local catalogue = lib:CreateIconCatalogue({ icons = entries })
    local history = lib:CreateIconHistory()
    local picker = lib:CreateIconPicker(UIParent, {
        catalogue = catalogue,
        history = history,
        searchIconTexture = "Test\\Search.tga",
        clearIconTexture = "Test\\Close.tga",
        caretIconTexture = "Test\\Caret.tga",
    })

    for _, shelf in pairs(picker.shelves) do
        shelf:SetWidth(400)
        assert(shelf.label.justifyH == "RIGHT")
    end

    assert(picker.search._libModernSettingsControlType == "searchBox")
    assert(picker.search.searchIcon.texture == "Test\\Search.tga")
    assert(picker.search.clearButton.icon.texture == "Test\\Close.tga")
    assert(picker.filter.dropdown.Arrow.texture == "Test\\Caret.tga")
    assert(picker.category.dropdown.Arrow.texture == "Test\\Caret.tga")
    assert(picker.artworkType.dropdown.Arrow.texture == "Test\\Caret.tga")

    for _, dropdown in ipairs({ picker.category, picker.artworkType }) do
        assert(
            not dropdown.dropdown:GetMenuDescription().maximumWidth,
            "artwork menus must use the same responsive sizing as ordinary LMS dropdowns"
        )
    end

    local writes, saved, closed, valid = 0, nil, nil, true
    local options = {
        addonName = "Test",
        sourceName = "Aura",
        value = 900,
        defaultIcon = 1,
        isValid = function()
            return valid
        end,
        onApply = function(value)
            writes, saved = writes + 1, value
        end,
        onClose = function(applied)
            closed = applied
        end,
    }
    assert(picker:Open(options))
    assert(
        picker.frame.resizable and picker.frame.topLevel and picker.frame.raised
    )
    assert(picker.frame.title == "Choose icon for Test / Aura")
    assert(
        picker.frame:IsShown()
            and picker.loading:IsShown()
            and #picker.results == 0,
        "opening must show chrome and loading feedback before preparing icons"
    )
    local openingHeight = picker.frame:GetHeight()

    for _, shelf in pairs(picker.shelves) do
        assert(
            shelf.placeholder:IsShown()
                and not shelf.empty:IsShown()
                and shelf.placeholder:GetHeight() == shelf:GetHeight(),
            "loading reserves a full icon row with an empty frame, without premature empty-history text"
        )
    end

    picker:Update(0.2)
    assert(
        #picker.results == 0,
        "the first update must allow the loading frame to paint"
    )
    picker:Update(0.2)
    assert(picker.scrollBox.first == 898 and not picker.loading:IsShown())
    assert(
        picker.frame:GetHeight() == openingHeight,
        "empty shelves must keep the opening height"
    )

    for _, shelf in pairs(picker.shelves) do
        assert(
            shelf.placeholder:IsShown() and shelf.empty:IsShown(),
            "empty histories retain their placeholder and show the shelf guidance"
        )
    end

    assert(picker.scrollBox.frames[1].button.entry.texture == 898)
    assert(picker.scrollBox.frames[1].button.icon.texture == 898)

    for _, wrapper in ipairs(picker.scrollBox.frames) do
        local button = wrapper.button
        local mask = button.icon._libModernSettingsSquareMask
        assert(button:GetWidth() == 42 and button:GetHeight() == 42)
        assert(button.icon:GetWidth() == 32 and button.icon:GetHeight() == 32)
        assert(
            mask:GetWidth() == 30 and mask:GetHeight() == 30,
            "pooled picker icons must retain the enlarged visible artwork after binding"
        )
    end

    assert(picker.gridView.width == 42 and picker.gridView.height == 42)
    assert(
        picker.gridView.horizontalSpacing == 2
            and picker.gridView.verticalSpacing == 2
    )
    assert(not picker.frame:GetScript("OnUpdate"), "idle pickers must not poll")

    -- Widths contain whole columns including the inset and scrollbar column.
    -- Cursor movement is physical; the same gesture must work at fractional scale.
    local function checkGridWidth()
        local left, right, top, bottom = picker.area:GetContentInsets()
        local columns = picker.gridView.stride
        assert(
            not picker.gridView.strideExtent,
            "explicit columns must not be replaced by native float measurements"
        )
        assert(
            picker.frame:GetWidth() - 24 - left - right
                == columns * 42 + (columns - 1) * 2
        )
        assert(
            picker.frame:GetWidth()
                == 24 + 8 + 27 + columns * 40 + (columns - 1) * 4,
            "larger artwork must preserve the previous window-width snap points"
        )
        assert(
            left + 42 / 2 == 8 + 40 / 2 and top + 42 / 2 == 8 + 40 / 2,
            "outer margins must keep the first icon centered at its previous position"
        )
        local rows = 10
        assert(
            top + bottom + rows * 42 + (rows - 1) * 2
                == 16 + rows * 40 + (rows - 1) * 4,
            "larger artwork must not change the scrollable height"
        )
    end

    checkGridWidth()
    local initialWidth, initialHeight =
        picker.frame:GetWidth(), picker.frame:GetHeight()
    local originalScale = picker.frame.GetEffectiveScale

    for _, scale in ipairs({ 1, 0.64, 1.25 }) do
        picker.frame.GetEffectiveScale = function()
            return scale
        end

        cursorX, cursorY = 1000, 500
        inputState.mouseDown = true
        picker:BeginResize()
        cursorX, cursorY = 1000 + 21 * scale, 500 - 13 * scale
        picker:Update(0.01)
        assert(
            picker.frame:GetWidth() == initialWidth,
            "less than half a column must keep the same width"
        )
        assert(math.abs(picker.frame:GetHeight() - initialHeight - 13) < 0.001)
        cursorX = 1000 + 23 * scale
        picker:Update(0.01)
        assert(picker.frame:GetWidth() == initialWidth + 44)
        checkGridWidth()
        local updates = picker.scrollBox.fullUpdates
        local getWidth, getHeight =
            picker.frame.GetWidth, picker.frame.GetHeight

        picker.frame.GetWidth = function(self)
            return getWidth(self) - 0.00002
        end

        picker.frame.GetHeight = function(self)
            return getHeight(self) + 0.00002
        end

        picker:Update(0.01)
        assert(
            picker.scrollBox.fullUpdates == updates,
            "fractional native measurements must not rebuild a stationary resize gesture"
        )
        picker.frame.GetWidth, picker.frame.GetHeight = getWidth, getHeight
        cursorX, cursorY = 1000, 500
        inputState.mouseDown = false
        picker:Update(0.01)
        assert(not picker.resize and not picker.frame:GetScript("OnUpdate"))
        assert(
            picker.frame:GetWidth() == initialWidth
                and picker.frame:GetHeight() == initialHeight
        )
    end

    picker.frame.GetEffectiveScale = originalScale
    inputState.mouseDown = true
    picker:BeginResize()
    cursorX, cursorY = -10000, 10000
    picker:Update(0.01)
    assert(
        picker.frame:GetWidth() == picker.frame.minWidth
            and picker.frame:GetHeight() == picker.frame.minHeight
    )
    checkGridWidth()
    picker:Close()
    assert(
        not picker.resize and not picker.frame:GetScript("OnUpdate"),
        "closing must stop an active resize"
    )
    inputState.mouseDown = false
    lib._iconUtils.SetBrowserSize(picker, initialWidth, initialHeight)
    picker:Open(options)
    picker:SetValue(30)
    picker:Close()
    assert(writes == 0 and closed == false and #history:GetIcons("recent") == 0)

    picker:Open(options)
    picker:Reset()
    assert(picker:GetValue() == nil and picker:Apply())
    assert(
        writes == 1
            and saved == nil
            and closed
            and #history:GetIcons("recent") == 0
    )
    picker:Open(options)
    picker:SetValue(30)
    assert(
        picker:Apply() and saved == 30 and history:GetIcons("recent")[1] == 30
    )
    picker:Open(options)
    picker:ToggleFavorite(22)
    picker:Close()
    assert(
        history:GetIcons("favorites")[1] == 22,
        "favorites persist independently of drafts"
    )

    picker:Open(options)
    local placeholderFrames = {}

    for kind, shelf in pairs(picker.shelves) do
        placeholderFrames[kind] = shelf.placeholder
        assert(shelf.placeholder:IsShown() and not shelf.empty:IsShown())
    end

    picker:Update(0.2)
    picker:Update(0.2)
    assert(
        picker.frame:GetHeight() == openingHeight,
        "one row of history must not enlarge the window"
    )

    for _, shelf in pairs(picker.shelves) do
        assert(
            not shelf.placeholder:IsShown()
                and not shelf.empty:IsShown()
                and shelf.buttons[1]:IsShown()
                and shelf:GetHeight() == shelf.buttons[1]:GetHeight(),
            "loaded history replaces the placeholder within the same reserved row"
        )
    end

    picker:ToggleFavorite(22)
    picker:Update(0.2)
    assert(
        picker.shelves.favorites.placeholder:IsShown()
            and not picker.shelves.favorites.buttons[1]:IsShown(),
        "removing the last favorite restores the empty frame"
    )
    picker:ToggleFavorite(22)
    picker:Close()
    picker:Open(options)

    for kind, shelf in pairs(picker.shelves) do
        assert(
            shelf.placeholder == placeholderFrames[kind]
                and shelf.placeholder:IsShown()
                and not shelf.buttons[1]:IsShown(),
            "reopening reuses placeholders and hides old history bindings"
        )
    end

    picker:Close()

    picker:Open(options)
    picker.search:SetText("no matches")
    picker:QueueSearch(0)
    picker:Update(0.2)
    picker:Update(0.2)
    local stale = picker.searchJob
    assert(stale and not stale.complete)
    picker.search:SetText("Artwork 42")
    picker:QueueSearch(0)
    assert(stale.cancelled)

    for _ = 1, 16 do
        picker:Update(0.2)
    end

    assert(#picker.results > 0 and not picker.searchJob)
    picker:Close()
    assert(not picker.frame:GetScript("OnUpdate"))

    picker:Open(options)
    picker.input:SetFocus()
    picker.input:SetText("-1")
    assert(not picker:Apply() and writes == 2)
    picker:Reset()
    assert(picker:Apply() and writes == 3)
    picker:Open(options)
    setCursor({ "item", 100 })
    picker:UpdateCursor()
    assert(picker.dropTarget:IsShown())
    picker:ReceiveDrag()
    assert(picker:GetValue() == 101 and GetCursorInfo() == nil)
    assert(not picker.dropTarget:IsShown())
    inputState.inCombat = true
    picker.frame:GetScript("OnEvent")(picker.frame, "PLAYER_REGEN_DISABLED")
    assert(not picker.session and writes == 3)
    assert(not picker:Open(options))
    assert(not pcall(function()
        lib:CreateIconPicker(UIParent)
    end))
    inputState.inCombat = false
    picker:Open(options)
    valid = false
    assert(not picker:Apply() and not picker.session and writes == 3)
    valid = true

    -- A consumer may open another session from its commit callback.
    local reentrant = {}

    for key, value in pairs(options) do
        reentrant[key] = value
    end

    reentrant.onApply = function()
        picker:Open(options)
    end

    picker:Open(reentrant)
    picker:SetValue(45)
    assert(picker:Apply() and picker.session and picker:GetValue() == 900)
    assert(history:GetIcons("recent")[1] == 45)
    picker:Close()
    assert(#picker.scrollBox.frames == 6, "reopening must reuse pooled frames")
    picker:Open(options)
    picker:Update(0.2)
    picker:Update(0.2)
    picker:Refresh()
    picker:Update(0.2)
    assert(
        picker.scrollBox.first == 898,
        "metadata refreshes must preserve the visible range"
    )
    local second = lib:CreateIconPicker(UIParent, { catalogue = catalogue })

    for _, shelf in pairs(second.shelves) do
        shelf:SetWidth(400)
    end

    second:Open(options)
    second:SetValue(123)
    picker:SetValue(234)
    second:Close()
    assert(picker.session and picker:GetValue() == 234)
    assert(second.history ~= picker.history and second.frame ~= picker.frame)
    picker:Close()

    local filteredCatalogue = lib:CreateIconCatalogue({
        icons = {
            {
                texture = 1,
                filename = "INV_Helm_Red",
                tags = { "item", "bags" },
            },
            {
                texture = 2,
                filename = "INV_Dagger_Red",
                tags = { "item", "equipped" },
            },
            {
                texture = 3,
                filename = "INV_Knife_Blue",
                tags = { "item", "bags", "custom" },
            },
            {
                texture = 4,
                filename = "Classicon_DemonHunter_Purple",
                tags = { "spell" },
            },
            {
                texture = 5,
                filename = "Spell_Holy_Justice",
                tags = { "spell", "myspells" },
            },
        },
    })
    local filteredHistory = lib:CreateIconHistory()

    for _, texture in ipairs({ 3, 1, 2 }) do
        filteredHistory:Record(texture)
        filteredHistory:ToggleFavorite(texture)
    end

    local filtered = lib:CreateIconPicker(UIParent, {
        catalogue = filteredCatalogue,
        history = filteredHistory,
        extraFilters = {
            {
                value = "custom",
                label = "Consumer metadata",
                match = function(entry)
                    return entry.tags.custom
                end,
            },
        },
    })

    for _, shelf in pairs(filtered.shelves) do
        shelf:SetWidth(400)
    end

    local filteredOptions = {
        addonName = "Test",
        sourceName = "Filters",
        defaultIcon = 1,
        suggestedIcons = {
            { texture = 1 },
            { texture = 4 },
        },
        onApply = function() end,
    }

    local function source(value)
        filtered.filter:SetValue(value)
        filtered.filter._libModernSettingsOnChanged(value)
    end

    local function results(...)
        for _ = 1, 16 do
            filtered:Update(0.2)
        end

        local expected = { ... }
        assert(
            not filtered.searchJob and #filtered.results == #expected,
            "unexpected results for "
                .. filtered.filterValue
                .. "/"
                .. filtered.categoryValue
                .. "/"
                .. filtered.typeValue
        )

        for index, texture in ipairs(expected) do
            assert(filtered.results[index].texture == texture)
        end
    end

    filtered:Open(filteredOptions)
    assert(
        not filtered.artworkType.dropdown:IsEnabled()
            and not filtered.artworkType.tooltipEnabled
    )
    results(1, 2, 3, 4, 5)
    filtered.category._libModernSettingsOnChanged("equipment")
    assert(
        filtered.artworkType.dropdown:IsEnabled()
            and filtered.artworkType.tooltipEnabled
    )
    filtered.artworkType._libModernSettingsOnChanged("daggers")
    results(2, 3)
    filtered.search:SetText("red")
    filtered:QueueSearch(0)
    source("item")
    results(2)
    source("bags")
    results()
    assert(filtered.empty:IsShown())
    assert(filtered.search.clearButton:IsShown())
    filtered.search.clearButton:Click()
    assert(
        filtered.search:GetText() == ""
            and not filtered.search.clearButton:IsShown()
    )
    assert(
        filtered.filterValue == "bags"
            and filtered.categoryValue == "equipment"
            and filtered.typeValue == "daggers",
        "clearing search must keep source and artwork filters"
    )
    results(3)
    assert(not filtered.empty:IsShown())
    source("favorites")
    results(3, 2)
    source("recent")
    results(2, 3)
    source("custom")
    results(3)
    source("suggested")
    results()
    filtered:SetArtworkCategory("classes")
    assert(filtered.typeValue == "all")
    results(4)
    filtered:SetArtworkType("hunter")
    results()
    filtered:SetArtworkType("demonhunter")
    results(4)
    source("all")
    filtered:SetArtworkCategory("colors")
    filtered:SetArtworkType("blue")
    results(3)
    filteredCatalogue:AddIcon({ texture = 3, filename = "INV_Knife_Red" })
    filtered:Refresh()
    results()
    filtered:Close()
    filtered:Open(filteredOptions)
    assert(filtered.categoryValue == "all" and filtered.typeValue == "all")
    assert(
        filtered.filterValue == "all"
            and not filtered.artworkType.dropdown:IsEnabled()
    )
    results(1, 2, 3, 4, 5)
    source("favorites")
    filtered:SetArtworkCategory("equipment")
    filtered:SetArtworkType("head")
    filtered.search:SetValue("helm")
    setCursor({ "unknown", 100 })
    filtered:ReceiveDrag()
    assert(
        GetCursorInfo() == "unknown"
            and filtered.filterValue == "favorites"
            and filtered.categoryValue == "equipment"
            and filtered.typeValue == "head"
            and filtered.search:GetText() == "helm",
        "unsupported drops must preserve the browse state and cursor"
    )
    setCursor({ "item", 100 })
    filtered:ReceiveDrag()
    assert(filtered:GetValue() == 101 and GetCursorInfo() == nil)
    assert(
        filtered.filter:GetValue() == "all"
            and filtered.category:GetValue() == "all"
            and filtered.artworkType:GetValue() == "all"
            and not filtered.artworkType.dropdown:IsEnabled()
    )
    assert(
        filtered.search:GetText() == ""
            and not filtered.search.clearButton:IsShown()
    )
    results(1, 2, 3, 4, 5, 101)
    assert(
        filtered.scrollBox.first == 4,
        "drops must add unknown artwork and reveal its selected grid entry"
    )
    filtered:Close()

    picker:Open(options)
    picker:SetArtworkCategory("equipment")
    picker:Update(0.2)
    picker:Update(0.2)
    local oldCategorySearch = picker.searchJob
    assert(oldCategorySearch and not oldCategorySearch.complete)
    picker:SetArtworkCategory("classes")
    assert(
        oldCategorySearch.cancelled,
        "changing categories must cancel unfinished searches"
    )
    picker:Update(0.2)
    local droppedSearch = picker.searchJob
    assert(droppedSearch and not droppedSearch.complete)
    setCursor({ "item", 100 })
    picker:ReceiveDrag()
    picker:Update(0.2)
    assert(
        droppedSearch.cancelled
            and not picker.searchJob
            and picker.scrollBox.first == 99,
        "a drop must replace an unfinished search with the selected artwork"
    )
    picker:Close()
    dofile("tests/icon_picker_filters.lua")(lib, setCursor)
    dofile("tests/icon_picker_refresh.lua")(lib, inputState)
    dofile("tests/icon_picker_performance.lua")(
        lib,
        picker,
        inputState,
        options,
        setCursor
    )
    CreateFrame, ScrollUtil = originalCreateFrame, originalScrollUtil
    lib.HideOwnedTooltip = originalHideOwnedTooltip
    debugprofilestop = originalProfileStop
    GetCursorPosition = originalCursorPosition
    print("LibModernSettings icon picker lifecycle and viewport tests passed")
end
