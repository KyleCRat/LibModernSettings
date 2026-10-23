return function(lib, openMenu, key, menu)
    local choices = {
        { type = "title", label = "Textures" },
        {
            value = "smooth",
            label = "Smooth",
            previewTexture = "Interface\\Buttons\\WHITE8X8",
            tooltip = "Smooth bar",
        },
        { value = "none", label = "No preview" },
        {
            value = "file",
            label = "File ID",
            previewTexture = 12345,
        },
        {
            value = "disabled",
            label = "Unavailable",
            previewTexture = 67890,
            enabled = false,
        },
    }
    local changes = 0
    local control = lib:CreateDropdown(nil, {
        width = 600,
        menuWidth = 300,
        value = "smooth",
        getChoices = function()
            return choices
        end,
        onChanged = function()
            changes = changes + 1
        end,
    })
    local button = control.dropdown
    local preview = button.selectionPreview

    local function checkSelectionBounds()
        local point, relativeTo, relativePoint, x, y = preview:GetPoint(1)
        assert(
            preview:GetNumPoints() == 1
                and point == "LEFT"
                and relativePoint == "LEFT"
        )
        assert(
            relativeTo == button and x == 8 and y == 1,
            "the closed preview must center in the visible recess, accounting for the atlas's bottom padding"
        )
        assert(
            preview:GetHeight() == 22
                and (button:GetHeight() - preview:GetHeight()) / 2 == 6
        )
        assert(
            preview:GetWidth() == button:GetWidth() - 42,
            "the sample must fill the body up to the arrow's inset column"
        )
    end

    assert(preview.texture == choices[2].previewTexture and preview:IsShown())
    checkSelectionBounds()
    assert(
        button.Text.drawLayer == "OVERLAY"
            and button.Text:GetFontObject() == GameFontHighlightOutline
    )
    assert(
        button:GetMenuDescription().minimumWidth == 300
            and button:GetMenuDescription().maximumWidth == 300,
        "an explicit menu width must override the native full-input minimum"
    )

    control:SetControlWidth(100)
    checkSelectionBounds()
    assert(
        preview:IsShown(),
        "the texture should remain behind the label at narrow widths"
    )
    assert(select(2, button.Text:GetPoint(2)) == button.arrowBackground)
    control:SetControlWidth(360)
    checkSelectionBounds()
    assert(preview:IsShown() and button.selectionPreview == preview)
    control:SetControlEnabled(false)
    assert(preview.alpha == 0.4)
    control:SetControlEnabled(true)
    assert(preview.alpha == 1 and changes == 0)

    function button:OpenMenu()
        openMenu(control)
    end

    control:_FocusForTab()
    key("SPACE")
    local firstRow = menu.rows[2]
    local firstSample = firstRow.attachedTextures[1]
    assert(
        firstSample.texture == choices[2].previewTexture
            and firstSample:IsShown()
    )
    assert(firstRow.fontString.text == "Smooth" and firstRow:GetHeight() == 24)
    assert(
        firstRow.fontString.drawLayer == "OVERLAY"
            and firstRow.fontString:GetFontObject()
                == GameFontHighlightOutline
    )
    assert(select(2, firstRow.fontString:GetPoint(1)) == firstSample)
    assert(select(2, firstRow.fontString:GetPoint(2)) == firstSample)
    assert(
        firstSample.drawLayer == "BACKGROUND" and firstSample.sublevel == -1,
        "row previews must sit behind the label and native hover/focus highlight"
    )
    assert(firstRow.description.tooltipText == "Smooth bar")
    assert(
        #menu.rows[3].attachedTextures == 0,
        "ordinary choices must not create preview textures"
    )
    assert(menu.rows[5].attachedTextures[1].alpha == 0.4)

    for _, row in ipairs(menu.rows) do
        assert(
            row:GetWidth() == 280,
            "fixed-width menus must keep full-width hit targets for plain and preview choices"
        )
    end

    key("DOWN")
    assert(
        control:GetValue() == "none" and not preview:IsShown() and changes == 1
    )
    assert(
        not firstSample:IsShown(),
        "native row reinitialization must retire the old attachment"
    )
    key("DOWN")
    assert(
        control:GetValue() == "file"
            and preview.texture == 12345
            and changes == 2
    )
    assert(menu.ScrollBox.revealedValue == "file")
    key("DOWN")
    assert(
        control:GetValue() == "file" and changes == 2,
        "disabled previews remain non-selectable"
    )
    key("ENTER")
    assert(
        not button:IsMenuOpen()
            and lib._navigationKeyboardFrame.control == control
    )
    assert(preview:IsShown() and preview.texture == 12345 and changes == 2)
    checkSelectionBounds()

    control:SetValue("unknown")
    assert(not preview:IsShown() and preview.texture == nil)
    control:SetValue("smooth")
    choices = {
        {
            value = "smooth",
            label = "Updated",
            previewTexture = 55555,
        },
    }
    control:SetValue("smooth")
    assert(
        preview:IsShown() and preview.texture == 55555 and changes == 2,
        "dynamic choices must refresh previews without submitting a value"
    )

    -- A consumer can normalize a mouse selection and replace the available textures.
    control:SetChoices({
        {
            value = "smooth",
            label = "Smooth",
            previewTexture = 111,
        },
        {
            value = "file",
            label = "File",
            previewTexture = 222,
        },
    })
    control:SetOnChanged(function()
        changes = changes + 1
        control:SetChoices({
            {
                value = "normalized",
                label = "Normalized",
                previewTexture = 333,
            },
        })
        control:SetValue("normalized")
    end)
    openMenu(control)
    button:Pick(
        button:GetMenuDescription().elements[2],
        MenuInputContext.MouseButton
    )
    assert(
        control:GetValue() == "normalized"
            and preview.texture == 333
            and changes == 3
    )

    lib._loadedModules["Controls/Dropdown"] = nil
    dofile("Controls/Dropdown.lua")
    assert(button.selectionPreview == preview and preview.texture == 333)
    checkSelectionBounds()
    assert(
        button.Text:GetFontObject() == GameFontHighlightOutline,
        "compatible upgrades must retain readable labels over the sample"
    )

    control:SetChoices({ { value = "normalized", label = "Plain" } })
    openMenu(control)

    for _, row in ipairs(menu.rows) do
        assert(
            #row.attachedTextures == 0,
            "recycled rows must not leak preview art into plain choices"
        )
        assert(
            row:GetWidth() == 280,
            "short plain labels must still fill the fixed-width menu"
        )
    end

    assert(not preview:IsShown() and preview.texture == nil)
    assert(
        button.Text:GetFontObject() == control._libModernSettingsSelectionFont
    )
    assert(select(2, button.Text:GetPoint(2)) == button.arrowBackground)
    button:CloseMenu()

    local multi = lib:CreateDropdown(nil, {
        multiSelect = true,
        menuWidth = 300,
        value = { one = true },
        choices = {
            {
                value = "one",
                label = "One",
                previewTexture = 444,
            },
        },
    })
    openMenu(multi)
    assert(menu.rows[1].attachedTextures[1].texture == 444)
    assert(
        menu.rows[1]:GetWidth() == 280,
        "fixed-width checkbox hit targets must fill the menu too"
    )
    assert(
        not multi.dropdown.selectionPreview,
        "a multi-select summary must not imply one selected texture"
    )
    key("SPACE")
    assert(not multi:GetValue().one and multi.dropdown:IsMenuOpen())
    multi.dropdown:CloseMenu()
    lib:_ClearNavigationFocus(multi)
    local plain = lib:CreateDropdown(nil, {
        choices = { { value = "plain", label = "Plain" } },
    })
    openMenu(plain)
    assert(
        menu.rows[1]:GetWidth() < 280,
        "pooled rows must return to native sizing when the next menu has no explicit width"
    )
    plain.dropdown:CloseMenu()

    for _, width in ipairs({ 420, 190 }) do
        plain:SetControlWidth(width)
        openMenu(plain)
        assert(
            plain.dropdown:GetMenuDescription().minimumWidth
                == plain.dropdown:GetWidth()
        )
        assert(not plain.dropdown:GetMenuDescription().maximumWidth)
        assert(
            menu.rows[1]:GetWidth() == plain.dropdown:GetWidth() - 20,
            "responsive dropdowns must follow their input width with full-width hit targets"
        )
        plain.dropdown:CloseMenu()
    end

    assert(not pcall(lib.CreateDropdown, lib, nil, {
        choices = {
            {
                value = "invalid",
                label = "Invalid",
                previewTexture = {},
            },
        },
    }))

    for _, width in ipairs({ 0, -1, math.huge, 0 / 0, "wide" }) do
        assert(not pcall(lib.CreateDropdown, lib, nil, { menuWidth = width }))
    end

    print("LibModernSettings dropdown texture preview tests passed")
end
