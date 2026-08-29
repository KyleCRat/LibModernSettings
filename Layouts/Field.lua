local MAJOR, MINOR = "LibModernSettings-1.0", 6
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 270
local DEFAULT_LABEL_HEIGHT = 18
local DEFAULT_INLINE_LABEL_WIDTH = 90
local DEFAULT_GAP = 8

local VALID_LABEL_POSITIONS = {
    top = true,
    left = true,
}

local function shallowCopy(source)
    local copy = {}

    if source then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end

    return copy
end

local function validateOptions(options)
    assert(
        type(options.label) == "string" and options.label ~= "",
        "field label must be a non-empty string"
    )
    assert(
        type(options.controlType) == "string"
            and options.controlType ~= "",
        "field controlType must be a non-empty string"
    )
    assert(
        options.controlType ~= "field",
        "fields cannot directly contain fields"
    )
    assert(
        options.controlOptions == nil
            or type(options.controlOptions) == "table",
        "field controlOptions must be a table or nil"
    )
    assert(
        options.labelPosition == nil
            or VALID_LABEL_POSITIONS[options.labelPosition],
        "field labelPosition must be top, left, or nil"
    )
    assert(
        options.width == nil
            or (type(options.width) == "number" and options.width > 0),
        "field width must be a positive number or nil"
    )
    assert(
        options.labelWidth == nil
            or (type(options.labelWidth) == "number"
                and options.labelWidth > 0),
        "field labelWidth must be a positive number or nil"
    )
    assert(
        options.labelHeight == nil
            or (type(options.labelHeight) == "number"
                and options.labelHeight > 0),
        "field labelHeight must be a positive number or nil"
    )
    assert(
        options.gap == nil
            or (type(options.gap) == "number" and options.gap >= 0),
        "field gap must be a non-negative number or nil"
    )
    assert(
        options.enabled == nil or type(options.enabled) == "boolean",
        "field enabled must be a boolean or nil"
    )
end

local function createField(parent, options)
    validateOptions(options)

    local width = options.width or DEFAULT_WIDTH
    local labelPosition = options.labelPosition or "top"
    local labelHeight = options.labelHeight or DEFAULT_LABEL_HEIGHT
    local labelWidth = options.labelWidth
        or DEFAULT_INLINE_LABEL_WIDTH
    local gap = options.gap

    if gap == nil then
        gap = DEFAULT_GAP
    end

    local controlWidth = width

    if labelPosition == "left" then
        controlWidth = width - labelWidth - gap
        assert(
            controlWidth > 0,
            "field label and gap must leave positive control width"
        )
    end

    local controlOptions = shallowCopy(options.controlOptions)
    local enabled = options.enabled

    if enabled == nil then
        enabled = controlOptions.enabled ~= false
    end

    local disabledTooltip = options.disabledTooltip

    if disabledTooltip == nil then
        disabledTooltip = controlOptions.disabledTooltip
    end

    local tooltip = options.tooltip

    if tooltip == nil then
        tooltip = controlOptions.tooltip
    end

    local tooltipTitle = options.tooltipTitle
        or controlOptions.tooltipTitle
        or options.label

    controlOptions.width = controlWidth
    controlOptions.enabled = enabled
    controlOptions.disabledTooltip = disabledTooltip

    if tooltip ~= nil then
        controlOptions.tooltip = tooltip
        controlOptions.tooltipTitle = tooltipTitle
    end

    local field = CreateFrame("Frame", nil, parent)
    local control = lib:CreateControl(
        options.controlType,
        field,
        controlOptions
    )
    local controlHeight = control:GetHeight()

    assert(
        type(controlHeight) == "number" and controlHeight > 0,
        "field controls must have a positive height"
    )
    assert(
        type(control.SetControlEnabled) == "function",
        "field controls must support SetControlEnabled"
    )

    local fieldHeight = labelPosition == "left"
        and math.max(labelHeight, controlHeight)
        or labelHeight + gap + controlHeight

    field:SetSize(width, fieldHeight)

    local label = lib:CreateText(field, {
        fontObject = options.labelFontObject or GameFontHighlight,
        text = options.label,
        width = labelPosition == "left" and labelWidth or width,
        height = labelPosition == "left" and fieldHeight or labelHeight,
        justifyH = options.labelJustifyH or "LEFT",
        justifyV = labelPosition == "left" and "MIDDLE" or "TOP",
    })

    control:ClearAllPoints()

    if labelPosition == "left" then
        label:SetPoint("LEFT", field, "LEFT", 0, 0)
        control:SetPoint("LEFT", field, "LEFT", labelWidth + gap, 0)
    else
        label:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
        control:SetPoint(
            "TOPLEFT",
            field,
            "TOPLEFT",
            0,
            -(labelHeight + gap)
        )
    end

    field.label = label
    field.control = control
    field._libModernSettingsInitialEnabled = enabled
    field._libModernSettingsInitialDisabledTooltip = disabledTooltip

    if tooltip ~= nil then
        lib:SetTooltip(field, {
            title = tooltipTitle,
            text = tooltip,
        })
    end

    return field
end

local fieldMethods = {}

function fieldMethods:GetControl()
    return self.control
end

function fieldMethods:SetControlEnabled(enabled, disabledTooltip)
    self.control:SetControlEnabled(enabled, disabledTooltip)

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self.label:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeField(field)
    field:SetControlEnabled(
        field._libModernSettingsInitialEnabled,
        field._libModernSettingsInitialDisabledTooltip
    )
    field._libModernSettingsInitialEnabled = nil
    field._libModernSettingsInitialDisabledTooltip = nil
end

lib:RegisterControlType(
    "field",
    createField,
    fieldMethods,
    initializeField
)

function lib:CreateField(parent, options)
    options = options or {}

    return self:CreateControl("field", parent, options)
end
