return function(lib, makeFrame, inputState, key)
    local function enter(input, text)
        local focused = GetCurrentKeyBoardFocus()

        if focused and focused ~= input then focused:ClearFocus() end

        input:FocusValue()
        input:SetText(text)
        input.scripts.OnEnterPressed(input)
    end

    local function parseNumber(text)
        local value = tonumber(text)

        if not value or value ~= value or value < 0 or value == math.huge then
            return nil, "Invalid position"
        end

        return value
    end

    local function checkPosition(frame, parent, x, y)
        local point, relativeTo, relativePoint, actualX, actualY =
            frame:GetPoint(1)
        assert(
            point == "TOPLEFT"
                and relativeTo == parent
                and relativePoint == "TOPLEFT"
        )
        assert(
            actualX == x and actualY == y,
            "wrapped pills and actions must follow row-major order"
        )
    end

    local changes, errors = 0, 0
    local list
    list = lib:CreateValueList(UIParent, {
        width = 270,
        maxValues = 4,
        parseValue = parseNumber,
        onChanged = function(values)
            changes = changes + 1
            -- Consumers may synchronously echo the accepted model value.
            list:SetValue(values)
            values[1] = -999
        end,
        onError = function(message)
            assert(message == "Invalid position")
            errors = errors + 1
        end,
    })
    assert(
        list:GetHeight() == 34 and #list.entries == 1 and #list:GetValue() == 0
    )
    assert(not list.removeButton:IsShown())
    assert(list.entries[1]:GetWidth() == 64)

    enter(list.entries[1], "20")
    assert(list:GetValue()[1] == 20 and changes == 1)
    assert(
        #list.slots == 2
            and list.entries[2]:HasFocus()
            and list.entries[2]:GetText() == ""
    )
    assert(list.removeButton:IsShown())
    enter(list.entries[2], "45.5")
    assert(
        #list:GetValue() == 2
            and list:GetValue()[2] == 45.5
            and #list.slots == 3
    )
    list:AddEntry()
    assert(
        #list.slots == 3,
        "adding while the final field is empty must reuse it"
    )
    enter(list.entries[3], "80")
    assert(#list.slots == 4 and #list:GetValue() == 3)
    assert(not list.addButton:IsEnabled())
    enter(list.entries[4], "125")
    assert(
        #list:GetValue() == 4
            and #list.slots == 4
            and list.entries[4]:HasFocus()
    )
    assert(changes == 4 and list:GetHeight() == 74)
    checkPosition(list.entries[1], list, 0, 0)
    checkPosition(list.entries[3], list, 140, 0)
    checkPosition(list.entries[4], list, 0, -40)
    checkPosition(list.removeButton, list, 70, -40)
    checkPosition(list.addButton, list, 110, -40)

    local saved = list:GetValue()
    saved[1] = 1000
    assert(list:GetValue()[1] == 20)
    enter(list.entries[4], "not a number")
    assert(errors == 1 and changes == 4 and list:GetValue()[4] == 125)
    assert(list.entries[4]:HasFocus() and list.entries[4]:GetText() == "125")
    list.entries[4]:SetText("Canceled")
    list.entries[4].scripts.OnEscapePressed(list.entries[4])
    assert(
        changes == 4
            and not list.entries[4]:HasFocus()
            and list.entries[4]:GetText() == "125"
    )

    list:RemoveLastEntry()
    assert(#list:GetValue() == 3 and #list.slots == 3 and changes == 5)
    assert(list.entries[3]:HasFocus() and not list.entries[4]:IsShown())
    list:RemoveLastEntry()
    list:RemoveLastEntry()
    assert(
        #list.slots == 1
            and #list:GetValue() == 1
            and not list.removeButton:IsShown()
    )
    assert(
        list:GetHeight() == 34,
        "removing extra fields must release their rows"
    )
    assert(list:RemoveLastEntry() == false)
    enter(list.entries[1], "")
    assert(#list:GetValue() == 0 and #list.slots == 1)

    local incoming = { 10, 30, 60, 90 }
    list:SetValue(incoming)
    incoming[1] = 200
    assert(list:GetValue()[1] == 10)
    local entries = { unpack(list.entries) }
    list:FocusValue(4)
    list.entries[4]:SetText("95")
    list:SetControlWidth(170)
    assert(list:GetHeight() == 114 and list.entries[4] == entries[4])
    assert(list.entries[4]:GetText() == "95" and list.entries[4]:HasFocus())
    checkPosition(list.entries[2], list, 70, 0)
    checkPosition(list.entries[3], list, 0, -40)
    checkPosition(list.entries[4], list, 0, -80)
    checkPosition(list.removeButton, list, 70, -80)
    checkPosition(list.addButton, list, 110, -80)
    assert(
        not list.scripts.OnMouseWheel
            and not list.entries[4].scripts.OnMouseWheel,
        "value fields must leave mouse wheel scrolling to the containing page"
    )

    for _, width in ipairs({ 354, 353, 354.0001, 353.9999, 50, 270 }) do
        list:SetControlWidth(width)
        local oneRow = width >= 353.9999
        assert(list:GetHeight() == (oneRow and 34 or width == 50 and 234 or 74))

        for index, input in ipairs(list.entries) do
            assert(input == entries[index] and input:GetNumPoints() == 1)
            local _, _, _, x, y = input:GetPoint(1)
            assert(x >= 0 and x + input:GetWidth() <= width + 0.001)
            assert(-y + input:GetHeight() <= list:GetHeight())
        end

        assert(list.entries[4]:HasFocus() and list.entries[4]:GetText() == "95")
    end

    for _, width in ipairs({ 144, 143.9999, 144.0001 }) do
        list:SetControlWidth(width)
        checkPosition(list.entries[4], list, 0, -80)
        checkPosition(list.removeButton, list, 70, -80)
        checkPosition(list.addButton, list, 110, -80)
    end

    list:CommitAndClearFocus()
    assert(list:GetValue()[4] == 95)

    list:FocusValue(1)
    list.entries[1]:SetText("50")
    local before = changes
    inputState.mouseDown = true
    list.entries[1]:ClearFocus()
    assert(changes == before)
    list:SetValue({ 7 })
    inputState.mouseDown = false
    lib:_FlushPendingEditBoxCommits()
    assert(
        list:GetValue()[1] == 7 and changes == before,
        "rebinding must cancel deferred edits"
    )
    list:FocusValue()
    list.entries[1]:SetText("70")
    list:SetControlEnabled(false, "Unavailable")
    assert(list:GetValue()[1] == 7 and not list.entries[1]:HasFocus())
    assert(not list.entries[1]:IsEnabled() and not list.addButton:IsEnabled())
    assert(list:AddEntry() == false)
    list:SetControlEnabled(true)
    list:FocusValue()
    list.entries[1]:SetText("70")
    list:Hide()
    list.scripts.OnHide(list)
    assert(list:GetValue()[1] == 7 and not list.entries[1]:HasFocus())
    list:Show()

    -- Consumer normalization/rebinding must supersede the edit and cancel advancement.
    list:SetOnChanged(function()
        list:SetValue({ 99 })
    end)
    enter(list.entries[1], "80")
    assert(
        list:GetValue()[1] == 99
            and list.entries[1]:GetText() == "99"
            and #list.slots == 1
    )
    assert(not list.entries[1]:HasFocus())

    local formatted = lib:CreateValueList(UIParent, {
        value = { 2 },
        parseValue = function(text)
            return tonumber(text:match("^(%d+)s$"))
        end,
        formatValue = function(value)
            return tostring(value) .. "s"
        end,
    })
    assert(formatted.entries[1]:GetText() == "2s")
    enter(formatted.entries[1], "7s")
    assert(
        formatted:GetValue()[1] == 7 and formatted.entries[1]:GetText() == "7s"
    )
    formatted:CancelAndClearFocus()
    assert(not pcall(function()
        formatted:SetOnChanged(false)
    end))
    assert(not pcall(function()
        formatted:SetOnError(false)
    end))
    assert(not pcall(function()
        formatted:FocusValue(0)
    end))
    assert(not pcall(function()
        formatted:SetValue({ math.huge })
    end))

    list:SetOnChanged(function()
        list:Hide()
        list.scripts.OnHide(list)
    end)
    enter(list.entries[1], "5")
    assert(
        #list.slots == 1 and not list.entries[1]:HasFocus(),
        "closing during a commit must not add/focus a field"
    )

    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local first = lib:CreateTextInput(root)
    first:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    local field = lib:CreateField(root, {
        label = "Values",
        controlType = "valueList",
        controlOptions = {
            value = { "One", "Two", "Three", "Four" },
            width = 170,
        },
        width = 170,
    })
    field:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
    local tabList = field:GetControl()
    local labelHeight = field.label:GetHeight()
    assert(
        tabList:GetHeight() == 114
            and field:GetHeight() == labelHeight + 7 + 114
    )
    field:SetControlWidth(354)
    assert(
        tabList:GetHeight() == 34 and field:GetHeight() == labelHeight + 7 + 34
    )
    field:SetControlWidth(170)
    assert(
        tabList:GetHeight() == 114
            and field:GetHeight() == labelHeight + 7 + 114,
        "a ValueList must reflow as one Field and report its full wrapped height"
    )
    first:FocusValue()
    first.scripts.OnTabPressed(first)
    assert(tabList.entries[1]:HasFocus())
    tabList.entries[1].scripts.OnTabPressed(tabList.entries[1])
    assert(tabList.entries[2]:HasFocus())
    tabList.entries[2].scripts.OnTabPressed(tabList.entries[2])
    assert(
        tabList.entries[3]:HasFocus(),
        "Tab must advance onto the next wrapped row"
    )
    inputState.modifiers.shift = true
    tabList.entries[3].scripts.OnTabPressed(tabList.entries[3])
    assert(tabList.entries[2]:HasFocus())
    tabList.entries[2].scripts.OnTabPressed(tabList.entries[2])
    assert(tabList.entries[1]:HasFocus())
    tabList.entries[1].scripts.OnTabPressed(tabList.entries[1])
    assert(first:HasFocus())
    inputState.modifiers.shift = false
    first:CancelAndClearFocus()
    tabList:FocusValue(4)
    tabList.entries[4].scripts.OnTabPressed(tabList.entries[4])
    assert(lib._navigationKeyboardFrame.control == tabList.removeButton)
    key("ENTER")
    assert(#tabList:GetValue() == 3 and tabList.entries[3]:HasFocus())
    tabList:CancelAndClearFocus()

    -- Existing children keep their hooks and drafts through compatible module upgrades.
    local hookCount = #tabList.entries[1].scriptHooks.OnEnterPressed
    tabList:FocusValue()
    tabList.entries[1]:SetText("Draft")

    for _, name in ipairs({ "Controls/TextInput", "Controls/ValueList" }) do
        lib._loadedModules[name] = nil
        dofile(name .. ".lua")
    end

    assert(
        tabList.entries[1]:GetText() == "Draft"
            and tabList.entries[1]:HasFocus()
    )
    assert(#tabList.entries[1].scriptHooks.OnEnterPressed == hookCount)
    enter(tabList.entries[1], "Updated")
    assert(tabList:GetValue()[1] == "Updated" and tabList.entries[2]:HasFocus())
    tabList:CancelAndClearFocus()
    local definition = lib._controlTypes.valueList.factory
    dofile("Controls/ValueList.lua")
    assert(
        lib._controlTypes.valueList.factory == definition,
        "duplicate modules must not replace the selected implementation"
    )
    local minor = lib._implementationMinor
    lib._implementationMinor = minor + 1
    dofile("Controls/ValueList.lua")
    assert(
        lib._controlTypes.valueList.factory == definition,
        "an older module must not overwrite a newer family implementation"
    )
    lib._implementationMinor = minor

    for _, options in ipairs({
        { entryWidth = 0 },
        { entryWidth = math.huge },
        { maxValues = 0 },
        { maxValues = 1.5 },
        { parseValue = true },
        { onError = "bad" },
        { value = { [1] = "One", [3] = "Three" } },
        { value = { "" } },
        { value = { 0 / 0 } },
        { value = { {} } },
        { value = false },
        {
            value = { 1, 2 },
            maxValues = 1,
        },
    }) do
        assert(not pcall(function()
            lib:CreateValueList(UIParent, options)
        end), "invalid list options should fail")
    end

    print("LibModernSettings value list tests passed")
end
