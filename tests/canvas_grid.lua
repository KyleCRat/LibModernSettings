return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, true)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, {
        width = 800,
        height = 100,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local group = root:BeginGroup()
    local grid = group:BeginGrid({
        minColumnWidth = 200,
        maxColumns = 3,
        columnGap = 12,
        rowGap = 4,
        marginTop = 5,
    })
    local cells, inputs, commits = {}, {}, 0

    for index = 1, 7 do
        cells[index] = grid:AddCell()
        inputs[index] = cells[index]:AddControl("textInput", {
            value = "Saved " .. index,
            height = index == 2 and 50 or 34,
            onCommit = function(text)
                commits = commits + 1
                return text
            end,
        }, { marginBottom = 0 })
    end

    grid:Finish({ marginBottom = 6 })
    group:Finish({ marginBottom = 7 })
    local following = root:AddControl("textInput", { value = "After grid" })
    root:AddSpacer(600)
    layout:Finalize()
    environment.Flush()
    local frameCount = environment.framesCreated
    inputs[7]:SetFocus()
    inputs[7]:SetText("Pending")
    local scrollBox = layout:GetScrollBox()
    scrollBox:ScrollToOffset(
        80,
        environment.ScrollBoxConstants.NoScrollInterpolation
    )

    local function resize(contentWidth)
        local left, right = layout:GetContentInsets()
        layout:SetSize(contentWidth + left + right, 100)
        environment.Flush()
        assert(
            scrollBox:GetDerivedScrollOffset() == 80,
            "grid reflow must preserve scroll position"
        )
        assert(
            environment.framesCreated == frameCount,
            "grid reflow must retain controls"
        )
        assert(
            inputs[7]:HasFocus()
                and inputs[7]:GetText() == "Pending"
                and commits == 0
        )
    end

    resize(624)
    assert(inputs[1]:GetWidth() == 200 and inputs[3].point[4] == 424)
    assert(
        inputs[1].point[5] == inputs[3].point[5],
        "three cells fit at the exact breakpoint"
    )
    assert(
        inputs[4].point[5] == inputs[1].point[5] - 54,
        "the tallest cell determines row height"
    )
    assert(inputs[7].point[5] == inputs[4].point[5] - 38)
    assert(following.point[5] == inputs[7].point[5] - 34 - 6 - 7)
    resize(623)
    assert(
        inputs[3].point[4] == inputs[1].point[4]
            and inputs[3].point[5] < inputs[1].point[5]
    )
    resize(412)
    assert(
        inputs[1]:GetWidth() == 200 and inputs[2].point[5] == inputs[1].point[5]
    )
    resize(411)
    assert(
        inputs[1]:GetWidth() == 411
            and inputs[2].point[5] == inputs[1].point[5] - 38
    )
    resize(1000)
    assert(
        inputs[4].point[4] == inputs[1].point[4],
        "maxColumns must cap wide grids"
    )

    loadVersion(environment, false)
    environment.Flush()
    assert(inputs[7]:HasFocus() and inputs[7]:GetText() == "Pending")
    assert(
        environment.framesCreated == frameCount,
        "library upgrades must retain grid instances"
    )
    resize(624)
    cells[2]:SetShown(false)
    environment.Flush()
    assert(not inputs[2]:IsShown() and inputs[3].point[4] == 212)
    group:SetShown(false)
    environment.Flush()
    assert(
        not inputs[1]:IsShown()
            and following.point[5] == -layout:GetStyleValue("paddingTop")
    )
    group:SetShown(true)
    environment.Flush()
    assert(
        inputs[1]:IsShown() and not inputs[2]:IsShown(),
        "nested visibility must survive hiding the grid's parent"
    )
    cells[2]:SetShown(true)
    environment.Flush()

    parent:Hide()
    local left, right = layout:GetContentInsets()
    layout:SetSize(411 + left + right, 100)
    assert(environment.QueueSize() == 0, "hidden pages must defer grid layout")
    parent:Show()
    parent.scripts.OnShow(parent)
    environment.Flush()
    assert(
        inputs[2].point[5] < inputs[1].point[5]
            and inputs[7]:GetText() == "Pending"
    )

    -- Tab uses visual order after each reflow; no separate per-grid focus list.
    inputs[7]:CancelAndClearFocus()

    for _, contentWidth in ipairs({ 411, 412, 624 }) do
        layout:SetSize(contentWidth + left + right, 100)
        environment.Flush()
        inputs[1]:FocusValue()

        for index = 1, 6 do
            inputs[index].scripts.OnTabPressed(inputs[index])
            assert(
                inputs[index + 1]:HasFocus(),
                "Tab must follow row-major grid order"
            )
            environment.Flush()
        end

        inputs[7]:ClearFocus()
    end

    for _, cell in ipairs(cells) do
        cell:SetShown(false)
    end

    environment.Flush()
    assert(
        following.point[5] == -layout:GetStyleValue("paddingTop") - 7,
        "an empty grid must consume no space or grid margins"
    )
    local appended =
        grid:AddCell()
            :AddControl("checkbox", { label = "Added later", value = true })
    grid:Finish()
    environment.Flush()
    assert(
        appended:GetValue()
            and appended.label:GetWidth() == layout:GetContentWidth() - 36
    )
    assert(
        following.point[5] < appended.point[5],
        "late cells must reflow following content"
    )

    for _, options in ipairs({
        {},
        { minColumnWidth = 0 },
        { minColumnWidth = -1 },
        { minColumnWidth = math.huge },
        { minColumnWidth = 100, maxColumns = 0 },
        { minColumnWidth = 100, maxColumns = 1.5 },
        { minColumnWidth = 100, columnGap = -1 },
        { minColumnWidth = 100, rowGap = -1 },
        { minColumnWidth = 100, marginTop = -1 },
    }) do
        assert(not pcall(root.BeginGrid, root, options))
    end

    assert(not pcall(root.BeginGrid, root, "invalid"))
    assert(not pcall(grid.Finish, grid, { marginBottom = -1 }))
    local beginGrid = root.BeginGrid
    loadVersion(environment, true)
    assert(
        root.BeginGrid == beginGrid,
        "an older embed must not replace the grid implementation"
    )
    print("LibModernSettings responsive canvas grid tests passed")
end
