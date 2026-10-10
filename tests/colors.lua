return function(lib, makeFrame, inputState)
    function CreateColor(r, g, b, a)
        return { r = r, g = g, b = b, a = a or 1 }
    end
    function UnitClass()
        return "Mage", "MAGE"
    end
    C_ClassColor = { GetClassColor = function()
        return CreateColor(0.25, 0.75, 1)
    end }
    RAID_CLASS_COLORS = {
        MAGE = C_ClassColor.GetClassColor(),
        WARRIOR = CreateColor(0.78, 0.61, 0.43),
        ADVENTURER = CreateColor(0.67, 0.83, 0.45),
        TRAVELER = CreateColor(0.53, 0.53, 0.93),
    }
    CLASS_SORT_ORDER = { "WARRIOR", "MAGE" }
    LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", WARRIOR = "Warrior" }
    Enum = Enum or {}
    Enum.ItemQuality = {
        Poor = 0,
        Common = 1,
        Uncommon = 2,
        Rare = 3,
        Epic = 4,
        Legendary = 5,
        Artifact = 6,
        Heirloom = 7,
        WoWToken = 8,
    }
    local qualityColors = {
        [0] = CreateColor(157 / 255, 157 / 255, 157 / 255),
        [1] = CreateColor(1, 1, 1),
        [2] = CreateColor(30 / 255, 1, 0),
        [3] = CreateColor(0, 112 / 255, 221 / 255),
        [4] = CreateColor(163 / 255, 53 / 255, 238 / 255),
        [5] = CreateColor(1, 128 / 255, 0),
        [6] = CreateColor(230 / 255, 204 / 255, 128 / 255),
        [7] = CreateColor(0, 0.8, 1),
        [8] = CreateColor(0, 0.8, 1),
    }
    for name, quality in pairs(Enum.ItemQuality) do
        _G["ITEM_QUALITY" .. quality .. "_DESC"] = name
    end
    C_Item = { GetItemQualityColor = function(quality)
        local color = assert(qualityColors[quality], "invalid item quality")
        return color.r, color.g, color.b
    end }
    UISpecialFrames = {}
    function ButtonFrameTemplate_HidePortrait(frame)
        frame.portraitHidden = true
    end
    local cursorX, cursorY = 0, 0
    function GetCursorPosition()
        return cursorX, cursorY
    end

    dofile("Utilities/Color.lua")
    dofile("Controls/Color.lua")
    dofile("Utilities/ColorPicker.lua")
    local Color = lib._colorUtils
    local function equalColor(actual, expected)
        for _, channel in ipairs({ "r", "g", "b", "a" }) do
            assert(math.abs(actual[channel] - expected[channel]) < 0.000001, "color differs: " .. channel)
        end
    end
    local red = CreateColor(1, 0, 0, 0.4)
    local blue = CreateColor(0, 0, 1)
    local green = CreateColor(0, 1, 0)

    for _, color in ipairs({ red, blue, green, CreateColor(0, 0, 0), CreateColor(1, 1, 1), CreateColor(0.4, 0.2, 0.8) }) do
        local h, s, v = Color.ToHSV(color)
        local r, g, b = Color.FromHSV(h, s, v)
        equalColor(CreateColor(r, g, b, color.a), color)
    end
    assert(Color.Hex(red, true) == "FF000066")
    assert(Color.Hex(red) == "FF0000")
    equalColor(Color.ParseHex(" #ff0000 ", 0.4), red)
    equalColor(Color.ParseHex("FF0000", 0.4), red)
    assert(Color.ParseHex("FF0000", 0).a == 0)
    assert(Color.ParseHex("FF0000").a == 1)
    equalColor(Color.ParseHex("FF000066", 1), red)
    equalColor(Color.ParseHex(" #ff000066 ", 1), red)
    equalColor(Color.ParseHex("33669980", 1), CreateColor(0.2, 0.4, 0.6, 128 / 255))
    assert(Color.ParseHex("FF000000", 1).a == 0)
    assert(Color.ParseHex("FF0000FF", 0).a == 1)
    assert(not Color.ParseHex("FF0000F", 0.4))
    assert(not Color.ParseHex("#FF0000F", 0.4))
    assert(not Color.ParseHex("FF0000660", 0.4))
    assert(not Color.ParseHex("FF0000GG", 0.4))
    assert(not Color.ParseHex("FF00GG", 1))
    assert(not Color.ParseHex("12345", 1))
    assert(not pcall(Color.Copy, { r = 0 / 0, g = 0, b = 0 }))
    assert(not pcall(Color.Copy, { r = math.huge, g = 0, b = 0 }))
    assert(Color.Copy(red, false).a == 1)

    local saved = { recent = {}, favorites = {} }
    local palette = lib:CreateColorPalette({
        maxRecent = 2,
        maxFavorites = 2,
        get = function() return saved end,
        set = function(value) saved = value end,
    })
    local original = saved
    palette:Record(red)
    palette:Record(blue)
    palette:Record(red)
    assert(#original.recent == 0, "palette mutated a database-owned table")
    assert(#saved.recent == 2 and saved.recent[1].r == 1)
    palette:Record(green)
    assert(#saved.recent == 2 and saved.recent[2].r == 1)
    local copy = palette:GetColors("recent")
    copy[1].r = 1
    assert(saved.recent[1].r == 0)
    assert(palette:ToggleFavorite(red) == true)
    assert(palette:ToggleFavorite(blue) == true)
    assert(palette:ToggleFavorite(green) == nil, "full favorites must not silently evict a saved color")
    assert(palette:ToggleFavorite(red) == false)
    assert(palette:ToggleFavorite(green) == true)
    assert(not pcall(function() lib:CreateColorPalette({ get = function() end }) end))

    lib:_ClearNavigationFocus()
    if inputState.keyboardFocus then
        inputState.keyboardFocus:ClearFocus()
    end
    local parent = makeFrame("Frame")
    parent:SetSize(700, 900)
    lib:EnableTabNavigation(parent)
    local notifications = {}
    local accent = CreateColor(1, 0.8, 0)
    local control = lib:CreateColor(parent, {
        value = red,
        label = "Test color",
        width = 300,
        hasOpacity = true,
        classColor = true,
        accentColor = function() return accent end,
        palette = palette,
        onChanged = function(value) notifications[#notifications + 1] = value end,
    })
    control:SetOnChanged(function(value)
        notifications[#notifications + 1] = value
        -- Consumers commonly save the callback value and refresh the input.
        control:SetValue(value)
    end)
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    assert(control.buttons.custom.selection:IsShown())
    assert(not control.buttons.class.selection:IsShown())
    assert(control.buttons.accent.point[4] == 38)
    assert(control.buttons.custom.point[4] == 76)
    assert(#notifications == 0)
    local returned = control:GetValue()
    returned.r = 0
    assert(control:GetValue().r == 1 and red.r == 1)
    assert(not pcall(function() control:SetValue({ r = 1, g = 1, b = 1, mode = "unknown" }) end))
    control.buttons.class:Click()
    assert(control:GetValue().mode == "class")
    equalColor(control:GetValue(), C_ClassColor.GetClassColor())
    assert(control.buttons.class.selection:IsShown())
    equalColor(control.buttons.custom.color, red)
    equalColor(control:GetValue().custom, red)
    local preset = control:GetValue()
    preset.custom.r = 0
    equalColor(control:GetValue().custom, red)
    control.buttons.accent:Click()
    assert(control:GetValue().mode == "accent")
    equalColor(control:GetValue(), accent)
    accent = CreateColor(0.2, 0.3, 0.4)
    control:RefreshColors()
    equalColor(control:GetValue(), accent)
    equalColor(control.buttons.custom.color, red)

    local restored = lib:CreateColor(makeFrame("Frame"), {
        value = control:GetValue(),
        hasOpacity = true,
        classColor = true,
        accentColor = accent,
    })
    assert(restored:GetValue().mode == "accent")
    equalColor(restored.buttons.custom.color, red)
    restored:Hide()

    control.buttons.custom:Click()
    local picker = lib._colorPicker
    local count = #notifications
    assert(control:GetValue().mode == "custom")
    assert(picker.session.owner == control)
    assert(picker.opacity:IsShown() and picker.inputs.a:IsShown())
    assert(picker.hex:HasFocus())
    assert(#picker.messages.messages == 0)
    assert(#picker.classColors == 2, "Class must contain playable classes only")
    assert(#picker.qualityColors == 9, "Quality must contain all item qualities")
    assert(picker.classColors[1].label == "Mage" and picker.classColors[2].label == "Warrior")
    for quality = Enum.ItemQuality.Poor, Enum.ItemQuality.WoWToken do
        local entry = picker.qualityColors[quality + 1]
        equalColor(entry.color, qualityColors[quality])
        assert(entry.label == _G["ITEM_QUALITY" .. quality .. "_DESC"])
    end
    equalColor(picker.session.original, red)
    assert(picker.hex:GetValue() == "FF0000")
    picker:SetColor(blue)
    assert(#notifications == count, "pending picker edits must not change the consumer")
    picker:Cancel()
    equalColor(control:GetValue(), red)
    assert(control:GetValue().mode == "custom")
    assert(not picker.session and not picker.frame:IsShown())
    assert(lib._navigationKeyboardFrame.control == control.buttons.custom)

    control:OpenPicker()
    assert(lib._colorPicker == picker, "reuse the picker")
    picker.hex:SetText("#FF0000")
    picker:Apply()
    equalColor(control:GetValue(), red)
    assert(#notifications == count + 1)
    assert(saved.recent[1].r == 1 and saved.recent[1].a == 0.4)
    assert(lib._navigationKeyboardFrame.control == control.buttons.custom)

    control:OpenPicker()
    picker.hex:ClearFocus()
    picker.opacity:_HandleSliderValueChanged(60)
    assert(picker.hex:GetValue() == "FF0000" and picker.color.a == 0.6)
    picker.hex:SetFocus()
    picker.hex:SetText("0000FF")
    picker:Apply()
    local translucentBlue = CreateColor(0, 0, 1, 0.6)
    equalColor(control:GetValue(), translucentBlue)
    control.buttons.class:Click()
    equalColor(control.buttons.custom.color, translucentBlue)
    control.buttons.custom:Click()
    equalColor(picker.session.original, translucentBlue)
    picker:SetColor(green)
    picker:Cancel()
    equalColor(control:GetValue(), translucentBlue)
    control:SetValue(red)

    control:OpenPicker()
    picker.hex:SetText("#33669980")
    assert(picker.hex:CommitAndClearFocus())
    local pastedColor = CreateColor(0.2, 0.4, 0.6, 128 / 255)
    equalColor(picker.color, pastedColor)
    assert(picker.hex:GetValue() == "336699")
    assert(picker.opacity:GetValue() == 50)
    assert(picker.inputs.a:GetValue() == "50")
    equalColor(control:GetValue(), red)
    picker:Apply()
    equalColor(control:GetValue(), pastedColor)

    control:OpenPicker()
    picker.hex:SetText("11223300")
    assert(picker.hex:CommitAndClearFocus())
    assert(picker.hex:GetValue() == "112233" and picker.opacity:GetValue() == 0)
    picker:Cancel()
    equalColor(control:GetValue(), pastedColor)
    control:SetValue(red)

    control:OpenPicker()
    local pickerHeight = picker.frame:GetHeight()
    picker.hex:SetText("1234567")
    picker:Apply()
    assert(picker.session and #picker.messages.messages == 1)
    assert(picker.messages.messages[1].message:find("RRGGBB"))
    assert(picker.frame:GetHeight() == pickerHeight, "validation errors must not resize the picker")
    assert(picker.hex:HasFocus(), "invalid hex must retain focus")
    local errorInput = picker.errorInput
    picker.messages.messages[1].close:Click()
    assert(picker.session and picker.hex:HasFocus() and #picker.messages.messages == 0)
    assert(picker.errorInput == errorInput, "dismissing feedback must not change validation state")
    picker.hex:SetText("00FF00")
    picker:Apply()
    assert(control:GetValue().g == 1 and control:GetValue().a == 0.4)

    do
        control:OpenPicker()
        picker.hex:SetText("1234567")
        picker.hex.scripts.OnEnterPressed(picker.hex)
        assert(picker.inputError and picker.hex:HasFocus())
        local messages = picker.messages
        local notice = assert(messages.messages[1])
        local update = assert(messages.frame:GetScript("OnUpdate"))
        update(messages.frame, 1)

        picker.hex.scripts.OnTabPressed(picker.hex)
        assert(inputState.keyboardFocus ~= picker.hex)
        assert(messages.messages[1] == notice,
            "committing on Tab must not dismiss an existing flash message")
        picker:CommitInputs()
        picker.inputs.r:FocusValue()
        picker.inputs.r:SetText("128")
        picker.inputs.r.scripts.OnEnterPressed(picker.inputs.r)
        assert(not picker.inputError and not picker.errorInput)
        assert(messages.messages[1] == notice,
            "valid submission must clear validation state without dismissing feedback")

        picker.opacity:_HandleSliderValueChanged(60)
        picker:SetHSV(0.2, 0.4, 0.8)
        picker.classes.buttons[1]:Click()
        picker:RefreshPalettes()
        assert(#messages.messages == 1 and messages.messages[1] == notice and notice.age == 1,
            "color changes and palette refreshes must preserve the message and its lifetime")
        update(messages.frame, messages.duration - 1 + messages.fadeDuration / 2)
        assert(messages.messages[1] == notice and notice.frame.alpha > 0 and notice.frame.alpha < 1)
        update(messages.frame, messages.fadeDuration)
        assert(#messages.messages == 0 and not messages.frame:GetScript("OnUpdate"))
        picker:Cancel()
    end

    control:OpenPicker()
    picker.hex:ClearFocus()
    picker.inputs.r:SetFocus()
    picker.inputs.r:SetText("256")
    picker:Apply()
    assert(picker.session, "invalid RGB must not apply")
    assert(picker.inputs.r:HasFocus(), "invalid channels must retain focus")
    picker.inputs.r:SetText("128")
    picker:Apply()
    assert(math.abs(control:GetValue().r - 128 / 255) < 0.000001)

    for _, case in ipairs({
        { input = picker.hex, value = "1234567" },
        { input = picker.inputs.r, value = "256" },
    }) do
        control:OpenPicker()
        picker.hex:CancelAndClearFocus()
        case.input:FocusValue()
        case.input:SetText(case.value)
        local isMouseButtonDown = IsMouseButtonDown
        IsMouseButtonDown = function()
            return true
        end
        case.input:ClearFocus()
        IsMouseButtonDown = isMouseButtonDown
        assert(lib._pendingEditBoxCommits[case.input], "mouse-down must defer validation")
        picker.apply:Click()
        assert(picker.session and #picker.messages.messages == 1, "invalid mouse Apply must stay open")
        assert(case.input:HasFocus() and inputState.keyboardFocus == case.input,
            "failed Apply must restore focus to the field that reported the error")
        assert(not lib._pendingEditBoxCommits[case.input])
        case.input.scripts.OnTabPressed(case.input)
        assert(inputState.keyboardFocus and inputState.keyboardFocus ~= case.input,
            "Tab must work after failed mouse Apply")
        picker.cancel:Click()
        assert(#picker.messages.messages == 0 and not picker.messages.frame:GetScript("OnUpdate"),
            "closing the picker must clear its notifications")
        assert(not picker.session and lib._navigationKeyboardFrame.control == control.buttons.custom,
            "Cancel must restore the owning input's focus after a validation error")
    end

    control:OpenPicker()
    picker.hex:ClearFocus()
    picker.inputs.a:SetFocus()
    picker.inputs.a:SetText("25.5")
    picker:Apply()
    assert(control:GetValue().a == 0.26)
    control:OpenPicker()
    picker.hex:ClearFocus()
    picker.opacity.valueBox:SetFocus()
    picker.opacity.valueBox:SetText("150")
    picker:Apply()
    assert(control:GetValue().a == 1)
    control:OpenPicker()
    picker:SetColor(red)
    picker.previous:Click()
    equalColor(picker.color, picker.session.original)
    picker.classes.buttons[1]:Click()
    assert(picker.color.a == picker.session.original.a)
    picker.frame:Hide()
    picker.frame.scripts.OnHide(picker.frame)
    assert(not picker.session, "native X/Escape hides must discard the draft")

    control:OpenPicker()
    picker:SetColor(blue)
    count = #notifications
    control:SetValue(green)
    assert(not picker.session)
    assert(#notifications == count)
    picker:Cancel()
    equalColor(control:GetValue(), green)
    control:OpenPicker()
    control:SetControlEnabled(false)
    assert(not picker.session and not control.buttons.custom:IsEnabled())
    control:OpenPicker()
    assert(not picker.session)
    control:SetControlEnabled(true)
    control:OpenPicker()
    control:Hide()
    control.scripts.OnHide(control)
    assert(not picker.session and #notifications == count)
    control:Show()

    local rgb = lib:CreateColor(parent, { value = red })
    rgb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -50)
    rgb:OpenPicker()
    assert(not picker.opacity:IsShown() and not picker.inputs.a:IsShown())
    assert(picker.color.a == 1 and #picker.hex:GetValue() == 6)
    picker.hex:SetText("33669900")
    assert(picker.hex:CommitAndClearFocus())
    equalColor(picker.color, CreateColor(0.2, 0.4, 0.6, 1))
    assert(picker.hex:GetValue() == "336699")
    local recentBefore = #rgb.palette:GetColors("recent")
    picker:SetColor(blue)
    picker.current:Click("RightButton")
    assert(#rgb.palette:GetColors("favorites") == 1)
    picker:Cancel()
    assert(#rgb.palette:GetColors("recent") == recentBefore)
    assert(#rgb.palette:GetColors("favorites") == 1)

    do
        local swatches = lib:CreateColor(makeFrame("Frame"), {
            value = red,
            hasOpacity = true,
            palette = lib:CreateColorPalette(),
        })
        swatches:OpenPicker()
        local emptyHeight = picker.frame:GetHeight()
        local emptyRowHeight = picker.favorites.frame:GetHeight()
        local columns = picker.favorites.columns
        local favorites = {}
        for index = 1, columns + 1 do
            favorites[index] = CreateColor(index / 20, 0.2, 0.3, 0.4)
            picker:ToggleFavorite(favorites[index])
            if index <= columns then
                assert(picker.frame:GetHeight() == emptyHeight, "first-row favorites must not resize the picker")
                assert(picker.favorites.frame:GetHeight() == emptyRowHeight)
            end
        end
        assert(picker.frame:GetHeight() > emptyHeight, "the next favorite must add a second row")
        picker:ToggleFavorite(favorites[columns + 1])
        assert(picker.frame:GetHeight() == emptyHeight)
        for index = 1, columns do
            picker:ToggleFavorite(favorites[index])
        end
        assert(picker.frame:GetHeight() == emptyHeight and picker.favorites.empty:IsShown())

        local quality = picker.qualities.buttons[Enum.ItemQuality.Epic + 1]
        quality:Click()
        local expected = Color.Copy(qualityColors[Enum.ItemQuality.Epic])
        expected.a = red.a
        equalColor(picker.color, expected)
        equalColor(swatches:GetValue(), red)
        quality:Click("RightButton")
        assert(#swatches.palette:GetColors("favorites") == 1)
        assert(picker.frame:GetHeight() == emptyHeight)
        picker:Apply()
        equalColor(swatches:GetValue(), expected)
        swatches:Hide()
    end

    control:OpenPicker()
    local oldSession = picker.session
    rgb:OpenPicker()
    lib:_CloseColorPicker(oldSession.owner, true)
    assert(picker.session.owner == rgb, "an old owner must not close or apply another input's picker")
    picker:Cancel()
    rgb.buttons.custom:_FocusForTab()
    assert(lib:_HandleNavigationKey(rgb.buttons.custom, "SPACE"))
    assert(picker.session.owner == rgb)
    picker:Cancel()
    assert(lib:_HandleNavigationKey(rgb.buttons.custom, "TAB"))
    assert(lib._navigationKeyboardFrame.control == control.buttons.class)
    assert(control.buttons.class.selection:IsShown() == false)

    -- Grayscale edits preserve hue, and mouse sampling clamps to the square.
    rgb:OpenPicker()
    picker:SetHSV(0.75, 0.7, 0.6)
    picker:SetColor(CreateColor(0.5, 0.5, 0.5))
    assert(picker.hue == 0.75)
    cursorX = picker.square:GetLeft() + 1000
    cursorY = picker.square:GetTop() + 1000
    picker.square.scripts.OnMouseDown(picker.square, "LeftButton")
    assert(picker.saturation == 1 and picker.brightness == 1)
    rgb:ClosePicker()
    assert(not picker.square:GetScript("OnUpdate"))

    -- Existing instances and palette objects keep dispatching after a compatible reload.
    local methods = lib._colorPalettePrototype
    local originalPrototype = lib._colorPickerPrototype
    for _, module in ipairs({ "Utilities/Color", "Controls/Color", "Utilities/ColorPicker" }) do
        lib._loadedModules[module] = nil
        dofile(module .. ".lua")
    end
    assert(lib._colorPalettePrototype == methods and lib._colorPickerPrototype == originalPrototype)
    rgb:SetValue(blue)
    rgb:OpenPicker()
    assert(lib._colorPicker == picker and picker.session.owner == rgb)
    picker:Cancel()
    lib:_ClearNavigationFocus()
    local factory = lib._controlTypes.color.factory
    lib._implementationMinor = 9
    dofile("Controls/Color.lua")
    assert(lib._controlTypes.color.factory == factory, "an older embed must not replace a newer control")
    lib._implementationMinor = 8
    print("LibModernSettings color picker tests passed")
end
