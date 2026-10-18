return function(lib)
    local changes = {}
    local slider = lib:CreateSlider(nil, {
        minValue = -10,
        maxValue = 10,
        step = 1,
        snapToStep = false,
        value = 1.234567,
        maxLetters = 16,
        onChanged = function(value)
            changes[#changes + 1] = value
        end,
    })
    local input = slider.valueBox
    assert(slider:GetValue() == 1.234567 and input:GetText() == "1.234567")
    assert(#changes == 0, "initialization must preserve precision without notifying")

    slider:SetValue(-2.345678)
    assert(slider:GetValue() == -2.345678 and input:GetText() == "-2.345678")
    assert(#changes == 0, "programmatic updates must not notify")
    input:SetText("3.125")
    slider:_FinalizeInput()
    assert(slider:GetValue() == 3.125 and changes[1] == 3.125)

    input:SetFocus()
    input.scripts.OnArrowPressed(input, "UP")
    assert(slider:GetValue() == 4.125, "arrow input must add a step without rounding the fraction")
    slider.scripts.OnMouseWheel(slider, -1)
    assert(slider:GetValue() == 3.125, "wheel input must retain the same precision")
    input:ClearFocus()

    slider:SetValue(20.375)
    assert(slider:GetValue() == 20.375 and slider.slider.value == 10)
    input:SetText("-20.375")
    slider:_FinalizeInput()
    assert(slider:GetValue() == -20.375 and slider.slider.value == -10)
    slider:_HandleSliderValueChanged(5)
    assert(slider:GetValue() == 5 and input:GetText() == "5")

    local beforeInvalid = #changes
    input:SetText("invalid")
    slider:_FinalizeInput()
    assert(slider:GetValue() == 5 and input:GetText() == "5" and #changes == beforeInvalid)
    for _, invalid in ipairs({ math.huge, -math.huge, 0 / 0 }) do
        assert(not pcall(slider.SetValue, slider, invalid), "exact values must still be finite")
    end

    local named = lib:CreateSlider(nil, {
        minValue = 0,
        maxValue = 10,
        step = 1,
        snapToStep = false,
        value = 0.5,
        valueLabels = { [0] = "Auto", [0.5] = "Half" },
    })
    assert(named.valueBox:GetText() == "Half", "fractional named values must not share an integer step")
    named.valueBox:SetText("auto")
    named:_FinalizeInput()
    assert(named:GetValue() == 0)

    for _, snapping in ipairs({ {}, { snapToStep = true } }) do
        snapping.minValue = 0
        snapping.maxValue = 10
        snapping.step = 1
        snapping.value = 1.25
        local stepped = lib:CreateSlider(nil, snapping)
        assert(stepped:GetValue() == 1, "existing consumers must keep stepped normalization")
        stepped:SetValue(20.75)
        assert(stepped:GetValue() == 21)
        stepped.valueBox:SetText("2.75")
        stepped:_FinalizeInput()
        assert(stepped:GetValue() == 3)
    end

    local ok, message = pcall(lib.CreateSlider, lib, nil, {
        minValue = 0,
        maxValue = 10,
        step = 1,
        snapToStep = "false",
    })
    assert(not ok and message:find("snapToStep"), "invalid precision options must fail at construction")

    print("LibModernSettings slider precision tests passed")
end
