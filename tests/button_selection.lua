return function(lib, makeFrame)
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)

    local buttons = {}
    local atlases = {
        regular = {
            normal = "common-button-tertiary-normal",
            hover = "common-button-tertiary-hover",
            selected = "common-button-tertiary-selected",
            disabled = "common-button-tertiary-disabled",
        },
        small = {
            normal = "common-button-tertiary-normal-small",
            hover = "common-button-tertiary-hover-small",
            selected = "common-button-tertiary-selected-small",
            disabled = "common-button-tertiary-disabled-small",
        },
        square = {
            normal = "common-button-tertiary-square-normal",
            hover = "common-button-tertiary-square-normal",
            selected = "common-button-tertiary-square-selected",
            disabled = "common-button-tertiary-square-disabled",
        },
    }

    for _, variant in ipairs({ "regular", "small", "square" }) do
        local clicks = 0
        local button = lib:CreateButton(root, {
            variant = variant,
            text = variant ~= "square" and "Select" or nil,
            iconAtlas = variant == "square" and "common-icon-plus" or nil,
            selected = true,
            onClick = function() clicks = clicks + 1 end,
        })
        local artwork = atlases[variant]
        buttons[#buttons + 1] = button

        assert(button:IsSelected() and button:GetNormalTexture().atlas == artwork.selected,
            "initial selection uses the matching native tertiary artwork")
        button.scripts.OnEnter(button)
        button.scripts.OnLeave(button)
        assert(button:GetNormalTexture().atlas == artwork.selected, "hover must not replace selection")

        button:_FocusForTab()
        assert(button:GetNormalTexture().atlas == artwork.selected, "keyboard focus preserves selection")
        button:SetSelected(false)
        assert(button:GetNormalTexture().atlas == artwork.hover, "clearing selection restores focused appearance")
        button:SetSelected(true)
        assert(clicks == 0, "changing selection never invokes the click callback")
        button:Click("LeftButton")
        assert(clicks == 1 and button:IsSelected(), "clicking does not toggle consumer-owned selection")

        button:SetControlEnabled(false)
        assert(not button:IsEnabled() and button:IsSelected(), "disabling does not clear selection")
        assert(button.disabledTexture.atlas == artwork.disabled, "native disabled artwork remains intact")
        button:SetControlEnabled(true)
        assert(button:GetNormalTexture().atlas == artwork.selected, "re-enabling restores selected artwork")

        button:SetSelected(false)
        assert(button:GetNormalTexture().atlas == artwork.normal)
        lib:_RefreshControlAppearance(button)
        assert(not button:IsSelected(), "appearance refresh must not restore the constructor's selected value")
        button.scripts.OnEnter(button)
        button:SetSelected(true)
        button:SetSelected(false)
        assert(button:GetNormalTexture().atlas == artwork.hover, "clearing selection also restores mouse hover")
        button.scripts.OnLeave(button)
        button:SetSelected(true)
        button:Hide()
        button.scripts.OnHide(button)
        button:Show()
        assert(button:IsSelected() and button:GetNormalTexture().atlas == artwork.selected,
            "hiding clears transient hover/focus, not selection")
        assert(not pcall(button.SetSelected, button, "yes"), "selection setters reject non-booleans")
    end

    lib._loadedModules["Controls/Button"] = nil
    dofile("Controls/Button.lua")

    for index, variant in ipairs({ "regular", "small", "square" }) do
        local button = buttons[index]
        assert(button:IsSelected() and button:GetNormalTexture().atlas == atlases[variant].selected,
            "live method and appearance upgrades preserve selected state")
    end

    local defaultButton = lib:CreateButton(root, {})
    assert(not defaultButton:IsSelected(), "ordinary action buttons default to unselected")
    assert(not pcall(lib.CreateButton, lib, root, { selected = "yes" }),
        "constructors reject invalid selected values")
    root:Hide()
end
