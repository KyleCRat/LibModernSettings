return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, true)

    local function wheelSurface(area)
        local surface = area:GetScrollBox()._libModernSettingsWheelFrame
        assert(surface, "scroll areas must receive wheel input outside the viewport")
        assert(surface:GetParent() == area.parent and surface.allPoints == area.parent,
            "wheel coverage must include all margins and follow the pane's size")
        assert(surface:IsMouseWheelEnabled() and surface.mouseEnabled == false,
            "margin scrolling must consume wheel input without capturing clicks or motion")
        assert(surface:GetFrameLevel() == area.parent:GetFrameLevel(),
            "wheel coverage must stay below the pane's native widgets and controls")
        return surface
    end

    local parent = environment.CreateFrame("Frame")
    parent:SetSize(300, 200)
    local parentHandler = function() error("parent wheel handler must not be called") end
    parent:SetScript("OnMouseWheel", parentHandler)
    local list = lib:CreateScrollArea(parent, { contentSpacing = "compact" })
    local surface = wheelSurface(list)
    local box = list:GetScrollBox()
    local deltas = {}
    box:SetScript("OnMouseWheel", function(self, delta)
        assert(self == box, "forwarded input must retain the native scroll owner")
        deltas[#deltas + 1] = delta
    end)

    surface.scripts.OnMouseWheel(surface, -1)
    assert(#deltas == 0, "an uninitialized view must consume input without scrolling")
    list:Init({})
    for _, delta in ipairs({ -1, 1, -2 }) do
        surface.scripts.OnMouseWheel(surface, delta)
    end
    assert(#deltas == 3 and deltas[1] == -1 and deltas[2] == 1 and deltas[3] == -2,
        "each wheel event must reach the native handler exactly once, unchanged")
    assert(parent:GetScript("OnMouseWheel") == parentHandler,
        "creating an area must not replace or hook the caller's scripts")

    local replacementCalls = 0
    box:SetScript("OnMouseWheel", function()
        replacementCalls = replacementCalls + 1
    end)
    surface.scripts.OnMouseWheel(surface, 1)
    assert(replacementCalls == 1 and #deltas == 3,
        "margin input must use the current native handler, not a cached script")

    -- A nested canvas must scroll its own view without also scrolling the list.
    local innerParent = environment.CreateFrame("Frame", nil, box)
    innerParent:SetSize(200, 100)
    local canvas = lib:CreateCanvasLayout(innerParent, { scrollable = true })
    canvas:Finalize()
    environment.Flush()
    local canvasCalls = 0
    canvas:GetScrollBox():SetScript("OnMouseWheel", function()
        canvasCalls = canvasCalls + 1
    end)
    local canvasSurface = wheelSurface(canvas.scrollArea)
    canvasSurface.scripts.OnMouseWheel(canvasSurface, -1)
    assert(canvasCalls == 1 and replacementCalls == 1)
    assert(canvasSurface:IsMouseWheelEnabled(), "fitting content must still consume wheel input")
    canvas:SetSize(250, 150)
    environment.Flush()
    assert(wheelSurface(canvas.scrollArea) == canvasSurface, "resizing must reuse the wheel surface")

    -- Upgrade an area predating margin scrolling while retaining an existing one.
    surface:Hide()
    box._libModernSettingsWheelFrame = nil
    local bar, view = list:GetScrollBar(), box:GetView()
    local framesBeforeUpgrade = environment.framesCreated
    loadVersion(environment, false)
    environment.Flush()
    local upgradedSurface = wheelSurface(list)
    assert(upgradedSurface ~= surface and environment.framesCreated == framesBeforeUpgrade + 1,
        "an older area needs only its missing wheel surface")
    assert(list:GetScrollBox() == box and list:GetScrollBar() == bar and box:GetView() == view)
    assert(box.initCount == 1 and wheelSurface(canvas.scrollArea) == canvasSurface)
    upgradedSurface.scripts.OnMouseWheel(upgradedSurface, -1)
    assert(replacementCalls == 2, "upgrading must not duplicate wheel dispatch")
    loadVersion(environment, false)
    loadVersion(environment, true)
    assert(environment.framesCreated == framesBeforeUpgrade + 1)
    assert(parent:GetScript("OnMouseWheel") == parentHandler)

    print("LibModernSettings scroll area wheel coverage and upgrade tests passed")
end
