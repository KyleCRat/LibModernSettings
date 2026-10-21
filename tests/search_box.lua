return function(lib, makeFrame, inputState)
    dofile("Controls/SearchBox.lua")
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local changes, lastValue, lastUserInput = 0, nil, nil
    local input = lib:CreateSearchBox(root, {
        value = "initial",
        placeholder = "Find icons",
        searchIconTexture = "Test\\Search.tga",
        clearIconTexture = "Test\\Close.tga",
        onChanged = function(value, userInput)
            changes = changes + 1
            lastValue, lastUserInput = value, userInput
        end,
    })
    assert(input.template == "SearchBoxNineSliceTemplate")
    assert(input.clearButton._libModernSettingsControlType == "button")
    assert(input.clearButton:GetNormalTexture().atlas == "common-button-tertiary-square-normal")
    assert(input.clearButton.pushedTexture.atlas == "common-button-tertiary-square-pressed")
    assert(input.clearButton.icon.texture == "Test\\Close.tga")
    assert(input.searchIcon.texture == "Test\\Search.tga")
    local dropdown = lib:CreateDropdown(UIParent, { choices = { { value = 1, label = "First" } } }).dropdown
    local square = dropdown.arrowBackground
    assert(input.clearButton:GetWidth() == square:GetWidth() and input.clearButton:GetHeight() == square:GetHeight())
    assert(input.clearButton:GetWidth() == 26 and input.clearButton:GetHeight() == 26)
    assert(input.clearButton.icon:GetWidth() == dropdown.Arrow:GetWidth())
    assert(input.clearButton.icon:GetHeight() == dropdown.Arrow:GetHeight())
    assert(input.clearButton:GetNormalTexture().atlas == square.atlas)
    for _, index in ipairs({ 1, 3, 4, 5 }) do
        assert(select(index, input.clearButton:GetPoint(1)) == select(index, square:GetPoint(1)),
            "search clear and dropdown squares must use the same inset and alignment")
    end
    assert(input.textInsets[1] == 30 and input.textInsets[2] == 34,
        "text and placeholder space must clear both custom icons")
    assert(input:GetValue() == "initial" and changes == 0 and input.clearButton:IsShown())
    assert(input.Instructions.text == "Find icons" and input:GetHeight() == 34)
    assert(not input.Instructions:IsShown())
    input:SetValue("")
    assert(changes == 0 and input.Instructions:IsShown() and not input.clearButton:IsShown())
    input:FocusValue()
    assert(input:HasFocus() and input.focusTexture:IsShown() and input.clearButton:IsShown())

    -- Simulate user typing; native SetText is a programmatic change.
    input.text = "typed"
    input:GetScript("OnTextChanged")(input, true)
    assert(input:GetValue() == "typed" and changes == 1 and lastValue == "typed" and lastUserInput)
    input.clearButton:Click()
    assert(input:GetValue() == "" and changes == 2 and lastValue == "" and not lastUserInput)
    assert(not input:HasFocus() and not input.focusTexture:IsShown() and not input.clearButton:IsShown())
    input:SetText("direct")
    assert(input:GetValue() == "direct" and changes == 3 and not lastUserInput)
    input:SetText("direct")
    assert(changes == 3, "unchanged text must not repeat the search")
    input:SetValue("silent")
    assert(changes == 3 and input:GetValue() == "silent")
    input:SetControlEnabled(false, "Unavailable")
    assert(not input:IsEnabled() and not input.clearButton:IsEnabled() and not input.focusTexture:IsShown())
    input.clearButton:Click()
    assert(changes == 3 and input:GetValue() == "silent")
    input:SetControlEnabled(true)
    assert(input.clearButton:IsEnabled())

    local nextInput = lib:CreateTextInput(root, {})
    input:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    nextInput:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
    input:FocusValue()
    input:GetScript("OnTabPressed")(input)
    assert(lib._navigationKeyboardFrame.control == input.clearButton and not input:HasFocus())
    lib:_HandleNavigationKey(input.clearButton, "TAB")
    assert(nextInput:HasFocus() and not input:HasFocus() and input:GetValue() == "silent")
    inputState.modifiers.shift = true
    nextInput:GetScript("OnTabPressed")(nextInput)
    assert(lib._navigationKeyboardFrame.control == input.clearButton)
    lib:_HandleNavigationKey(input.clearButton, "TAB")
    inputState.modifiers.shift = false
    assert(input:HasFocus())
    input:GetScript("OnEnterPressed")(input)
    assert(not input:HasFocus() and input:GetValue() == "silent" and changes == 3)
    input:FocusValue()
    input:GetScript("OnEscapePressed")(input)
    assert(not input:HasFocus() and input:GetValue() == "silent")

    input:SetOnChanged(function(value)
        changes = changes + 1
        input:SetValue(value:upper())
    end)
    input:SetText("normalize")
    assert(changes == 4 and input:GetValue() == "NORMALIZE",
        "consumer normalization through SetValue must not recurse")

    local clearButton, focusTexture = input.clearButton, input.focusTexture
    local nativeTextChanged = input.baseScripts.OnTextChanged
    local hooks = #input.scriptHooks.OnTextChanged
    lib._loadedModules["Controls/SearchBox"] = nil
    dofile("Controls/SearchBox.lua")
    assert(input.clearButton == clearButton and input.focusTexture == focusTexture)
    assert(clearButton:GetWidth() == square:GetWidth() and clearButton:GetHeight() == square:GetHeight())
    assert(input.clearButton.icon.texture == "Test\\Close.tga"
        and input.searchIcon.texture == "Test\\Search.tga")
    assert(input.baseScripts.OnTextChanged == nativeTextChanged and #input.scriptHooks.OnTextChanged == hooks)
    assert(input:GetValue() == "NORMALIZE" and changes == 4)
    input:SetText("upgrade")
    assert(input:GetValue() == "UPGRADE" and changes == 5)

    input:SetOnChanged(nil)
    input:SetValue("")
    assert(input.Instructions:IsShown() and changes == 5)
    local nativeArtwork = lib:CreateSearchBox(UIParent, {})
    assert(nativeArtwork.searchIcon.atlas == "common-searchbar-icon-a")
    assert(nativeArtwork.clearButton.icon.atlas == "common-search-clearbutton")
    assert(not nativeArtwork.clearButton:IsShown() and nativeArtwork.Instructions:IsShown())
    local tall = lib:CreateSearchBox(UIParent, { height = 50 })
    assert(tall.clearButton:GetWidth() == square:GetWidth() and tall.clearButton:GetHeight() == square:GetHeight(),
        "a taller search input must not enlarge its inset action square")
    local fileIDs = lib:CreateSearchBox(UIParent, { searchIconTexture = 1, clearIconTexture = 2 })
    assert(fileIDs.searchIcon.texture == 1 and fileIDs.clearButton.icon.texture == 2)
    for key, value in pairs({
        value = false,
        placeholder = false,
        onChanged = "bad",
        maxLetters = -1,
        width = 0,
        height = -1,
        searchIconTexture = false,
        clearIconTexture = {},
    }) do
        assert(not pcall(lib.CreateSearchBox, lib, root, { [key] = value }), key .. " should reject invalid options")
    end
    assert(not pcall(input.SetValue, input, 1))
    assert(not pcall(input.SetOnChanged, input, "bad"))
    print("LibModernSettings search box tests passed")
end
