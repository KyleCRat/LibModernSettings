return function(lib, upgraded)
    local control = lib:CreateDropdown(nil, {
        width = 180,
        choices = {
            { value = 1, label = "First" },
            { value = 2, label = "Second" },
        },
        value = 1,
    })
    local button = control.dropdown
    assert(control:GetHeight() == 34 and button:GetHeight() == 34)
    assert(control:GetContentTopInset() == 0)
    assert(button.Background.allPoints == button)
    assert(button.Background.atlas == "common-button-tertiary-depressed-normal")
    assert(
        button.focusTexture.atlas
            == "common-button-tertiary-depressed-normal-glow"
    )
    assert(not button.focusTexture:IsShown())
    assert(
        select(4, button.focusTexture:GetPoint(1)) == -2
            and select(5, button.focusTexture:GetPoint(1)) == 3
    )
    assert(
        select(4, button.focusTexture:GetPoint(2)) == 2
            and select(5, button.focusTexture:GetPoint(2)) == -1
    )
    assert(
        button.arrowBackground.atlas == "common-button-tertiary-square-normal"
    )
    assert(
        button.arrowBackground:GetWidth() == 26
            and button.arrowBackground:GetHeight() == 26
    )
    assert(
        button.arrowBackground.point[1] == "RIGHT"
            and button.arrowBackground.point[4] == -4
    )
    assert(button.Arrow.point[2] == button.arrowBackground)
    assert(
        button.Arrow:GetWidth() == 12 and button.Arrow.rotation == math.pi * 1.5
    )
    assert(button.Text.justifyV == "MIDDLE" and button.Text:GetHeight() == 34)
    assert(select(4, button.Text:GetPoint(1)) == 12)
    assert(select(2, button.Text:GetPoint(2)) == button.arrowBackground)

    button:OnEnter()
    assert(
        button.Background.atlas == "common-button-tertiary-depressed-normal"
            and not button.focusTexture:IsShown(),
        "hover alone must not change the recessed body or imply input focus"
    )
    assert(
        button.arrowBackground.atlas == "common-button-tertiary-square-hover"
    )
    button.down = true
    button:OnButtonStateChanged()
    assert(button.Background.atlas == "common-button-tertiary-depressed-normal")
    assert(
        button.arrowBackground.atlas == "common-button-tertiary-square-pressed"
    )
    assert(button.Arrow.point[4] == 1 and button.Arrow.point[5] == 0)
    button.down = nil
    button.menu = {}
    button:OnLeave()
    assert(
        button.Background.atlas == "common-button-tertiary-depressed-normal"
            and button.focusTexture:IsShown()
    )
    assert(
        button.arrowBackground.atlas == "common-button-tertiary-square-pressed",
        "open menus press only the caret square"
    )
    button.menu = nil
    control:_OnMenuClosed()
    assert(not button.focusTexture:IsShown())

    control:_SetNavigationHighlight(true)
    button.scripts.OnLeave(button)
    assert(
        button.focusTexture:IsShown(),
        "mouse leave must preserve the focused input glow"
    )
    button.scripts.OnEnter(button)
    control:_SetNavigationHighlight(false)
    assert(
        not button.focusTexture:IsShown()
            and button.arrowBackground.atlas
                == "common-button-tertiary-square-hover",
        "losing focus while hovered must clear the body glow without clearing caret hover"
    )
    control:_SetNavigationHighlight(true)

    control:SetControlEnabled(false)
    assert(
        button.Background.atlas == "common-button-tertiary-depressed-normal"
            and not button.focusTexture:IsShown()
    )
    assert(
        button.arrowBackground.atlas == "common-button-tertiary-square-disabled"
    )
    assert(button.Arrow.atlas == "common-dropdown-icon-next-disabled")
    control:SetControlEnabled(true)
    assert(button.Background.atlas == "common-button-tertiary-depressed-normal")
    assert(control:GetValue() == 1)

    local body, square, caret, text =
        button.Background, button.arrowBackground, button.Arrow, button.Text
    local focus = button.focusTexture
    control:SetControlWidth(320)
    control:SetControlHeight(50)
    assert(button:GetWidth() == 320 and button:GetHeight() == 34)
    assert(control:GetContentTopInset() == 8)
    control:SetValue(2)
    assert(
        button.Background == body
            and button.arrowBackground == square
            and button.Arrow == caret
            and button.Text == text
    )
    assert(button.focusTexture == focus)
    assert(control:GetValue() == 2)

    assert(
        upgraded.dropdown:GetHeight() == 34 and upgraded:GetHeight() == 60,
        "upgrades must preserve explicit row heights while replacing the old button art"
    )
    assert(
        upgraded.dropdown.Background.atlas
            == "common-button-tertiary-depressed-normal"
    )
    assert(
        upgraded.dropdown.focusTexture.atlas
            == "common-button-tertiary-depressed-normal-glow"
    )
    assert(
        upgraded.dropdown.arrowBackground.atlas
            == "common-button-tertiary-square-normal"
    )
    assert(
        #upgraded.dropdown.callbacks.OnMenuOpen == 1
            and #upgraded.dropdown.callbacks.OnMenuClose == 1
    )
    print("LibModernSettings dropdown artwork tests passed")
end
