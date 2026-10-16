return function(lib, makeFrame, inputState, openMenu, key)
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local commits = 0
    local text = lib:CreateTextInput(root, {
        value = "Saved",
        onCommit = function(value)
            commits = commits + 1
            return value
        end,
    })
    text:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    local first = lib:CreateDropdown(root, {
        choices = { { value = 1, label = "One" }, { value = 2, label = "Two" } },
        value = 1,
    })
    first:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
    local second = lib:CreateDropdown(root, { choices = {}, value = nil })
    second:SetPoint("TOPLEFT", root, "TOPLEFT", 150, -50)
    function first.dropdown:OpenMenu() openMenu(first) end
    function second.dropdown:OpenMenu() openMenu(second) end
    local changes = 0
    local slider = lib:CreateSlider(root, {
        minValue = 0, maxValue = 10, step = 1, value = 5,
        onChanged = function() changes = changes + 1 end,
    })
    slider:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -100)
    local input = slider.valueBox
    local function tab(editBox, reverse)
        inputState.modifiers.shift = reverse == true
        editBox.scripts.OnTabPressed(editBox)
        inputState.modifiers.shift = false
    end

    text:FocusValue()
    text:SetText("Pending")
    tab(text)
    assert(commits == 1 and text:GetValue() == "Pending" and not text:HasFocus())
    local keyboard = lib._navigationKeyboardFrame
    assert(keyboard.control == first and not first.dropdown:IsMenuOpen() and first:GetValue() == 1,
        "Tab must focus the dropdown without opening its menu")
    first.dropdown.scripts.OnLeave(first.dropdown)
    assert(first.dropdown.focusTexture:IsShown(),
        "mouse leave must preserve the focused dropdown's input glow")
    key("DOWN")
    assert(first:GetValue() == 1 and keyboard.propagateKeyboardInput,
        "closed dropdowns must not change selection on arrow keys")
    key("SPACE")
    assert(first.dropdown:IsMenuOpen() and not keyboard.propagateKeyboardInput)
    key("DOWN")
    assert(first:GetValue() == 2)
    key("ENTER")
    assert(not first.dropdown:IsMenuOpen() and keyboard.control == first)
    key("TAB")
    assert(not first.dropdown:IsMenuOpen() and not second.dropdown:IsMenuOpen() and keyboard.control == second)
    assert(not first.dropdown.focusTexture:IsShown() and second.dropdown.focusTexture:IsShown())
    assert(not keyboard.propagateKeyboardInput,
        "Tab must remain consumed when focusing the next dropdown resets the keyboard frame")
    key("ENTER")
    key("TAB")
    assert(not second.dropdown:IsMenuOpen() and input:HasFocus())
    input:SetText("17")
    tab(input)
    assert(slider:GetValue() == 17 and changes == 1 and text:HasFocus(),
        "the final input must commit once and wrap to the first input")
    tab(text, true)
    assert(input:HasFocus(), "Shift+Tab must wrap to the final input")
    tab(input, true)
    assert(keyboard.control == second and not second.dropdown:IsMenuOpen())
    key("ENTER")
    key("SPACE")
    assert(not second.dropdown:IsMenuOpen() and keyboard.control == second)
    inputState.modifiers.shift = true
    key("TAB")
    assert(keyboard.control == first and not first.dropdown:IsMenuOpen() and not second.dropdown:IsMenuOpen())
    key("SPACE")
    key("TAB")
    inputState.modifiers.shift = false
    assert(text:HasFocus() and not first.dropdown:IsMenuOpen())

    -- Hidden parents, disabled primitives, and other windows do not enter the cycle.
    local hidden = makeFrame("Frame", root)
    local hiddenText = lib:CreateTextInput(hidden, {})
    hidden:Hide()
    local unrelated = lib:CreateTextInput(makeFrame("Frame", UIParent), {})
    local nested = makeFrame("Frame", root)
    lib:EnableTabNavigation(nested)
    local nestedText = lib:CreateTextInput(nested, {})
    first:SetControlEnabled(false)
    second:Hide()
    tab(text)
    assert(input:HasFocus() and not hiddenText:HasFocus() and not unrelated:HasFocus()
        and not nestedText:HasFocus())
    input:SetText("invalid")
    tab(input)
    assert(text:HasFocus() and slider:GetValue() == 17 and changes == 1)
    slider:SetControlEnabled(false)
    tab(text)
    assert(text:HasFocus(), "a group with one eligible input must retain focus")

    -- Commits can change eligibility or open a dialog; never use stale candidates.
    text:SetOnCommit(function(value)
        slider:SetControlEnabled(true)
        return value
    end)
    tab(text)
    assert(input:HasFocus(), "eligibility changes during commit must take effect immediately")
    tab(input)
    text:SetOnCommit(function(value)
        if value == "Rejected" then
            return nil, "Rejected"
        end
        return value
    end)
    for _, reverse in ipairs({ false, true }) do
        text:SetText("Rejected")
        tab(text, reverse)
        assert(text:GetText() == "Pending" and not input:HasFocus() and text:HasFocus(),
            "rejected Tab and Shift+Tab commits must retain focus on the restored value")
        tab(text, reverse)
        assert(input:HasFocus(), "Tab navigation must resume after a rejected commit")
        tab(input)
    end
    text:SetOnCommit(function(value)
        unrelated:FocusValue()
        return value
    end)
    text:FocusValue()
    tab(text)
    assert(unrelated:HasFocus() and not input:HasFocus(), "commit dialogs must keep their focus")
    unrelated:CancelAndClearFocus()
    text:SetOnCommit(function(value)
        root:Hide()
        return value
    end)
    text:FocusValue()
    tab(text)
    assert(not input:HasFocus() and not text:HasFocus())
    root:Show()

    first:SetControlEnabled(true)
    second:Show()
    text:SetOnCommit(nil)
    text:FocusValue()
    inputState.inCombat = true
    tab(text)
    assert(input:HasFocus() and not first.dropdown:IsMenuOpen(),
        "Tab must not open menus that cannot receive keyboard input in combat")
    input:ClearFocus()
    inputState.inCombat = false

    -- Manually linked edit boxes outside a group retain Blizzard's native contract.
    local standalone = lib:CreateTextInput(makeFrame("Frame", UIParent), {})
    standalone.nextEditBox = unrelated
    standalone:FocusValue()
    tab(standalone)
    assert(unrelated:HasFocus())
    unrelated:CancelAndClearFocus()
end
