return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, false)

    local function createCanvas(env, library, heights)
        local page = env.CreateFrame("Frame")
        local layout = library:CreateCanvasLayout(page, {
            width = 600,
            height = 200,
            scrollable = true,
        })
        local frames = {}
        local expanded = {
            above = false,
            border = true,
            after = true,
        }

        for index, key in ipairs({ "above", "border", "after" }) do
            local frame = env.CreateFrame("Frame", nil, layout:GetContent())
            frame:SetSize(layout:GetContentWidth(), heights[index])
            layout:GetRootFlow():AddFrame(frame, { fillWidth = true })
            frames[key] = frame
        end

        layout:GetRootFlow():AddSpacer(600)
        -- Deliberately register in a different order from their visual placement.
        for _, key in ipairs({ "after", "above", "border" }) do
            local sectionKey = key
            layout:RegisterScrollSection(key, frames[key], {
                isExpanded = function()
                    return expanded[sectionKey]
                end,
            })
        end

        layout:Finalize()
        env.Flush()
        return layout, frames, expanded, page
    end

    local function top(layout, frame)
        return layout:GetContent():GetTop() - frame:GetTop()
    end

    local function scroll(layout, offset)
        layout:GetScrollBox():ScrollToOffset(
            offset,
            environment.ScrollBoxConstants.NoScrollInterpolation
        )
    end

    local function checkOffset(layout, expected)
        local actual = layout:GetScrollBox():GetDerivedScrollOffset()
        assert(
            math.abs(actual - expected) < 0.001,
            "expected scroll offset " .. expected .. ", got " .. actual
        )
    end

    local function copyData(value)
        if type(value) == "table" then
            assert(
                getmetatable(value) == nil,
                "bookmarks must not retain frame or consumer objects"
            )
            local copy = {}

            for key, child in pairs(value) do
                copy[key] = copyData(child)
            end

            return copy
        end

        assert(
            type(value) == "string"
                or type(value) == "number"
                or type(value) == "boolean",
            "bookmarks must contain only value data, never frames or callbacks"
        )
        return value
    end

    local source, sourceFrames, expanded, sourcePage =
        createCanvas(environment, lib, { 300, 400, 300 })
    local target, targetFrames, _, targetPage =
        createCanvas(environment, lib, { 100, 500, 300 })
    local input = lib:CreateTextInput(sourceFrames.border, { value = "Saved" })
    input:SetPoint("TOPLEFT", sourceFrames.border, "TOPLEFT", 0, -100)
    input:SetFocus()
    input:SetText("Pending draft")
    local frameCount = environment.framesCreated

    scroll(source, top(source, sourceFrames.border) + 70)
    local bookmark = assert(source:CaptureScrollBookmark())
    local independentCopy = copyData(bookmark)
    target:RestoreScrollBookmark(bookmark)
    assert(
        target:GetScrollAnchor() == targetFrames.border,
        "shared keys must match across different canvases"
    )

    -- Capture again before the target's first reflow; its actual scroll is still at zero.
    local pending = assert(target:CaptureScrollBookmark())
    source:RestoreScrollBookmark(pending)
    environment.Flush()
    checkOffset(source, top(source, sourceFrames.border) + 70)
    checkOffset(target, top(target, targetFrames.border) + 70)
    assert(input:HasFocus() and input:GetText() == "Pending draft")
    assert(
        environment.framesCreated == frameCount,
        "bookmark operations must not recreate controls"
    )

    -- Deferred reflows and repeated cross-form restores must not accumulate drift.
    for _, height in ipairs({ 50, 240, 120 }) do
        targetFrames.above:SetHeight(height)
        environment.Flush()
        checkOffset(target, top(target, targetFrames.border) + 70)
        source:RestoreScrollBookmark(target:CaptureScrollBookmark())
        environment.Flush()
        checkOffset(source, top(source, sourceFrames.border) + 70)
        target:RestoreScrollBookmark(source:CaptureScrollBookmark())
        environment.Flush()
        checkOffset(target, top(target, targetFrames.border) + 70)
    end

    targetFrames.border:SetHeight(34)
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border))
    targetFrames.border:SetHeight(500)
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border) + 70)

    -- Missing and hidden sections fall back in source visual order, not registration order.
    targetFrames.border:Hide()
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.after)
    checkOffset(target, top(target, targetFrames.after))
    targetFrames.after:Hide()
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.above)
    checkOffset(target, top(target, targetFrames.above))
    targetFrames.above:Hide()
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    checkOffset(target, 0)

    for _, frame in pairs(targetFrames) do
        frame:Show()
    end

    target:RestoreScrollBookmark(independentCopy)
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border) + 70)

    -- Expansion is read live. A short open section wins over a larger collapsed one.
    expanded.border = false
    scroll(source, top(source, sourceFrames.after) - 180)
    local openSection = assert(source:CaptureScrollBookmark())
    target:RestoreScrollBookmark(openSection)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.after)
    checkOffset(target, top(target, targetFrames.after) - 180)
    expanded.after = false
    local collapsed = assert(source:CaptureScrollBookmark())
    target:RestoreScrollBookmark(collapsed)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.border)
    expanded.border = true
    expanded.after = true

    scroll(source, 0)
    local beginning = source:CaptureScrollBookmark()
    target:RestoreScrollBookmark(beginning)
    environment.Flush()
    checkOffset(target, 0)
    scroll(source, top(source, sourceFrames.border) - 80)
    local negativeOffset = source:CaptureScrollBookmark()
    target:RestoreScrollBookmark(negativeOffset)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.border)
    checkOffset(target, top(target, targetFrames.border) - 80)

    -- A hidden page cannot capture a new position, but it can accept a destination bookmark.
    sourcePage:Hide()
    assert(source:CaptureScrollBookmark() == nil)
    sourcePage:Show()
    source:GetContent():Hide()
    assert(source:CaptureScrollBookmark() == nil)
    source:GetContent():Show()
    targetPage:Hide()
    target:RestoreScrollBookmark(bookmark)
    targetFrames.above:SetHeight(90)
    environment.Flush()
    targetPage:Show()
    targetPage.scripts.OnShow(targetPage)
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border) + 70)

    -- Hidden ancestors inside the content exclude a section from matching.
    local holder = environment.CreateFrame("Frame", nil, target:GetContent())
    holder:Hide()
    targetFrames.border:SetParent(holder)
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.after)
    targetFrames.border:SetParent(target:GetContent())
    targetFrames.border:SetParent(source:GetContent())
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    assert(
        target:GetScrollAnchor() == targetFrames.after,
        "reparented sections must not match"
    )
    targetFrames.border:SetParent(target:GetContent())

    -- Replacing a registered key supports rebuilt or pooled section frames.
    target:RestoreScrollBookmark(bookmark)
    local replacement =
        environment.CreateFrame("Frame", nil, target:GetContent())
    replacement:SetSize(300, 400)
    replacement:SetPoint("TOPLEFT", target:GetContent(), "TOPLEFT", 0, -350)
    local options = {
        isExpanded = function()
            return true
        end,
    }
    target:RegisterScrollSection("border", replacement, options)

    options.isExpanded = function()
        error("registration must copy the supplied options")
    end

    environment.Flush()
    assert(target:GetScrollAnchor() == replacement)
    checkOffset(target, 420)
    scroll(target, 410)
    target:RestoreScrollBookmark(target:CaptureScrollBookmark())
    environment.Flush()
    checkOffset(target, 410)
    assert(target:UnregisterScrollSection("border"))
    assert(not target:UnregisterScrollSection("border"))
    assert(target:GetScrollAnchor() == nil)
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    assert(target:GetScrollAnchor() == targetFrames.after)
    target:RegisterScrollSection("border", targetFrames.border)
    target:RestoreScrollBookmark(bookmark)
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border) + 70)

    target:RestoreScrollBookmark(negativeOffset)
    target:RestoreScrollBookmark(nil)
    local unchanged = target:GetScrollBox():GetDerivedScrollOffset()
    environment.Flush()
    checkOffset(target, unchanged)
    assert(target:GetScrollAnchor() == nil)
    target:RestoreScrollBookmark(bookmark)
    scroll(target, 100)
    environment.Flush()
    checkOffset(target, 100)

    scroll(source, source:GetContent():GetHeight() - 200)
    assert(
        source:CaptureScrollBookmark() == nil,
        "no section intersects the unregistered footer"
    )

    -- Failed public calls leave the existing registration/anchor usable.
    target:RestoreScrollBookmark(bookmark)

    for _, key in ipairs({
        "",
        false,
        1,
        {},
    }) do
        assert(
            not pcall(target.RegisterScrollSection, target, key, replacement)
        )
        assert(not pcall(target.UnregisterScrollSection, target, key))
    end

    assert(not pcall(target.RegisterScrollSection, target, nil, replacement))
    assert(
        not pcall(
            target.RegisterScrollSection,
            target,
            "bad",
            sourceFrames.border
        )
    )
    assert(
        not pcall(
            target.RegisterScrollSection,
            target,
            "bad",
            target:GetContent()
        )
    )
    assert(
        not pcall(
            target.RegisterScrollSection,
            target,
            "duplicate",
            targetFrames.border
        )
    )
    assert(
        not pcall(
            target.RegisterScrollSection,
            target,
            "bad",
            replacement,
            false
        )
    )
    assert(
        not pcall(
            target.RegisterScrollSection,
            target,
            "bad",
            replacement,
            { isExpanded = true }
        )
    )

    for _, invalid in ipairs({
        false,
        1,
        "bookmark",
        {},
        { version = 2 },
        { version = 1, kind = "other" },
    }) do
        assert(not pcall(target.RestoreScrollBookmark, target, invalid))
    end

    for _, invalid in ipairs({ false, "1", math.huge, 0 / 0 }) do
        local malformed = copyData(bookmark)
        malformed.offset = invalid
        assert(not pcall(target.RestoreScrollBookmark, target, malformed))
    end

    local malformed = copyData(bookmark)
    malformed.fallbacks = {
        [1] = "a",
        [2] = "b",
        [4] = "c",
        [6] = "d",
    }
    assert(not pcall(target.RestoreScrollBookmark, target, malformed))
    environment.Flush()
    checkOffset(target, top(target, targetFrames.border) + 70)

    target:RegisterScrollSection("border", targetFrames.border, {
        isExpanded = function()
            return "yes"
        end,
    })
    scroll(target, top(target, targetFrames.border) + 30)
    assert(not pcall(target.CaptureScrollBookmark, target))
    target:RegisterScrollSection("border", targetFrames.border)
    assert(target:CaptureScrollBookmark())
    environment.Flush()

    local plain = lib:CreateCanvasLayout(
        environment.CreateFrame("Frame"),
        { width = 600, height = 200 }
    )
    assert(
        not pcall(
            plain.RegisterScrollSection,
            plain,
            "section",
            plain:GetContent()
        )
    )
    assert(not pcall(plain.UnregisterScrollSection, plain, "section"))
    assert(not pcall(plain.CaptureScrollBookmark, plain))
    assert(not pcall(plain.RestoreScrollBookmark, plain, bookmark))

    -- Registrations and captured values survive both library load orders.
    local upgradeEnvironment = newEnvironment()
    local oldLib = loadVersion(upgradeEnvironment, true)
    local retained, retainedFrames =
        createCanvas(upgradeEnvironment, oldLib, { 300, 400, 300 })
    retained:GetScrollBox():ScrollToOffset(
        top(retained, retainedFrames.border) + 35,
        upgradeEnvironment.ScrollBoxConstants.NoScrollInterpolation
    )
    local retainedBookmark = retained:CaptureScrollBookmark()
    local newLib = loadVersion(upgradeEnvironment, false)
    upgradeEnvironment.Flush()
    local fresh, freshFrames =
        createCanvas(upgradeEnvironment, newLib, { 100, 500, 300 })
    fresh:RestoreScrollBookmark(retainedBookmark)
    upgradeEnvironment.Flush()
    checkOffset(fresh, top(fresh, freshFrames.border) + 35)
    loadVersion(upgradeEnvironment, true)
    retained:RestoreScrollBookmark(fresh:CaptureScrollBookmark())
    upgradeEnvironment.Flush()
    checkOffset(retained, top(retained, retainedFrames.border) + 35)
    assert(environment.QueueSize() == 0 and upgradeEnvironment.QueueSize() == 0)

    print("LibModernSettings canvas scroll bookmark tests passed")
end
