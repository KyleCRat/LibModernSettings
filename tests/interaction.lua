return function(lib, makeFrame)
    local parent = makeFrame("Frame", UIParent)
    local events = {}
    local function observe(control, reason)
        events[#events + 1] = { control = control, reason = reason }
    end

    local input = lib:CreateTextInput(parent, { value = "saved" })
    lib:SetOnInteraction(input, observe)
    input:SetValue("refreshed")
    assert(#events == 0, "programmatic values must not activate editing")
    input:FocusValue()
    assert(#events == 1 and events[1].control == input)
    assert(events[1].reason == "focus")
    input:SetText("draft")
    input.scripts.OnEnterPressed(input)
    assert(not input:HasFocus() and input:GetValue() == "draft")

    local slider = lib:CreateSlider(parent, {
        value = 5,
        minValue = 0,
        maxValue = 10,
        step = 1,
    })
    lib:SetOnInteraction(slider, observe)
    slider.valueBox:SetFocus()
    assert(events[#events].control == slider)
    slider.valueBox:ClearFocus()
    slider.slider.Slider.scripts.OnMouseDown(slider.slider.Slider, "LeftButton")
    assert(events[#events].control == slider)
    assert(events[#events].reason == "activate")

    local button = lib:CreateButton(parent, { text = "Action" })
    lib:SetOnInteraction(button, observe)
    local before = #events
    button:_FocusForTab()
    assert(#events == before + 1 and events[#events].control == button)
    button:_ReleaseTabFocus()
    button.scripts.OnMouseDown(button, "LeftButton")
    assert(events[#events].reason == "activate")
    before = #events
    button:SetControlEnabled(false)
    button.scripts.OnMouseDown(button, "LeftButton")
    assert(#events == before, "disabled controls must not activate editing")
    button:SetControlEnabled(true)
    parent:Hide()
    button.scripts.OnMouseDown(button, "LeftButton")
    assert(#events == before, "hidden controls must not activate editing")
    parent:Show()

    local color = lib:CreateColor(parent, { value = { r = 1, g = 0, b = 0 } })
    lib:SetOnInteraction(color, observe)
    color.buttons.custom:_FocusForTab()
    assert(
        events[#events].control == color,
        "compound children notify their logical owner"
    )
    color.buttons.custom:_ReleaseTabFocus()
    color:OpenPicker()
    assert(
        events[#events].control == color and events[#events].reason == "open"
    )
    before = #events
    lib._colorPicker:SetColor({ r = 0, g = 0, b = 1 })
    assert(#events == before, "picker edits must not switch the editing owner")
    color:ClosePicker()

    lib:SetOnInteraction(color.buttons.custom, observe)
    color.buttons.custom:_FocusForTab()
    assert(events[#events].control == color.buttons.custom)
    color.buttons.custom:_ReleaseTabFocus()
    lib:SetOnInteraction(color.buttons.custom, nil)
    color.buttons.custom:_FocusForTab()
    assert(events[#events].control == color)
    color.buttons.custom:_ReleaseTabFocus()

    local hooks = #input.scriptHooks.OnMouseDown
    lib:SetOnInteraction(input, observe)
    lib:_ConfigureControlNavigation(input)
    assert(
        #input.scriptHooks.OnMouseDown == hooks,
        "rebinding must not accumulate hooks"
    )
    lib:SetOnInteraction(input, nil)
    before = #events
    input:FocusValue()
    assert(#events == before, "removed observers must not receive events")
    input:CancelAndClearFocus()
    local replacementCalls = 0
    lib:SetOnInteraction(input, function()
        replacementCalls = replacementCalls + 1
    end)
    lib._loadedModules["Utilities/ControlNavigation"] = nil
    dofile("Utilities/ControlNavigation.lua")
    input:FocusValue()
    assert(replacementCalls == 1 and #events == before)
    input:CancelAndClearFocus()
    assert(not pcall(lib.SetOnInteraction, lib, input, true))
    print("LibModernSettings interaction observer tests passed")
end
