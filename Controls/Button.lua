local MAJOR, MINOR = "LibModernSettings-1.0", 10
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Button", MINOR) then
    return
end

local BUTTON_STYLES = {
    regular = {
        height = 34,
        minWidth = 46,
        paddingX = 12,
        normal = "common-button-tertiary-normal",
        hover = "common-button-tertiary-hover",
        pressed = "common-button-tertiary-pressed",
        disabled = "common-button-tertiary-disabled",
        selected = "common-button-tertiary-selected",
        normalFont = GameFontNormal,
        highlightFont = GameFontHighlight,
        disabledFont = GameFontDisable,
    },
    small = {
        height = 25,
        minWidth = 65,
        paddingX = 9,
        maxIconSize = 14,
        normal = "common-button-tertiary-normal-small",
        hover = "common-button-tertiary-hover-small",
        pressed = "common-button-tertiary-pressed-small",
        disabled = "common-button-tertiary-disabled-small",
        selected = "common-button-tertiary-selected-small",
        normalFont = GameFontNormalSmall,
        highlightFont = GameFontHighlightSmall,
        disabledFont = GameFontDisableSmall,
    },
    square = {
        height = 34,
        minWidth = 34,
        defaultWidth = 34,
        paddingX = 0,
        maxIconSize = 16,
        normal = "common-button-tertiary-square-normal",
        pressed = "common-button-tertiary-square-pressed",
        disabled = "common-button-tertiary-square-disabled",
        selected = "common-button-tertiary-square-selected",
        highlight = "common-button-tertiary-square-normal",
        normalFont = GameFontNormal,
        highlightFont = GameFontHighlight,
        disabledFont = GameFontDisable,
        iconOnly = true,
    },
}

local DEFAULT_ICON_GAP = 4
local DEFAULT_TEXTURE_ICON_SIZE = 16

local function validateButtonIcon(options, style)
    assert(options.iconAtlas == nil or type(options.iconAtlas) == "string",
        "iconAtlas must be a string or nil")
    assert(options.iconTexture == nil or type(options.iconTexture) == "string"
        or type(options.iconTexture) == "number", "iconTexture must be a texture path, file ID, or nil")
    assert(not (options.iconAtlas and options.iconTexture), "use either iconAtlas or iconTexture")
    assert(not style.iconOnly or options.iconAtlas or options.iconTexture,
        "square buttons require iconAtlas or iconTexture")
end

local function sizeButtonIcon(icon, style, options)
    if options.iconSize then
        icon:SetSize(options.iconSize, options.iconSize)
        return
    end

    local maxIconSize = options.maxIconSize or style.maxIconSize

    if not maxIconSize then
        return
    end

    local width = icon:GetWidth()
    local height = icon:GetHeight()
    local largestDimension = math.max(width, height)

    if largestDimension <= maxIconSize then
        return
    end

    local scale = maxIconSize / largestDimension

    icon:SetSize(
        math.floor((width * scale) + 0.5),
        math.floor((height * scale) + 0.5)
    )
end

local function applyButtonIcon(button, style, options)
    if not options.iconAtlas and not options.iconTexture then
        if button.icon then button.icon:Hide() end
        return
    end

    local icon = button.icon

    if not icon then
        icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
        button.icon = icon
    end

    if options.iconAtlas then
        icon:SetAtlas(options.iconAtlas, true)
    else
        icon:SetTexture(options.iconTexture)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetSize(DEFAULT_TEXTURE_ICON_SIZE, DEFAULT_TEXTURE_ICON_SIZE)
    end

    sizeButtonIcon(icon, style, options)
    icon:SetDesaturated(not button:IsEnabled())
    icon:SetAlpha(button:IsEnabled() and 1 or 0.5)
    icon:Show()
end

local function getButtonStyle(button)
    if button._libModernSettingsButtonStyle then
        return button._libModernSettingsButtonStyle
    end

    return button:GetHeight() <= BUTTON_STYLES.small.height
        and BUTTON_STYLES.small
        or BUTTON_STYLES.regular
end

