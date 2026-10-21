local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)
if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Browser", MINOR) then
    return
end

local Icons = lib._iconUtils
local SIZE, GAP = 42, 2
local INSET_SIDE = 12
local MIN_WIDTH, MIN_HEIGHT = 480, 440
Icons.ButtonSize = SIZE
Icons.ButtonStep = SIZE + GAP
Icons.ShelfIconOffset = 80

local function label(parent, value, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    text:SetText(value)
    text:SetJustifyH("LEFT")
    return text
end

function Icons.CreateButton(picker, parent)
    local button = lib:CreateButton(parent, {
        variant = "square",
        width = SIZE,
        iconTexture = 134400,
        iconSize = 32,
        iconMaskInset = 6,
        onClick = function(self, mouseButton)
            if not picker:Validate() or not self.entry then
                return
            end
            if mouseButton == "RightButton" then
                picker:ToggleFavorite(self.entry.texture)
            else
                picker:SetValue(self.entry.texture)
            end
        end,
    })
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.favorite = button:CreateTexture(nil, "OVERLAY")
    button.favorite:SetAtlas("PetJournal-FavoritesIcon")
    button.favorite:SetSize(12, 12)
    button.favorite:SetPoint("TOPRIGHT", -3, -3)
    button.favorite:Hide()
    return button
end

local function makeShelf(picker, kind, title, y)
    local shelf = CreateFrame("Frame", nil, picker.frame)
    shelf:SetPoint("TOPLEFT", 18, -y)
    shelf:SetPoint("TOPRIGHT", -18, -y)
    shelf:SetHeight(SIZE)
    shelf.label = label(shelf, title, "GameFontHighlight")
    shelf.label:SetPoint("LEFT")
    shelf.label:SetWidth(Icons.ShelfIconOffset - GAP)
    shelf.label:SetJustifyH("RIGHT")
    shelf.placeholder = CreateFrame("Frame", nil, shelf)
    shelf.placeholder:SetSize(SIZE, SIZE)
    shelf.placeholder:SetPoint("LEFT", Icons.ShelfIconOffset, 0)
    lib:_CreateAtlasTexture(shelf.placeholder, "ARTWORK", "common-button-tertiary-square-normal")
    shelf.empty = label(shelf, kind == "recent" and "Applied icons appear here." or "Right-click an icon to save it.")
    shelf.empty:SetPoint("LEFT", shelf.placeholder, "RIGHT", GAP, 0)
    shelf.empty:SetPoint("RIGHT")
    shelf.buttons = {}
    picker.shelves[kind] = shelf
end

local function makeInputs(picker)
    local frame = picker.frame
    local title = label(frame, "Texture file ID or path")
    title:SetPoint("TOPLEFT", 18, -39)
    picker.preview = Icons.CreateButton(picker, frame)
    picker.preview:SetPoint("TOPRIGHT", -18, -53)
    picker.input = lib:CreateTextInput(frame, {
        onCommit = function(text)
            local value, message = Icons.Normalize(text)
            if message then
                return nil, message
            end
            picker:SetValue(value, true)
            return value and tostring(value) or ""
        end,
        onError = function(message)
            picker.inputError = true
            picker:Error(message)
        end,
        tooltip = "Choose artwork below, enter a texture file ID or Interface path, or drag a spell, item, macro, mount or pet here. Reset restores the addon's default artwork.",
    })
    picker.input:SetPoint("TOPLEFT", 18, -57)
    picker.input:SetPoint("RIGHT", picker.preview, "LEFT", -8, 0)

    picker.filter = lib:CreateDropdown(frame, {
        width = 186,
        value = "all",
        choices = picker.filters,
        tooltip = "Choose where to browse: all icons, your history, your character or a Blizzard catalogue. Search and artwork filters narrow this selection together.",
        onChanged = function(value)
            picker.filterValue = value
            picker:QueueSearch(0)
        end,
    })
    picker.filter:SetPoint("TOPRIGHT", -18, -102)
    picker.search = lib:CreateSearchBox(frame, {
        placeholder = "Search icons",
        searchIconTexture = picker.searchIconTexture,
        clearIconTexture = picker.clearIconTexture,
        tooltip = "Search icon filenames, file IDs, known spell/item names and supplied keywords. Every word must match; small typos are tolerated. Names are unavailable for some artwork. Clearing the search shows all icons within the selected filters.",
        onChanged = function(_, userInput)
            picker:QueueSearch(userInput and 0.15 or 0)
        end,
    })
    picker.search:SetPoint("TOPLEFT", 18, -102)
    picker.search:SetPoint("RIGHT", picker.filter, "LEFT", -8, 0)
    picker.category = lib:CreateDropdown(frame, {
        value = "all",
        choices = Icons.ArtworkCategories,
        tooltip = "Choose an artwork category, then optionally narrow it by type. Categories use words in icon filenames and combine with the source and search above.",
        onChanged = function(value)
            picker:SetArtworkCategory(value)
        end,
    })
    picker.category:SetPoint("TOPLEFT", 18, -146)
    picker.category:SetPoint("TOPRIGHT", frame, "TOP", -4, -146)
    picker.artworkType = lib:CreateDropdown(frame, {
        value = "all",
        choices = Icons.ArtworkCategories[1].types,
        tooltip = "Choose an artwork category on the left to enable its specific types. All types includes the whole chosen category.",
        onChanged = function(value)
            picker:SetArtworkType(value)
        end,
    })
    picker.artworkType:SetPoint("TOPRIGHT", -18, -146)
    picker.artworkType:SetPoint("TOPLEFT", frame, "TOP", 4, -146)
    for _, input in ipairs({ picker.input, picker.search }) do
        input:HookScript("OnEscapePressed", function()
            picker:Close()
        end)
    end
end

local function makeGrid(picker)
    local inset = picker.frame.Inset
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", INSET_SIDE, -278)
    inset:SetPoint("BOTTOMRIGHT", -INSET_SIDE, 50)
    -- Spend one unit from each outer margin as well as two from each gap.
    -- Larger buttons keep the same centers, column widths and scroll range.
    local area = lib:CreateScrollArea(inset, {
        contentSpacing = "compact",
        contentPadding = { left = 7, top = 7, bottom = 7 },
        scrollbarGap = 3,
    })
    local view = CreateScrollBoxListGridView(1, 0, 0, 0, 0, GAP, GAP)
    view:SetElementSize(SIZE, SIZE)
    view:SetElementInitializer("Frame", function(wrapper, index)
        if not wrapper.button then
            wrapper.button = Icons.CreateButton(picker, wrapper)
            wrapper.button:SetPoint("CENTER")
        end
        local entry = picker.results[index]
        if picker.settingResults then
            -- Skip provisional rows while replacing results and restoring the
            -- viewport. Ordinary scrolling binds immediately, without blanking.
            if wrapper.button.entry ~= entry then
                lib:HideOwnedTooltip(wrapper.button)
                wrapper.button.entry = entry
            end
            wrapper.button:Hide()
            picker.paintPending = true
            picker:Wake()
        else
            picker:Bind(wrapper.button, entry)
        end
    end)
    view:SetElementResetter(function(wrapper)
        wrapper.button.entry = nil
        wrapper.button:Hide()
        lib:HideOwnedTooltip(wrapper.button)
        -- Retain the texture and tooltip cache on the pooled button. Rebinding
        -- replaces changed artwork; releasing a row must not unload it first.
    end)
    area:Init(view)
    picker.gridView = view
    picker.area, picker.scrollBox = area, area:GetScrollBox()
    picker.empty = label(inset, "No matching icons")
    picker.empty:SetPoint("CENTER")
    picker.empty:Hide()
    picker.loading = CreateFrame("Frame", nil, inset, "SpinnerTemplate")
    picker.loading:SetSize(48, 48)
    picker.loading:SetPoint("CENTER")
    picker.loading:Hide()
end

local function makeActions(picker)
    local frame = picker.frame
    local cancel = lib:CreateButton(frame, {
        text = "Cancel",
        width = 100,
        onClick = function()
            picker:Close()
        end,
    })
    cancel:SetPoint("BOTTOMRIGHT", -24, 10)
    local reset = lib:CreateButton(frame, {
        text = "Reset",
        width = 100,
        tooltip = "Preview the addon's default icon. Apply saves the reset; Cancel keeps the previous icon.",
        onClick = function()
            picker:Reset()
        end,
    })
    reset:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    local apply = lib:CreateButton(frame, {
        text = "Apply",
        width = 100,
        onClick = function()
            picker:Apply()
        end,
    })
    apply:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    picker.status = label(frame, "")
    picker.status:SetPoint("LEFT", frame, "BOTTOMLEFT", 18, 27)
    picker.status:SetPoint("RIGHT", apply, "LEFT", -8, 0)
end

local function makeDropTarget(picker)
    local overlay = CreateFrame("Frame", nil, picker.frame)
    overlay:SetPoint("TOPLEFT", 8, -29)
    overlay:SetPoint("BOTTOMRIGHT", -8, 8)
    overlay:SetFrameLevel(picker.frame:GetFrameLevel() + 50)
    overlay:EnableMouse(true)
    local backdrop = overlay:CreateTexture(nil, "BACKGROUND")
    backdrop:SetAllPoints()
    backdrop:SetColorTexture(0, 0, 0, 0.82)
    local text = label(overlay, "Drop here to choose this icon")
    text:SetPoint("CENTER")
    local function receive()
        picker:ReceiveDrag()
    end
    overlay:SetScript("OnReceiveDrag", receive)
    overlay:SetScript("OnMouseUp", receive)
    overlay:SetScript("OnMouseDown", function()
        -- Consume the click; release handles both click and drag cursors.
    end)
    overlay:Hide()
    picker.dropTarget = overlay
end

function Icons.GetBrowserWidth(picker, width)
    local left, right = picker.area:GetContentInsets()
    local margins = INSET_SIDE * 2 + left + right
    local minimumColumns = math.ceil((MIN_WIDTH - margins + GAP) / Icons.ButtonStep)
    local columns = math.max(minimumColumns, math.floor((width - margins + GAP) / Icons.ButtonStep + 0.5))
    return margins + columns * Icons.ButtonStep - GAP, columns
end

function Icons.SetBrowserSize(picker, width, height)
    local snappedWidth, columns = Icons.GetBrowserWidth(picker, width)
    height = math.max(MIN_HEIGHT, height)
    if picker.browserWidth == snappedWidth and picker.browserHeight == height then
        return
    end
    -- The snapped window and native grid must agree even when frame measurements
    -- round slightly below a column boundary at fractional effective scales.
    picker.browserWidth, picker.browserHeight = snappedWidth, height
    picker.columns = columns
    picker.gridView:SetStride(columns)
    picker.frame:SetSize(snappedWidth, height)
    if picker.session then
        picker.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end
end

function Icons.CreateBrowser(picker, parent)
    local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate")
    picker.frame = frame
    frame:Hide()
    frame:SetSize(620, 660)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function()
        -- The inset owns scrolling; outer window margins still consume it.
    end)
    ButtonFrameTemplate_HidePortrait(frame)
    frame.TopTileStreaks:Hide()
    frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -1)
    frame.CloseButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.TitleContainer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.CloseButton:SetScript("OnClick", function()
        picker:Close()
    end)
    frame:SetScript("OnHide", function()
        picker:Close()
    end)
    frame:SetScript("OnSizeChanged", function(_, width)
        if picker.shelfWidth ~= width then
            picker.shelfWidth = width
            picker.shelvesPending = true
            picker:Wake()
        end
    end)
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            picker:Close()
        elseif event == "CURSOR_CHANGED" then
            picker:UpdateCursor()
        else
            picker:OnMetadataEvent(event, ...)
        end
    end)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key)
        frame:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then
            picker:Close()
        end
    end)
    picker.messages = lib:CreateFlashMessages(frame)
    makeInputs(picker)
    makeShelf(picker, "recent", "Recent", 189)
    makeShelf(picker, "favorites", "Favorites", 233)
    makeGrid(picker)
    frame:SetResizeBounds(Icons.GetBrowserWidth(picker, MIN_WIDTH), MIN_HEIGHT)
    Icons.SetBrowserSize(picker, frame:GetWidth(), frame:GetHeight())
    makeActions(picker)
    makeDropTarget(picker)
    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            picker:BeginResize()
        end
    end)
    resize:SetScript("OnMouseUp", function()
        picker:EndResize()
    end)
    lib:EnableTabNavigation(frame)
end
