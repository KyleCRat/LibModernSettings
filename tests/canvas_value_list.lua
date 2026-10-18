return function(newEnvironment, loadVersion)
    local function deferSizeNotification(frame)
        local setSize = frame.SetSize
        local pending
        frame.SetSize = function(self, width, height)
            if self.width ~= width or self.height ~= height then
                self.width, self.height = width, height
                pending = true
            end
        end
        return function()
            frame.SetSize = setSize
            if pending and frame.scripts.OnSizeChanged then
                frame.scripts.OnSizeChanged(frame, frame:GetWidth(), frame:GetHeight())
            end
        end
    end

    local function notifySizeWhenMeasured(frame)
        local setSize = frame.SetSize
        local getWidth = frame.GetWidth
        local getHeight = frame.GetHeight
        local pending
        local function notify()
            if pending then
                pending = nil
                frame.scripts.OnSizeChanged(frame, frame.width, frame.height)
            end
        end
        frame.SetSize = function(self, width, height)
            if self.width ~= width or self.height ~= height then
                self.width, self.height = width, height
                pending = true
            end
        end
        frame.GetWidth = function(self)
            notify()
            return getWidth(self)
        end
        frame.GetHeight = function(self)
            notify()
            return getHeight(self)
        end
        return function()
            notify()
            frame.SetSize = setSize
            frame.GetWidth = getWidth
            frame.GetHeight = getHeight
        end
    end

    local environment = newEnvironment()
    local lib = loadVersion(environment, false)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, { width = 220, height = 100, scrollable = true })
    local left, right = layout:GetContentInsets()
    layout:SetSize(170 + left + right, 100)
    local root = layout:GetRootFlow()
    root:AddSpacer(40)
    local changes = 0
    local field = root:AddControl("field", {
        label = "Positions",
        controlType = "valueList",
        controlOptions = {
            value = { 10, 30, 60 },
            parseValue = tonumber,
            onChanged = function()
                changes = changes + 1
            end,
        },
    }, { marginBottom = 6 })
    local following = root:AddControl("textInput", { value = "After positions" })
    root:AddSpacer(600)
    layout:Finalize()
    environment.Flush()

    local list = field:GetControl()
    local sizeChanged = list.scripts.OnSizeChanged
    local childSizeChanging
    list.scripts.OnSizeChanged = function(...)
        childSizeChanging = true
        sizeChanged(...)
        childSizeChanging = nil
    end
    local setFieldHeight = field.SetHeight
    function field:SetHeight(height)
        assert(not childSizeChanging,
            "a child size callback must not resize its Field while native geometry is resolving")
        setFieldHeight(self, height)
    end
    -- This harness does not resolve FontString-relative anchors. Supply the
    -- stacked Field geometry so focused-child scrolling uses native coordinates.
    function list:GetTop()
        return field:GetTop() - field.label:GetHeight() + select(5, self:GetPoint())
    end
    local scrollBox = layout:GetScrollBox()
    local function checkFollowing()
        assert(following.point[5] == field.point[5] - field:GetHeight() - 6,
            "following controls must move below the whole wrapped field")
    end
    local function checkVisible(control)
        local top = layout:GetContent():GetTop() - control:GetTop()
        local offset = scrollBox:GetDerivedScrollOffset()
        assert(top >= offset and top + control:GetHeight() <= offset + scrollBox:GetVisibleExtent(),
            string.format("focused field bounds %.2f..%.2f must fit viewport %.2f..%.2f",
                top, top + control:GetHeight(), offset, offset + scrollBox:GetVisibleExtent()))
    end

    assert(list:GetHeight() == 74)
    checkFollowing()
    list:FocusValue(3)
    local flushSizeNotification = deferSizeNotification(list)
    list.entries[3]:SetText("70")
    list.entries[3].scripts.OnEnterPressed(list.entries[3])
    flushSizeNotification()
    environment.Flush(2)
    assert(list:GetHeight() == 114 and #list.slots == 4 and changes == 1)
    assert(list.entries[4]:HasFocus() and list.entries[4]:GetText() == "")
    checkFollowing()
    checkVisible(list.entries[4])

    local frameCount = environment.framesCreated
    local entries = { unpack(list.entries) }
    local clears = {}
    for _, input in ipairs(entries) do
        clears[input] = input.clearPointsCount or 0
    end
    list.entries[4]:SetText("85")
    for _, width in ipairs({ 354, 170, 354, 170 }) do
        layout:SetSize(width + left + right, 100)
        environment.Flush()
        assert(list:GetHeight() == (width == 354 and 34 or 114))
        assert(list.entries[4]:HasFocus() and list.entries[4]:GetText() == "85" and changes == 1)
        assert(environment.framesCreated == frameCount, "resizing must retain all value fields")
        for index, input in ipairs(entries) do
            assert(list.entries[index] == input and (input.clearPointsCount or 0) == clears[input],
                "wrapping must not detach or rebuild existing inputs")
        end
        checkFollowing()
    end

    -- Tab and explicit focus share Canvas reveal behavior for a tall composite.
    list:CancelAndClearFocus()
    list:FocusValue(1)
    environment.Flush()
    checkVisible(list.entries[1])
    for index = 1, 3 do
        list.entries[index].scripts.OnTabPressed(list.entries[index])
        environment.Flush()
        assert(list.entries[index + 1]:HasFocus())
        checkVisible(list.entries[index + 1])
    end
    list:RemoveLastEntry()
    environment.Flush(2)
    assert(list:GetHeight() == 74 and list.entries[3]:HasFocus())
    checkFollowing()
    checkVisible(list.entries[3])

    list:CancelAndClearFocus()
    parent:Hide()
    layout:SetSize(354 + left + right, 100)
    assert(environment.QueueSize() == 0)
    parent:Show()
    parent.scripts.OnShow(parent)
    environment.Flush()
    assert(list:GetHeight() == 34 and list:GetValue()[3] == 70)
    checkFollowing()
    list:FocusValue(1)
    environment.Flush()
    checkVisible(field)
    list:CancelAndClearFocus()

    layout:SetSize(170 + left + right, 100)
    list:SetValue({ 10, 20, 30, 40 })
    environment.Flush(2)
    list:FocusValue(1)
    list:FocusValue(4)
    assert(environment.QueueSize() == 1, "rapid focus requests must coalesce to the latest pill")
    environment.Flush()
    checkVisible(list.entries[4])
    local settledOffset = scrollBox:GetDerivedScrollOffset()
    list:FocusValue(1)
    list:SetValue({ 15, 25, 35, 45 })
    environment.Flush()
    assert(scrollBox:GetDerivedScrollOffset() == settledOffset,
        "rebinding before reveal must cancel scrolling to the previous owner's input")
    list:FocusValue(1)
    parent:Hide()
    environment.Flush()
    assert(scrollBox:GetDerivedScrollOffset() == settledOffset,
        "closing before reveal must leave the saved scroll position alone")
    list:CancelAndClearFocus()

    -- Native measurements can synchronously dispatch a pending size callback.
    -- Grow/shrink without a window resize: the label, full Field height and next
    -- row must settle without changing the parent from inside that callback.
    parent:Show()
    parent.scripts.OnShow(parent)
    layout:SetSize(284 + left + right, 100)
    list:SetValue({ 10, 20, 30 })
    environment.Flush(2)
    local fieldPoint = field.point
    local labelPoint = field.label.point
    local restoreMeasurements = notifySizeWhenMeasured(list)
    for iteration = 1, 4 do
        list:FocusValue(3)
        list.entries[3]:SetText(tostring(30 + iteration))
        list.entries[3].scripts.OnEnterPressed(list.entries[3])
        environment.Flush(2)
        assert(list:GetHeight() == 74 and field:GetHeight() == field.label:GetHeight() + 7 + 74)
        assert(list.entries[4]:HasFocus())
        checkFollowing()
        checkVisible(field)

        list:RemoveLastEntry()
        environment.Flush(2)
        assert(list:GetHeight() == 34 and field:GetHeight() == field.label:GetHeight() + 7 + 34)
        assert(list.entries[3]:HasFocus())
        assert(field:IsVisible() and field.label:IsShown())
        assert(field.point == fieldPoint and field.label.point == labelPoint,
            "row-count changes must retain the Field and label anchors")
        assert(field._libModernSettingsExplicitHeight == nil)
        assert(list._libModernSettingsExplicitHeight == nil)
        checkFollowing()
        checkVisible(field)
    end

    list:AddEntry()
    list:RemoveLastEntry()
    list:AddEntry()
    list:SetValue({ 5 })
    environment.Flush(2)
    assert(list:GetHeight() == 34 and field:GetHeight() == field.label:GetHeight() + 7 + 34,
        "queued layout must use the latest values after rapid changes and rebinding")
    assert(next(lib._pendingFieldLayouts) == nil)
    checkFollowing()
    restoreMeasurements()

    -- Sections can contain their own non-scrolling canvas. Resolve child growth
    -- before revealing through the outer viewport, even if pairs visits it first.
    local nestedEnvironment = newEnvironment()
    local nestedLib = loadVersion(nestedEnvironment, false)
    local window = nestedEnvironment.CreateFrame("Frame")
    nestedLib:EnableTabNavigation(window)
    local outer = nestedLib:CreateCanvasLayout(window, { width = 300, height = 100, scrollable = true })
    local section = nestedEnvironment.CreateFrame("Frame", nil, outer:GetContent())
    section:SetSize(outer:GetContentWidth(), 1)
    outer:GetRootFlow():AddFrame(section, { fillWidth = true })
    local inner = nestedLib:CreateCanvasLayout(section, { width = outer:GetContentWidth(), height = 1 })
    local nestedField = inner:GetRootFlow():AddControl("field", {
        label = "Nested positions",
        controlType = "valueList",
        controlOptions = { value = { 10, 20, 30, 40, 50 } },
    })
    inner:GetContent():HookScript("OnSizeChanged", function(content)
        section:SetHeight(content:GetHeight())
        outer:RequestLayout()
    end)
    inner:Finalize()
    outer:Finalize()
    nestedEnvironment.Flush()
    local nestedList = nestedField:GetControl()
    function nestedList:GetTop()
        return nestedField:GetTop() - nestedField.label:GetHeight() + select(5, self:GetPoint())
    end
    nestedEnvironment.pairs = function(values)
        if values == nestedLib._canvasLayouts then
            local order = { outer, inner }
            local index = 0
            return function()
                index = index + 1
                return order[index], true
            end
        end
        return pairs(values)
    end
    local flushListSize = deferSizeNotification(nestedList)
    local flushContentSize = deferSizeNotification(inner:GetContent())
    nestedList:AddEntry()
    flushListSize()
    flushContentSize()
    nestedEnvironment.Flush(2)
    local focused = nestedList.entries[#nestedList.slots]
    assert(focused:HasFocus())
    local top = outer:GetContent():GetTop() - focused:GetTop()
    local offset = outer:GetScrollBox():GetDerivedScrollOffset()
    assert(top >= offset and top + focused:GetHeight() <= offset + 100,
        string.format("nested focused bounds %.2f..%.2f must fit viewport %.2f..%.2f; section %.2f, content %.2f",
            top, top + focused:GetHeight(), offset, offset + 100, section:GetHeight(), outer:GetContent():GetHeight()))
    assert(not inner.dirty and not outer.dirty)
    nestedList:CancelAndClearFocus()
    print("LibModernSettings wrapping value list canvas tests passed")
end
