local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Button", MINOR)
then
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
        selectedOutset = 3,
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
        selectedOutset = 2.5,
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

local function applyButtonTexture(button, getter, setter, layer, atlas)
    local texture = button[getter](button)

    if not texture then
        texture = lib:_CreateAtlasTexture(button, layer, atlas)
        button[setter](button, texture)
    else
        texture:SetAtlas(atlas, false)
    end

    return texture
end

-- Icon buttons and color swatches share state artwork; each owns its content.
function lib:_ApplyButtonArtwork(button, variant)
    local style = BUTTON_STYLES[variant]
    button._libModernSettingsButtonStyle = style

    applyButtonTexture(
        button,
        "GetNormalTexture",
        "SetNormalTexture",
        "BACKGROUND",
        style.normal
    )
    applyButtonTexture(
        button,
        "GetPushedTexture",
        "SetPushedTexture",
        "BACKGROUND",
        style.pressed
    )
    applyButtonTexture(
        button,
        "GetDisabledTexture",
        "SetDisabledTexture",
        "BACKGROUND",
        style.disabled
    )

    if style.highlight then
        local highlight = applyButtonTexture(
            button,
            "GetHighlightTexture",
            "SetHighlightTexture",
            "HIGHLIGHT",
            style.highlight
        )
        highlight:SetBlendMode("ADD")
        -- Older swatches explicitly hid this texture. The native button owns
        -- whether the highlight is drawn for mouse hover or keyboard focus.
        highlight:Show()
    end
end

local selectionMethods = {}
lib._buttonSelectionMethods = selectionMethods

-- Selection is consumer-owned persistent state, not a pressed/hover effect.
-- Clicking still calls onClick; it never toggles selection automatically.
function selectionMethods:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be a boolean")
    self._libModernSettingsSelected = selected
    self:_RefreshNavigationHover()
end

function selectionMethods:IsSelected()
    return self._libModernSettingsSelected == true
end

local function validateButtonIcon(options, style)
    assert(
        options.iconAtlas == nil or type(options.iconAtlas) == "string",
        "iconAtlas must be a string or nil"
    )
    assert(
        options.iconTexture == nil
            or type(options.iconTexture) == "string"
            or type(options.iconTexture) == "number",
        "iconTexture must be a texture path, file ID, or nil"
    )
    assert(
        not (options.iconAtlas and options.iconTexture),
        "use either iconAtlas or iconTexture"
    )
    assert(
        not style.iconOnly or options.iconAtlas or options.iconTexture,
        "square buttons require iconAtlas or iconTexture"
    )
end

local function sizeButtonIcon(icon, style, options)
    local width, height = DEFAULT_TEXTURE_ICON_SIZE, DEFAULT_TEXTURE_ICON_SIZE

    if options.iconSize then
        width, height = options.iconSize, options.iconSize
    else
        if options.iconAtlas then
            width, height = icon:GetWidth(), icon:GetHeight()
        end

        local maxIconSize = options.maxIconSize or style.maxIconSize
        local largestDimension = math.max(width, height)

        if maxIconSize and largestDimension > maxIconSize then
            local scale = maxIconSize / largestDimension
            width = math.floor((width * scale) + 0.5)
            height = math.floor((height * scale) + 0.5)
        end
    end

    if
        not lib:_LayoutSizeMatches(icon:GetWidth(), width)
        or not lib:_LayoutSizeMatches(icon:GetHeight(), height)
    then
        icon:SetSize(width, height)
    end
end

