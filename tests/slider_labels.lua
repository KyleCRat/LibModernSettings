return function(lib, inputState)
    local changes = {}
    local labels = { [-1] = "Inherit", [100] = "Full" }
    local slider = lib:CreateSlider(nil, {
        minValue = -1,
        maxValue = 100,
        step = 1,
        value = -1,
        suffix = "%",
        valueLabels = labels,
        onChanged = function(value)
            assert(type(value) == "number", "labels must not change the numeric value contract")
            changes[#changes + 1] = value
        end,
    })
    local input = slider.valueBox
    assert(slider:GetValue() == -1 and input:GetText() == "Inherit")
    assert(input.maxLetters >= #"Inherit", "the input must allow the complete label")
    assert(#changes == 0)

    labels[-1] = "Changed"
    input:SetText("  iNhErIt  ")
    slider:_FinalizeInput()
    assert(input:GetText() == "Inherit" and #changes == 0, "construction must copy the label mapping")

    input:SetText("25%")
    slider:_FinalizeInput()
    assert(slider:GetValue() == 25 and input:GetText() == "25%" and changes[1] == 25)
    input:SetText("FULL")
    slider:_FinalizeInput()
    assert(slider:GetValue() == 100 and input:GetText() == "Full" and changes[2] == 100)
    input:SetText("-1")
    slider:_FinalizeInput()
    assert(slider:GetValue() == -1 and input:GetText() == "Inherit" and changes[3] == -1)
    input:SetText("invalid")
    slider:_FinalizeInput()
    assert(input:GetText() == "Inherit" and #changes == 3)

    slider:SetValue(150)
    assert(slider:GetValue() == 150 and input:GetText() == "150%" and slider.slider.value == 100)
    slider:_HandleSliderValueChanged(-1)
    assert(slider:GetValue() == -1 and input:GetText() == "Inherit" and changes[4] == -1)

    input:SetFocus()
    input.scripts.OnArrowPressed(input, "UP")
    assert(slider:GetValue() == 0 and input:GetText() == "0%")
    slider.scripts.OnMouseWheel(slider, -1)
    assert(slider:GetValue() == -1 and input:GetText() == "Inherit" and input:HasFocus())
    inputState.modifiers.shift = true
    slider.scripts.OnMouseWheel(slider, 1)
    assert(slider:GetValue() == 9, "Shift-wheel must add ten steps from the named value")
    slider.scripts.OnMouseWheel(slider, -1)
    assert(slider:GetValue() == -1)
    inputState.modifiers.control = true
    slider.scripts.OnMouseWheel(slider, 1)
    assert(slider:GetValue() == 49, "Ctrl-wheel must still take priority over Shift")
    slider.scripts.OnMouseWheel(slider, -1)
    assert(slider:GetValue() == -1)
    inputState.modifiers.shift = false
    inputState.modifiers.control = false
    local beforeBlur = #changes
    input:ClearFocus()
    assert(#changes == beforeBlur, "focus loss must not notify twice for a named value")

    -- A named endpoint does not impose new bounds on numeric editing.
    input:SetFocus()
    input.scripts.OnArrowPressed(input, "DOWN")
    assert(slider:GetValue() == -2 and slider.slider.value == -1)
    slider:SetOnChanged(function(value)
        slider:SetValue(math.max(-1, math.min(100, value)))
    end)
    input.scripts.OnArrowPressed(input, "DOWN")
    assert(slider:GetValue() == -1 and input:GetText() == "Inherit")
    input:ClearFocus()

    local custom = lib:CreateSlider(nil, {
        minValue = 0,
        maxValue = 100,
        step = 1,
        valueLabels = { [0] = "Auto" },
        maxLetters = 0,
        suffix = "px",
        inputFormatter = function(value)
            assert(value ~= 0, "named values must bypass the numeric formatter")
            return string.format("%.1f", value)
        end,
        inputParser = function(text)
            assert(text:lower() ~= "auto", "labels must be recognized before custom parsing")
            local numericText = text:gsub("px$", "")
            return tonumber(numericText)
        end,
    })
    assert(custom.valueBox.maxLetters == 0, "an unbounded input must stay unbounded")
    assert(custom:GetValue() == 0 and custom.valueBox:GetText() == "Auto")
    custom.valueBox:SetText("1e3")
    custom:_FinalizeInput()
    assert(custom:GetValue() == 1000 and custom.valueBox:GetText() == "1000.0px")
    custom.valueBox:SetText("auto")
    custom:_FinalizeInput()
    assert(custom:GetValue() == 0 and custom.valueBox:GetText() == "Auto")
    custom.valueBox:SetText("12px")
    custom:_FinalizeInput()
    assert(custom:GetValue() == 12 and custom.valueBox:GetText() == "12.0px")

    local fractional = lib:CreateSlider(nil, {
        minValue = 0,
        maxValue = 1,
        step = 0.1,
        value = 0.3,
        valueLabels = { [0.3] = "Default" },
    })
    assert(fractional.valueBox:GetText() == "Default", "labels must use the same snapping as numeric values")
    fractional:SetValue(0.7)
    fractional.valueBox:SetText("default")
    fractional:_FinalizeInput()
    assert(math.abs(fractional:GetValue() - 0.3) < 1e-9 and fractional.valueBox:GetText() == "Default")

    for _, invalid in ipairs({
        false,
        "Auto",
        { auto = "Auto" },
        { [math.huge] = "Auto" },
        { [0] = true },
        { [0] = "   " },
        { [0] = "Auto", [1] = " aUtO " },
        { [0] = "Auto", [0.1] = "Default" },
    }) do
        local ok, message = pcall(lib.CreateSlider, lib, nil, {
            minValue = 0,
            maxValue = 100,
            step = 1,
            valueLabels = invalid,
        })
        assert(not ok and message:find("valueLabels"), "invalid label maps must fail at construction")
    end

    print("LibModernSettings slider label tests passed")
end