local function layoutButtonContent(button)
    local style = getButtonStyle(button)
    local label = button.label or button:GetFontString()
    local icon = button.icon

    if icon and not icon:IsShown() then
        icon = nil
    end

    if not label then
        return
    end

    button.label = label
    button._libModernSettingsMinWidth =
        button._libModernSettingsMinWidth or style.minWidth
    button._libModernSettingsPaddingX =
        button._libModernSettingsPaddingX or style.paddingX
    button._libModernSettingsIconGap =
        button._libModernSettingsIconGap or DEFAULT_ICON_GAP

    local textWidth = label:GetStringWidth()
    local iconWidth = icon and icon:GetWidth() or 0
    local gap = icon and textWidth > 0
        and button._libModernSettingsIconGap
        or 0

    label:ClearAllPoints()

    if icon then
        icon:ClearAllPoints()

        if style.iconOnly then
            local mask = lib:_ApplyTertiarySquareMask(button, icon, button:GetWidth())
            icon:SetPoint("CENTER", mask, "CENTER", 0, 0)
        else
            icon:SetPoint(
                "CENTER",
                button,
                "CENTER",
                -((textWidth + gap) / 2),
                0
            )
        end

        label:SetPoint(
            "CENTER",
            button,
            "CENTER",
            (iconWidth + gap) / 2,
            0
        )
    else
        label:SetPoint("CENTER", button, "CENTER", 0, 0)
    end

    if button._libModernSettingsFitToContent then
        local contentWidth = textWidth + iconWidth + gap
        local width = math.max(
            button._libModernSettingsMinWidth,
            math.ceil(
                contentWidth
                    + (button._libModernSettingsPaddingX * 2)
            )
        )

        button:SetWidth(width)
        if button._libModernSettingsAppliedSize then
            button._libModernSettingsAppliedSize.width = width
        end
    end
end

local function createButton(parent, options)
    local style = BUTTON_STYLES[options.variant or "regular"]

    assert(
        style,
        "button variant must be 'regular', 'small', or 'square'"
    )
    assert(
        options.onClick == nil or type(options.onClick) == "function",
        "onClick must be a function or nil"
    )
    assert(
        options.selected == nil or type(options.selected) == "boolean",
        "selected must be a boolean or nil"
    )
    validateButtonIcon(options, style)
    assert(
        options.iconSize == nil
            or (type(options.iconSize) == "number"
                and options.iconSize > 0),
        "iconSize must be a positive number or nil"
    )
    assert(
        options.maxIconSize == nil
            or (type(options.maxIconSize) == "number"
                and options.maxIconSize > 0),
        "maxIconSize must be a positive number or nil"
    )
    assert(
        not style.iconOnly or options.text == nil or options.text == "",
        "square buttons do not support text"
    )

    local button = CreateFrame("Button", nil, parent)
    local initialWidth = options.width
        or (options.fitToContent and style.minWidth)
        or style.defaultWidth
        or 100
    local initialHeight = options.height or style.height

    if style.iconOnly then
        assert(
            options.width == nil
                or options.height == nil
                or options.width == options.height,
            "square button width and height must match"
        )

        local squareSize = options.width
            or options.height
            or style.defaultWidth

        initialWidth = squareSize
        initialHeight = squareSize
    end

    button:SetSize(initialWidth, initialHeight)
    button._libModernSettingsButtonStyle = style
    button._libModernSettingsSelected = options.selected == true
    button._libModernSettingsFitToContent = options.fitToContent == true
    button._libModernSettingsMinWidth = options.minWidth
        or (options.fitToContent and options.width)
        or style.minWidth
    button._libModernSettingsPaddingX = options.paddingX
        or style.paddingX
    button._libModernSettingsIconGap = options.iconGap
        or DEFAULT_ICON_GAP

    local label = button:CreateFontString(nil, "OVERLAY")

    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    button:SetFontString(label)
    button:SetNormalFontObject(options.normalFont or style.normalFont)
    button:SetHighlightFontObject(
        options.highlightFont or style.highlightFont
    )
    button:SetDisabledFontObject(
        options.disabledFont or style.disabledFont
    )
    local normalTexture = lib:_CreateAtlasTexture(
        button,
        "BACKGROUND",
        style.normal
    )

    button:SetNormalTexture(normalTexture)
    button:SetPushedTexture(lib:_CreateAtlasTexture(
        button,
        "BACKGROUND",
        style.pressed
    ))
    button:SetDisabledTexture(lib:_CreateAtlasTexture(
        button,
        "BACKGROUND",
        style.disabled
    ))

    if style.highlight then
        local highlightTexture = lib:_CreateAtlasTexture(
            button,
            "HIGHLIGHT",
            style.highlight
        )

        highlightTexture:SetBlendMode("ADD")
        button:SetHighlightTexture(highlightTexture)
    end

    button:SetText(options.text or "")
    button.label = label

    applyButtonIcon(button, style, options)
    layoutButtonContent(button)
    button._libModernSettingsOnClick = options.onClick
    button:SetScript("OnClick", function(self, ...)
        self:_HandleClick(...)
    end)

    if options.tooltip then
        lib:SetTooltip(button, {
            title = options.tooltipTitle,
            text = options.tooltip,
        })
    end

    return button
