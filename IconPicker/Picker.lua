local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Picker", MINOR)
then
    return
end

local Icons = lib._iconUtils
lib._iconPickerPrototype = lib._iconPickerPrototype or {}
local Picker = lib._iconPickerPrototype
Picker.__index = Picker

local EVENTS = {
    "PLAYER_REGEN_DISABLED",
    "CURSOR_CHANGED",
    "SPELLS_CHANGED",
    "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE_DELAYED",
    "GET_ITEM_INFO_RECEIVED",
}

function Picker:Error(message)
    self.messages:Show(message, "error")
end

function Picker:Validate()
    local session = self.session

    if not session then return false end

    if InCombatLockdown() or (session.isValid and not session.isValid()) then
        self:Close()
        return false
    end

    return self.session == session
end

function Picker:Wake()
    if self.session then
        if not self.onUpdate then
            self.onUpdate = function(_, elapsed)
                self:Update(elapsed)
            end
        end

        self.frame:SetScript("OnUpdate", self.onUpdate)
    end
end

local function getTooltip(catalogue, entry)
    if
        not entry.pickerTooltip
        or not entry.filenameRead
        or entry.pickerTooltipName ~= entry.name
        or entry.pickerTooltipFilename ~= entry.filename
    then
        catalogue:Describe(entry)
        local name = entry.name
            or entry.filename:match("([^\\/]*)$")
            or tostring(entry.texture)

        if name == "" then name = "Icon " .. tostring(entry.texture) end

        entry.pickerTooltip = {
            title = name,
            text = tostring(entry.texture)
                .. "\nRight-click to add or remove a favorite.",
        }
        entry.pickerTooltipName = entry.name
        entry.pickerTooltipFilename = entry.filename
    end

    return entry.pickerTooltip
end

function Picker:Bind(button, entry)
    if button.entry ~= entry then
        lib:HideOwnedTooltip(button)
        button.entry = entry
    end

    if button.boundTexture ~= entry.texture then
        button:SetButtonIcon({ iconTexture = entry.texture })
        button.boundTexture = entry.texture
    end

    local key = Icons.Key(entry.texture)
    local selected = key == Icons.Key(self.value)

    if button:IsSelected() ~= selected then button:SetSelected(selected) end

    local favorite = self.favorites[key] == true

    if button.favorite:IsShown() ~= favorite then
        button.favorite:SetShown(favorite)
    end

    local tooltip = getTooltip(self.catalogue, entry)

    if button.boundTooltip ~= tooltip then
        lib:SetTooltip(button, tooltip)
        button.boundTooltip = tooltip
    end

    button:Show()
end

