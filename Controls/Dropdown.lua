local MAJOR, MINOR = "LibModernSettings-1.0", 3
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
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

    local control = CreateFrame("Frame", nil, parent)
    local width = options.width or 270

    control:SetSize(width, options.height or 60)
    control._libModernSettingsChoices = options.choices or {}
    control._libModernSettingsGetChoices = options.getChoices
    control._libModernSettingsOnChanged = options.onChanged

    local label = lib:CreateText(control, {
        fontObject = options.fontObject or GameFontHighlight,
        text = options.label,
        width = width,
    })
    label:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)

    local dropdown = CreateFrame(
        "DropdownButton",
        nil,
        control,
        "WowStyle1DropdownTemplate"
    )
    dropdown:SetWidth(width - 16)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -7)

    control.label = label
    control.dropdown = dropdown
    control.currentValue = options.value

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
