return function(lib)
    dofile("IconPicker/Filters.lua")
    local Icons = lib._iconUtils
    local catalogue = lib:CreateIconCatalogue()
    local nextTexture = 1

    local function matches(category, kind, filename, name)
        local entry = catalogue:AddIcon({
            texture = nextTexture,
            filename = filename,
            name = name,
        })
        nextTexture = nextTexture + 1
        return Icons.GetArtworkFilter(category, kind)(entry, catalogue)
    end

    assert(
        matches("equipment", "head", "Interface\\Icons\\INV_Helm_Plate_Red.blp")
    )
    assert(matches("equipment", "back", "INV_Cape_Cloth_Blue"))
    assert(matches("equipment", "daggers", "INV_Knife_1H_Green"))
    assert(matches("equipment", "offhands", "INV_OffHand_1H"))
    assert(matches("equipment", "polearms", "INV_WarGlaive_Purple"))
    assert(matches("creatures", "mounts", "INV_StegodonPrimalMount_Blue"))
    assert(matches("classes", "evoker", "INV_Pant_Mail_RaidEvokerUlatek_D_01"))
    assert(matches("classes", "deathknight", "Spell_DeathKnight_Rune"))
    assert(matches("classes", "deathknight", "Spell_Deathknight_Rune"))
    assert(matches("classes", "demonhunter", "Classicon_DemonHunter_Void_256"))
    assert(not matches("classes", "hunter", "Classicon_DemonHunter_Void_256"))
    assert(not matches("classes", "mage", "Spell_Damage"))
    assert(matches("crafting", "mining", "INV_Ore_Copper"))
    assert(not matches("crafting", "mining", "Ability_Mount_CoreHound"))
    assert(not matches("crafting", "mining", "Ability_Mount_Sporebat"))
    assert(matches("magic", "frost", "Spell_Ice_Bolt"))
    assert(not matches("magic", "frost", "Spell_Holy_Justice"))
    assert(not matches("equipment", "ranged", "INV_Rainbow_Blue"))
    assert(
        matches(
            "achievements",
            "raids",
            "INV_112_Achievement_Raid_ManaforgeOmega"
        )
    )
    assert(not matches("achievements", "raids", "INV_Helm_Plate_Raid"))
    assert(matches("achievements", "all", "Achievement_Unknown_Category"))
    assert(matches("colors", "blue", "INV_StegodonPrimalMount_Blue"))
    assert(not matches("colors", "blue", "INV_Unknown", "Blue spell"))
    assert(not matches("magic", "holy", "INV_Unknown", "Holy Light"))
    assert(not matches("colors", "all", "FileData ID 123", "Red icon"))
    assert(matches("symbols", "interface", "Interface\\Icons\\UI_Chat.blp"))
    assert(matches("symbols", "interface", "UI_AllianceIcon"))
    assert(
        not matches(
            "symbols",
            "interface",
            "INV_12PH_Folk_801_Parttion_Pillar_Icon"
        )
    )
    assert(not matches("symbols", "interface", "INV_Icon_Feather01e"))
    assert(not matches("symbols", "all", "INV_Icon_Feather01e"))
    assert(not matches("symbols", "interface", "INV_UI_Icon_Feather"))

    for _, filename in ipairs({
        "INV_Ammo_Arrow_01",
        "Ability_Hunter_MarkedForDeath",
        "Ability_Poisons",
        "Ability_Rogue_MarkedForDeath",
        "UI_Arrow",
        "UI-RaidTargetingIcon_8",
    }) do
        assert(
            not matches("symbols", "markers", filename),
            "raid markers must match exact file IDs, not suggestive filenames"
        )
    end

    local nativeCatalogue = lib:GetIconCatalogue()

    for id = 137001, 137008 do
        local marker = nativeCatalogue.byTexture[id]
        assert(
            Icons.GetArtworkFilter("symbols", "markers")(
                marker,
                nativeCatalogue
            )
        )
        assert(
            Icons.GetArtworkFilter("symbols", "all")(marker, nativeCatalogue)
        )
        assert(
            not Icons.GetArtworkFilter("equipment", "all")(
                marker,
                nativeCatalogue
            )
        )
    end

    for id = 6033345, 6033354 do
        local number = nativeCatalogue.byTexture[id]
        assert(
            Icons.GetArtworkFilter("symbols", "numbers")(
                number,
                nativeCatalogue
            )
        )
        assert(
            Icons.GetArtworkFilter("symbols", "all")(number, nativeCatalogue)
        )
        assert(
            not Icons.GetArtworkFilter("symbols", "markers")(
                number,
                nativeCatalogue
            )
        )
    end

    assert(Icons.GetArtworkFilter("all", "all") == nil)
    assert(not pcall(Icons.GetArtworkFilter, "all", "head"))
    assert(not pcall(Icons.GetArtworkCategory, "not-a-category"))

    local entry =
        catalogue:AddIcon({ texture = nextTexture, filename = "INV_Helm_Red" })
    local isHelm = Icons.GetArtworkFilter("equipment", "head")
    local isDagger = Icons.GetArtworkFilter("equipment", "daggers")
    assert(isHelm(entry, catalogue) and not isDagger(entry, catalogue))
    catalogue:AddIcon({ texture = nextTexture, name = "A new dagger alias" })
    assert(
        isHelm(entry, catalogue) and not isDagger(entry, catalogue),
        "session-discovered names must not change filename classifications"
    )
    catalogue:AddIcon({ texture = nextTexture, filename = "INV_Knife_Blue" })
    assert(
        not isHelm(entry, catalogue) and isDagger(entry, catalogue),
        "replacing supplied filenames must invalidate classification words"
    )

    -- Exercise every type against the shipped names, without spell/item caches.
    -- This catches spelling/tokenization mistakes that make whole menus empty.
    local snapshot = lib:CreateIconCatalogue()

    for _, block in ipairs(lib._iconNameIndex.blocks) do
        for id, name in pairs(block.names) do
            snapshot:AddIcon({ texture = id, filename = name })
        end
    end
    -- Raid-target artwork lives outside Interface/Icons in the listfile.
    -- Include the same native additions as the live browser.
    for id = 137001, 137008 do
        local marker = nativeCatalogue.byTexture[id]
        snapshot:AddIcon({ texture = id, filename = marker.filename })
    end

    local markers =
        snapshot:BeginSearch("", Icons.GetArtworkFilter("symbols", "markers"))

    -- Step advances the iterator; drain it to completion.
    -- selene: allow(empty_loop)
    while not markers:Step(128) do
    end

    assert(
        #markers.results == 8,
        "Raid markers must contain exactly the eight native markers"
    )

    for _, definition in ipairs(Icons.GetArtworkCategory("symbols").types) do
        if definition.value == "markers" then
            assert(definition.label == "Raid markers")
            assert(definition.tooltip:find("Only the eight", 1, true))
        end
    end

    local categoryValues, typeCount = {}, 0

    for _, category in ipairs(Icons.ArtworkCategories) do
        assert(not categoryValues[category.value] and category.tooltip)
        categoryValues[category.value] = true
        local typeValues = {}

        for _, kind in ipairs(category.types) do
            if kind.value then
                assert(not typeValues[kind.value])
                typeValues[kind.value] = true

                if kind.value ~= "all" then
                    typeCount = typeCount + 1
                    assert(kind.tooltip)
                    local search = snapshot:BeginSearch(
                        "",
                        Icons.GetArtworkFilter(category.value, kind.value)
                    )

                    -- Step performs the search work before reporting completion.
                    -- selene: allow(empty_loop)
                    while not search:Step(128) do
                    end

                    assert(
                        #search.results > 0,
                        category.value
                            .. "/"
                            .. kind.value
                            .. " matched no bundled names"
                    )

                    for _, result in ipairs(search.results) do
                        assert(
                            category.match(result, snapshot),
                            "a type must stay within its category"
                        )
                    end
                end
            end
        end
    end

    print(
        "LibModernSettings artwork filters passed against "
            .. #snapshot.entries
            .. " names across "
            .. typeCount
            .. " types"
    )
end
