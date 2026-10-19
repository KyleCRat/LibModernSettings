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
            outset = 3,
        },
        small = {
            normal = "common-button-tertiary-normal-small",
            hover = "common-button-tertiary-hover-small",
            selected = "common-button-tertiary-selected-small",
            disabled = "common-button-tertiary-disabled-small",
            outset = 2.5,
        },
        square = {
            normal = "common-button-tertiary-square-normal",
            hover = "common-button-tertiary-square-normal",
            selected = "common-button-tertiary-square-selected",
            disabled = "common-button-tertiary-square-disabled",
            outset = 0,
        },
    }

    local function checkArtworkBounds(button, outset)
        local texture = button:GetNormalTexture()
        local point, relativeTo, relativePoint, x, y = texture:GetPoint(1)
        assert(point == "TOPLEFT" and relativeTo == button and relativePoint == "TOPLEFT")
        assert(x == -outset and y == outset, "selected glow margins must not shrink the visible button body")
        point, relativeTo, relativePoint, x, y = texture:GetPoint(2)
        assert(point == "BOTTOMRIGHT" and relativeTo == button and relativePoint == "BOTTOMRIGHT")
        assert(x == outset and y == -outset)
    end

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
        local width, height = button:GetWidth(), button:GetHeight()
        buttons[#buttons + 1] = button

        assert(button:IsSelected() and button:GetNormalTexture().atlas == artwork.selected,
            "initial selection uses the matching native tertiary artwork")
        checkArtworkBounds(button, artwork.outset)
        button.scripts.OnEnter(button)
        button.scripts.OnLeave(button)
        assert(button:GetNormalTexture().atlas == artwork.selected, "hover must not replace selection")

        button:_FocusForTab()
        assert(button:GetNormalTexture().atlas == artwork.selected, "keyboard focus preserves selection")
        button:SetSelected(false)
        assert(button:GetNormalTexture().atlas == artwork.hover, "clearing selection restores focused appearance")
        checkArtworkBounds(button, 0)
        button:SetSelected(true)
        assert(clicks == 0, "changing selection never invokes the click callback")
        button:Click("LeftButton")
        assert(clicks == 1 and button:IsSelected(), "clicking does not toggle consumer-owned selection")

        button:SetControlEnabled(false)
        assert(not button:IsEnabled() and button:IsSelected(), "disabling does not clear selection")
        assert(button.disabledTexture.atlas == artwork.disabled, "native disabled artwork remains intact")
        button:SetControlEnabled(true)
        assert(button:GetNormalTexture().atlas == artwork.selected, "re-enabling restores selected artwork")
        checkArtworkBounds(button, artwork.outset)

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
        checkArtworkBounds(button, artwork.outset)
        assert(button:GetWidth() == width and button:GetHeight() == height,
            "selection and transient states must preserve the layout and hit area")
        assert(not pcall(button.SetSelected, button, "yes"), "selection setters reject non-booleans")
    end

    lib._loadedModules["Controls/Button"] = nil
    dofile("Controls/Button.lua")

    for index, variant in ipairs({ "regular", "small", "square" }) do
        local button = buttons[index]
        assert(button:IsSelected() and button:GetNormalTexture().atlas == atlases[variant].selected,
            "live method and appearance upgrades preserve selected state")
        checkArtworkBounds(button, atlases[variant].outset)
    end

    local defaultButton = lib:CreateButton(root, {})
    assert(not defaultButton:IsSelected(), "ordinary action buttons default to unselected")
    assert(not pcall(lib.CreateButton, lib, root, { selected = "yes" }),
        "constructors reject invalid selected values")

    local toggle = lib:CreateButton(root, {
        width = 42,
        text = "",
        onClick = function(button)
            button:SetSelected(not button:IsSelected())
            button:SetButtonText(button:IsSelected() and "NOT" or "")
        end,
    })
    local label = toggle:GetFontString()
    local function checkCenteredLabel()
        local point, relativeTo, relativePoint, x, y = label:GetPoint(1)
        assert(point == "CENTER" and relativeTo == toggle and relativePoint == "CENTER")
        assert(x == 0 and y == 0, "refreshing a toggle inside OnClick must not leave a press/release offset")
        assert(toggle:GetWidth() == 42 and toggle:GetHeight() == 34)
    end

    for index = 1, 4 do
        -- Model native press/pop around a consumer's label and selection update.
        local offsetX, offsetY = toggle:GetPushedTextOffset()
        local point, relativeTo, relativePoint, x, y = label:GetPoint(1)
        label:SetPoint(point, relativeTo, relativePoint, x + offsetX, y + offsetY)
        toggle:Click("LeftButton")
        point, relativeTo, relativePoint, x, y = label:GetPoint(1)
        label:SetPoint(point, relativeTo, relativePoint, x - offsetX, y - offsetY)
        checkCenteredLabel()
    end
    toggle:_HandleNavigationAction("activate", {})
    checkCenteredLabel()
    toggle:SetControlEnabled(false)
    toggle:SetControlEnabled(true)
    lib:_RefreshControlAppearance(toggle)
    checkCenteredLabel()
    root:Hide()
end
