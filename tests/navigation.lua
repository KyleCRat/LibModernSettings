return function(lib, makeFrame, inputState)
    local changes = 0
    local slider = lib:CreateSlider(nil, {
        minValue = 0, maxValue = 2, step = 0.25, value = 1,
        onChanged = function() changes = changes + 1 end,
    })
    local input = slider.valueBox
    assert(not slider:IsMouseWheelEnabled())
    slider.scripts.OnMouseWheel(slider, 1)
    assert(slider:GetValue() == 1 and changes == 0)
    slider.slider.Slider.scripts.OnMouseUp(slider.slider.Slider, "LeftButton")
    assert(input:HasFocus() and slider:IsMouseWheelEnabled())
    assert(input.altArrowKeyMode == false)
    slider.scripts.OnMouseWheel(slider, 4)
    assert(slider:GetValue() == 1.25 and changes == 1, "one wheel event must move one step")
    input.scripts.OnArrowPressed(input, "DOWN")
    assert(slider:GetValue() == 1 and changes == 2)
    input.scripts.OnArrowPressed(input, "LEFT")
    slider.scripts.OnMouseWheel(slider, 0)
    assert(changes == 2)

    input:SetText("5.5")
    input.scripts.OnArrowPressed(input, "UP")
    assert(slider:GetValue() == 5.75 and slider.slider.value == 2)
    assert(input:HasFocus(), "stepping must preserve editing focus")
    input.scripts.OnMouseWheel(input, -1)
    assert(slider:GetValue() == 5.5)
    input:SetText("invalid")
    input.scripts.OnArrowPressed(input, "UP")
    assert(slider:GetValue() == 5.75, "invalid pending text must fall back to the committed value")
    input:ClearFocus()
    assert(changes == 5, "focus loss must not commit a stepped value twice")
    for _, target in ipairs({ slider, input, slider.slider.Slider, slider.slider.Back, slider.slider.Forward }) do
        assert(not target:IsMouseWheelEnabled())
        target.scripts.OnMouseWheel(target, 1)
    end
    assert(changes == 5)

    input:SetFocus()
    slider:SetControlEnabled(false)
    input.scripts.OnArrowPressed(input, "UP")
    assert(changes == 5 and not input:IsMouseWheelEnabled())
    slider:SetControlEnabled(true)
    slider:Hide()
    input.scripts.OnArrowPressed(input, "UP")
    assert(changes == 5)
    slider:Show()
    slider:SetOnChanged(function(value)
        changes = changes + 1
        slider:SetValue(math.max(0.5, math.min(6, value)))
    end)
    input:SetText("-1")
    input.scripts.OnArrowPressed(input, "DOWN")
    assert(slider:GetValue() == 0.5 and input:GetText() == "0.5")
    input:ClearFocus()
    assert(changes == 6, "consumer normalization must not cause duplicate notification")
    for _, value in ipairs({ math.huge, -math.huge, 0 / 0 }) do
        assert(not pcall(slider.SetValue, slider, value))
    end
    local parsed = lib:CreateSlider(nil, {
        minValue = 0, maxValue = 10, step = 0.5, value = 2,
        inputParser = tonumber,
    })
    parsed.valueBox:SetText("1e999")
    parsed:_FinalizeInput()
    assert(parsed:GetValue() == 2 and parsed.valueBox:GetText() == "2")

    inputState.modifiers.shift = true
    input:SetFocus()
    local beforeShift = changes
    for _, target in ipairs({ slider, input, slider.slider.Slider, slider.slider.Back, slider.slider.Forward }) do
        target.scripts.OnMouseWheel(target, 4)
        assert(slider:GetValue() == 3, "Shift-wheel must add ten fractional steps per event")
        target.scripts.OnMouseWheel(target, -4)
        assert(slider:GetValue() == 0.5, "Shift-wheel must subtract ten steps")
    end
    assert(changes == beforeShift + 10, "each Shift-wheel event must notify once")
    input:SetText("5.5")
    input.scripts.OnMouseWheel(input, 1)
    assert(slider:GetValue() == 6, "Shift-wheel must respect consumer limits on pending input")
    input:SetText("-1")
    input.scripts.OnMouseWheel(input, -1)
    assert(slider:GetValue() == 0.5)
    input.scripts.OnArrowPressed(input, "UP")
    assert(slider:GetValue() == 0.75, "Shift must not change arrow-key stepping")
    inputState.modifiers.shift = false
    input.scripts.OnMouseWheel(input, 1)
    assert(slider:GetValue() == 1, "releasing Shift must restore single-step scrolling")
    local afterShift = changes
    inputState.modifiers.shift = true
    input.scripts.OnMouseWheel(input, 0)
    input:ClearFocus()
    input.scripts.OnMouseWheel(input, 1)
    assert(changes == afterShift, "zero delta and unfocused Shift-wheel must not submit changes")
    inputState.modifiers.shift = false

    inputState.modifiers.control = true
    local controlChanges = 0
    parsed:SetOnChanged(function() controlChanges = controlChanges + 1 end)
    parsed.valueBox:SetFocus()
    for _, target in ipairs({ parsed, parsed.valueBox, parsed.slider.Slider, parsed.slider.Back, parsed.slider.Forward }) do
        target.scripts.OnMouseWheel(target, 4)
        assert(parsed:GetValue() == 27, "Ctrl-wheel must add fifty fractional steps per event")
        target.scripts.OnMouseWheel(target, -4)
        assert(parsed:GetValue() == 2, "Ctrl-wheel must subtract fifty steps")
    end
    assert(controlChanges == 10, "each Ctrl-wheel event must notify once")
    inputState.modifiers.shift = true
    parsed.scripts.OnMouseWheel(parsed, 1)
    assert(parsed:GetValue() == 27, "Ctrl must take priority over Shift")
    inputState.modifiers.control = false
    parsed.scripts.OnMouseWheel(parsed, -1)
    assert(parsed:GetValue() == 22, "releasing Ctrl must restore the held Shift modifier")
    inputState.modifiers.shift = false
    parsed.scripts.OnMouseWheel(parsed, -1)
    assert(parsed:GetValue() == 21.5, "releasing both modifiers must restore single steps")
    parsed.valueBox:ClearFocus()
    assert(controlChanges == 13, "focus loss must not submit a modified step twice")

    inputState.modifiers.control = true
    input:SetFocus()
    input.scripts.OnMouseWheel(input, 1)
    assert(slider:GetValue() == 6, "Ctrl-wheel must respect the consumer's upper limit")
    input.scripts.OnMouseWheel(input, -1)
    assert(slider:GetValue() == 0.5, "Ctrl-wheel must respect the consumer's lower limit")
    input:ClearFocus()
    local afterControl = changes
    input.scripts.OnMouseWheel(input, 1)
    assert(changes == afterControl, "unfocused Ctrl-wheel must not submit changes")
    inputState.modifiers.control = false

    for _, case in ipairs({
        { modifiers = { shift = false, control = false, alt = true, meta = false }, steps = 1 },
        { modifiers = { shift = false, control = false, alt = false, meta = true }, steps = 1 },
        { modifiers = { shift = true, control = false, alt = true, meta = true }, steps = 10 },
        { modifiers = { shift = true, control = true, alt = true, meta = true }, steps = 50 },
    }) do
        inputState.modifiers = case.modifiers
        parsed:SetValue(2)
        parsed.valueBox:SetFocus()
        parsed.scripts.OnMouseWheel(parsed, 1)
        local expected = 2 + case.steps * 0.5
        assert(parsed:GetValue() == expected, "unassigned modifiers must preserve the wheel rules")
        parsed.valueBox.scripts.OnArrowPressed(parsed.valueBox, "DOWN")
        assert(parsed:GetValue() == expected - 0.5, "wheel modifiers must not accelerate keyboard input")
        parsed.valueBox:ClearFocus()
    end
    inputState.modifiers = { shift = false, control = false, alt = false, meta = false }

    local choices = {}
    for index = 1, 8 do
        choices[index] = { label = "Choice " .. index, value = index }
    end
    local picks = 0
    local dropdown = lib:CreateDropdown(nil, {
        getChoices = function() return choices end,
        value = 4,
    })
    dropdown:SetOnChanged(function(value)
        picks = picks + 1
        -- AirAuras and other bindings refresh their controls after persisting.
        dropdown:SetValue(value)
    end)
    inputState.keyboardFocus = nil

    local menu = makeFrame("Frame")
    menu.ScrollBox = makeFrame("Frame", menu)
    menu.ScrollBox:EnableMouseWheel(true)
    function menu:GetLeft() return 100 end
    function menu.ScrollBox:HasDataProvider() return self.dataProvider ~= nil end
    function menu.ScrollBox:RemoveDataProvider()
        for _, row in ipairs(self.dataProvider or {}) do
            row:Hide()
        end
        self.dataProvider = nil
        self.firstVisible = 1
        self.revealedValue = nil
    end
    function menu.ScrollBox:GetScrollPercentage()
        local range = math.max(1, #(self.dataProvider or {}) - 3)
        return ((self.firstVisible or 1) - 1) / range
    end
    function menu.ScrollBox:SetScrollPercentage(percentage, interpolation)
        assert(interpolation == ScrollBoxConstants.NoScrollInterpolation)
        local range = math.max(0, #(self.dataProvider or {}) - 3)
        self.firstVisible = 1 + math.floor(percentage * range + 0.5)
        for index, row in ipairs(self.dataProvider or {}) do
            local visible = index >= self.firstVisible and index < self.firstVisible + 3
            row:SetShown(visible)
            if visible then
                row:SetParent(self)
            end
        end
    end
    local function attachMenuTexture(row)
        local texture = row:CreateTexture(nil, "ARTWORK")
        row.attachedTextures[#row.attachedTextures + 1] = texture
        return texture
    end
    local function initializeMenuRow(row)
        -- Model compositor cleanup before native radio/checkbox regions and custom attachments.
        for _, texture in ipairs(row.attachedTextures or {}) do
            texture:Hide()
        end
        row.attachedTextures = {}
        row.AttachTexture = attachMenuTexture
        row.leftTexture1 = row.leftTexture1 or row:CreateTexture(nil, "ARTWORK")
        row.leftTexture1:SetSize(16, 16)
        row.fontString = row.fontString or row:CreateFontString(nil, "ARTWORK", GameFontHighlight)
        row.fontString:ClearAllPoints()
        row.fontString:SetFontObject(GameFontHighlight)
        row.fontString:SetPoint("LEFT", row, "LEFT", 20, 0)
        row.fontString:SetHeight(20)
        row.fontString:SetText(row.description[1] or row.description.label or "")
        for _, initializer in ipairs(row.description.initializers or {}) do
            local width, height = initializer(row)
            if width and height then
                row:SetSize(width, height)
            end
        end
    end
    function menu:SetMenuDescription(description)
        local previousRows = self.rows or {}
        local rows = {}
        for _, row in ipairs(previousRows) do
            for _, resetter in ipairs(row.description.resetters or {}) do
                resetter(row)
            end
            row:Hide()
        end
        for index, element in description:EnumerateElementDescriptions() do
            -- Pool reacquisition need not preserve order. Blizzard reanchors
            -- every row to the menu, even when its old ScrollBox provider exists.
            local row = previousRows[#previousRows - index + 1] or makeFrame("Button", self)
            row.description = element
            function row:GetElementDescription() return self.description end
            row:SetParent(self)
            row:Show()
            row.highlight = row.highlight or row:CreateTexture(nil, "BACKGROUND")
            row.highlight:Hide()
            initializeMenuRow(row)
            rows[index] = row
        end
        self.rows = rows
        self.ScrollBox:SetShown(#rows > 3)
        if self.ScrollBox:IsShown() and not self.ScrollBox:HasDataProvider() then
            self.ScrollBox.dataProvider = rows
            self.ScrollBox:SetScrollPercentage(0, ScrollBoxConstants.NoScrollInterpolation)
        end
    end
    function menu:ReinitializeAll()
        self.refreshCount = (self.refreshCount or 0) + 1
        for _, row in ipairs(self.rows or {}) do
            initializeMenuRow(row)
        end
    end
    local nativeWheels = 0
    local function nativeWheel(_, delta)
        nativeWheels = nativeWheels + 1
        local scrollBox = menu.ScrollBox
        local range = math.max(1, #(scrollBox.dataProvider or {}) - 3)
        local offset = delta < 0 and 1 or (delta > 0 and -1 or 0)
        local percentage = math.max(0, math.min(1, scrollBox:GetScrollPercentage() + offset / range))
        scrollBox:SetScrollPercentage(percentage, ScrollBoxConstants.NoScrollInterpolation)
    end
    menu:SetScript("OnMouseWheel", nativeWheel)
    menu.ScrollBox:SetScript("OnMouseWheel", nativeWheel)
    function menu.ScrollBox:ScrollToElementDataByPredicate(predicate, align, offset, interpolation)
        assert(align == ScrollBoxConstants.AlignNearest and offset == 0)
        assert(interpolation == ScrollBoxConstants.NoScrollInterpolation)
        for index, frame in ipairs(self.dataProvider) do
            if predicate(frame) then
                local first = self.firstVisible or 1
                if index < first then
                    first = index
                elseif index > first + 2 then
                    first = index - 2
                end
                self:SetScrollPercentage((first - 1) / (#self.dataProvider - 3), interpolation)
                self.revealedValue = frame:GetElementDescription():GetData()
                return
            end
        end
        self.revealedValue = nil
        return false
    end
    local function openMenu(owner)
        owner = owner or dropdown
        owner.dropdown:GenerateMenu()
        menu:SetMenuDescription(owner.dropdown:GetMenuDescription())
        for _, callback in ipairs(owner.dropdown:GetMenuDescription().menuAcquiredCallbacks) do
            callback(menu)
        end
        menu:Show()
        menu.scripts.OnShow(menu)
        owner.dropdown.menu = menu
        -- Blizzard's OnMenuOpen passes only the dropdown, unlike OnMenuClose.
        owner.dropdown:TriggerEvent(DropdownButtonMixin.Event.OnMenuOpen, owner.dropdown)
    end
    function dropdown.dropdown:OpenMenu() openMenu(dropdown) end
    local function key(keyName)
        local keyboard = lib._navigationKeyboardFrame
        keyboard.scripts.OnKeyDown(keyboard, keyName)
    end
    local function wheel(delta)
        menu.ScrollBox.scripts.OnMouseWheel(menu.ScrollBox, delta)
    end
    local function assertMenuLayout()
        if menu.ScrollBox:IsShown() then
            for index, row in ipairs(menu.rows) do
                assert(menu.ScrollBox.dataProvider[index] == row,
                    "the scrolling provider must follow the rebuilt menu order")
                assert(row.description == dropdown.dropdown:GetMenuDescription().elements[index])
                if row:IsShown() then
                    assert(row.parent == menu.ScrollBox, "visible rows must stay in their scrolling slots")
                end
            end
        else
            assert(not menu.ScrollBox:HasDataProvider(), "short menus must release old scrolling rows")
        end
    end

    assert(not dropdown.dropdown:IsMouseWheelEnabled())
    openMenu()
    local keyboard = lib._navigationKeyboardFrame
    assert(dropdown._libModernSettingsOpenMenu == menu)
    assert(keyboard:IsShown() and not dropdown.dropdown:IsMouseWheelEnabled())
    assert(menu:GetScript("OnMouseWheel") == nativeWheel and not menu:IsMouseWheelEnabled())
    assert(menu.ScrollBox:GetScript("OnMouseWheel") == nativeWheel and menu.ScrollBox:IsMouseWheelEnabled())
    assert(menu.ScrollBox.revealedValue == 4 and menu.ScrollBox.firstVisible == 2)
    key("DOWN")
    assert(dropdown:GetValue() == 5 and picks == 1 and not keyboard.propagateKeyboardInput)
    assert(menu.ScrollBox.revealedValue == 5 and menu.ScrollBox.firstVisible == 3)
    assert(dropdown.dropdown:IsMenuOpen(), "stepping must leave the menu open")
    assertMenuLayout()
    wheel(-1)
    assert(dropdown:GetValue() == 5 and picks == 1 and menu.ScrollBox.firstVisible == 4,
        "the wheel must scroll the menu without changing selection")
    key("UP")
    assert(dropdown:GetValue() == 4 and picks == 2)
    assert(menu.ScrollBox.firstVisible == 4, "an already-visible selection must not reset the viewport")
    assertMenuLayout()
    wheel(0)
    key("W")
    assert(picks == 2 and keyboard.propagateKeyboardInput)
    inputState.keyboardFocus = input
    key("DOWN")
    assert(picks == 2 and keyboard.propagateKeyboardInput, "text input must keep its arrow keys")
    key("SPACE")
    assert(dropdown.dropdown:IsMenuOpen() and keyboard.propagateKeyboardInput,
        "typing a space must not confirm a dropdown behind the edit box")
    key("ENTER")
    assert(dropdown.dropdown:IsMenuOpen() and keyboard.propagateKeyboardInput,
        "focused text input must keep Enter")
    inputState.keyboardFocus = nil

    dropdown:SetValue(1)
    key("UP")
    wheel(1)
    assert(dropdown:GetValue() == 1 and picks == 2, "top boundary must not wrap or notify")
    assert(menu.ScrollBox.firstVisible == 1)
    dropdown:SetValue(8)
    key("DOWN")
    wheel(-1)
    assert(dropdown:GetValue() == 8 and picks == 2, "bottom boundary must not move backward or wrap")
    assert(menu.ScrollBox.firstVisible == 6)
    dropdown:SetValue("absent")
    key("DOWN")
    assert(dropdown:GetValue() == 1)
    dropdown:SetValue("absent")
    key("UP")
    assert(dropdown:GetValue() == 8)
    dropdown:SetValue(4)
    dropdown.dropdown:GetMenuDescription().radioButtons[5].disabled = true
    key("DOWN")
    assert(dropdown:GetValue() == 6, "navigation must skip unselectable choices")

    inputState.inCombat = true
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_DISABLED")
    assert(not keyboard:IsShown())
    key("DOWN")
    key("ENTER")
    assert(dropdown.dropdown:IsMenuOpen(), "combat must release keyboard confirmation")
    key("SPACE")
    assert(dropdown.dropdown:IsMenuOpen(), "combat must also release Space")
    inputState.inCombat = false
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_ENABLED")
    assert(keyboard:IsShown())
    local selected = dropdown.dropdown:GetMenuDescription().radioButtons[2]
    dropdown.dropdown:Pick(selected, MenuInputContext.MouseButton)
    assert(dropdown:GetValue() == 2 and not dropdown.dropdown:IsMenuOpen())
    assert(keyboard:IsShown() and keyboard.control == dropdown and keyboard:GetParent() == dropdown.dropdown,
        "selection must transfer focus before the native menu hides its children")
    assert(menu:GetScript("OnMouseWheel") == nativeWheel and not menu:IsMouseWheelEnabled())
    assert(menu.ScrollBox:GetScript("OnMouseWheel") == nativeWheel and menu.ScrollBox:IsMouseWheelEnabled())
    assert(not dropdown.dropdown:IsMouseWheelEnabled())
    local beforeWheel = nativeWheels
    menu.ScrollBox.scripts.OnMouseWheel(menu.ScrollBox, 1)
    assert(nativeWheels == beforeWheel + 1, "a reused Blizzard menu must retain its native wheel handler")

    openMenu()
    assert(lib._navigationKeyboardFrame == keyboard)
    key("DOWN")
    local confirmedValue, beforeConfirm = dropdown:GetValue(), picks
    key("ENTER")
    assert(dropdown:GetValue() == confirmedValue and picks == beforeConfirm,
        "Enter must retain the selected value without submitting it twice")
    assert(not dropdown.dropdown:IsMenuOpen() and keyboard:IsShown() and keyboard.control == dropdown)
    assert(not keyboard.propagateKeyboardInput, "confirming a dropdown must consume Enter before chat")
    key("ENTER")
    assert(dropdown.dropdown:IsMenuOpen() and not keyboard.propagateKeyboardInput,
        "Enter on a focused closed dropdown must reopen it")
    key("ENTER")
    assert(not dropdown.dropdown:IsMenuOpen() and picks == beforeConfirm,
        "Enter must also accept the existing selection without arrow navigation")
    for _, activationKey in ipairs({ "ENTER", "SPACE" }) do
        openMenu()
        inputState.mouseFoci = { menu.ScrollBox }
        keyboard.scripts.OnEvent(keyboard, "GLOBAL_MOUSE_DOWN", "LeftButton")
        assert(keyboard.control == dropdown, "clicking a menu scrollbar must retain keyboard selection")
        inputState.mouseFoci = {}
        key("DOWN")
        local value, changes = dropdown:GetValue(), picks
        key(activationKey)
        assert(not dropdown.dropdown:IsMenuOpen() and dropdown:GetValue() == value and picks == changes)
        assert(keyboard.control == dropdown and keyboard:IsVisible()
            and dropdown.dropdown.focusTexture:IsShown())
        assert(not keyboard.propagateKeyboardInput, "activation must not reach chat or jump bindings")
    end
    openMenu()
    key("ESCAPE")
    assert(not dropdown.dropdown:IsMenuOpen() and keyboard.control == dropdown)
    key("ESCAPE")
    assert(not dropdown.dropdown:IsMenuOpen() and not keyboard:IsShown())
    key("ENTER")
    assert(keyboard.propagateKeyboardInput and not dropdown.dropdown:IsMenuOpen())

    -- Global mouse events may arrive before or after Blizzard closes the menu.
    for _, closeFirst in ipairs({ false, true }) do
        openMenu()
        inputState.mouseFoci = { UIParent }
        if closeFirst then dropdown.dropdown:CloseMenu() end
        keyboard.scripts.OnEvent(keyboard, "GLOBAL_MOUSE_DOWN", "LeftButton")
        if not closeFirst then dropdown.dropdown:CloseMenu() end
        assert(keyboard.control == nil and not keyboard:IsShown()
            and not dropdown.dropdown.focusTexture:IsShown(),
            "outside clicks must release focus regardless of menu-close callback order")
    end
    inputState.mouseFoci = {}

    dropdown:_FocusForTab()
    dropdown.dropdown:SetEnabled(false)
    assert(keyboard.control == nil and not keyboard:IsShown(), "disabling a closed dropdown must release focus")
    dropdown:SetControlEnabled(true)
    openMenu()
    dropdown:SetControlEnabled(false)
    assert(not dropdown.dropdown:IsMenuOpen() and not keyboard:IsShown())
    dropdown:SetControlEnabled(true)
    openMenu()
    dropdown:Hide()
    dropdown.dropdown.scripts.OnHide(dropdown.dropdown)
    assert(not dropdown.dropdown:IsMenuOpen() and not keyboard:IsShown())
    assert(#dropdown.dropdown.callbacks.OnMenuOpen == 1 and #dropdown.dropdown.callbacks.OnMenuClose == 1)
    dropdown:Show()
    dropdown:SetChoices({})
    openMenu()
    local beforeEmpty = picks
    key("UP")
    key("DOWN")
    wheel(-1)
    assert(picks == beforeEmpty and menu.ScrollBox.revealedValue == nil)
    assertMenuLayout()
    key("ENTER")
    assert(not dropdown.dropdown:IsMenuOpen() and picks == beforeEmpty,
        "confirming an empty menu must not invent a selection")
    openMenu()
    key("SPACE")
    assert(not dropdown.dropdown:IsMenuOpen() and picks == beforeEmpty)

    dropdown:SetChoices(choices)
    dropdown:SetValue(1)
    openMenu()
    for expected = 2, 8 do
        local before = picks
        key("DOWN")
        assert(dropdown:GetValue() == expected and picks == before + 1)
        assert(menu.ScrollBox.revealedValue == expected)
        assertMenuLayout()
    end
    for expected = 7, 1, -1 do
        key("UP")
        assert(dropdown:GetValue() == expected and menu.ScrollBox.revealedValue == expected)
        assertMenuLayout()
    end

    local reversed = {}
    for index = #choices, 1, -1 do
        reversed[#reversed + 1] = choices[index]
    end
    dropdown:SetChoices(reversed)
    dropdown:SetValue(4)
    key("DOWN")
    assert(dropdown:GetValue() == 3 and menu.ScrollBox.revealedValue == 3)
    assertMenuLayout()
    dropdown:SetOnChanged(function(value)
        picks = picks + 1
        dropdown:SetChoices({ choices[1], choices[2] })
        dropdown:SetValue(value)
    end)
    key("DOWN")
    assert(dropdown:GetValue() == 2 and not menu.ScrollBox:IsShown())
    assertMenuLayout()
    key("UP")
    assert(dropdown:GetValue() == 1)
    assertMenuLayout()
    dropdown.dropdown:CloseMenu()

    dropdown:SetOnChanged(function(value)
        picks = picks + 1
        dropdown:SetValue(value)
    end)

    local grouped = {
        { type = "title", label = "First group" },
        { value = 1, label = "First", tooltip = "First explanation" },
        { value = 2, label = "Unavailable", enabled = false, tooltip = "Disabled explanation" },
        { type = "divider" },
        { type = "title", label = "Second group" },
        { value = 3, label = "Last", tooltipTitle = "Custom title", tooltip = "Last explanation" },
    }
    dropdown:SetChoices(grouped)
    dropdown:SetValue(1)
    openMenu()
    local description = dropdown.dropdown:GetMenuDescription()
    assert(#description.elements == 6 and #description.radioButtons == 3)
    assert(description.elements[1].kind == "title" and description.elements[1].label == "First group")
    assert(description.elements[4].kind == "divider" and not description.elements[4]:CanSelect())
    assert(description.radioButtons[1].tooltipTitle == "First")
    assert(description.radioButtons[1].tooltipText == "First explanation")
    assert(not description.radioButtons[2]:CanSelect())
    assert(description.radioButtons[2].tooltipText == "Disabled explanation")
    assert(description.radioButtons[3].tooltipTitle == "Custom title")
    key("DOWN")
    assert(dropdown:GetValue() == 3 and menu.ScrollBox.revealedValue == 3,
        "arrows skip headings, dividers and disabled choices, then reveal the selected row")
    assertMenuLayout()
    local groupedPicks = picks
    key("DOWN")
    assert(picks == groupedPicks and dropdown:GetValue() == 3, "grouped menus stop at their last choice")
    key("UP")
    assert(dropdown:GetValue() == 1)
    dropdown:SetValue(2)
    key("DOWN")
    assert(dropdown:GetValue() == 3, "a disabled saved selection remains a navigation starting point")
    dropdown:SetValue(nil)
    dropdown:_ScrollSelectionIntoView()
    assert(menu.ScrollBox.revealedValue == nil, "an unset selection must not scroll to a heading")
    key("DOWN")
    assert(dropdown:GetValue() == 1, "an unset selection starts at the first enabled radio")
    dropdown:SetValue(nil)
    key("UP")
    assert(dropdown:GetValue() == 3, "reverse navigation starts at the last enabled radio")
    grouped[3].enabled = true
    grouped[3].tooltip = nil
    dropdown:SetChoices(grouped)
    key("UP")
    description = dropdown.dropdown:GetMenuDescription()
    assert(dropdown:GetValue() == 2 and description.radioButtons[2]:CanSelect())
    assert(description.radioButtons[2].tooltipText == nil, "menu regeneration must drop removed tooltip data")
    assertMenuLayout()
    key("SPACE")
    assert(not dropdown.dropdown:IsMenuOpen() and keyboard.control == dropdown,
        "grouped selections preserve input focus when confirmed")

    -- Emulate an already-open menu from an embed predating navigation.
    dropdown:SetChoices(choices)
    dropdown:SetValue(3)
    menu:SetMenuDescription(dropdown.dropdown:GetMenuDescription())
    dropdown.dropdown.menu = menu
    menu:Show()
    dropdown.dropdown.callbacks = {}
    dropdown._libModernSettingsNavigationHooked = nil
    for _, description in dropdown.dropdown:GetMenuDescription():EnumerateElementDescriptions() do
        description[3] = function(value)
            dropdown:_SelectValue(value)
        end
    end
    lib._loadedModules["Controls/Dropdown"] = nil
    dofile("Controls/Dropdown.lua")
    key("DOWN")
    assert(dropdown:GetValue() == 4 and dropdown.dropdown:IsMenuOpen(),
        "live upgrades must replace old menu responders before stepping")
    lib._dropdownKeyboardFrame = lib._navigationKeyboardFrame
    lib._navigationKeyboardFrame = nil
    lib._loadedModules["Utilities/KeyboardNavigation"] = nil
    dofile("Utilities/KeyboardNavigation.lua")
    assert(lib._navigationKeyboardFrame == keyboard and lib._dropdownKeyboardFrame == nil,
        "compatible upgrades must reuse the existing keyboard frame")
    key("SPACE")
    assert(not dropdown.dropdown:IsMenuOpen() and dropdown:GetValue() == 4)
    openMenu()
    assertMenuLayout()
    dropdown.dropdown:CloseMenu()
    assert(menu.ScrollBox:GetScript("OnMouseWheel") == nativeWheel)
    assert(#dropdown.dropdown.callbacks.OnMenuOpen == 1 and #dropdown.dropdown.callbacks.OnMenuClose == 1)

    -- Older dropdowns can have retained appearance/menu callbacks but lack the
    -- new regions and closed-input focus hooks. Prepare regions before refresh.
    dropdown.dropdown._libModernSettingsInputNavigationHooked = nil
    dropdown.dropdown.focusTexture = nil
    dropdown.dropdown.arrowBackground = nil
    for _, script in ipairs({ "OnEnter", "OnLeave", "OnDisable", "OnHide" }) do
        dropdown.dropdown.scriptHooks[script] = nil
        dropdown.dropdown:SetScript(script, nil)
    end
    dropdown.dropdown:SetScript("OnLeave", dropdown.dropdown.OnLeave)
    lib._loadedModules["Controls/Dropdown"] = nil
    dofile("Controls/Dropdown.lua")
    dropdown:_FocusForTab()
    dropdown.dropdown.scripts.OnLeave(dropdown.dropdown)
    assert(dropdown.dropdown.focusTexture:IsShown(),
        "upgraded dropdowns must retain their keyboard focus glow")
    dropdown.dropdown:SetEnabled(false)
    assert(not keyboard:IsShown() and keyboard.control == nil,
        "upgraded dropdowns must release closed-input focus when disabled")
    dropdown:SetControlEnabled(true)
    assert(#dropdown.dropdown.callbacks.OnMenuOpen == 1 and #dropdown.dropdown.callbacks.OnMenuClose == 1)
    dofile("tests/tab_navigation.lua")(lib, makeFrame, inputState, openMenu, key)
    dofile("tests/button_navigation.lua")(lib, makeFrame, inputState, openMenu, key)
    dofile("tests/navigation_contract.lua")(lib, makeFrame, inputState, key)
    dofile("tests/dropdown_multi.lua")(lib, openMenu, key, menu)
    dofile("tests/dropdown_previews.lua")(lib, openMenu, key, menu)
    dofile("tests/value_list.lua")(lib, makeFrame, inputState, key)
    print("LibModernSettings navigation tests passed")
end
