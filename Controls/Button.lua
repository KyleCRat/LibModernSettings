local MAJOR, MINOR = "LibModernSettings-1.0", 1
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local BUTTON_STYLES = {
    regular = {
        height = 34,
        normal = "common-button-tertiary-normal",
        hover = "common-button-tertiary-hover",
        pressed = "common-button-tertiary-pressed",
        disabled = "common-button-tertiary-disabled",
        normalFont = GameFontNormal,
        highlightFont = GameFontHighlight,
        disabledFont = GameFontDisable,
    },
    small = {
        height = 22,
        normal = "common-button-tertiary-normal-small",
        hover = "common-button-tertiary-hover-small",
        pressed = "common-button-tertiary-pressed-small",
        disabled = "common-button-tertiary-disabled-small",
        normalFont = GameFontNormalSmall,
        highlightFont = GameFontHighlightSmall,
        disabledFont = GameFontDisableSmall,
    },
}

local function createButton(parent, options)
    local style = BUTTON_STYLES[options.variant or "regular"]

    assert(style, "button variant must be 'regular' or 'small'")
    assert(
        options.onClick == nil or type(options.onClick) == "function",
        "onClick must be a function or nil"
    )

    local button = CreateFrame("Button", nil, parent)

    button:SetSize(options.width or 100, options.height or style.height)
    button:SetNormalFontObject(options.normalFont or style.normalFont)
    button:SetHighlightFontObject(
        options.highlightFont or style.highlightFont
    )
    button:SetDisabledFontObject(
        options.disabledFont or style.disabledFont
    )
    button:SetNormalTexture(lib:_CreateAtlasTexture(
        button,
        "BACKGROUND",
        style.normal
    ))
    button:SetHighlightTexture(lib:_CreateAtlasTexture(
        button,
        "HIGHLIGHT",
        style.hover
    ))
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
    button:SetText(options.text or "")
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

function buttonMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

lib:RegisterControlType("button", createButton, buttonMethods)

function lib:CreateButton(parent, options)
    options = options or {}

    local button = self:CreateControl("button", parent, options)

    button:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )

    return button
end
