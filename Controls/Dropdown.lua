local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 270
local LABELED_HEIGHT = 60
local UNLABELED_HEIGHT = 34
local DROPDOWN_INSET = 8

local function setControlWidth(control, width)
    assert(
        type(width) == "number" and width > 0,
        "dropdown width must be a positive number"
    )

    local leftInset = control._libModernSettingsLeftInset
    local rightInset = control._libModernSettingsRightInset

    if leftInset == nil then
        leftInset = DROPDOWN_INSET
    end
    if rightInset == nil then
        rightInset = DROPDOWN_INSET
    end

    control:SetWidth(width)
    control.label:SetWidth(width)
    control.dropdown:SetWidth(math.max(
        1,
        width - leftInset - rightInset
    ))
end

local function createDropdown(parent, options)
    assert(
        options.choices == nil or type(options.choices) == "table",
        "choices must be a table or nil"
    )
    assert(
        options.getChoices == nil
            or type(options.getChoices) == "function",
        "getChoices must be a function or nil"
    )
    assert(
        options.onChanged == nil or type(options.onChanged) == "function",
        "onChanged must be a function or nil"
    )
    assert(
        options.showLabel == nil or type(options.showLabel) == "boolean",
        "showLabel must be a boolean or nil"
    )
    assert(
        options.leftInset == nil
            or (type(options.leftInset) == "number"
                and options.leftInset >= 0),
        "leftInset must be a non-negative number or nil"
    )
    assert(
        options.rightInset == nil
            or (type(options.rightInset) == "number"
                and options.rightInset >= 0),
        "rightInset must be a non-negative number or nil"
    )

    local control = CreateFrame("Frame", nil, parent)
    local width = options.width or DEFAULT_WIDTH
    local showLabel = options.showLabel ~= false
    local leftInset = options.leftInset
    local rightInset = options.rightInset

    if leftInset == nil then
        leftInset = DROPDOWN_INSET
    end
    if rightInset == nil then
        rightInset = DROPDOWN_INSET
    end

    control:SetSize(
        width,
        options.height
            or (showLabel and LABELED_HEIGHT or UNLABELED_HEIGHT)
    )
    control._libModernSettingsChoices = options.choices or {}
    control._libModernSettingsGetChoices = options.getChoices
    control._libModernSettingsOnChanged = options.onChanged
    control._libModernSettingsLeftInset = leftInset
    control._libModernSettingsRightInset = rightInset

    local label = lib:CreateText(control, {
        fontObject = options.fontObject or GameFontHighlight,
        text = options.label,
        width = width,
    })

    local dropdown = CreateFrame(
        "DropdownButton",
        nil,
        control,
        "WowStyle1DropdownTemplate"
    )

    control.label = label
    control.dropdown = dropdown
    control.currentValue = options.value

    setControlWidth(control, width)

    if showLabel then
        label:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)
        dropdown:SetPoint(
            "TOPLEFT",
            label,
            "BOTTOMLEFT",
            leftInset,
            -7
        )
    else
        label:Hide()
        dropdown:SetPoint(
            "LEFT",
            control,
            "LEFT",
            leftInset,
            0
        )
    end

    if options.tooltip then
        lib:SetTooltip(control, {
            title = options.tooltipTitle or options.label,
            text = options.tooltip,
        })
    end

    lib:AddTooltipTarget(control, dropdown)

    return control
end

local dropdownMethods = {}

function dropdownMethods:_InitializeMenu()
    local control = self

    self.dropdown:SetupMenu(function(_, rootDescription)
        control:_BuildMenu(rootDescription)
    end)
end

function dropdownMethods:_GetChoices()
    local choices

    if self._libModernSettingsGetChoices then
        choices = self._libModernSettingsGetChoices()
    else
        choices = self._libModernSettingsChoices
    end

    assert(type(choices) == "table", "dropdown choices must be a table")

    return choices
end

function dropdownMethods:_BuildMenu(rootDescription)
    local choices = self:_GetChoices()
    local control = self

    local function isSelected(value)
        return control:GetValue() == value
    end

    local function setSelected(value)
        control:_SelectValue(value)
    end

    for i = 1, #choices do
        local choice = choices[i]

        rootDescription:CreateRadio(
            choice.label,
            isSelected,
            setSelected,
            choice.value
        )
    end
end

function dropdownMethods:_SelectValue(value)
    self.currentValue = value

    if self._libModernSettingsOnChanged then
        self._libModernSettingsOnChanged(value)
    end
end

function dropdownMethods:SetValue(value)
    self.currentValue = value
    self.dropdown:GenerateMenu()
end

function dropdownMethods:GetValue()
    return self.currentValue
end

function dropdownMethods:SetChoices(choices)
    assert(type(choices) == "table", "choices must be a table")
    self._libModernSettingsChoices = choices
    self._libModernSettingsGetChoices = nil
    self.dropdown:GenerateMenu()
end

function dropdownMethods:SetOnChanged(onChanged)
    assert(
        onChanged == nil or type(onChanged) == "function",
        "onChanged must be a function or nil"
    )
    self._libModernSettingsOnChanged = onChanged
end

function dropdownMethods:SetControlWidth(width)
    setControlWidth(self, width)
end

function dropdownMethods:SetControlEnabled(enabled, disabledTooltip)
    self.dropdown:SetEnabled(enabled == true)

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self.label:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeDropdown(dropdown, options)
    dropdown:_InitializeMenu()
    dropdown:SetValue(options.value)
    dropdown:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
end

lib:RegisterControlType(
    "dropdown",
    createDropdown,
    dropdownMethods,
    initializeDropdown
)

function lib:CreateDropdown(parent, options)
    options = options or {}

    return self:CreateControl("dropdown", parent, options)
end
