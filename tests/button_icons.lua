return function(lib, makeFrame)
    local buttons = {}

    for _, variant in ipairs({ "regular", "small", "square" }) do
        local clicks = 0
        local button = lib:CreateButton(makeFrame("Frame"), {
            variant = variant,
            iconTexture = "example.tga",
            selected = true,
            onClick = function() clicks = clicks + 1 end,
        })
        buttons[#buttons + 1] = button

        assert(button.icon.texture == "example.tga" and button.icon:IsShown())
        assert(button.icon:GetWidth() == (variant == "small" and 14 or 16),
            "texture icons have a defined size and respect compact-button limits")
        local mask = button.icon._libModernSettingsSquareMask

        if variant == "square" then
            assert(mask and mask.texture == lib._tertiarySquareMask and #button.icon.masks == 1,
                "square icons receive the shared corner mask automatically")
            assert(mask:GetWidth() == 24 and mask:GetHeight() == 24
                and mask.point[2] == button and mask.point[5] == 1,
                "the mask follows the button's inner border, not the smaller glyph's corners")
            assert(button.icon.point[2] == mask and button.icon.point[4] == 0 and button.icon.point[5] == 0,
                "square icons are centered within the clipping area")
            assert(mask.wrapHorizontal == "CLAMPTOBLACKADDITIVE"
                and mask.wrapVertical == "CLAMPTOBLACKADDITIVE")
        else
            assert(mask == nil and button.icon.masks == nil, "text button icons stay unmasked")
        end

        button:SetButtonIcon({ iconTexture = 12345 })
        assert(button.icon.texture == 12345 and button:IsSelected() and clicks == 0,
            "replacing a texture preserves selection without invoking a click")
        button:SetButtonIcon({ iconAtlas = "wide-icon" })
        assert(button.icon.atlas == "wide-icon" and button.icon:GetWidth() == button.icon:GetHeight() * 2,
            "switching to an atlas restores its natural aspect ratio")
        button:SetControlEnabled(false)
        button:SetButtonIcon({ iconTexture = "replacement.tga" })
        assert(button.icon.atlas == nil and button.icon:GetWidth() == button.icon:GetHeight(),
            "switching back to a texture clears atlas UVs and size")
        assert(button.icon.texCoord[1] == 0 and button.icon.texCoord[2] == 1
            and button.icon.texCoord[3] == 0 and button.icon.texCoord[4] == 1)
        assert(button.icon.desaturated and button.icon.alpha == 0.5,
            "replaced icons retain their disabled appearance")
        button:SetControlEnabled(true)
        lib:_RefreshControlAppearance(button)
        assert(button.icon.texture == "replacement.tga" and not button.icon.desaturated
            and button.icon.alpha == 1 and button:IsSelected(), "appearance refresh retains the replacement")

        if variant == "square" then
            assert(button.icon._libModernSettingsSquareMask == mask and #button.icon.masks == 1,
                "source, enabled-state, and appearance changes reuse the same mask")
            assert(not pcall(button.SetButtonIcon, button, {}), "square buttons must retain an icon")
        else
            button:SetButtonIcon({})
            assert(not button.icon:IsShown(), "text buttons can remove an icon")
            button:SetButtonIcon({ iconTexture = "replacement.tga" })
        end

        assert(not pcall(button.SetButtonIcon, button, {
            iconAtlas = "common-icon-plus", iconTexture = "example.tga",
        }), "setters reject competing icon sources")
    end

    local square = lib:CreateButton(makeFrame("Frame"), {
        variant = "square", iconTexture = "large.tga", iconSize = 24,
    })
    assert(square:GetWidth() == 34 and square.icon:GetWidth() == 24,
        "larger artwork does not change the tertiary button's size")
    local squareMask = square.icon._libModernSettingsSquareMask
    assert(squareMask:GetWidth() == 24, "filled artwork meets the masked inset")
    square:SetButtonIcon({ iconAtlas = "common-icon-plus" })
    assert(square.icon:GetWidth() == 24, "source changes preserve explicit icon sizing")
    square:SetSize(40, 40)
    assert(squareMask:GetWidth() == 28 and squareMask:GetHeight() == 28
        and square.icon:GetWidth() == 24, "resizing updates the clipping area without resizing the icon")

    local oversized = lib:CreateButton(makeFrame("Frame"), {
        variant = "square", iconTexture = "large.tga", iconSize = 48,
    })
    assert(oversized.icon:GetWidth() == 48 and oversized.icon._libModernSettingsSquareMask:GetWidth() == 24,
        "oversized artwork is clipped at the button border rather than expanding the mask")

    local atlasButton = lib:CreateButton(makeFrame("Frame"), {
        variant = "square", iconAtlas = "wide-icon", width = 40,
    })
    assert(atlasButton.icon:GetWidth() == 16 and atlasButton.icon:GetHeight() == 8
        and atlasButton.icon._libModernSettingsSquareMask:GetWidth() == 28,
        "atlas-only consumers get the default mask without losing natural icon proportions")

    local textButton = lib:CreateButton(makeFrame("Frame"), { text = "Text", fitToContent = true })
    local plainWidth = textButton:GetWidth()
    textButton:SetButtonIcon({ iconTexture = "example.tga" })
    assert(textButton:GetWidth() > plainWidth, "adding an icon relayouts fit-to-content commands")
    textButton:SetButtonIcon({})
    assert(textButton:GetWidth() == plainWidth, "removed icons leave no width or gap behind")

    for _, options in ipairs({
        { iconAtlas = "common-icon-plus", iconTexture = "example.tga" },
        { iconTexture = {} },
        { variant = "square" },
    }) do
        assert(not pcall(lib.CreateButton, lib, makeFrame("Frame"), options),
            "constructors reject invalid icon sources")
    end

    local originalMaskPath = lib._tertiarySquareMask
    lib._tertiarySquareMask = "new-embed-mask.tga"
    squareMask:SetAllPoints(square.icon)
    lib._loadedModules["Utilities/Atlas"] = nil
    dofile("Utilities/Atlas.lua")
    lib._loadedModules["Controls/Button"] = nil
    dofile("Controls/Button.lua")

    for _, button in ipairs(buttons) do
        assert(button.icon.texture == "replacement.tga" and button.icon:IsShown() and button:IsSelected(),
            "live button upgrades retain runtime icon changes")

        if button.icon._libModernSettingsSquareMask then
            assert(button.icon._libModernSettingsSquareMask.texture == lib._tertiarySquareMask
                and #button.icon.masks == 1, "upgraded controls reuse their mask with the accepted embed's media")
            assert(#button.scriptHooks.OnSizeChanged == 1, "upgrades do not duplicate mask-resize hooks")
        end
    end

    assert(squareMask.allPoints == nil and squareMask.point[2] == square
        and square.icon._libModernSettingsSquareMask == squareMask,
        "upgrades re-anchor legacy artwork-relative masks without replacing them")
    square:SetSize(50, 50)
    assert(squareMask:GetWidth() == 35, "retained square buttons keep updating their masks after an upgrade")
    lib._tertiarySquareMask = originalMaskPath
end
