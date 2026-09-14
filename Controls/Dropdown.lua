local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 270
local DEFAULT_INSET = 0
local LEGACY_INSET = 8
local DEFAULT_MENU_HEIGHT_RATIO = 0.75

local function getMaxMenuHeight()
    return math.max(
        1,
        math.floor(UIParent:GetHeight() * DEFAULT_MENU_HEIGHT_RATIO)
    )
end

local function centerScrollableMenuOnShow(menuFrame)
    menuFrame:SetScript("OnShow", function(frame)
        frame:SetScript("OnShow", nil)

        if not frame.ScrollBox:IsShown() then
            return
        end

        local left = frame:GetLeft()

        frame:ClearAllPoints()
        frame:SetPoint(
            "LEFT",
            UIParent,
            "BOTTOMLEFT",
            left,
            UIParent:GetHeight() / 2
        )
    end)
end

local function layoutDropdown(control)
    local width = control:GetWidth()
    local leftInset = control._libModernSettingsLeftInset
    local rightInset = control._libModernSettingsRightInset
    control.label:SetWidth(width)
    control.dropdown:SetWidth(math.max(
        1,
        width - leftInset - rightInset
    ))

    if control.label:IsShown() then
        return lib:_LayoutStackedLabel(
            control, control.label, control.dropdown,
            control._libModernSettingsLabelLayout
        )
    end

    control.dropdown:ClearAllPoints()
    control.dropdown:SetPoint("LEFT", control, "LEFT", leftInset, 0)
    return control.dropdown:GetHeight()
end

local function onDropdownShow(control)
    if control._libModernSettingsVisualRefreshPending then
        return
    end

    control._libModernSettingsVisualRefreshPending = true
    C_Timer.After(0, function()
        control._libModernSettingsVisualRefreshPending = nil
        if not control:IsVisible() then
            return
        end

        -- Canvas OnRefresh can run before its parent is shown and laid out.
        -- Native OnShow updates selection text, but not the arrow's state.
        control:RefreshLayout()
        control.dropdown:OnButtonStateChanged()
        control.dropdown:Update()
    end)
end

local function configureDropdownVisibility(control)
    if control._libModernSettingsVisibilityHooked then
        return
    end

    control._libModernSettingsVisibilityHooked = true
    control:HookScript("OnShow", onDropdownShow)
    if control:IsVisible() then
        onDropdownShow(control)
    end
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
        options.height == nil or (type(options.height) == "number" and options.height > 0),
        "height must be a positive number or nil"
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
    local hasLabel = type(options.label) == "string" and options.label ~= ""
    local leftInset = options.leftInset or DEFAULT_INSET
    local rightInset = options.rightInset or DEFAULT_INSET

    control:SetWidth(width)
    control._libModernSettingsExplicitHeight = options.height
    control._libModernSettingsChoices = options.choices or {}
    control._libModernSettingsGetChoices = options.getChoices
    control._libModernSettingsOnChanged = options.onChanged
    control._libModernSettingsLeftInset = leftInset
    control._libModernSettingsRightInset = rightInset
    control._libModernSettingsLabelLayout = { inputOffsetX = leftInset }

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

    if not hasLabel then
        label:Hide()
    end
    lib:_RefreshControlLayout(control, layoutDropdown)
    lib:_WatchControlSize(control)

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

    rootDescription:SetScrollMode(getMaxMenuHeight())
    rootDescription:AddMenuAcquiredCallback(centerScrollableMenuOnShow)

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

dropdownMethods.SetControlWidth = lib._SetControlWidth
dropdownMethods.SetControlHeight = lib._SetControlHeight

function dropdownMethods:RefreshLayout()
    lib:_RefreshControlLayout(self, layoutDropdown)
end

function dropdownMethods:GetContentTopInset()
    if self.label:IsShown() then
        return 0
    end

    return (self:GetHeight() - self.dropdown:GetHeight()) / 2
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
    configureDropdownVisibility(dropdown)
end

lib:RegisterControlType(
    "dropdown",
    createDropdown,
    dropdownMethods,
    initializeDropdown
)

-- Preserve the reserved space of controls already laid out by an older embed.
for control, controlType in pairs(lib._controlInstances) do
    if controlType == "dropdown" then
        if not control._libModernSettingsLabelLayout then
            control._libModernSettingsExplicitHeight = control:GetHeight()
            control._libModernSettingsLeftInset = control._libModernSettingsLeftInset or LEGACY_INSET
            control._libModernSettingsRightInset = control._libModernSettingsRightInset or LEGACY_INSET
            control._libModernSettingsLabelLayout = {
                inputOffsetX = control._libModernSettingsLeftInset,
            }
            control:RefreshLayout()
            lib:_WatchControlSize(control)
        end
        configureDropdownVisibility(control)
    end
end

function lib:CreateDropdown(parent, options)
    options = options or {}

    return self:CreateControl("dropdown", parent, options)
end
