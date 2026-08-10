local MAJOR, MINOR = "LibModernSettings-1.0", 1
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local CHECKBOX_SIZE = 34
local LABEL_GAP = 2
local CHECKMARK_ATLAS = "common-icon-checkmark-yellow"
local CHECKMARK_SCALE = 1.25
local CHECKMARK_OFFSET_X = 2
local CHECKMARK_OFFSET_Y = 2

local CHECKBOX_ATLASES = {
    normal = "common-button-tertiary-square-normal",
    hover = "common-button-tertiary-square-hover",
    pressed = "common-button-tertiary-square-pressed",
    disabled = "common-button-tertiary-square-disabled",
}

local function createCheckmark(checkbox, disabled)
    local texture = checkbox:CreateTexture(nil, "ARTWORK")

    texture:SetPoint(
        "CENTER",
        checkbox,
        "CENTER",
        CHECKMARK_OFFSET_X,
        CHECKMARK_OFFSET_Y
    )
    texture:SetAtlas(CHECKMARK_ATLAS, true)
    texture:SetScale(CHECKMARK_SCALE)

    if disabled then
        texture:SetDesaturated(true)
        texture:SetVertexColor(
            GRAY_FONT_COLOR.r,
            GRAY_FONT_COLOR.g,
            GRAY_FONT_COLOR.b
        )
    end

    return texture
end

local function createCheckbox(parent, options)
    assert(
        options.onChanged == nil or type(options.onChanged) == "function",
        "onChanged must be a function or nil"
    )

    local checkbox = CreateFrame("CheckButton", nil, parent)

    checkbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
    checkbox:SetNormalTexture(lib:_CreateAtlasTexture(
        checkbox,
        "BACKGROUND",
        CHECKBOX_ATLASES.normal
    ))
    checkbox:SetPushedTexture(lib:_CreateAtlasTexture(
        checkbox,
        "BACKGROUND",
        CHECKBOX_ATLASES.pressed
    ))
    checkbox:SetHighlightTexture(lib:_CreateAtlasTexture(
        checkbox,
        "HIGHLIGHT",
        CHECKBOX_ATLASES.hover
    ))
    checkbox:SetDisabledTexture(lib:_CreateAtlasTexture(
        checkbox,
        "BACKGROUND",
        CHECKBOX_ATLASES.disabled
    ))
    checkbox:SetCheckedTexture(createCheckmark(checkbox, false))
    checkbox:SetDisabledCheckedTexture(createCheckmark(checkbox, true))
    checkbox._libModernSettingsOnChanged = options.onChanged
    checkbox:SetScript("OnClick", function(self)
        self:_HandleClick()
    end)

    if options.label then
        local width = options.width or 220
        local label = lib:CreateText(checkbox, {
            fontObject = options.fontObject or GameFontHighlight,
            text = options.label,
            width = math.max(width - CHECKBOX_SIZE - LABEL_GAP, 1),
            justifyV = "MIDDLE",
        })

        label:SetPoint("LEFT", checkbox, "RIGHT", LABEL_GAP, 0)
        checkbox.label = label

        if width > CHECKBOX_SIZE then
            checkbox:SetHitRectInsets(0, CHECKBOX_SIZE - width, 0, 0)
        end
    end

    if options.tooltip then
        lib:SetTooltip(checkbox, {
            title = options.tooltipTitle,
            text = options.tooltip,
        })
    end

    return checkbox
end

local checkboxMethods = {}

function checkboxMethods:_HandleClick()
    local checked = self:GetChecked() == true

    PlaySound(
        checked
            and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
            or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
    )

    if self._libModernSettingsOnChanged then
        self._libModernSettingsOnChanged(checked)
    end
end

function checkboxMethods:SetValue(value)
    self:SetChecked(value == true)
end

function checkboxMethods:GetValue()
    return self:GetChecked() == true
end

function checkboxMethods:SetOnChanged(onChanged)
    assert(
        onChanged == nil or type(onChanged) == "function",
        "onChanged must be a function or nil"
    )
    self._libModernSettingsOnChanged = onChanged
end

function checkboxMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)

    if self.label then
        local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

        self.label:SetTextColor(color.r, color.g, color.b)
    end

    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeCheckbox(checkbox, options)
    checkbox:SetValue(options.value)
    checkbox:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
end

lib:RegisterControlType(
    "checkbox",
    createCheckbox,
    checkboxMethods,
    initializeCheckbox
)

function lib:CreateCheckbox(parent, options)
    options = options or {}

    return self:CreateControl("checkbox", parent, options)
end
