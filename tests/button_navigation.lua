return function(lib, makeFrame, inputState, openMenu, key)
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local saved
    local first = lib:CreateTextInput(root, {
        onCommit = function(value)
            saved = value
            return value
        end,
    })
    first:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    local changes = 0
    local checkbox = lib:CreateCheckbox(root, {
        value = false,
        onChanged = function()
            assert(saved == "Submitted", "pending text must be committed before activation")
            changes = changes + 1
        end,
    })
    checkbox:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
    local body = makeFrame("Frame", root)
    body:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -150)
    body:Hide()
    local text = lib:CreateTextInput(body, {})
    local expansions = 0
    local header = lib:CreateExpandableHeader(root, {
        text = "Section", expanded = false,
        onExpandedChanged = function(_, expanded, button)
            assert(button == "LeftButton")
            expansions = expansions + 1
            body:SetShown(expanded)
        end,
    })
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -100)
    local advanced = lib:CreateCheckbox(header, { label = "Advanced" })
    advanced:SetPoint("TOPLEFT", header, "TOPLEFT", 150, 0)
    local dropdown = lib:CreateDropdown(root, {
        choices = { { value = 1, label = "One" } }, value = 1,
    })
    dropdown:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -220)
    function dropdown.dropdown:OpenMenu() openMenu(dropdown) end

    local buttons = {}
    local clicks = {}
    for index, variant in ipairs({ "regular", "small", "square" }) do
        clicks[index] = 0
        local button = lib:CreateButton(root, {
            variant = variant,
            text = variant ~= "square" and "Action" or nil,
            iconAtlas = variant == "square" and "common-icon-backarrow" or nil,
            onClick = function(owner, mouseButton)
                assert(owner == buttons[index] and mouseButton == "LeftButton")
                assert(saved == "Submitted", "button callbacks must see the committed input")
                clicks[index] = clicks[index] + 1
            end,
        })
        button:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -220 - index * 50)
        buttons[index] = button
    end

    first:FocusValue()
    first:SetText("Submitted")
    first.scripts.OnTabPressed(first)
    local keyboard = lib._navigationKeyboardFrame
    assert(saved == "Submitted" and not first:HasFocus() and checkbox.highlightLocked)
    key("SPACE")
    assert(checkbox:GetValue() and changes == 1 and checkbox.highlightLocked)
    assert(inputState.lastSound == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    assert(not keyboard.propagateKeyboardInput)
    key("ENTER")
    assert(not checkbox:GetValue() and changes == 2 and checkbox.highlightLocked)
    assert(inputState.lastSound == SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    key("UP")
    assert(changes == 2 and keyboard.propagateKeyboardInput)

    key("TAB")
    assert(not checkbox.highlightLocked and header.highlightLocked)
    header.scripts.OnLeave(header)
    assert(header:GetNormalTexture().atlas == "common-button-tertiary-hover",
        "mouse leave must not erase the focused header's hover appearance")
    key("SPACE")
    assert(header:IsExpanded() and body:IsShown() and expansions == 1)
    key("ENTER")
    assert(not header:IsExpanded() and not body:IsShown() and expansions == 2)
    key("TAB")
    assert(advanced.highlightLocked and not header.highlightLocked,
        "focusable headers must not hide nested checkboxes from Tab traversal")
    key("SPACE")
    assert(advanced:GetValue() and not header:IsExpanded() and expansions == 2,
        "activating a nested checkbox must not activate its parent header")
    key("TAB")
    assert(keyboard.control == dropdown and not dropdown.dropdown:IsMenuOpen() and not advanced.highlightLocked,
        "collapsed section contents must be skipped")
    assert(not keyboard.propagateKeyboardInput)
    inputState.modifiers.shift = true
    key("TAB")
    assert(advanced.highlightLocked and not dropdown.dropdown:IsMenuOpen())
    key("TAB")
    inputState.modifiers.shift = false
    assert(header.highlightLocked)
    key("ENTER")
    key("TAB")
    key("TAB")
    assert(text:HasFocus() and not advanced.highlightLocked and keyboard.control == nil)
    text.scripts.OnTabPressed(text)
    key("SPACE")
    assert(dropdown.dropdown:IsMenuOpen())
    key("SPACE")
    assert(not dropdown.dropdown:IsMenuOpen() and keyboard.control == dropdown)

    for index, button in ipairs(buttons) do
        key("TAB")
        assert(keyboard.control == button and button.highlightLocked)
        if index <= 2 then
            button.scripts.OnLeave(button)
            local hover = index == 2 and "common-button-tertiary-hover-small" or "common-button-tertiary-hover"
            assert(button:GetNormalTexture().atlas == hover)
        end
        key("ENTER")
        key("SPACE")
        assert(clicks[index] == 2 and button.highlightLocked and not keyboard.propagateKeyboardInput,
            "each activation key must click each button variant once and retain focus")
    end
    key("TAB")
    assert(first:HasFocus() and not buttons[3].highlightLocked and keyboard.control == nil)
    inputState.modifiers.shift = true
    first.scripts.OnTabPressed(first)
    for index = #buttons, 1, -1 do
        assert(keyboard.control == buttons[index] and buttons[index].highlightLocked)
        key("TAB")
    end
    inputState.modifiers.shift = false
    assert(keyboard.control == dropdown and not dropdown.dropdown:IsMenuOpen())

    buttons[1]:SetControlEnabled(false)
    buttons[2]:Hide()
    key("TAB")
    assert(keyboard.control == buttons[3], "hidden and disabled action buttons must be skipped")
    buttons[3]:SetEnabled(false)
    assert(keyboard.control == nil and not buttons[3].highlightLocked)
    for _, button in ipairs(buttons) do
        button:SetControlEnabled(true)
        button:Show()
    end

    checkbox:_FocusForTab()
    inputState.mouseFoci = { checkbox }
    keyboard.scripts.OnEvent(keyboard, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(checkbox.highlightLocked, "clicking the focused control must preserve focus")
    checkbox:Click("LeftButton")
    assert(changes == 3)
    inputState.mouseFoci = { root }
    keyboard.scripts.OnEvent(keyboard, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(not checkbox.highlightLocked and keyboard.control == nil)
    key("SPACE")
    assert(changes == 3 and keyboard.propagateKeyboardInput)
    inputState.mouseFoci = {}

    checkbox:_FocusForTab()
    checkbox:SetControlEnabled(false)
    assert(not checkbox.highlightLocked and keyboard.control == nil)
    first:FocusValue()
    first.scripts.OnTabPressed(first)
    assert(header.highlightLocked, "disabled checkboxes must be skipped")
    header:Hide()
    header.scripts.OnHide(header)
    assert(not header.highlightLocked and keyboard.control == nil)
    header:Show()
    header:_FocusForTab()
    header.scripts.OnEnter(header)
    key("ESCAPE")
    assert(not header.highlightLocked and not keyboard.propagateKeyboardInput)
    assert(header:GetNormalTexture().atlas == "common-button-tertiary-hover")
    header.scripts.OnLeave(header)
    assert(header:GetNormalTexture().atlas == "common-button-tertiary-normal")

    checkbox:SetControlEnabled(true)
    checkbox:_FocusForTab()
    inputState.inCombat = true
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_DISABLED")
    assert(not keyboard:IsShown() and not checkbox.highlightLocked)
    key("SPACE")
    assert(changes == 3)
    inputState.inCombat = false
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_ENABLED")
    assert(keyboard:IsShown() and checkbox.highlightLocked)
    first:FocusValue()
    assert(not checkbox.highlightLocked and keyboard.control == nil,
        "focusing an edit box must release button keyboard input immediately")
    first:CancelAndClearFocus()

    checkbox:_FocusForTab()
    root:Hide()
    keyboard.scripts.OnHide(keyboard)
    root:Show()
    assert(not checkbox.highlightLocked and keyboard.control == nil,
        "hiding and reopening the window must not restore stale button focus")

    checkbox:_FocusForTab()
    lib._loadedModules["Controls/Checkbox"] = nil
    lib._loadedModules["Controls/ExpandableHeader"] = nil
    dofile("Controls/Checkbox.lua")
    dofile("Controls/ExpandableHeader.lua")
    key("SPACE")
    assert(changes == 4 and checkbox.highlightLocked,
        "live upgrades must preserve focus and activate only once")
    checkbox:SetOnChanged(function() first:FocusValue() end)
    key("ENTER")
    assert(first:HasFocus() and not checkbox.highlightLocked and keyboard.control == nil,
        "an activation callback that opens an input must retain the new focus")
    first:CancelAndClearFocus()

    buttons[1]:_FocusForTab()
    lib._loadedModules["Controls/Button"] = nil
    dofile("Controls/Button.lua")
    key("SPACE")
    assert(clicks[1] == 3 and buttons[1].highlightLocked,
        "compatible upgrades must preserve action-button focus and invoke one callback")
    buttons[1]:SetOnClick(function() first:FocusValue() end)
    key("ENTER")
    assert(first:HasFocus() and not buttons[1].highlightLocked and keyboard.control == nil,
        "a button's input dialog must keep the focus it acquires")
    assert(not keyboard.propagateKeyboardInput)
    first:CancelAndClearFocus()
end
