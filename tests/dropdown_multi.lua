return function(lib, openMenu, key, menu)
    local changes, lastKey, lastChecked = 0, nil, nil
    local initial = { first = true }
    local choices = {
        { type = "title", label = "Group" },
        { value = "first", label = "First", tooltip = "First choice" },
        { value = "disabled", label = "Disabled", enabled = false },
        { type = "divider" },
        { value = "second", label = "Second" },
        { value = false, label = "False is a valid choice" },
        { value = "last", label = "Last" },
    }
    local control = lib:CreateDropdown(nil, {
        multiSelect = true,
        choices = choices,
        value = initial,
        placeholder = "Choose states",
        selectionText = function(values)
            return values.first and "Has first" or "Other states"
        end,
        onChanged = function(values, changed, checked)
            changes = changes + 1
            lastKey, lastChecked = changed, checked
            values.leaked = true
        end,
    })
    local button = control.dropdown
    initial.first = nil
    assert(control:GetValue().first and not control:GetValue().leaked)
    local copy = control:GetValue()
    copy.first = nil
    assert(control:GetValue().first, "multi-select values must not alias caller-owned tables")
    assert(button.defaultText == "Choose states" and button.selectionFunc() == "Has first")
    assert(not pcall(control.SetValue, control, "first"))
    assert(not pcall(control.SetValue, control, { first = 1 }))
    assert(not pcall(lib.CreateDropdown, lib, nil, { multiSelect = "yes" }))
    assert(not pcall(lib.CreateDropdown, lib, nil, { selectionText = true }))
    assert(not pcall(lib.CreateDropdown, lib, nil, { placeholder = 1 }))
    assert(not pcall(lib.CreateDropdown, lib, nil, { multiSelect = true, choices = { { label = "Missing identity" } } }))
    control:SetValue({ first = true, unavailable = true, second = false })
    control:SetChoices(choices)
    assert(control:GetValue().unavailable and control:GetValue().second == nil,
        "choice changes must preserve unknown selections and omit false entries")
    control:SetValue({ first = true })

    function button:OpenMenu()
        openMenu(control)
    end
    control:_FocusForTab()
    assert(not button:IsMenuOpen(), "Tab must not open multi-select menus")
    key("SPACE")
    assert(button:IsMenuOpen() and control._libModernSettingsMenuFocus == "first")
    key("UP")
    assert(control._libModernSettingsMenuFocus == "first" and changes == 0)
    key("DOWN")
    assert(control._libModernSettingsMenuFocus == "second" and changes == 0)
    assert(menu.ScrollBox.revealedValue == "second", "arrow focus must reveal an offscreen choice")
    local focused
    for _, row in ipairs(menu.rows) do
        if row.description:GetData() == "second" then
            focused = row
        end
    end
    assert(focused.highlight:IsShown(), "keyboard focus must be visible independently from checkbox selection")
    focused.highlight:Hide()
    focused.description.onLeave(focused)
    assert(focused.highlight:IsShown(), "native mouse leave must preserve the keyboard focus highlight")
    key("SPACE")
    assert(control:GetValue().first and control:GetValue().second and not control:GetValue().leaked)
    assert(lastKey == "second" and lastChecked and changes == 1 and button:IsMenuOpen())
    key("ENTER")
    assert(not control:GetValue().second and lastChecked == false and changes == 2 and button:IsMenuOpen())
    key("DOWN")
    assert(control._libModernSettingsMenuFocus == false)
    key("SPACE")
    assert(control:GetValue()[false] and changes == 3, "boolean choice identities must survive focus and selection")
    key("DOWN")
    key("DOWN")
    assert(control._libModernSettingsMenuFocus == "last" and changes == 3)
    key("SPACE")
    assert(control:GetValue().last and changes == 4)
    key("ESCAPE")
    assert(not button:IsMenuOpen() and lib._navigationKeyboardFrame.control == control)
    assert(next(control._libModernSettingsMenuRows) == nil, "closing must release pooled-row references")

    -- Consumer normalization can replace choices/values during a checkbox pick.
    control:SetOnChanged(function(values, changed)
        changes = changes + 1
        control:SetChoices(choices)
        control:SetValue({ [changed] = true })
    end)
    openMenu(control)
    key("DOWN")
    key("SPACE")
    assert(control:GetValue().second and not control:GetValue().first and button:IsMenuOpen())
    assert(control._libModernSettingsMenuFocus == "second")
    local description = button:GetMenuDescription().elements[2]
    button:Pick(description, MenuInputContext.MouseButton)
    assert(control:GetValue().first and not control:GetValue().second and button:IsMenuOpen(),
        "mouse checks must stay open and keep consumer normalization")
    lib._loadedModules["Controls/Dropdown"] = nil
    dofile("Controls/Dropdown.lua")
    assert(control:GetValue().first and button:IsMenuOpen())
    key("DOWN")
    assert(control._libModernSettingsMenuFocus == "second")
    control:SetControlEnabled(false)
    assert(not button:IsMenuOpen() and lib._navigationKeyboardFrame.control == nil)
    control:SetControlEnabled(true)
    control:SetChoices({ { type = "title", label = "Empty" } })
    control:SetValue(nil)
    openMenu(control)
    key("DOWN")
    key("SPACE")
    assert(next(control:GetValue()) == nil and button:IsMenuOpen())
    key("ESCAPE")
    key("ESCAPE")
    print("LibModernSettings multi-select dropdown tests passed")
end