local function applyButtonIcon(button, style, options)
    local icon = button.icon
    local wasShown = icon and icon:IsShown()

    if not options.iconAtlas and not options.iconTexture then
        if icon then icon:Hide() end

        return wasShown
    end

    local previousWidth = icon and icon:GetWidth() or 0
    local previousHeight = icon and icon:GetHeight() or 0

    if not icon then
        icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
        button.icon = icon
    end

    if options.iconAtlas then
        icon:SetAtlas(options.iconAtlas, true)
    else
        icon:SetTexture(options.iconTexture)
        icon:SetTexCoord(0, 1, 0, 1)
    end

    sizeButtonIcon(icon, style, options)
    icon:SetDesaturated(not button:IsEnabled())
    icon:SetAlpha(button:IsEnabled() and 1 or 0.5)
    icon:Show()

    return not wasShown
        or not lib:_LayoutSizeMatches(icon:GetWidth(), previousWidth)
        or not lib:_LayoutSizeMatches(icon:GetHeight(), previousHeight)
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

    if icon and not icon:IsShown() then icon = nil end

    if not label then return end

    -- SetButtonText can reanchor this label inside OnClick. Native push/pop
    -- displacement would then offset the new anchor again on mouse release.
    -- Keep label placement here; the pressed texture supplies click feedback.
    button:SetPushedTextOffset(0, 0)
    button.label = label
    button._libModernSettingsMinWidth = button._libModernSettingsMinWidth
        or style.minWidth
    button._libModernSettingsPaddingX = button._libModernSettingsPaddingX
        or style.paddingX
    button._libModernSettingsIconGap = button._libModernSettingsIconGap
        or DEFAULT_ICON_GAP

    local textWidth = label:GetStringWidth()
    local iconWidth = icon and icon:GetWidth() or 0
    local gap = icon and textWidth > 0 and button._libModernSettingsIconGap or 0

    if icon then
        if style.iconOnly then
            local mask = lib:_ApplyTertiarySquareMask(
                button,
                icon,
                button:GetWidth(),
                button._libModernSettingsIconMaskInset
            )
            lib:_SetLayoutPoint(icon, "CENTER", mask, "CENTER", 0, 0)
        else
            lib:_SetLayoutPoint(
                icon,
                "CENTER",
                button,
                "CENTER",
                -((textWidth + gap) / 2),
                0
            )
        end

        lib:_SetLayoutPoint(
            label,
            "CENTER",
            button,
            "CENTER",
            (iconWidth + gap) / 2,
            0
        )
    else
        lib:_SetLayoutPoint(label, "CENTER", button, "CENTER", 0, 0)
    end

    if button._libModernSettingsFitToContent then
        local contentWidth = textWidth + iconWidth + gap
        local width = math.max(
            button._libModernSettingsMinWidth,
            math.ceil(contentWidth + (button._libModernSettingsPaddingX * 2))
        )

        button:SetWidth(width)

        if button._libModernSettingsAppliedSize then
            button._libModernSettingsAppliedSize.width = width
        end
    end
end

local function createButton(parent, options)
    local style = BUTTON_STYLES[options.variant or "regular"]

    assert(style, "button variant must be 'regular', 'small', or 'square'")
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
        options.iconMaskInset == nil
            or (
                style.iconOnly
                and type(options.iconMaskInset) == "number"
                and options.iconMaskInset >= 0
                and options.iconMaskInset < math.huge
            ),
        "iconMaskInset must be finite and non-negative, and requires a square button"
    )
    assert(
        options.iconSize == nil
            or (type(options.iconSize) == "number" and options.iconSize > 0),
        "iconSize must be a positive number or nil"
    )
    assert(
        options.maxIconSize == nil
            or (
                type(options.maxIconSize) == "number"
                and options.maxIconSize > 0
            ),
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

        local squareSize = options.width or options.height or style.defaultWidth

        initialWidth = squareSize
        initialHeight = squareSize
    end

    button:SetSize(initialWidth, initialHeight)
    button._libModernSettingsButtonStyle = style
    button._libModernSettingsIconMaskInset = options.iconMaskInset
    button._libModernSettingsSelected = options.selected == true
    button._libModernSettingsFitToContent = options.fitToContent == true
    button._libModernSettingsMinWidth = options.minWidth
        or (options.fitToContent and options.width)
        or style.minWidth
    button._libModernSettingsPaddingX = options.paddingX or style.paddingX
    button._libModernSettingsIconGap = options.iconGap or DEFAULT_ICON_GAP

    local label = button:CreateFontString(nil, "OVERLAY")

    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    button:SetFontString(label)
    button:SetNormalFontObject(options.normalFont or style.normalFont)
    button:SetHighlightFontObject(options.highlightFont or style.highlightFont)
    button:SetDisabledFontObject(options.disabledFont or style.disabledFont)
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

local buttonMethods = {
    SetSelected = selectionMethods.SetSelected,
    IsSelected = selectionMethods.IsSelected,
}

function buttonMethods:_HandleClick(...)
    local onClick = self._libModernSettingsOnClick

    lib:_FlushPendingEditBoxCommits()

    if onClick then onClick(self, ...) end
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

function buttonMethods:SetButtonIcon(options)
    assert(type(options) == "table", "button icon options must be a table")
    local style = getButtonStyle(self)
    validateButtonIcon(options, style)

    local appearance = self._libModernSettingsAppearanceOptions
    appearance.iconAtlas = options.iconAtlas
    appearance.iconTexture = options.iconTexture

    -- Pooled icons change artwork without rebuilding fonts, button geometry or
    -- masks. Adding/removing an icon or changing its dimensions still reflows.
    if applyButtonIcon(self, style, appearance) then
        layoutButtonContent(self)
    end
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
    button:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)
