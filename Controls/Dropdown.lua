local MAJOR, MINOR = "LibModernSettings-1.0", 9
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Dropdown", MINOR) then
    return
end

local DEFAULT_WIDTH = 270
-- The native 25px button's border/shadow extends beyond its hitbox. Give it
-- a regular control footprint without stretching Blizzard's child textures.
local DEFAULT_INPUT_HEIGHT = 34
local DEFAULT_INSET = 0
local LEGACY_INSET = 8
local DEFAULT_MENU_HEIGHT_RATIO = 0.75

local function stepSelection(control, context)
    return control:_StepSelection(context.direction)
end

local NAVIGATION_ACTIONS = {
    activate = function(control)
        if control.dropdown:IsMenuOpen() then
            -- Arrow navigation already applied the current selection.
            control.dropdown:CloseMenu()
        else
            control.dropdown:OpenMenu()
        end
        return true
    end,
    dismiss = function(control)
        if control.dropdown:IsMenuOpen() then
            control.dropdown:CloseMenu()
        else
            lib:_ClearNavigationFocus(control)
        end
        return true
    end,
    previous = stepSelection,
    next = stepSelection,
}

local function configureDropdownMenu(control)
    local dropdown = control.dropdown
    if control._libModernSettingsNavigationHooked then
        return
    end
    control._libModernSettingsNavigationHooked = true
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function(_, openedDropdown)
        control:_OnMenuOpened(openedDropdown.menu)
    end, control)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        control:_OnMenuClosed()
    end, control)
    if dropdown:IsMenuOpen() then
        control:_GenerateMenu()
        control:_OnMenuOpened(dropdown.menu)
    end
end

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
    local nativeHeight = control.dropdown:GetHeight()
    local inputHeight = math.max(DEFAULT_INPUT_HEIGHT, nativeHeight)
    local bottomInset = (inputHeight - nativeHeight) / 2
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
        ) + bottomInset
    end

    control.dropdown:ClearAllPoints()
    control.dropdown:SetPoint("LEFT", control, "LEFT", leftInset, 0)
    return inputHeight
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

function dropdownMethods:_OnMenuOpened(menu)
    self._libModernSettingsOpenMenu = menu
    lib:_SetNavigationFocus(self, menu)
    self:_ScrollSelectionIntoView()
end

function dropdownMethods:_OnMenuClosed()
    self._libModernSettingsOpenMenu = nil

    local keyboard = lib._navigationKeyboardFrame
    if keyboard and keyboard.control == self then
        -- Blizzard calls OnMenuClose before hiding/recycling the menu. Move the
        -- keyboard frame back to the input before its old parent disappears.
        self:_FocusForTab()
    end
end

function dropdownMethods:_ScrollSelectionIntoView()
    local menu = self._libModernSettingsOpenMenu
    if not menu or not menu.ScrollBox:IsShown() or not menu.ScrollBox:HasDataProvider() then
        return
    end

    local value = self:GetValue()
    menu.ScrollBox:ScrollToElementDataByPredicate(function(frame)
        -- An onChanged callback can regenerate the menu, replacing descriptions.
        return frame:GetElementDescription():GetData() == value
    end, ScrollBoxConstants.AlignNearest, 0, ScrollBoxConstants.NoScrollInterpolation)
end

function dropdownMethods:_StepSelection(direction)
    local dropdown = self.dropdown
    if not self:IsVisible() or not dropdown:IsEnabled() or not dropdown:IsMenuOpen() then
        return
    end

    local previous, following, selections = dropdown:CollectSelectionData()
    local description
    if #selections == 0 then
        for _, candidate in dropdown:GetMenuDescription():EnumerateElementDescriptions() do
            if candidate:IsRadio() and candidate:CanSelect() then
                description = candidate
                if direction > 0 then
                    break
                end
            end
        end
    elseif direction > 0 then
        description = following
    else
        description = previous
    end

    if description then
        dropdown:Pick(description, MenuInputContext.None)
    end
    self:_ScrollSelectionIntoView()
    return true
end

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

    local function setSelected(value, inputData)
        control:_SelectValue(value)
        if inputData.context ~= MenuInputContext.MouseButton then
            return MenuResponse.Refresh
        end
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

function dropdownMethods:_GenerateMenu()
    local menu = self.dropdown.menu
    local scrollPercentage
    if menu then
        -- Blizzard reanchors/recycles menu rows during generation but retains
        -- the ScrollBox provider. Release its old row references first.
        scrollPercentage = menu.ScrollBox:GetScrollPercentage()
        menu.ScrollBox:RemoveDataProvider()
    end

    self.dropdown:GenerateMenu()

    if menu and menu.ScrollBox:HasDataProvider() then
        menu.ScrollBox:SetScrollPercentage(scrollPercentage, ScrollBoxConstants.NoScrollInterpolation)
    end
end

function dropdownMethods:SetValue(value)
    self.currentValue = value
    self:_GenerateMenu()
end

function dropdownMethods:GetValue()
    return self.currentValue
end

function dropdownMethods:SetChoices(choices)
    assert(type(choices) == "table", "choices must be a table")
    self._libModernSettingsChoices = choices
    self._libModernSettingsGetChoices = nil
    self:_GenerateMenu()
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
    if not enabled then
        self:_ReleaseTabFocus()
    end

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self.label:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeDropdown(dropdown, options)
    dropdown:_InitializeMenu()
    configureDropdownMenu(dropdown)
    dropdown:SetValue(options.value)
    dropdown:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
    configureDropdownVisibility(dropdown)
end

local function refreshDropdownAppearance(control, options)
    lib:_ApplyInputWidth(control, options.width or DEFAULT_WIDTH)
    control._libModernSettingsLeftInset = options.leftInset or DEFAULT_INSET
    control._libModernSettingsRightInset = options.rightInset or DEFAULT_INSET
    control._libModernSettingsLabelLayout.inputOffsetX = control._libModernSettingsLeftInset
    control._libModernSettingsExplicitHeight = options.height
    lib:_ApplyDefaultFont(control.label, options.fontObject or GameFontHighlight)
    control:RefreshLayout()
end

lib:RegisterControlType(
    "dropdown",
    createDropdown,
    dropdownMethods,
    initializeDropdown,
    refreshDropdownAppearance
)

lib:RegisterControlNavigation("dropdown", {
    input = function(control)
        return control.dropdown
    end,
    actions = NAVIGATION_ACTIONS,
    release = function(control)
        control.dropdown:CloseMenu()
    end,
    hover = function(control, highlighted)
        -- DropdownButton uses ButtonStateBehaviorMixin, not Button highlight textures.
        if highlighted == (control.dropdown:IsOver() == true) then
            return
        end
        if highlighted then
            control.dropdown:OnEnter()
        else
            control.dropdown:OnLeave()
        end
    end,
})

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
        configureDropdownMenu(control)
    end
end

function lib:CreateDropdown(parent, options)
    options = options or {}

    return self:CreateControl("dropdown", parent, options)
end
