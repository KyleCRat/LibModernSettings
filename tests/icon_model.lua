return function(lib)
    issecretvalue = issecretvalue or function()
        return false
    end
    dofile("IconPicker/Model.lua")
    local Icons = lib._iconUtils
    assert(Icons.Normalize(" 123 ") == 123)
    assert(Icons.Normalize("Interface/Icons/Test") == "Interface\\Icons\\Test")
    assert(Icons.Normalize("") == nil)
    assert(Icons.Filename("FileData ID 123") == nil)
    assert(Icons.Filename("FileData ID: 123") == nil)
    for _, invalid in ipairs({ 0, -1, 1.5, math.huge, 0 / 0, false, {} }) do
        local value, message = Icons.Normalize(invalid)
        assert(value == nil and message)
    end

    local saved = { recent = { 10, 20, 10 }, favorites = { 20 } }
    local writes = 0
    local history = lib:CreateIconHistory({
        get = function()
            return saved
        end,
        set = function(value)
            saved = value
            writes = writes + 1
        end,
        maxRecent = 2,
        maxFavorites = 2,
    })
    local original = saved
    local copy = history:GetIcons("recent")
    copy[1] = 99
    assert(saved.recent[1] == 10 and #saved.recent == 3)
    history:Record(20)
    assert(saved ~= original and original.recent[1] == 10)
    history:Record(30)
    assert(#saved.recent == 2 and saved.recent[1] == 30 and saved.recent[2] == 20)
    history:Record(nil)
    assert(writes == 2)
    assert(history:ToggleFavorite(30))
    local accepted, message = history:ToggleFavorite(40)
    assert(accepted == nil and message and #saved.favorites == 2)
    assert(history:ToggleFavorite(20) == false and saved.favorites[1] == 30)
    local other = lib:CreateIconHistory()
    assert(#other:GetIcons("recent") == 0)

    local reads = 0
    local catalogue = lib:CreateIconCatalogue({
        getFilename = function(id)
            reads = reads + 1
            return id == 1 and "Interface\\Icons\\Spell_Fire_FlameShock" or ""
        end,
        icons = {
            { texture = 1, name = "Flame Shock", tags = { "spell" } },
            { texture = 2, name = "Mana Potion", tags = { "item" } },
            { texture = "Interface/Icons/Custom", name = "Custom" },
        },
    })
    local entry = catalogue:AddIcon({ texture = 1, name = "Lava", keywords = "shaman damage" })
    assert(#catalogue.entries == 3 and reads == 0)
    catalogue:AddIcon({ texture = "interface\\icons\\CUSTOM", keywords = "other name" })
    assert(#catalogue.entries == 3)
    local search = catalogue:BeginSearch("flmae shok")
    assert(not search:Step(1) and search.nextIndex == 2)
    assert(search:Step(2) and search.results[1] == entry)
    assert(reads == 2)
    search = catalogue:BeginSearch("shaman fire")
    assert(search:Step(3) and #search.results == 1 and reads == 2)
    search = catalogue:BeginSearch("mana", function(value)
        return value.tags.spell
    end)
    assert(search:Step(3) and #search.results == 0)
    search = catalogue:BeginSearch("")
    search:Step(1)
    search:Cancel()
    search:Step(100)
    assert(#search.results == 1 and not search.complete)
    search = catalogue:BeginSearch("", nil, {})
    assert(search:Step(1) and #search.results == 0)
    catalogue:AddIcon({ texture = 1, keywords = "new association" })
    search = catalogue:BeginSearch("association")
    assert(search:Step(3) and #search.results == 1)
    assert(reads == 2, "adding metadata must not repeat filename lookups")
    catalogue:AddIcon({ texture = 2, filename = "Interface\\Icons\\INV_Alchemy_Flask" })
    search = catalogue:BeginSearch("alchemy")
    assert(search:Step(3) and #search.results == 1 and search.results[1].texture == 2)
    assert(reads == 2, "an explicit filename should invalidate search without another lookup")
    local cached = catalogue.byTexture[2].searchText
    local repeated, changed = catalogue:AddIcon({ texture = 2, filename = "Interface\\Icons\\INV_Alchemy_Flask" })
    assert(not changed and repeated.searchText == cached,
        "unchanged metadata must not discard normalized search text or report a change")
    local updated, metadataChanged = catalogue:AddIcon({ texture = 2, keywords = "new alias" })
    assert(metadataChanged and updated == repeated and not updated.searchText)
    assert(not pcall(function()
        search:Step(0)
    end))
    local ranking = lib:CreateIconCatalogue({
        icons = {
            { texture = 1, name = "Storm" },
            { texture = 2, name = "Strom" },
            { texture = 3, name = "Storm" },
        },
    })
    search = ranking:BeginSearch("strom")
    local steps = 0
    repeat
        steps = steps + 1
    until search:Step(1)
    assert(steps > 3, "ranked results must also merge in bounded batches")
    assert(search.results[1].texture == 2, "an exact match must outrank a transposition")
    assert(search.results[2].texture == 1 and search.results[3].texture == 3)
    print("LibModernSettings icon history and search tests passed")
end
