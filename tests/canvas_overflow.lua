return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, true)

    local function create(options)
        local parent = environment.CreateFrame("Frame")
        parent:SetSize(656, 300)
        return lib:CreateCanvasLayout(parent, options), parent
    end

    local function point(region, name, x, y)
        local _, _, _, actualX, actualY = region:GetPointByName(name)
        assert(actualX == x and actualY == y, name .. " geometry differs")
    end

    local overflow = { left = 8, right = 8 }
    local layout, parent = create({
        scrollable = true,
        scrollArea = { preset = "inset" },
        contentOverflow = overflow,
    })
    local control =
        layout:GetRootFlow():AddControl("textInput", { value = "Retained" })
    layout:GetRootFlow():AddSpacer(1000)
    layout:Finalize()
    environment.Flush(10)
    overflow.left, overflow.right = 100, 100

    local content, box, bar =
        layout:GetContent(), layout:GetScrollBox(), layout:GetScrollBar()
    local clears = content.clearPointsCount
    local frames = environment.framesCreated
    local left, right, top, bottom = layout:GetContentInsets()
    assert(left == 16 and right == 39 and top == 16 and bottom == 16)
    assert(layout:GetContentWidth() == 601 and control:GetWidth() == 601)
    point(box, "TOPLEFT", 8, -6)
    point(box, "BOTTOMRIGHT", -31, 5)
    point(content, "TOPLEFT", 8, 0)
    point(bar, "TOPRIGHT", -6, -6)
    local _, _, _, viewportLeft = box:GetPointByName("TOPLEFT")
    assert(
        viewportLeft + content.point[4] == left,
        "expanding the clip region must preserve the controls' screen alignment"
    )

    box:ScrollToOffset(
        200,
        environment.ScrollBoxConstants.NoScrollInterpolation
    )
    parent:Hide()
    layout:SetSize(756, 300)
    parent:Show()
    parent.scripts.OnShow(parent)
    layout:RefreshLayout()
    environment.Flush(10)
    assert(content:GetWidth() == 701 and control:GetWidth() == 701)
    assert(box:GetDerivedScrollOffset() == 200)
    point(content, "TOPLEFT", 8, 0)

    loadVersion(environment, false)
    loadVersion(environment, true)
    environment.Flush(10)
    assert(
        environment.framesCreated == frames
            and content.clearPointsCount == clears,
        "compatible upgrades must retain widgets, content anchors and copied overflow options"
    )
    assert(
        layout:GetScrollBox() == box
            and layout:GetScrollBar() == bar
            and box.initCount == 1
    )
    assert(
        box:GetDerivedScrollOffset() == 200 and control:GetValue() == "Retained"
    )
    point(box, "TOPLEFT", 8, -6)
    point(box, "BOTTOMRIGHT", -31, 5)
    point(content, "TOPLEFT", 8, 0)

    local bounded = create({
        scrollable = true,
        scrollArea = { preset = "inset" },
        contentOverflow = { left = 100, right = 100 },
    })
    bounded:Finalize()
    point(bounded:GetScrollBox(), "TOPLEFT", 4, -6)
    point(bounded:GetScrollBox(), "BOTTOMRIGHT", -23, 5)
    point(bounded:GetContent(), "TOPLEFT", 12, 0)
    assert(
        bounded:GetContentWidth() == 601,
        "overflow must stop at border clearance and the scrollbar column"
    )

    local legacy = create({
        scrollable = true,
        style = { paddingLeft = 9, scrollbarGap = 5 },
        contentOverflow = { left = 100, right = 2 },
    })
    legacy:Finalize()
    point(legacy:GetScrollBox(), "TOPLEFT", 0, 0)
    point(legacy:GetScrollBox(), "BOTTOMRIGHT", -20, 0)
    point(legacy:GetContent(), "TOPLEFT", 9, 0)

    local header = create({
        scrollArea = { preset = "inset" },
        contentOverflow = { left = 8, right = 8 },
    })
    assert(header:GetContentWidth() == 601 and not header:GetScrollBox())
    point(header:GetContent(), "TOPLEFT", 16, 0)

    local flush = create({
        scrollable = true,
        scrollArea = {
            preset = "none",
            contentPadding = { left = 0 },
            scrollbarGap = 0,
        },
        contentOverflow = { left = 8, right = 8 },
    })
    flush:Finalize()
    point(flush:GetScrollBox(), "TOPLEFT", 0, 0)
    point(flush:GetScrollBox(), "BOTTOMRIGHT", -17, 0)
    point(flush:GetContent(), "TOPLEFT", 0, 0)

    for _, invalid in ipairs({
        false,
        true,
        1,
        { left = -1 },
        { right = math.huge },
        { left = 0 / 0 },
        { right = "8" },
    }) do
        assert(
            not pcall(create, { scrollable = true, contentOverflow = invalid })
        )
    end

    environment.Flush(10)
    print("LibModernSettings canvas artwork overflow tests passed")
end
