return function(lib, inputState)
    local cursor
    function GetCursorInfo()
        return unpack(cursor or {})
    end
    function ClearCursor()
        cursor = nil
    end
    C_Item.GetItemIconByID = function(id)
        assert(id == 100)
        return 101
    end
    C_Spell = { GetSpellTexture = function(id)
        assert(id == 200, "cursor spells use the spell ID, not the spellbook slot")
        return 201
    end }
    C_MountJournal = { GetMountInfoByID = function()
        return nil, nil, 301
    end }
    C_PetJournal = { GetPetInfoByPetID = function()
        return nil, nil, nil, nil, nil, nil, nil, nil, 401
    end }
    function GetMacroInfo()
        return "Macro", 501
    end
    C_EquipmentSet = {
        GetEquipmentSetID = function(name)
            assert(name == "Equipment")
            return 600
        end,
        GetEquipmentSetInfo = function(id)
            assert(id == 600)
            return "Equipment", 601
        end,
    }
    C_TransmogOutfitInfo = { GetOutfitInfo = function()
        return { icon = 701 }
    end }
    dofile("IconPicker/Sources.lua")
    for _, sample in ipairs({
        { { "item", 100 }, 101 },
        { { "spell", 4, "spell", 200 }, 201 },
        { { "petaction", 200 }, 201 },
        { { "mount", 300 }, 301 },
        { { "battlepet", "GUID" }, 401 },
        { { "macro", 500 }, 501 },
        { { "equipmentset", 600 }, 601 },
        { { "equipmentset", "Equipment" }, 601 },
        { { "outfit", 700 }, 701 },
    }) do
        cursor = sample[1]
        assert(lib:GetCursorIcon() == sample[2])
        assert(cursor ~= nil, "reading a cursor must not clear it")
    end
    cursor = { "unknown", 100 }
    local icon, message = lib:GetCursorIcon()
    assert(not icon and message)
    inputState.inCombat = true
    cursor = { "item", 100 }
    assert(lib:GetCursorIcon() == nil)
    inputState.inCombat = false
    cursor = nil
    assert(lib:GetCursorIcon() == nil)

    local calls = 0
    function GetMacroIcons(values)
        calls = calls + 1
        values[1], values[2], values[3], values[4] = 10, 20, 137008, 6033345
    end
    GetMacroItemIcons = GetMacroIcons
    function GetLooseMacroIcons(values)
        calls = calls + 1
        values[1] = "test"
    end
    GetLooseMacroItemIcons = GetLooseMacroIcons
    function GetFileIDFromPath(path)
        local marker = path:match("^Interface\\TargetingFrame\\UI%-RaidTargetingIcon_([1-8])$")
        if marker then
            return 137000 + tonumber(marker)
        end
        assert(path == "Interface\\Icons\\test")
        return 10
    end
    C_Texture.GetFilenameFromFileDataID = function()
        return ""
    end
    local catalogue = lib:GetIconCatalogue()
    assert(#catalogue.entries == 21 and calls == 4,
        "native raid markers and numbers must be available and deduplicated with macro artwork")
    assert(lib:GetIconCatalogue() == catalogue and calls == 4)
    assert(catalogue.byTexture[10].tags.spell and catalogue.byTexture[10].tags.item)
    assert(catalogue.byTexture[10].filename == "Interface\\Icons\\test",
        "legacy filenames must survive conversion to file IDs")
    local legacySearch = catalogue:BeginSearch("test")
    assert(legacySearch:Step(100) and #legacySearch.results == 1)
    local markerNames = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
    for index, name in ipairs(markerNames) do
        local entry = catalogue.byTexture[137000 + index]
        assert(entry and entry.name == "Raid target: " .. name)
        assert(entry.filename == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index)
        for _, query in ipairs({ name, "rt" .. index, tostring(137000 + index) }) do
            local markerSearch = catalogue:BeginSearch(query)
            assert(markerSearch:Step(100) and markerSearch.results[1] == entry,
                "native markers must be searchable by name, chat marker and file ID")
        end
    end
    local crossSearch = catalogue:BeginSearch("red x")
    assert(crossSearch:Step(100) and #crossSearch.results == 1
        and crossSearch.results[1].texture == 137007)
    local markerSearch = catalogue:BeginSearch("raid marker")
    assert(markerSearch:Step(100) and #markerSearch.results == 8)
    assert(catalogue.byTexture[137008].tags.spell and catalogue.byTexture[137008].tags.item,
        "adding native metadata must preserve membership supplied by the client")
    for number = 0, 9 do
        local entry = catalogue.byTexture[6033345 + number]
        assert(entry and entry.name == "Number " .. number)
        assert(entry.filename == "Interface\\Icons\\INV_MISC_Number_" .. number)
        local numberSearch = catalogue:BeginSearch(tostring(6033345 + number))
        assert(numberSearch:Step(100) and numberSearch.results[1] == entry,
            "an exact file ID must rank before neighboring numbers matched through typo tolerance")
    end
    local numberSearch = catalogue:BeginSearch("digit nine")
    assert(numberSearch:Step(100) and #numberSearch.results == 1
        and numberSearch.results[1].texture == 6033354)
    Enum.SpellBookSpellBank = { Player = 0 }
    Enum.BagIndex = { Backpack = 0, ReagentBag = 5 }
    NUM_BAG_SLOTS, NUM_REAGENTBAG_SLOTS = 4, 1
    INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED = 1, 1
    C_SpellBook = {
        GetNumSpellBookSkillLines = function()
            return 1
        end,
        GetSpellBookSkillLineInfo = function()
            return { itemIndexOffset = 0, numSpellBookItems = 1 }
        end,
        GetSpellBookItemInfo = function()
            return { iconID = 9001, name = "Known spell", spellID = 1234 }
        end,
    }
    function GetInventoryItemLink()
        return "|Hitem:5678|h[Known equipment]|h"
    end
    function GetInventoryItemTexture()
        return 9002
    end
    function GetInventoryItemID()
        return 5678
    end
    local hasItem = true
    C_Container = {
        GetContainerNumSlots = function(bag)
            return bag == 0 and hasItem and 1 or 0
        end,
        GetContainerItemInfo = function()
            return { iconFileID = 9003, hyperlink = "|Hitem:9999|h[Known potion]|h", itemID = 9999 }
        end,
    }
    lib:_QueuePlayerIconRefresh(catalogue)
    lib:_RefreshPlayerIconCatalogue(catalogue)
    assert(catalogue.byTexture[9001].tags.myspells and catalogue.byTexture[9002].tags.equipped)
    assert(catalogue.byTexture[9003].tags.bags and catalogue.byTexture[9003].name == "Known potion")
    hasItem = false
    inputState.inCombat = true
    lib:_QueuePlayerIconRefresh(catalogue, "BAG_UPDATE_DELAYED")
    lib:_RefreshPlayerIconCatalogue(catalogue)
    assert(catalogue.byTexture[9003].tags.bags, "combat must not scan or rewrite inventory metadata")
    inputState.inCombat = false
    lib:_RefreshPlayerIconCatalogue(catalogue)
    assert(not catalogue.byTexture[9003].tags.bags, "current inventory filters must discard stale membership")
    local search = catalogue:BeginSearch("known potion")
    assert(search:Step(100) and #search.results == 1)
    print("LibModernSettings icon cursor and catalogue tests passed")
    return function(value)
        cursor = value
    end
end
