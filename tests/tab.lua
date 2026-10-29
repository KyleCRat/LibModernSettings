return function(lib, makeFrame)
    dofile("Utilities/TabArtwork.lua")
    dofile("Controls/Tab.lua")
    assert(LibStub("LibYvSkins-1.0", true) == nil)
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local clicks = 0
    local tab = lib:CreateTab(root, {
        text = "Display",
        selected = true,
        width = 116,
        height = 28,
        onClick = function()
            clicks = clicks + 1
        end,
    })
    assert(tab:IsSelected() and tab:GetWidth() == 116)
    assert(tab.art.layers.selected[1]:IsShown())
    assert(tab.art.layers.border[1].texture == lib._headerTabTexture)
    tab:Click("LeftButton")
    assert(clicks == 1 and tab:IsSelected())
    tab:SetSelected(false)
    tab:_FocusForTab()
    assert(tab.art.layers.hover[1]:IsShown())
    tab:_HandleNavigationAction("activate", {})
    assert(clicks == 2 and not tab:IsSelected())
    tab:_ReleaseTabFocus()
    assert(not tab.art.layers.hover[1]:IsShown())

    local flush = lib._FlushPendingEditBoxCommits
    lib._FlushPendingEditBoxCommits = function()
        return false
    end
    tab:Click("LeftButton")
    assert(clicks == 2, "rejected pending edits must block tab activation")
    lib._FlushPendingEditBoxCommits = flush
    tab:SetSelected(true)
    tab:SetControlEnabled(false)
    tab:Click("LeftButton")
    assert(clicks == 2 and tab:IsSelected())
    tab:SetControlEnabled(true)

    local tint = { 0.1, 0.2, 0.3, 1 }
    tab:SetTabAppearance({ mode = "flat", colors = { flatAccent = tint } })
    tint[1] = 0.8
    assert(tab.art.flat[2].vertexColor[1] == 0.1)
    assert(not tab.art.layers.selected[1]:IsShown())
    assert(tab:IsSelected() and tab:GetWidth() == 116)
    tab:SetTabAppearance()
    assert(tab.art.layers.selected[1]:IsShown())
    assert(not tab.art.flat[2]:IsShown())

    local x, y, width, height, scale = 10.3, 20.45, 116, 28, 1
    function tab:GetRect()
        return x, y, width, height
    end
    function tab:GetEffectiveScale()
        return scale
    end
    local function near(value, expected)
        assert(math.abs(value - expected) < 0.00001)
    end
    local function verifyGeometry()
        tab:RefreshTabGeometry()
        local unit = 1 / scale

        for _, slices in pairs(tab.art.layers) do
            for index, texture in ipairs(slices) do
                if tab.art.visible[index] then
                    local left = (x + texture.point[4]) / unit
                    local bottom = (y + texture.point[5]) / unit
                    local right = left + texture:GetWidth() / unit
                    local top = bottom + texture:GetHeight() / unit
                    near(left, math.floor(left + 0.5))
                    near(bottom, math.floor(bottom + 0.5))
                    near(right, math.floor(right + 0.5))
                    near(top, math.floor(top + 0.5))
                    assert(right > left and top > bottom)
                else
                    assert(not texture:IsShown())
                end
            end
        end
    end
    for _, nextScale in ipairs({ 0.64, 0.8, 1, 1.25 }) do
        scale = nextScale
        verifyGeometry()
        x, y = x + 0.37, y + 0.23
        verifyGeometry()
    end
    width, height = 20, 6
    verifyGeometry()
    local writes = tab.art.layers.border[1].sizeWrites
    for _ = 1, 100 do
        tab.scripts.OnUpdate(tab, 0.016)
    end
    assert(tab.art.layers.border[1].sizeWrites == writes)
    local dispatch, artwork = tab.SetSelected, tab.art
    lib._loadedModules["Controls/Tab"] = nil
    dofile("Controls/Tab.lua")
    assert(tab.SetSelected == dispatch and tab.art == artwork)
    assert(tab:IsSelected())
    tab:Click("LeftButton")
    assert(clicks == 3)

    assert(not pcall(function()
        tab:SetSelected(1)
    end))
    assert(not pcall(function()
        tab:SetTabAppearance({ mode = "unknown" })
    end))
    assert(not pcall(function()
        tab:SetTabAppearance({ colors = { border = { 2, 0, 0 } } })
    end))
    assert(not pcall(function()
        lib:CreateTab(root, { width = math.huge })
    end))
    print(
        "LibModernSettings standalone tabs, skin state, geometry and idle tests passed"
    )
end
