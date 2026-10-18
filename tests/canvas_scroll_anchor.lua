return function(newEnvironment, loadVersion)
    local function addSection(environment, layout, height)
        local frame = environment.CreateFrame("Frame", nil, layout:GetContent())
        frame:SetSize(layout:GetContentWidth(), height)
        layout:GetRootFlow():AddFrame(frame, { fillWidth = true })
        return frame
    end

    local environment = newEnvironment()
    local lib = loadVersion(environment, false)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, { width = 600, height = 200, scrollable = true })
    local above = addSection(environment, layout, 300)
    local section = addSection(environment, layout, 400)
    local input = lib:CreateTextInput(section, { value = "Retained" })
    input:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -100)
    local below = addSection(environment, layout, 600)
    layout:Finalize()
    environment.Flush()
    local scrollBox = layout:GetScrollBox()
    local frameCount = environment.framesCreated

    local function top(frame)
        return layout:GetContent():GetTop() - frame:GetTop()
    end

    local function checkOffset(expected)
        assert(math.abs(scrollBox:GetDerivedScrollOffset() - expected) < 0.001,
            "scroll anchor must follow the section's content position: expected "
                .. expected .. ", got " .. scrollBox:GetDerivedScrollOffset())
    end

    scrollBox:ScrollToOffset(top(section) + 75, environment.ScrollBoxConstants.NoScrollInterpolation)
    layout:SetScrollAnchor(section, 75)
    input:SetFocus()
    input:SetText("Uncommitted")

    -- Nested sections can notify in separate ticks, after an outer reflow.
    for _, height in ipairs({ 50, 500, 125, 300 }) do
        above:SetHeight(height)
        environment.Flush()
        checkOffset(top(section) + 75)
        assert(layout:GetScrollAnchor() == section)
    end
    assert(input:HasFocus() and input:GetText() == "Uncommitted")
    assert(environment.framesCreated == frameCount, "anchoring must retain all controls")

    section:SetHeight(34)
    environment.Flush()
    checkOffset(top(section))
    section:SetHeight(400)
    environment.Flush()
    checkOffset(top(section) + 75)

    layout:SetScrollAnchor(section, -40)
    environment.Flush()
    checkOffset(top(section) - 40)
    layout:RefreshLayout()
    assert(layout:GetScrollAnchor() == section,
        "native FullUpdate scroll notifications must not cancel the anchor")

    -- Replacing a pending bookmark must win without a delayed old scroll.
    layout:SetScrollAnchor(above, 20)
    layout:SetScrollAnchor(section, 25)
    environment.Flush()
    checkOffset(top(section) + 25)
    assert(#scrollBox.callbacks[environment.BaseScrollBoxEvents.OnScroll] == 1)

    scrollBox:TriggerEvent(environment.BaseScrollBoxEvents.OnScroll)
    assert(layout:GetScrollAnchor() == nil,
        "an interpolated wheel gesture must release the anchor before its first offset change")
    layout:SetScrollAnchor(section, 25)
    scrollBox:ScrollToOffset(100, environment.ScrollBoxConstants.NoScrollInterpolation)
    assert(layout:GetScrollAnchor() == nil, "external scrolling must release the anchor")
    above:SetHeight(450)
    environment.Flush()
    checkOffset(100)

    layout:SetScrollAnchor(section)
    layout:SetScrollAnchor(nil)
    environment.Flush()
    checkOffset(100)
    assert(layout:GetScrollAnchor() == nil)

    layout:SetScrollAnchor(section, 250)
    below:SetHeight(1)
    environment.Flush()
    checkOffset(layout:GetContent():GetHeight() - scrollBox:GetVisibleExtent())
    assert(layout:GetScrollAnchor() == section, "clamping must not discard the requested section")
    below:SetHeight(600)
    environment.Flush()
    checkOffset(top(section) + 250)

    layout:SetScrollAnchor(section, 0)
    layout:_ScrollControlIntoView(below)
    assert(layout:GetScrollAnchor() == nil, "keyboard reveal must own the scroll position")
    local revealed = scrollBox:GetDerivedScrollOffset()
    environment.Flush()
    checkOffset(revealed)

    parent:Hide()
    layout:SetScrollAnchor(section, 30)
    above:SetHeight(50)
    environment.Flush()
    checkOffset(revealed)
    parent:Show()
    parent.scripts.OnShow(parent)
    environment.Flush()
    checkOffset(top(section) + 30)

    section:Hide()
    layout:RequestLayout()
    environment.Flush()
    section:Show()
    layout:RequestLayout()
    environment.Flush()
    checkOffset(top(section) + 30)

    -- Use a scaled descendant: offsets remain in the outer canvas's units.
    local child = environment.CreateFrame("Frame", nil, section)
    child:SetSize(50, 100)
    function child:GetEffectiveScale()
        return 2
    end
    function child:GetTop()
        return section:GetTop() / 2
    end
    layout:SetScrollAnchor(child, 60)
    environment.Flush()
    checkOffset(top(section) + 60)
    child:SetParent(parent)
    layout:RequestLayout()
    environment.Flush()
    assert(layout:GetScrollAnchor() == nil, "reparented anchors must be released")

    for _, invalid in ipairs({ false, "15", math.huge, -math.huge, 0 / 0 }) do
        assert(not pcall(layout.SetScrollAnchor, layout, section, invalid))
    end
    assert(not pcall(layout.SetScrollAnchor, layout, parent, 0))
    assert(not pcall(layout.SetScrollAnchor, layout, "section", 0))
    assert(not pcall(layout.SetScrollAnchor, layout, nil, 0))
    local plain = lib:CreateCanvasLayout(environment.CreateFrame("Frame"), { width = 600, height = 200 })
    assert(not pcall(plain.SetScrollAnchor, plain, plain:GetContent(), 0))

    -- The prototype API also works on retained canvases after a compatible upgrade.
    local upgradeEnvironment = newEnvironment()
    local oldLib = loadVersion(upgradeEnvironment, true)
    local oldParent = upgradeEnvironment.CreateFrame("Frame")
    local retained = oldLib:CreateCanvasLayout(oldParent, { width = 600, height = 200, scrollable = true })
    local oldAbove = addSection(upgradeEnvironment, retained, 300)
    local oldSection = addSection(upgradeEnvironment, retained, 500)
    retained:Finalize()
    upgradeEnvironment.Flush()
    loadVersion(upgradeEnvironment, false)
    retained:SetScrollAnchor(oldSection, 20)
    oldAbove:SetHeight(150)
    upgradeEnvironment.Flush()
    assert(retained:GetScrollBox():GetDerivedScrollOffset()
        == retained:GetContent():GetTop() - oldSection:GetTop() + 20)
    loadVersion(upgradeEnvironment, true)
    oldAbove:SetHeight(250)
    upgradeEnvironment.Flush()
    assert(retained:GetScrollBox():GetDerivedScrollOffset()
        == retained:GetContent():GetTop() - oldSection:GetTop() + 20)

    print("LibModernSettings canvas scroll anchor tests passed")
end
