return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, false)

    -- Size notifications deliberately arrive later than the explicit layout.
    local function delaySizeEvents(env, frame)
        local handler = frame.scripts.OnSizeChanged

        if handler then
            frame.scripts.OnSizeChanged = function(self, width, height)
                env.C_Timer.After(0, function()
                    handler(self, width, height)
                end)
            end
        end
    end

    local function addNested(env, library, flow)
        local frame = env.CreateFrame("Frame", nil, flow.layout:GetContent())
        frame:SetSize(flow:GetWidth(), 1)
        local child
        local calls = 0
        local placement = {
            fillWidth = true,
            onLayout = function(owner)
                calls = calls + 1
                assert(
                    owner == frame and child,
                    "nested content must be built before the first reflow"
                )
                child:SetSize(owner:GetWidth(), 1)
                child:RefreshLayout()
                owner:SetHeight(child:GetContent():GetHeight())
            end,
        }
        flow:AddFrame(frame, placement)
        assert(
            calls == 0,
            "adding a custom frame must not run its construction-time callback"
        )

        placement.onLayout = function()
            error("placement options must be copied")
        end

        child = library:CreateCanvasLayout(
            frame,
            { width = frame:GetWidth(), height = 1 }
        )
        child:GetContent():HookScript("OnSizeChanged", function()
            flow.layout:RequestLayout()
        end)
        delaySizeEvents(env, frame)
        delaySizeEvents(env, child:GetContent())
        return child, frame
    end

    local function createPage(env, library)
        local page = env.CreateFrame("Frame")
        local layout = library:CreateCanvasLayout(page, {
            width = 720,
            height = 200,
            scrollable = true,
        })
        local group = layout:GetRootFlow():BeginGroup()
        local child, section = addNested(env, library, group)
        local columns =
            child:GetRootFlow():BeginColumns({ minColumnWidth = 240 })
        columns.left:AddControl("textInput", { value = "First column" })
        columns.right:AddControl("textInput", { value = "Second column" })
        columns:Finish()
        local grandchild = addNested(env, library, child:GetRootFlow())
        local details = grandchild:GetRootFlow():BeginGroup()
        local values = details:AddControl("field", {
            label = "Values",
            controlType = "valueList",
            controlOptions = { value = { "1", "2" } },
        })
        details:Finish()
        grandchild:Finalize()
        child:Finalize()
        group:Finish()
        local target = layout:GetRootFlow():AddCustom(400)
        local input = library:CreateTextInput(target, { value = "Saved" })
        input:SetPoint("TOPLEFT", target, "TOPLEFT", 0, -20)
        layout:GetRootFlow():AddSpacer(600)
        layout:RegisterScrollSection("target", target)
        layout:Finalize()
        env.Flush(10)

        page.SetAlpha = function()
            error("selection layout must never change page opacity")
        end

        return layout, page, section, target, input, values, details, group
    end

    local function offset(layout, target)
        return layout:GetContent():GetTop() - target:GetTop() + 20
    end

    local source, _, _, sourceTarget = createPage(environment, lib)
    source:GetScrollBox():ScrollToOffset(
        offset(source, sourceTarget),
        environment.ScrollBoxConstants.NoScrollInterpolation
    )
    local bookmark = source:CaptureScrollBookmark()
    local layout, page, section, target, input, values, details, group =
        createPage(environment, lib)
    input:SetFocus()
    input:SetText("Draft")
    local content = layout:GetContent()
    local clears = content.clearPointsCount

    for index, width in ipairs({ 400, 720, 500, 640, 360, 720 }) do
        page:Hide()
        details:SetShown(index % 2 == 0)
        values:GetControl():SetValue({ "1", "2", "3", "4", "5", "6", "7", "8" })
        layout:SetSize(width, 200)
        page:Show()
        page.scripts.OnShow(page)
        layout:RestoreScrollBookmark(bookmark)
        layout:RefreshLayout()
        local expected = offset(layout, target)
        assert(
            layout:GetScrollBox():GetDerivedScrollOffset() == expected,
            "nested sizes and bookmark must be final before deferred callbacks run"
        )
        assert(-target.point[5] >= -section.point[5] + section:GetHeight())
        local height, targetTop = content:GetHeight(), target.point[5]
        environment.Flush(15)
        assert(
            content:GetHeight() == height and target.point[5] == targetTop,
            "late native size notifications must not change settled geometry"
        )
        assert(layout:GetScrollBox():GetDerivedScrollOffset() == expected)
        assert(
            page:IsShown() and input:GetText() == "Draft" and input:HasFocus()
        )
    end

    input:CancelAndClearFocus()

    -- An excluded nested flow must not participate or run its callback.
    group:SetShown(false)
    local childWidth = section:GetWidth()
    layout:SetSize(450, 200)
    layout:RefreshLayout()
    assert(section:GetWidth() == childWidth)
    group:SetShown(true)
    layout:RefreshLayout()
    assert(section:GetWidth() == layout:GetContentWidth())
    environment.Flush(15)
    assert(
        content.clearPointsCount == clears,
        "reflow must retain native content anchors"
    )
    -- ValueList may create retained pills once when the larger value is assigned.
    local frames = environment.framesCreated

    for _ = 1, 6 do
        layout:RestoreScrollBookmark(source:CaptureScrollBookmark())
        layout:RefreshLayout()
    end

    environment.Flush(15)
    assert(
        environment.framesCreated == frames,
        "selection changes must not duplicate forms or controls"
    )
    assert(
        environment.QueueSize() == 0,
        "settled selection layout must leave no repeating work"
    )

    for _, invalid in ipairs({ true, 2, "callback" }) do
        local invalidLayout = lib:CreateCanvasLayout(
            environment.CreateFrame("Frame"),
            { width = 500, height = 200 }
        )
        local frame =
            environment.CreateFrame("Frame", nil, invalidLayout:GetContent())
        frame:SetSize(100, 100)
        assert(
            not pcall(
                invalidLayout:GetRootFlow().AddFrame,
                invalidLayout:GetRootFlow(),
                frame,
                { onLayout = invalid }
            )
        )
    end

    local upgrades = newEnvironment()
    local oldLib = loadVersion(upgrades, true)
    local retained, _, _, retainedTarget = createPage(upgrades, oldLib)
    loadVersion(upgrades, false)
    upgrades.Flush(15)
    retained:SetSize(420, 200)
    retained:RestoreScrollBookmark(bookmark)
    retained:RefreshLayout()
    assert(
        retained:GetScrollBox():GetDerivedScrollOffset()
            == offset(retained, retainedTarget)
    )
    loadVersion(upgrades, true)
    loadVersion(upgrades, false)
    upgrades.Flush(15)
    assert(
        retained:GetScrollBox():GetDerivedScrollOffset()
            == offset(retained, retainedTarget)
    )

    print("LibModernSettings synchronous nested canvas tests passed")
end