end

local buttonMethods = {}

function buttonMethods:_HandleClick(...)
    local onClick = self._libModernSettingsOnClick

    lib:_FlushPendingEditBoxCommits()

    if onClick then
        onClick(self, ...)
    end
end

function buttonMethods:SetOnClick(onClick)
    assert(
        onClick == nil or type(onClick) == "function",
        "onClick must be a function or nil"
    )
    self._libModernSettingsOnClick = onClick
end

-- Selection is consumer-owned persistent state, not a pressed/hover effect.
-- Clicking still calls onClick; it never toggles selection automatically.
function buttonMethods:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be a boolean")
    self._libModernSettingsSelected = selected
    self:_RefreshNavigationHover()
end

function buttonMethods:IsSelected()
    return self._libModernSettingsSelected == true
end

function buttonMethods:SetButtonText(text)
    assert(type(text) == "string", "button text must be a string")
    assert(
        not getButtonStyle(self).iconOnly or text == "",
        "square buttons do not support text"
    )
    self:SetText(text)
    layoutButtonContent(self)
end

function buttonMethods:SetButtonIcon(options)
    assert(type(options) == "table", "button icon options must be a table")
    validateButtonIcon(options, getButtonStyle(self))

    local appearance = self._libModernSettingsAppearanceOptions
    appearance.iconAtlas = options.iconAtlas
    appearance.iconTexture = options.iconTexture
    lib:_RefreshControlAppearance(self)
end

function buttonMethods:FitToContents()
    self._libModernSettingsFitToContent = true
    layoutButtonContent(self)
end

function buttonMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)
    self:_RefreshNavigationHover()

    if self.icon then
        self.icon:SetDesaturated(enabled ~= true)
        self.icon:SetAlpha(enabled and 1 or 0.5)
    end

    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeButton(button, options)
    button:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
end

local function refreshButtonAppearance(button, options)
    local style = BUTTON_STYLES[options.variant or "regular"]
    local width = options.width or style.defaultWidth or 100
    local height = options.height or style.height
    if style.iconOnly then
        width = options.width or options.height or style.defaultWidth
        height = width
    end
    lib:_ApplyFixedControlSize(button, width, height)
    button._libModernSettingsButtonStyle = style
    button._libModernSettingsMinWidth = options.minWidth
        or (options.fitToContent and options.width) or style.minWidth
    button._libModernSettingsPaddingX = options.paddingX or style.paddingX
    button._libModernSettingsIconGap = options.iconGap or DEFAULT_ICON_GAP
    lib:_ApplyButtonFonts(button,
        options.normalFont or style.normalFont,
        options.highlightFont or style.highlightFont,
        options.disabledFont or style.disabledFont)
    applyButtonIcon(button, style, options)
    layoutButtonContent(button)

    if style.iconOnly and not button._libModernSettingsIconMaskSizeHooked then
        button._libModernSettingsIconMaskSizeHooked = true
        button:HookScript("OnSizeChanged", function(self)
            lib:_ApplyTertiarySquareMask(self, self.icon, self:GetWidth())
        end)
    end
end

lib:RegisterControlType(
    "button",
    createButton,
    buttonMethods,
    initializeButton,
    refreshButtonAppearance
)

lib:RegisterControlNavigation("button", {
    actions = lib._buttonNavigationActions,
    highlight = lib._SetButtonNavigationHighlight,
    hover = function(control, highlighted)
        local style = getButtonStyle(control)
        local texture = control:GetNormalTexture()

        if texture then
            local atlas = style.normal

            if control:IsSelected() then
                atlas = style.selected
            elseif highlighted and style.hover then
                atlas = style.hover
            end

            texture:SetAtlas(atlas, false)
        end
    end,
})

function lib:CreateButton(parent, options)
    options = options or {}

    return self:CreateControl("button", parent, options)
end