function Picker:RefreshHistory()
    local history = self.history:_GetSnapshot()
    self.historyRevision = self.history.revision or 0
    self.historyEntries = {}
    self.favorites = {}

    for _, icon in ipairs(history.favorites) do
        self.favorites[Icons.Key(icon)] = true
    end

    for kind, icons in pairs(history) do
        local entries = {}

        for _, icon in ipairs(icons) do
            entries[#entries + 1] = self.catalogue:AddIcon({ texture = icon })
        end

        self.historyEntries[kind] = entries
    end

    self.shelvesPending = true
end

function Picker:RefreshShelves()
    for kind, shelf in pairs(self.shelves) do
        local entries = self.historyEntries[kind]
        local capacity = math.max(
            1,
            math.floor(
                (shelf:GetWidth() - Icons.ShelfIconOffset) / Icons.ButtonStep
            )
        )
        shelf.visibleCount = math.min(capacity, #entries)

        for index = 1, shelf.visibleCount do
            local button = shelf.buttons[index]

            if not button then
                button = Icons.CreateButton(self, shelf)
                button:SetPoint(
                    "LEFT",
                    Icons.ShelfIconOffset + (index - 1) * Icons.ButtonStep,
                    0
                )
                shelf.buttons[index] = button
            end
        end

        for index = shelf.visibleCount + 1, #shelf.buttons do
            shelf.buttons[index]:Hide()
        end

        shelf.placeholder:SetShown(#entries == 0)
        shelf.empty:SetShown(#entries == 0)
    end

    self.paintPending = true
end

function Picker:Paint()
    self.scrollBox:ForEachFrame(function(wrapper)
        local entry = wrapper.button.entry

        if entry then self:Bind(wrapper.button, entry) end
    end)

    for kind, shelf in pairs(self.shelves) do
        for index = 1, shelf.visibleCount or 0 do
            self:Bind(shelf.buttons[index], self.historyEntries[kind][index])
        end
    end

    local session = self.session
    local texture = self.value or session.defaultIcon or 134400
    self:Bind(self.preview, self.catalogue:AddIcon({ texture = texture }))

    if not self.value and session.defaultIconColor then
        self.preview.icon:SetVertexColor(unpack(session.defaultIconColor))
    else
        self.preview.icon:SetVertexColor(1, 1, 1)
    end
end

function Picker:SetValue(value, fromInput)
    if not self:Validate() then return false end

    local icon, message = Icons.Normalize(value)

    if message then
        self:Error(message)
        return false
    end

    self.value = icon
    self.inputError = nil

    if not fromInput then self.input:SetValue(icon and tostring(icon) or "") end

    self.paintPending = true
    self:Wake()
    return true
end

function Picker:GetValue()
    return self.value
end

function Picker:Reset()
    self.input:CancelAndClearFocus()
    return self:SetValue(nil)
end

function Picker:ToggleFavorite(value)
    if not self:Validate() then return end

    local _, message = self.history:ToggleFavorite(value)

    if message then
        self:Error(message)
        return
    end

    self.historyPending = true

    if self.filterValue == "favorites" then self:QueueSearch(0) end

    self:Wake()
end

function Picker:UpdateCursor()
    self.dropTarget:SetShown(self.session ~= nil and lib:GetCursorIcon() ~= nil)
end

function Picker:ReceiveDrag()
    if not self:Validate() then return end

    local icon, message = lib:GetCursorIcon()

    if icon then
        if self.catalogue then self.catalogue:AddIcon({ texture = icon }) end

        self:SetValue(icon)
        self:ResetBrowseFilters()
        self.revealSelection = true
        self:QueueSearch(0)
        ClearCursor()
        self:UpdateCursor()
    elseif message then
        self:Error(message)
    end
end

function Picker:ResetBrowseFilters()
    self.filterValue = "all"
    self.filter:SetValue("all")
    self.categoryValue, self.typeValue = "all", "all"
    self:RefreshArtworkControls()
    self.search:SetValue("")
end

function Picker:BeginResize()
    if not self:Validate() or not self.input:CommitAndClearFocus() then
        return
    end

    self.search:ClearFocus()
    local frame = self.frame
    local x, y = GetCursorPosition()
    self.resize = {
        x = x,
        y = y,
        width = self.browserWidth,
        height = self.browserHeight,
        scale = frame:GetEffectiveScale(),
    }
    -- GetLeft/GetTop and SetPoint offsets use this frame's coordinates. Preserve
    -- its top-left corner while dragging the opposite corner at any UI scale.
    local left, top = frame:GetLeft(), frame:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    self:Wake()
end

function Picker:UpdateResize()
    local resize = self.resize

    if not resize then return end

    local x, y = GetCursorPosition()
    Icons.SetBrowserSize(
        self,
        resize.width + (x - resize.x) / resize.scale,
        resize.height + (resize.y - y) / resize.scale
    )
end

function Picker:EndResize()
    self:UpdateResize()
    self.resize = nil
end

function Picker:SetResults(results, revealSelection)
    local retainTexture = self.retainTexture
    self.retainTexture = nil
    self.results = results
    self.settingResults = true
    -- Replacing the provider synchronously updates the native grid; scrolling
    -- then settles its visible range without another explicit layout pass.
    self.scrollBox:SetDataProvider(CreateIndexRangeDataProvider(#results))
    local selected
    local target = revealSelection and self.value or retainTexture

    if target then
        local key = Icons.Key(target)

        if results == self.catalogue.entries then
            local entry = self.catalogue.byTexture[key]
            selected = entry and entry.index
        else
            for index, entry in ipairs(results) do
                if Icons.Key(entry.texture) == key then
                    selected = index
                    break
                end
            end
        end
    end

    if #results > 0 then
        self.scrollBox:ScrollToElementDataIndex(
            selected or 1,
            selected and revealSelection and ScrollBoxConstants.AlignCenter
                or ScrollBoxConstants.AlignBegin,
            0,
            ScrollBoxConstants.NoScrollInterpolation
        )
    end

    self.settingResults = nil
    self.loading:Hide()
    self.empty:SetShown(#results == 0)
    self.status:SetText(tostring(#results) .. " icons")
    self.paintPending = true
    self:Wake()
end

function Picker:QueueSearch(delay, retainViewport)
    if not self.session then return end

    if self.searchJob then
        self.searchJob:Cancel()
        self.searchJob = nil
    end

    if not retainViewport then self.retainTexture = nil end

    self.searchDelay = delay
    self:Wake()
end

function Picker:RefreshResults()
    if not self.searchDelay and not self.searchJob then
        local entry = self.results[self.scrollBox:GetDataIndexBegin()]
        self.retainTexture = entry and entry.texture
    end

    self:QueueSearch(0, true)
    self.paintPending = true
end

function Picker:OnMetadataEvent(event, itemID, success)
    if
        self.catalogue
        and lib:_QueuePlayerIconRefresh(self.catalogue, event, itemID, success)
    then
        self.metadataPending = true
        self:Wake()
    end
end

function Picker:RefreshArtworkControls()
    local category = Icons.GetArtworkCategory(self.categoryValue)
    self.category:SetValue(self.categoryValue)
    self.artworkType:SetChoices(category.types)
    self.artworkType:SetValue(self.typeValue)
    self.artworkType:SetControlEnabled(self.categoryValue ~= "all")
end

function Picker:SetArtworkCategory(value)
    Icons.GetArtworkCategory(value)
    self.categoryValue, self.typeValue = value, "all"
    self:RefreshArtworkControls()
    self:QueueSearch(0)
end

function Picker:SetArtworkType(value)
    Icons.GetArtworkFilter(self.categoryValue, value)
    self.typeValue = value
    self.artworkType:SetValue(value)
    self:QueueSearch(0)
end

function Picker:StartSearch()
    local kind = self.filterValue
    local query = strtrim(self.search:GetText() or "")
    local artworkFilter =
        Icons.GetArtworkFilter(self.categoryValue, self.typeValue)
    local entries, filter

    if kind == "all" and query == "" and not artworkFilter then
        self:SetResults(self.catalogue.entries, self.revealSelection)
        self.revealSelection = nil
        return
    elseif kind == "recent" or kind == "favorites" then
        entries = self.historyEntries[kind]
    elseif kind == "suggested" then
        entries = self.suggested
    else
        for _, definition in ipairs(self.filters) do
            if definition.value == kind then
                filter = definition.match
                break
            end
        end
    end

    if filter and artworkFilter then
        local sourceFilter = filter

        filter = function(entry, catalogue)
            return sourceFilter(entry, catalogue)
                and artworkFilter(entry, catalogue)
        end
    else
        filter = filter or artworkFilter
    end

    self.searchJob = self.catalogue:BeginSearch(query, filter, entries)
    self.status:SetText("Searching…")
end

function Picker:Update(elapsed)
    if not self:Validate() then return end

    if self.resize then
        if IsMouseButtonDown("LeftButton") then
            self:UpdateResize()
        else
            self:EndResize()
        end
    end

    if self.opening then
        -- OnUpdate can run before the first paint of a newly shown frame.
        -- Yield this update so chrome/loading feedback reaches the screen first.
        self.opening = nil
        return
    end

    if self.preparing then
        if not self.catalogue then
            self.catalogue = lib:_AdvanceIconCatalogue()
            return
        end

        local session = self.session
        self.catalogue:AddIcon({ texture = session.defaultIcon or 134400 })

        if self.value then self.catalogue:AddIcon({ texture = self.value }) end

        self.suggested = self.catalogue:AddIcons(session.suggestedIcons or {})
        self.preparing = nil

        if self.includePlayerIcons then self:OnMetadataEvent() end

        self:QueueSearch(0)
    end

    if self.metadataPending then
        self.metadataPending = nil

        if self.includePlayerIcons then
            lib:_RefreshPlayerIconCatalogue(self.catalogue)
        end
    end

    local revision = self.catalogue.playerRevision or 0

    if self.playerRevision ~= revision then
        self.playerRevision = revision
        self:RefreshResults()
    end

    if
        self.historyPending
        or self.historyRevision ~= (self.history.revision or 0)
    then
        self.historyPending = nil
        self:RefreshHistory()

        if self.filterValue == "recent" or self.filterValue == "favorites" then
            self:RefreshResults()
        end
    end

    if self.searchDelay then
        self.searchDelay = self.searchDelay - elapsed

        if self.searchDelay <= 0 then
            self.searchDelay = nil
            self:StartSearch()
        end
    end

    if self.searchJob then
        local started = debugprofilestop()

        for _ = 1, 16 do
            if self.searchJob:Step(128) then
                local job = self.searchJob
                self.searchJob = nil
                self:SetResults(job.results, self.revealSelection)
                self.revealSelection = nil
                break
            end

            if debugprofilestop() - started >= 3 then break end
        end
    end

    if self.shelvesPending then
        self.shelvesPending = nil
        self:RefreshShelves()
    end

    if self.paintPending then
        self.paintPending = nil
        self:Paint()
    end

    if
        not self.searchDelay
        and not self.searchJob
        and not self.metadataPending
        and not self.historyPending
        and not self.shelvesPending
        and not self.paintPending
        and not self.resize
    then
        self.frame:SetScript("OnUpdate", nil)
    end
end

-- Consumers can extend their catalogue while a window is open. Re-evaluate the
-- current filter/query and keep the visible artwork when it still matches.
function Picker:Refresh()
    if self:Validate() then
        if self.includePlayerIcons then self:OnMetadataEvent() end

        self.historyPending = true
        self:RefreshResults()
    end
end

function Picker:Apply()
    local session = self.session

    if
        not self:Validate()
        or not self.input:CommitAndClearFocus()
        or self.inputError
        or self.session ~= session
    then
        return false
    end

    local value = self.value
    local accepted, message = session.onApply(value)

    if accepted == false then
        if self.session == session and message then self:Error(message) end

        return false
    end

    self.history:Record(value)

    if self.session == session then self:Close(true) end

    return true
end

function Picker:Close(applied)
    local session = self.session
    self.session, self.value = nil, nil

    if self.searchJob then self.searchJob:Cancel() end

    self.searchJob, self.searchDelay, self.metadataPending = nil, nil, nil
    self.paintPending, self.shelvesPending, self.historyPending = nil, nil, nil
    self.preparing, self.opening = nil, nil
    self.retainTexture = nil
    self.resize = nil
    self.frame:SetScript("OnUpdate", nil)
    self.frame:UnregisterAllEvents()
    self.frame:StopMovingOrSizing()
    self.input:CancelAndClearFocus()
    self.search:ClearFocus()
    self.dropTarget:Hide()
    self.loading:Hide()
    self.frame:Hide()

    if session and session.onClose then session.onClose(applied == true) end
end

function Picker:Open(options)
    assert(
        type(options) == "table" and type(options.onApply) == "function",
        "icon picker Open requires an onApply function"
    )

    for _, key in ipairs({ "addonName", "sourceName" }) do
        assert(
            type(options[key]) == "string" and options[key] ~= "",
            key .. " must be non-empty text"
        )
    end

    for _, key in ipairs({ "isValid", "onClose" }) do
        assert(
            options[key] == nil or type(options[key]) == "function",
            key .. " must be a function"
        )
    end

    if InCombatLockdown() then return false end

    local value, message = Icons.Normalize(options.value)
    assert(not message, message)
    self:Close()

    if self.session then return false end

    self.session = {}

    for key, option in pairs(options) do
        self.session[key] = option
    end

    if not self:Validate() then return false end

    self.catalogue = self.catalogue or lib._defaultIconCatalogue
    self.preparing, self.opening = true, true
    self.historyPending = true
    self.results = {}
    self.scrollBox:SetDataProvider(CreateIndexRangeDataProvider(0))
    self.empty:Hide()
    self.preview:Hide()

    for _, shelf in pairs(self.shelves) do
        shelf.visibleCount = 0

        for _, button in ipairs(shelf.buttons) do
            button:Hide()
        end

        shelf.placeholder:Show()
        shelf.empty:Hide()
    end

    self.status:SetText("Loading icons…")
    self.loading:Show()

    if not self.rememberFilters then self:ResetBrowseFilters() end

    self.frame:SetTitle(
        "Choose icon for " .. options.addonName .. " / " .. options.sourceName
    )
    self.frame:SetScale(
        math.min(
            1,
            (UIParent:GetHeight() - 32) / self.frame:GetHeight(),
            (UIParent:GetWidth() - 32) / self.frame:GetWidth()
        )
    )
    self.frame:Show()
    self.frame:Raise()
    self.frame:SetPropagateKeyboardInput(true)
    self:SetValue(value)
    self.revealSelection = true
    self:UpdateCursor()

    for index, event in ipairs(EVENTS) do
        if index <= 2 or self.includePlayerIcons then
            self.frame:RegisterEvent(event)
        end
    end

    return true
end

function lib:CreateIconPicker(parent, options)
    assert(not InCombatLockdown(), "create icon pickers outside combat")
    options = options or {}
    local filters, seen = {}, {}

    for _, definitions in ipairs({ Icons.Filters, options.extraFilters or {} }) do
        for _, definition in ipairs(definitions) do
            local copy = {}

            for key, value in pairs(definition) do
                copy[key] = value
            end

            if copy.type ~= "title" and copy.type ~= "divider" then
                assert(
                    type(copy.value) == "string" and not seen[copy.value],
                    "icon filters require unique string values"
                )
                assert(
                    copy.match == nil or type(copy.match) == "function",
                    "icon filter match must be a function"
                )
                seen[copy.value] = true
            end

            filters[#filters + 1] = copy
        end
    end

    local picker = setmetatable({
        history = options.history or self:CreateIconHistory(),
        catalogue = options.catalogue,
        includePlayerIcons = options.includePlayerIcons == true
            or (
                options.catalogue == nil
                and options.includePlayerIcons ~= false
            ),
        results = {},
        favorites = {},
        shelves = {},
        filters = filters,
        searchIconTexture = options.searchIconTexture,
        clearIconTexture = options.clearIconTexture,
        caretIconTexture = options.caretIconTexture,
        rememberFilters = options.rememberFilters == true,
        categoryValue = "all",
        typeValue = "all",
    }, Picker)
    Icons.CreateBrowser(picker, parent or UIParent)
    picker:ResetBrowseFilters()
    return picker
end
