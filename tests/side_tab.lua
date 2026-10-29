return function(lib, makeFrame)
    dofile("Controls/SideTab.lua")
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local clicks = 0
    local tab = lib:CreateSideTab(root, {
        iconTexture = 134400,
        selected = true,
        onClick = function()
            clicks = clicks + 1
        end,
    })
    assert(tab:GetWidth() == 43 and tab:GetHeight() == 55)
    assert(tab.background.atlas == "common-sidetab")
    assert(tab.selection.atlas == "common-sidetab-selected")
    assert(tab.hover.atlas == "common-sidetab-hover")
    assert(tab.background:GetWidth() == 45 and tab.background:GetHeight() == 60)
    assert(tab:IsSelected() and tab.selection:IsShown())
    tab:Click("LeftButton")
    assert(
        clicks == 1 and tab:IsSelected(),
        "tabs do not toggle their own selection"
    )
    tab:SetSelected(false)
    assert(not tab.selection:IsShown() and clicks == 1)
    tab:SetSelected(true)
    tab.scripts.OnEnter(tab)
    assert(tab.selection:IsShown(), "hover must not replace selected artwork")
    tab:_FocusForTab()
    assert(tab.selection:IsShown())
    tab:SetControlEnabled(false)
    assert(not tab:IsEnabled() and tab:IsSelected())
    tab:SetControlEnabled(true)
    tab:SetSelected(false)
    lib:_RefreshControlAppearance(tab)
    assert(
        not tab:IsSelected(),
        "appearance refresh must retain current selection"
    )

    -- Re-registering a compatible implementation upgrades existing controls.
    local dispatch = tab.SetSelected
    lib._loadedModules["Controls/SideTab"] = nil
    dofile("Controls/SideTab.lua")
    tab:SetSelected(true)
    assert(tab.SetSelected == dispatch and tab.selection:IsShown())
    assert(not pcall(function()
        lib:CreateSideTab(root, {})
    end))
    assert(not pcall(function()
        lib:CreateSideTab(root, { iconTexture = 1, iconAtlas = "test" })
    end))
    assert(not pcall(function()
        tab:SetSelected("yes")
    end))
    assert(not pcall(function()
        tab:SetOnClick(true)
    end))
    print("LibModernSettings side-tab tests passed")
end
