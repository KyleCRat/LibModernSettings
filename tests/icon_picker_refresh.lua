return function(lib, inputState)
    local originals = {}
    for _, name in ipairs({
        "C_SpellBook", "C_Container", "GetInventoryItemID",
        "GetInventoryItemTexture", "GetInventoryItemLink",
    }) do
        originals[name] = _G[name]
    end
    local counts = { spells = 0, equipment = 0, bags = 0, history = 0, searches = 0, shelves = 0 }
    local function resetCounts()
        for key in pairs(counts) do
            counts[key] = 0
        end
    end
    local spellName = "Known spell"
    local equipment = { id = 2222, texture = 2002, name = "Known equipment" }
    local bags = {
        { id = 3333, texture = 2003, name = "Known potion" },
        { id = 3334, texture = 2001, name = "Shared spell icon item" },
    }
    local function itemLink(item)
        return item.name and ("|Hitem:" .. item.id .. "|h[" .. item.name .. "]|h") or nil
    end
    C_SpellBook = {
        GetNumSpellBookSkillLines = function()
            counts.spells = counts.spells + 1
            return 1
        end,
        GetSpellBookSkillLineInfo = function()
            return { itemIndexOffset = 0, numSpellBookItems = 1 }
        end,
        GetSpellBookItemInfo = function()
            return { iconID = 2001, name = spellName, spellID = 1111 }
        end,
    }
    function GetInventoryItemID(_, slot)
        counts.equipment = counts.equipment + 1
        return slot == INVSLOT_FIRST_EQUIPPED and equipment and equipment.id or nil
    end
    function GetInventoryItemTexture()
        return equipment.texture
    end
    function GetInventoryItemLink()
        return itemLink(equipment)
    end
    C_Container = {
        GetContainerNumSlots = function(bag)
            counts.bags = counts.bags + 1
            return bag == Enum.BagIndex.Backpack and #bags or 0
        end,
        GetContainerItemInfo = function(_, slot)
            local item = bags[slot]
            return { itemID = item.id, iconFileID = item.texture, hyperlink = itemLink(item) }
        end,
    }

    local entries = {}
    for index = 1, 1000 do
        entries[index] = { texture = index, name = "Artwork " .. index }
    end
    local catalogue = lib:CreateIconCatalogue({ icons = entries })
    local saved = { recent = { 10, 20 }, favorites = { 20 } }
    local history = lib:CreateIconHistory({
        get = function()
            counts.history = counts.history + 1
            return saved
        end,
        set = function(value)
            saved = value
        end,
    })
    local options = {
        addonName = "Test",
        sourceName = "Refresh ownership",
        value = 900,
        onApply = function()
            error("refreshes must not commit a draft")
        end,
    }
    local function makePicker()
        local picker = lib:CreateIconPicker(UIParent, {
            catalogue = catalogue,
            includePlayerIcons = true,
            history = history,
        })
        for _, shelf in pairs(picker.shelves) do
            shelf:SetWidth(400)
        end
        local startSearch = picker.StartSearch
        function picker:StartSearch()
            counts.searches = counts.searches + 1
            return startSearch(self)
        end
        local refreshShelves = picker.RefreshShelves
        function picker:RefreshShelves()
            counts.shelves = counts.shelves + 1
            return refreshShelves(self)
        end
        picker:Open(options)
        picker:Update(0.2)
        picker:Update(0.2)
        return picker
    end
    local function event(picker, name, ...)
        picker.frame:GetScript("OnEvent")(picker.frame, name, ...)
    end
    local function settle(picker)
        for _ = 1, 80 do
            if not picker.frame:GetScript("OnUpdate") then
                return
            end
            picker:Update(0.2)
        end
        error("picker did not become idle")
    end
    local picker = makePicker()
    assert(counts.spells == 1 and counts.history == 1)
    assert(catalogue.byTexture[2001].tags.myspells and catalogue.byTexture[2002].tags.equipped
        and catalogue.byTexture[2003].tags.bags)
    assert(catalogue.byTexture[2001].name == "Known spell" and catalogue.byTexture[2001].tags.bags,
        "shared artwork must retain deterministic spellbook/equipment/bag naming order")
    picker.search:SetText("artwork")
    picker:Update(0.2)
    local job = picker.searchJob
    assert(job and job.nextIndex == 129)
    resetCounts()
    for index = 1, 10 do
        event(picker, "GET_ITEM_INFO_RECEIVED", 999000 + index, true)
        picker:Update(0.2)
    end
    assert(not job.cancelled and job.nextIndex > 129 and counts.searches == 0
        and counts.spells == 0 and counts.equipment == 0 and counts.bags == 0,
        "unrelated item notifications must not rescan sources or restart an active search")
    settle(picker)
    assert(#picker.results == 1000)
    event(picker, "GET_ITEM_INFO_RECEIVED", 3333, true)
    assert(not picker.frame:GetScript("OnUpdate"), "already named items must not wake an idle picker")

    picker.search:SetText("unmatched review query")
    picker:Update(0.2)
    job = picker.searchJob
    resetCounts()
    for _ = 1, 20 do
        event(picker, "BAG_UPDATE_DELAYED")
    end
    picker:Update(0.2)
    local bagCount = 1 + NUM_BAG_SLOTS + NUM_REAGENTBAG_SLOTS
    assert(counts.bags == bagCount and counts.spells == 0 and counts.equipment == 0)
    assert(picker.searchJob == job and not job.cancelled and counts.searches == 0,
        "coalesced unchanged bag contents must preserve the in-flight search")
    resetCounts()
    event(picker, "PLAYER_EQUIPMENT_CHANGED", INVSLOT_FIRST_EQUIPPED)
    picker:Update(0.2)
    assert(counts.equipment > 0 and counts.bags == 0 and counts.spells == 0 and counts.searches == 0)
    resetCounts()
    event(picker, "SPELLS_CHANGED")
    picker:Update(0.2)
    assert(counts.spells == 1 and counts.bags == 0 and counts.equipment == 0 and counts.searches == 0)
    bags = {}
    event(picker, "BAG_UPDATE_DELAYED")
    picker:Update(0.2)
    assert(job.cancelled and counts.searches == 1 and not catalogue.byTexture[2003].tags.bags
        and catalogue.byTexture[2002].tags.equipped,
        "a real membership change must restart the search and preserve other source tags")

    -- Names may arrive after an item appears. Only its source should retry,
    -- and unrelated, failed, repeated or obsolete completions do no work.
    picker.search:SetText("")
    settle(picker)
    bags = { { id = 4444, texture = 2004 }, equipment }
    event(picker, "BAG_UPDATE_DELAYED")
    settle(picker)
    assert(catalogue.playerSources.bags.pendingItems[4444])
    assert(catalogue.byTexture[2002].tags.equipped and catalogue.byTexture[2002].tags.bags)
    resetCounts()
    event(picker, "GET_ITEM_INFO_RECEIVED", 4444, false)
    event(picker, "GET_ITEM_INFO_RECEIVED", 9999, true)
    assert(not picker.frame:GetScript("OnUpdate"))
    bags[1].name = "Loaded potion"
    event(picker, "GET_ITEM_INFO_RECEIVED", 4444, true)
    settle(picker)
    assert(counts.bags == bagCount and counts.spells == 0 and counts.equipment == 0 and counts.searches == 1)
    assert(catalogue.byTexture[2004].name == "Loaded potion"
        and not catalogue.playerSources.bags.pendingItems[4444])
    resetCounts()
    event(picker, "GET_ITEM_INFO_RECEIVED", 4444, true)
    assert(not picker.frame:GetScript("OnUpdate") and counts.bags == 0)
    bags = { { id = 5555, texture = 2005 } }
    event(picker, "BAG_UPDATE_DELAYED")
    settle(picker)
    bags = {}
    event(picker, "BAG_UPDATE_DELAYED")
    settle(picker)
    event(picker, "GET_ITEM_INFO_RECEIVED", 5555, true)
    assert(not picker.frame:GetScript("OnUpdate") and not catalogue.byTexture[2002].tags.bags
        and catalogue.byTexture[2002].tags.equipped)
    equipment = { id = 7777, texture = 2007 }
    event(picker, "PLAYER_EQUIPMENT_CHANGED", INVSLOT_FIRST_EQUIPPED)
    settle(picker)
    assert(catalogue.playerSources.equipped.pendingItems[7777])
    equipment.name = "Loaded equipment"
    resetCounts()
    event(picker, "GET_ITEM_INFO_RECEIVED", 7777, true)
    settle(picker)
    assert(counts.equipment > 0 and counts.spells == 0 and counts.bags == 0
        and catalogue.byTexture[2007].name == "Loaded equipment")

    -- Two open windows share acquisition, but each refreshes its own query.
    local second = makePicker()
    for _, window in ipairs({ picker, second }) do
        window.search:SetText("artwork")
        window:Update(0.2)
    end
    local firstJob, secondJob = picker.searchJob, second.searchJob
    spellName = "Changed spell name"
    event(picker, "SPELLS_CHANGED")
    event(second, "SPELLS_CHANGED")
    resetCounts()
    picker:Update(0.2)
    second:Update(0.2)
    assert(counts.spells == 1 and counts.equipment == 0 and counts.bags == 0
        and counts.searches == 2 and firstJob.cancelled and secondJob.cancelled,
        "simultaneous pickers must consume one shared metadata refresh")
    settle(picker)
    second:Close()
    picker.search:SetText("")
    settle(picker)

    resetCounts()
    for index = 1, 20 do
        picker:SetValue(800 + index)
        picker:Update(0.2)
    end
    assert(counts.history == 0 and counts.shelves == 0,
        "selection changes must paint cached shelves without history reads or layout")
    picker:SetValue(20)
    settle(picker)
    assert(picker.shelves.recent.buttons[2]:IsSelected() and picker.shelves.favorites.buttons[1]:IsSelected()
        and not picker.shelves.recent.buttons[1]:IsSelected())
    picker.shelfWidth = picker.frame:GetWidth()
    resetCounts()
    for index = 1, 20 do
        picker.frame:GetScript("OnSizeChanged")(picker.frame, picker.shelfWidth, picker.frame:GetHeight() + index)
        picker:Update(0.2)
    end
    assert(counts.history == 0 and counts.shelves == 0,
        "height-only resizing must not read history or relayout the horizontal shelves")
    for _, shelf in pairs(picker.shelves) do
        shelf:SetWidth(444)
    end
    picker.frame:GetScript("OnSizeChanged")(picker.frame, picker.shelfWidth + 44, picker.frame:GetHeight())
    settle(picker)
    assert(counts.history == 0 and counts.shelves == 1,
        "width changes must lay out cached history without rereading storage")
    picker:ToggleFavorite(30)
    resetCounts()
    settle(picker)
    assert(counts.history == 1 and picker.favorites[30]
        and picker.shelves.favorites.buttons[2].entry.texture == 30)
    history:ToggleFavorite(40)
    resetCounts()
    picker:SetValue(40)
    settle(picker)
    assert(counts.history == 1 and picker.favorites[40],
        "an active picker must notice edits through a shared history object")
    saved.favorites = { 50 }
    picker:Refresh()
    resetCounts()
    settle(picker)
    assert(counts.history == 1 and picker.favorites[50] and not picker.favorites[40],
        "explicit refresh must reread externally changed storage")
    local normalize, normalized = lib._iconUtils.Normalize, 0
    lib._iconUtils.Normalize = function(value)
        normalized = normalized + 1
        return normalize(value)
    end
    history:GetIcons("recent")
    lib._iconUtils.Normalize = normalize
    assert(normalized == #saved.recent, "reading one history list must not normalize the other list")

    local before = picker.scrollBox.fullUpdates
    picker:SetResults(catalogue.entries, true)
    assert(picker.scrollBox.fullUpdates - before == 2,
        "provider replacement and scrolling already perform their native updates")
    before = picker.scrollBox.fullUpdates
    picker:SetResults({}, false)
    assert(picker.scrollBox.fullUpdates - before == 1, "empty results need only the provider's native update")
    picker:Close()
    resetCounts()
    lib:_QueuePlayerIconRefresh(catalogue)
    inputState.inCombat = true
    lib:_RefreshPlayerIconCatalogue(catalogue)
    inputState.inCombat = false
    assert(counts.spells == 0 and counts.equipment == 0 and counts.bags == 0
        and catalogue.playerRefresh, "combat must defer queued scans without discarding them")
    for name, original in pairs(originals) do
        _G[name] = original
    end
    print("Icon picker refresh checks: unrelated events 0 scans/restarts; 20 selections and 20 height changes 0 history reads/layouts")
end
