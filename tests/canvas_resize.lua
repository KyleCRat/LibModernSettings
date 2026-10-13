return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, false)
    local parent = environment.CreateFrame("Frame")
    local header = lib:CreateCanvasLayout(parent, { width = 700, height = 34 })
    local toolbar = header:GetRootFlow():AddCustom(34)
    local name = lib:CreateTextInput(toolbar, { value = "Retained name" })
    name:SetPoint("LEFT", toolbar, "LEFT", 0, 0)
    local enabled = lib:CreateCheckbox(toolbar, { value = true, label = "Enabled" })
    enabled:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    header:Finalize()
    environment.Flush()

    local body = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(body, { width = 700, height = 160, scrollable = true })
    local root = layout:GetRootFlow()
    root:AddSpacer(100)
    local columns = root:BeginColumns({ minColumnWidth = 260 })
    local field = columns.left:AddControl("field", {
        label = "Name", description = "Retained description", controlType = "textInput",
        controlOptions = { value = "Original value" },
    })
    local slider = columns.right:AddControl("slider", {
        label = "Scale", minValue = 0, maxValue = 5, step = 0.1, value = 1,
    })
    columns:Finish()
    local dropdown = root:AddControl("dropdown", {
        label = "Choice", choices = { { value = 1, label = "One" } }, value = 1,
    })
    root:AddSpacer(600)
    layout:Finalize()
    environment.Flush()

    local regions = {
        toolbar, name, enabled, layout:GetContent(), field, field.label, field:GetControl(), field.description,
        slider, slider.label, slider.inputRow, slider.slider, slider.valueBox,
        dropdown, dropdown.label, dropdown.dropdown,
    }
    local cleared = {}
    for _, region in ipairs(regions) do
        cleared[region] = region.clearPointsCount or 0
    end
    local frameCount = environment.framesCreated
    field:GetControl():SetFocus()
    field:GetControl():SetText("Uncommitted input")

    for _, offset in ipairs({ 0, 160, 500 }) do
        layout:GetScrollBox():ScrollToOffset(offset, environment.ScrollBoxConstants.NoScrollInterpolation)
        for _, width in ipairs({ 680, 540, 520, 720, 560, 700 }) do
            header:SetSize(width, 34)
            layout:SetSize(width, 160)
            environment.Flush()
            assert(layout:GetScrollBox():GetDerivedScrollOffset() == offset,
                "reflow must preserve the scrolled position while it remains in range")
            for _, region in ipairs(regions) do
                assert((region.clearPointsCount or 0) == cleared[region],
                    "resizing must not detach established input or container anchors")
                assert(region:GetNumPoints() > 0, "resizing must leave every input anchored")
            end
        end
    end

    assert(name:GetValue() == "Retained name" and enabled:GetValue())
    assert(field:GetControl():GetText() == "Uncommitted input" and field:GetControl():HasFocus())
    assert(environment.framesCreated == frameCount, "resize must reuse controls and containers")
    assert(environment.QueueSize() == 0, "resizing must stop scheduling once geometry settles")

    body:Hide()
    layout:SetSize(510, 200)
    layout:RequestLayout()
    assert(environment.QueueSize() == 0, "hidden resizes must wait for the page to return")
    body:Show()
    body.scripts.OnShow(body)
    environment.Flush()
    assert(field:GetControl():GetText() == "Uncommitted input")
    assert(layout:GetContent():GetWidth() == layout:GetContentWidth())
    assert((layout:GetContent().clearPointsCount or 0) == cleared[layout:GetContent()])

    layout:SetSize(510, 2000)
    environment.Flush()
    assert(layout:GetScrollBox():GetDerivedScrollOffset() == 0,
        "growing beyond the content must clamp to the beginning")
    assert(layout:GetContent():GetTop() == layout:GetScrollBox():GetScrollTarget():GetTop())
    layout:SetSize(700, 160)
    environment.Flush()
    assert(layout:GetScrollBox():GetDerivedScrollOffset() == 0)

    -- An anchored viewport can notify after it has already resolved its size.
    -- Feeding that same size back must not create an additional native resize.
    local setSize, setWidth, setHeight = body.SetSize, body.SetWidth, body.SetHeight
    body.width, body.height = 710, 170
    local function rejectResize()
        error("resolved parent dimensions must not be written back from OnSizeChanged")
    end
    body.SetSize, body.SetWidth, body.SetHeight = rejectResize, rejectResize, rejectResize
    layout:SetSize(710, 170)
    environment.Flush()
    body.SetSize, body.SetWidth, body.SetHeight = setSize, setWidth, setHeight

    -- Content-sized sections retain a one-pixel layout minimum, but their
    -- consumer measures the parent's actual height from the finished contents.
    local section = environment.CreateFrame("Frame")
    local child = lib:CreateCanvasLayout(section, { width = 500, height = 1 })
    child:GetRootFlow():AddControl("textInput", { value = "Section contents" })
    child:Finalize()
    environment.Flush()
    local measuredHeight = child:GetContent():GetHeight()
    section:SetHeight(measuredHeight)
    section:HookScript("OnSizeChanged", function(_, _, height)
        assert(height == measuredHeight, "a width-only reflow must not collapse the measured section height")
    end)
    child:SetSize(600, 1)
    environment.Flush()
    assert(section:GetHeight() == measuredHeight and child:GetCanvasHeight() == 1)

    -- Upgrade a retained canvas which still uses Blizzard's default linear
    -- placement, rather than testing only instances made by the new constructor.
    local upgradeEnvironment = newEnvironment()
    local oldLib = loadVersion(upgradeEnvironment, true)
    local oldParent = upgradeEnvironment.CreateFrame("Frame")
    local retained = oldLib:CreateCanvasLayout(oldParent, { width = 600, height = 160, scrollable = true })
    local retainedInput = retained:GetRootFlow():AddControl("textInput", { value = "Retained" })
    retained:GetRootFlow():AddSpacer(900)
    retained:Finalize()
    upgradeEnvironment.Flush()
    local scrollBox, scrollBar = retained:GetScrollBox(), retained:GetScrollBar()
    local nativeView = scrollBox:GetView()
    nativeView.Layout = upgradeEnvironment.CreateScrollBoxLinearView().Layout
    scrollBox:FullUpdate()
    scrollBox:ScrollToOffset(200, upgradeEnvironment.ScrollBoxConstants.NoScrollInterpolation)
    assert(retained:GetContent():GetNumPoints() == 2)
    retainedInput:SetFocus()
    retainedInput:SetText("Still editing")
    local created = upgradeEnvironment.framesCreated

    loadVersion(upgradeEnvironment, false)
    upgradeEnvironment.Flush()
    assert(retained:GetScrollBox() == scrollBox and retained:GetScrollBar() == scrollBar)
    assert(scrollBox:GetView() == nativeView and scrollBox:GetDerivedScrollOffset() == 200)
    assert(retainedInput:HasFocus() and retainedInput:GetText() == "Still editing")
    local contentClears = retained:GetContent().clearPointsCount or 0
    retained:SetSize(500, 160)
    upgradeEnvironment.Flush()
    assert((retained:GetContent().clearPointsCount or 0) == contentClears)
    assert(upgradeEnvironment.framesCreated == created, "upgrade must retain the native view and controls")

    print("LibModernSettings retained canvas resize tests passed")
end
