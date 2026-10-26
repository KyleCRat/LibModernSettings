return function(lib, makeFrame)
    local original = { r = 1, g = 0, b = 0, a = 0.4 }
    local blue = { r = 0, g = 0, b = 1, a = 0.6 }
    local defaultColor = { r = 1, g = 0.85, b = 0.2, a = 0.8 }
    local events = {}
    local saved, control

    local function equal(actual, expected)
        for _, channel in ipairs({ "r", "g", "b", "a" }) do
            assert(
                math.abs(actual[channel] - expected[channel]) < 0.000001,
                channel .. " differs"
            )
        end
    end

    for _, invalid in ipairs({
        true,
        false,
        "default",
        1,
        {},
    }) do
        assert(
            not pcall(
                lib.CreateColor,
                lib,
                makeFrame("Frame"),
                { defaultColor = invalid }
            )
        )
    end

    local legacy = lib:CreateColor(makeFrame("Frame"), { classColor = true })
    assert(legacy:GetValue().mode == "custom" and not legacy.buttons.default)
    assert(
        legacy.buttons.class.point[4] == 0
            and legacy.buttons.custom.point[4] == 38
    )
    assert(not pcall(legacy.SetValue, legacy, {
        r = 1,
        g = 1,
        b = 1,
        mode = "default",
    }))

    local initial =
        lib:CreateColor(makeFrame("Frame"), { defaultColor = defaultColor })
    assert(
        initial:GetValue().mode == "default"
            and initial.buttons.default:IsSelected()
    )
    assert(
        initial:GetValue().a == 1,
        "RGB-only default sources must remain opaque"
    )

    local parent = makeFrame("Frame")
    parent:SetSize(500, 200)
    lib:EnableTabNavigation(parent)
    control = lib:CreateColor(parent, {
        value = original,
        hasOpacity = true,
        defaultColor = function()
            return defaultColor
        end,
        classColor = true,
        accentColor = blue,
        palette = lib:CreateColorPalette(),
        onChanged = function(value)
            saved = value
            events[#events + 1] = value.mode
            -- A settings consumer saves the whole value and rebinds the control.
            control:SetValue(value)
        end,
        onPreview = function(value)
            events[#events + 1] = value and "preview" or "end"
        end,
    })
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    assert(
        control:GetValue().mode == "custom",
        "an explicit value takes priority over the default mode"
    )

    for index, mode in ipairs({ "default", "class", "accent", "custom" }) do
        assert(control.buttons[mode].point[4] == (index - 1) * 38)
    end

    assert(#events == 0)

    control.buttons.default:Click()
    local picker = lib._colorPicker
    assert(saved.mode == "default" and not picker.session)
    equal(saved, defaultColor)
    equal(saved.custom, original)
    assert(
        control.buttons.default:IsSelected()
            and not control.buttons.custom:IsSelected()
    )
    local copy = control:GetValue()
    copy.r = 0
    copy.custom.r = 0
    equal(control:GetValue(), defaultColor)
    equal(control:GetValue().custom, original)
    assert(original.r == 1 and defaultColor.r == 1)

    control.buttons.class:Click()
    assert(saved.mode == "class")
    equal(saved, C_ClassColor.GetClassColor())
    equal(saved.custom, original)
    control.buttons.default:Click()
    control.buttons.custom:Click()
    assert(saved.mode == "custom" and picker.session.owner == control)
    equal(picker.session.original, original)
    picker:SetColor(blue)
    local count = #events
    picker:Cancel()
    assert(#events == count + 1 and events[#events] == "end")
    assert(
        control:GetValue().mode == "custom",
        "Cancel keeps the selected Custom mode"
    )
    equal(control:GetValue(), original)
    assert(#control.palette:GetColors("recent") == 0)

    control:OpenPicker()
    picker:SetColor(blue)
    count = #events
    control.buttons.default:Click()
    assert(not picker.session and #events == count + 2)
    assert(
        events[count + 1] == "end" and events[count + 2] == "default",
        "choosing Default must discard the live draft before committing its mode"
    )
    equal(saved.custom, original)
    control.buttons.custom:Click()
    equal(picker.session.original, original)
    picker:SetColor(blue)
    count = #events
    picker:Apply()
    assert(
        #events == count + 2
            and events[count + 1] == "end"
            and events[count + 2] == "custom"
    )
    equal(control:GetValue(), blue)
    assert(#control.palette:GetColors("recent") == 1)

    control.buttons.default:Click()
    local restored = lib:CreateColor(makeFrame("Frame"), {
        value = saved,
        hasOpacity = true,
        defaultColor = defaultColor,
    })
    assert(restored:GetValue().mode == "default")
    equal(restored:GetValue().custom, blue)
    count = #events
    defaultColor = { r = 0.6, g = 0.85, b = 1, a = 1 }
    control:RefreshColors()
    equal(control:GetValue(), defaultColor)
    equal(control.buttons.default.color, defaultColor)
    equal(control:GetValue().custom, blue)
    assert(#events == count and not picker.session)

    control.buttons.default:_FocusForTab()
    assert(lib:_HandleNavigationKey(control.buttons.default, "TAB"))
    assert(lib._navigationKeyboardFrame.control == control.buttons.class)
    assert(
        control:GetValue().mode == "default",
        "focus must not change the chosen color mode"
    )
    assert(lib:_HandleNavigationKey(control.buttons.class, "SPACE"))
    assert(control:GetValue().mode == "class")
    control.buttons.default:_FocusForTab()
    assert(lib:_HandleNavigationKey(control.buttons.default, "ENTER"))
    assert(control:GetValue().mode == "default" and not picker.session)

    control.buttons.custom:Click()
    picker:SetColor(original)
    control:RefreshColors()
    assert(
        picker.session.owner == control,
        "refreshing sources must not discard a Custom draft"
    )
    equal(picker.color, original)
    control:SetControlEnabled(false)
    assert(not picker.session and events[#events] == "end")

    for _, button in pairs(control.buttons) do
        assert(not button:IsEnabled())
    end

    control:OpenPicker()
    assert(not picker.session)
    equal(control:GetValue(), blue)
    control:SetControlEnabled(true)
    control:SetValue(restored:GetValue())
    count = #events

    -- Retained optional and legacy inputs must survive a compatible embed upgrade.
    local mask = control.buttons.default.swatchMask
    local minor = lib._implementationMinor
    lib._loadedModules["Controls/Color"] = nil
    dofile("Controls/Color.lua")
    assert(control:GetValue().mode == "default" and #events == count)
    assert(
        control.buttons.default.swatchMask == mask
            and #control.buttons.default.swatch.masks == 1
    )
    equal(control:GetValue(), defaultColor)
    equal(control:GetValue().custom, blue)
    assert(not legacy.buttons.default and legacy.buttons.custom.point[4] == 38)
    local factory = lib._controlTypes.color.factory
    lib._loadedModules["Controls/Color"] = nil
    lib._implementationMinor = minor + 1
    dofile("Controls/Color.lua")
    assert(
        lib._controlTypes.color.factory == factory,
        "an older embed must not replace the Default-capable control"
    )
    lib._implementationMinor = minor
    lib._loadedModules["Controls/Color"] = minor
    lib:_ClearNavigationFocus()
    print("LibModernSettings default color source tests passed")
end
