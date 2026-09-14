local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 270
local DEFAULT_INLINE_LABEL_HEIGHT = 18
local DEFAULT_INLINE_LABEL_WIDTH = 90
local DEFAULT_INLINE_GAP = 8

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

local function layoutField(field)
    local layout = field._libModernSettingsFieldLayout
    local width = field:GetWidth()
    local label = field.label
    local control = field.control
    local controlWidth = width

    if layout.labelPosition == "left" then
        controlWidth = math.max(1, width - layout.labelWidth - layout.gap)
    end

    if type(control.SetControlWidth) == "function" then
        control:SetControlWidth(controlWidth)
    else
        control:SetWidth(controlWidth)
    end
    label:ClearAllPoints()
    control:ClearAllPoints()

    if layout.labelPosition == "left" then
        local height = math.max(
            layout.labelHeight or math.max(DEFAULT_INLINE_LABEL_HEIGHT, label:GetStringHeight()),
            control:GetHeight()
        )

        label:SetWidth(layout.labelWidth)
        label:SetHeight(field._libModernSettingsExplicitHeight or height)
        label:SetJustifyV("MIDDLE")
        label:SetPoint("LEFT", field, "LEFT", 0, 0)
        control:SetPoint("LEFT", field, "LEFT", layout.labelWidth + layout.gap, 0)
        return height
    end

    label:SetWidth(width)
    layout.contentTopInset = type(control.GetContentTopInset) == "function"
        and control:GetContentTopInset() or 0
    return lib:_LayoutStackedLabel(field, label, control, layout)
end

local function watchFieldSize(field)
    lib:_WatchControlSize(field)
    field.control:HookScript("OnSizeChanged", function()
        field:RefreshLayout()
    end)
end

local function createField(parent, options)
    validateOptions(options)

    local width = options.width or DEFAULT_WIDTH
    local labelPosition = options.labelPosition or "top"
    local labelHeight = options.labelHeight
    local labelWidth = options.labelWidth
        or DEFAULT_INLINE_LABEL_WIDTH
    local gap = options.gap

    local controlWidth = width

    if labelPosition == "left" then
        gap = gap or DEFAULT_INLINE_GAP
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

    local label = lib:CreateText(field, {
        fontObject = options.labelFontObject or GameFontHighlight,
        text = options.label,
        width = labelPosition == "left" and labelWidth or width,
        height = labelHeight,
        justifyH = options.labelJustifyH or "LEFT",
        justifyV = labelPosition == "left" and "MIDDLE" or "TOP",
    })

    field.label = label
    field.control = control
    field._libModernSettingsFieldLayout = {
        labelPosition = labelPosition,
        labelWidth = labelWidth,
        labelHeight = labelHeight,
        gap = gap,
    }
    field._libModernSettingsInitialEnabled = enabled
    field._libModernSettingsInitialDisabledTooltip = disabledTooltip
    field:SetWidth(width)
    lib:_RefreshControlLayout(field, layoutField)
    watchFieldSize(field)

    if tooltip ~= nil then
        lib:SetTooltip(field, {
            title = tooltipTitle,
            text = tooltip,
        })
    end

    return field
end

local fieldMethods = {}

fieldMethods.SetControlWidth = lib._SetControlWidth
fieldMethods.SetControlHeight = lib._SetControlHeight

function fieldMethods:RefreshLayout()
    lib:_RefreshControlLayout(self, layoutField)
end

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

-- Keep the layout choices of Fields constructed by an older embedded copy.
for field, controlType in pairs(lib._controlInstances) do
    if controlType == "field" and not field._libModernSettingsFieldLayout then
        local control = field.control
        local point, relativeTo, _, x, y = control:GetPoint(1)
        local inline = point == "LEFT"
        local labelWidth = field.label:GetWidth()
        local topInset = type(control.GetContentTopInset) == "function"
            and control:GetContentTopInset() or 0
        local gap = inline and x - labelWidth or topInset - y

        if not inline and relativeTo == field then
            gap = -y - field.label:GetHeight()
        end

        field._libModernSettingsFieldLayout = {
            labelPosition = inline and "left" or "top",
            labelWidth = labelWidth,
            labelHeight = field.label:GetHeight(),
            gap = gap,
        }
        field._libModernSettingsExplicitHeight = field:GetHeight()
        field:RefreshLayout()
        watchFieldSize(field)
    end
end

function lib:CreateField(parent, options)
    options = options or {}

    return self:CreateControl("field", parent, options)
end
