return function(lib, makeFrame)
    local Color = lib._colorUtils
    local original = { r = 1, g = 0, b = 0, a = 0.4 }
    local blue = { r = 0, g = 0, b = 1, a = 0.6 }
    local previews, events = {}, {}
    local applied = 0
    local control

    local function equal(actual, expected)
        for _, channel in ipairs({ "r", "g", "b", "a" }) do
            assert(
                math.abs(actual[channel] - expected[channel]) < 0.000001,
                channel .. " differs"
            )
        end
    end

    local function preview(value)
        previews[#previews + 1] = value and Color.Copy(value) or false
        events[#events + 1] = value and "preview" or "end"

        if value then
            assert(value.mode == "custom")
            value.r = 0.123 -- The callback must not own the picker's draft.
        end
    end

    control = lib:CreateColor(makeFrame("Frame"), {
        value = original,
        hasOpacity = true,
        classColor = true,
        palette = lib:CreateColorPalette(),
        onPreview = preview,
        onChanged = function(value)
            applied = applied + 1
            events[#events + 1] = "apply"
            control:SetValue(value)
        end,
    })
    assert(
        not pcall(
            lib.CreateColor,
            lib,
            makeFrame("Frame"),
            { onPreview = true }
        )
    )
    assert(not pcall(control.SetOnPreview, control, true))
    control:OpenPicker()
    local picker = lib._colorPicker
    assert(#previews == 0, "opening without an edit must not start a preview")
    picker:SetColor(blue)
    equal(previews[#previews], blue)
    equal(picker.color, blue)
    equal(control:GetValue(), original)
    assert(applied == 0 and #control.palette:GetColors("recent") == 0)
    picker:SetColor(blue)
    picker:Sync()
    assert(#previews == 1, "unchanged frames must not repeat previews")

    picker:SetHSV(0.25, 0.5, 0.75)
    equal(previews[#previews], picker.color)
    picker.hex:ClearFocus()
    picker.opacity:_HandleSliderValueChanged(25)
    assert(previews[#previews].a == 0.25)
    picker.hex:FocusValue()
    picker.hex:SetText("33669980")
    assert(picker.hex:CommitAndClearFocus())
    equal(previews[#previews], { r = 0.2, g = 0.4, b = 0.6, a = 128 / 255 })
    picker.inputs.r:FocusValue()
    picker.inputs.r:SetText("64")
    assert(picker.inputs.r:CommitAndClearFocus())
    assert(previews[#previews].r == 64 / 255)
    picker.classes.buttons[1]:Click()
    equal(previews[#previews], picker.color)
    picker.previous:Click()
    equal(previews[#previews], original)
    picker:Cancel()
    assert(previews[#previews] == false and applied == 0)
    equal(control:GetValue(), original)
    assert(#control.palette:GetColors("recent") == 0)
    local count = #previews
    control:ClosePicker()
    control:OpenPicker()
    picker:Cancel()
    assert(
        #previews == count,
        "closing an unchanged picker must not end another preview"
    )

    control:OpenPicker()
    picker:SetColor(blue)
    picker:Apply()
    assert(events[#events - 1] == "end" and events[#events] == "apply")
    equal(control:GetValue(), blue)
    assert(applied == 1 and #control.palette:GetColors("recent") == 1)

    for _, close in ipairs({
        function()
            control:ClosePicker()
        end,
        function()
            picker.frame:Hide()
            picker.frame.scripts.OnHide(picker.frame)
        end,
        function()
            control:Hide()
            control.scripts.OnHide(control)
        end,
        function()
            control:SetControlEnabled(false)
        end,
        function()
            control:SetValue(blue)
        end,
    }) do
        control:Show()
        control:SetControlEnabled(true)
        control:OpenPicker()
        picker:SetColor(original)
        local before = #previews
        close()
        assert(
            not picker.session
                and #previews == before + 1
                and previews[#previews] == false
        )
        equal(control:GetValue(), blue)
        assert(applied == 1)
    end

    control:SetControlEnabled(true)
    control:Show()
    control:OpenPicker()
    picker:SetColor(original)
    local replacement = 0
    control:SetOnPreview(function(value)
        replacement = replacement + 1

        if value then control:SetValue(blue) end
    end)
    assert(
        previews[#previews] == false and replacement == 0 and not picker.session
    )
    control:OpenPicker()
    picker.hex:SetText("00FF00")
    picker:Apply()
    assert(
        not picker.session and replacement == 2,
        "consumer rebinding must end the preview once"
    )
    equal(control:GetValue(), blue)
    assert(applied == 1, "a rebound input must not receive the obsolete Apply")

    control:SetOnPreview(preview)
    control:OpenPicker()
    picker:SetColor(original)
    local rgbPreview
    local rgb = lib:CreateColor(makeFrame("Frame"), {
        value = original,
        onPreview = function(value)
            rgbPreview = value
        end,
    })
    rgb:OpenPicker()
    assert(previews[#previews] == false and picker.session.owner == rgb)
    picker:SetColor(blue)
    assert(rgbPreview.a == 1 and rgbPreview.mode == "custom")
    rgb:ClosePicker()
    assert(rgbPreview == nil)

    control:SetOnPreview(nil)
    count = #previews
    control:OpenPicker()
    picker:SetColor(original)
    picker:Cancel()
    assert(#previews == count)
    lib:_ClearNavigationFocus()
    print("LibModernSettings color preview tests passed")
end
