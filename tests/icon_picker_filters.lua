return function(lib, setCursor)
    local catalogue = lib:CreateIconCatalogue({
        icons = {
            {
                texture = 201,
                filename = "INV_Helm_Red",
                tags = { "item", "bags" },
            },
            {
                texture = 202,
                filename = "INV_Dagger_Blue",
                tags = { "item", "bags" },
            },
            {
                texture = 203,
                filename = "INV_Dagger_Red",
                tags = { "item", "equipped" },
            },
        },
    })

    local function createPicker()
        local picker = lib:CreateIconPicker(UIParent, {
            catalogue = catalogue,
            rememberFilters = true,
        })

        for _, shelf in pairs(picker.shelves) do
            shelf:SetWidth(400)
        end

        return picker
    end

    local function results(picker, ...)
        for _ = 1, 16 do
            picker:Update(0.2)
        end

        local expected = { ... }
        assert(not picker.searchJob and #picker.results == #expected)

        for index, texture in ipairs(expected) do
            assert(picker.results[index].texture == texture)
        end
    end

    local function source(picker, value)
        picker.filter:SetValue(value)
        picker.filter._libModernSettingsOnChanged(value)
    end

    local function checkFilters(picker)
        assert(
            picker.filter:GetValue() == "bags"
                and picker.category:GetValue() == "equipment"
        )
        assert(
            picker.artworkType:GetValue() == "daggers"
                and picker.artworkType.dropdown:IsEnabled()
        )
        assert(
            picker.search:GetText() == "blue"
                and picker.search.clearButton:IsShown()
        )
    end

    local writes, saved = 0, nil
    local options = {
        addonName = "Test",
        sourceName = "First aura",
        value = 201,
        defaultIcon = 201,
        suggestedIcons = { { texture = 201 } },
        onApply = function(value)
            writes, saved = writes + 1, value
        end,
    }
    local picker = createPicker()
    picker:Open(options)
    results(picker, 201, 202, 203)
    source(picker, "bags")
    picker:SetArtworkCategory("equipment")
    picker:SetArtworkType("daggers")
    picker.search:SetText("blue")
    picker:SetValue(202)
    picker:Close()
    assert(
        writes == 0 and not picker.frame:GetScript("OnUpdate"),
        "closing before the search runs must discard the draft and stop work"
    )

    options.sourceName, options.value = "Another aura", 203
    options.suggestedIcons = { { texture = 203 } }
    picker:Open(options)
    checkFilters(picker)
    assert(
        picker:GetValue() == 203
            and picker.frame.title == "Choose icon for Test / Another aura",
        "remembered filters must not retain the previous editing owner or icon draft"
    )
    results(picker, 202)

    local other = createPicker()
    other:Open(options)
    assert(
        other.filter:GetValue() == "all"
            and other.category:GetValue() == "all"
            and other.artworkType:GetValue() == "all"
            and other.search:GetText() == "",
        "new picker instances must start clean, without sharing browse state"
    )
    results(other, 201, 202, 203)
    other:Close()
    checkFilters(picker)

    assert(picker:Reset() and picker:GetValue() == nil)
    checkFilters(picker)
    picker:SetValue(202)
    assert(picker:Apply() and writes == 1 and saved == 202)
    picker:Open(options)
    checkFilters(picker)
    results(picker, 202)

    source(picker, "suggested")
    picker:SetArtworkCategory("all")
    picker.search.clearButton:Click()
    results(picker, 203)
    picker:Close()
    options.suggestedIcons = { { texture = 201 } }
    picker:Open(options)
    results(picker, 201)
    assert(
        picker.filter:GetValue() == "suggested",
        "retained Suggested filtering must use the current owner's suggestions"
    )

    source(picker, "bags")
    picker:SetArtworkCategory("equipment")
    picker:SetArtworkType("daggers")
    picker.search:SetText("blue")
    setCursor({ "item", 100 })
    picker:ReceiveDrag()
    assert(picker:GetValue() == 101)
    picker:Close()
    picker:Open(options)
    assert(
        picker.filter:GetValue() == "all"
            and picker.category:GetValue() == "all"
            and picker.artworkType:GetValue() == "all"
            and not picker.artworkType.dropdown:IsEnabled()
            and picker.search:GetText() == "",
        "accepted drops must clear remembered filters on subsequent openings too"
    )
    results(picker, 201, 202, 203, 101)
    picker:Close()
    print("LibModernSettings icon picker remembered-filter tests passed")
end
