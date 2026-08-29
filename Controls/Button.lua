local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
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
        highlight = "common-button-tertiary-square-normal",
        normalFont = GameFontNormal,
        highlightFont = GameFontHighlight,
        disabledFont = GameFontDisable,
        iconOnly = true,
    },
}

local DEFAULT_ICON_GAP = 4

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
        icon:SetPoint(
            "CENTER",
            button,
            "CENTER",
            -((textWidth + gap) / 2),
            0
        )
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
        options.iconAtlas == nil or type(options.iconAtlas) == "string",
        "iconAtlas must be a string or nil"
    )
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
        not style.iconOnly or type(options.iconAtlas) == "string",
        "square buttons require iconAtlas"
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

    if options.iconAtlas then
        local icon = button:CreateTexture(nil, "OVERLAY", nil, 1)

        icon:SetAtlas(options.iconAtlas, true)
        sizeButtonIcon(icon, style, options)

        button.icon = icon
    end

    layoutButtonContent(button)
    button._libModernSettingsOnClick = options.onClick
    if style.hover then
        button:SetScript("OnEnter", function()
            normalTexture:SetAtlas(style.hover, false)
        end)
        button:SetScript("OnLeave", function()
            normalTexture:SetAtlas(style.normal, false)
        end)
    end
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
    if self._libModernSettingsOnClick then
        self._libModernSettingsOnClick(self, ...)
    end
end

function buttonMethods:SetOnClick(onClick)
    assert(
        onClick == nil or type(onClick) == "function",
        "onClick must be a function or nil"
    )
    self._libModernSettingsOnClick = onClick
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

function buttonMethods:FitToContents()
    self._libModernSettingsFitToContent = true
    layoutButtonContent(self)
end

function buttonMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)

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

lib:RegisterControlType(
    "button",
    createButton,
    buttonMethods,
    initializeButton
)

function lib:CreateButton(parent, options)
    options = options or {}

    return self:CreateControl("button", parent, options)
end