end

local function refreshButtonAppearance(button, options)
    local style = BUTTON_STYLES[options.variant or "regular"]
    local width = options.width or style.defaultWidth or 100
    local height = options.height or style.height

    if style.iconOnly then
        width = options.width or options.height or style.defaultWidth
        height = width
    end

    button._libModernSettingsIconMaskInset = options.iconMaskInset
    lib:_ApplyFixedControlSize(button, width, height)
    lib:_ApplyButtonArtwork(button, options.variant or "regular")
    button._libModernSettingsMinWidth = options.minWidth
        or (options.fitToContent and options.width)
        or style.minWidth
    button._libModernSettingsPaddingX = options.paddingX or style.paddingX
    button._libModernSettingsIconGap = options.iconGap or DEFAULT_ICON_GAP
    lib:_ApplyButtonFonts(
        button,
        options.normalFont or style.normalFont,
        options.highlightFont or style.highlightFont,
        options.disabledFont or style.disabledFont
    )
    applyButtonIcon(button, style, options)
    layoutButtonContent(button)

    if style.iconOnly and not button._libModernSettingsIconMaskSizeHooked then
        button._libModernSettingsIconMaskSizeHooked = true
        button:HookScript("OnSizeChanged", function(self)
            lib:_ApplyTertiarySquareMask(
                self,
                self.icon,
                self:GetWidth(),
                self._libModernSettingsIconMaskInset
            )
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

lib._buttonNavigation = {
    actions = lib._buttonNavigationActions,
    highlight = lib._SetButtonNavigationHighlight,
    hover = function(control, highlighted)
        local style = getButtonStyle(control)
        local texture = control:GetNormalTexture()

        if texture then
            local atlas = style.normal
            local outset = 0

            if control:IsSelected() then
                atlas = style.selected
                outset = style.selectedOutset or 0
            elseif highlighted and style.hover then
                atlas = style.hover
            end

            texture:SetAtlas(atlas, false)
            -- Selected text-button atlases include extra glow margins. Keep
            -- their visible body aligned without enlarging the button's hit area.
            if texture._libModernSettingsButtonOutset ~= outset then
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", control, "TOPLEFT", -outset, outset)
                texture:SetPoint(
                    "BOTTOMRIGHT",
                    control,
                    "BOTTOMRIGHT",
                    outset,
                    -outset
                )
                texture._libModernSettingsButtonOutset = outset
            end
        end
    end,
}

lib:RegisterControlNavigation("button", lib._buttonNavigation)

function lib:CreateButton(parent, options)
    options = options or {}

    return self:CreateControl("button", parent, options)
end
