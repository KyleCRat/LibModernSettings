local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Dropdown", MINOR)
then
    return
end

local DEFAULT_WIDTH = 270
local DEFAULT_INPUT_HEIGHT = 34
local INPUT_ATLAS = "common-button-tertiary-depressed-normal"
local ACTION_STYLE = lib._inputActionSquareStyle
local TEXT_INSET = 12
local DEFAULT_INSET = 0
local LEGACY_INSET = 8
local DEFAULT_MENU_HEIGHT_RATIO = 0.75
local PREVIEW_HEIGHT = 22
local SELECTION_PREVIEW_OFFSET_Y = 1
local PREVIEW_GAP = 8
local PREVIEW_ROW_HEIGHT = 24

local function stepSelection(control, context)
    return control:_StepSelection(context.direction)
end

local NAVIGATION_ACTIONS = {
    activate = function(control)
        if control.dropdown:IsMenuOpen() then
            if control._libModernSettingsMultiSelect then
                control:_ToggleFocusedChoice()
                return true
            end
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

local function onButtonStateChanged(dropdown)
    dropdown._libModernSettingsDropdownControl:_RefreshButtonState()
end

local function copySelections(value)
    assert(
        value == nil or type(value) == "table",
        "multi-select value must be a set table or nil"
    )
    local result = {}

    for key, selected in pairs(value or {}) do
        assert(
            type(key) == "string"
                or type(key) == "number"
                or type(key) == "boolean",
            "multi-select keys must be strings, numbers or booleans"
        )
        assert(
            type(selected) == "boolean",
            "multi-select values must be booleans"
        )

        if selected then result[key] = true end
    end

    return result
end

local function refreshMenuRowFocus(control, button, description)
    -- Menu rows use an attached BACKGROUND highlight rather than a Button's
    -- HIGHLIGHT texture. Preserve native mouse hover while adding keyboard focus.
    if description:GetData() == control._libModernSettingsMenuFocus then
        button.highlight:SetAlpha(1)
        button.highlight:Show()
    elseif not button:IsMouseMotionFocus() then
        button.highlight:Hide()
    end
end

local function layoutSelectionPreview(control)
    local dropdown = control.dropdown
    local preview = dropdown.selectionPreview

    if not preview then return end

    local leftInset = TEXT_INSET - ACTION_STYLE.inset
    local available = dropdown:GetWidth()
        - leftInset
        - ACTION_STYLE.size
        - ACTION_STYLE.inset * 2
    local shown = control._libModernSettingsSelectionTexture ~= nil
        and available > 0
    preview:SetShown(shown)
    preview:SetSize(math.max(1, available), PREVIEW_HEIGHT)
    -- The recessed atlas has more transparent padding below its visible border.
    lib:_SetLayoutPoint(
        preview,
        "LEFT",
        dropdown,
        "LEFT",
        leftInset,
        SELECTION_PREVIEW_OFFSET_Y
    )
    dropdown.Text:SetPoint(
        "RIGHT",
        dropdown.arrowBackground,
        "LEFT",
        -ACTION_STYLE.inset,
        0
    )

    if shown then
        dropdown.Text:SetFontObject(GameFontHighlightOutline)
    else
        dropdown.Text:SetFontObject(control._libModernSettingsSelectionFont)
    end
end

local function addTexturePreview(description, choice)
    description:AddInitializer(function(button)
        -- The native menu compositor releases attachments when rows are refreshed or pooled.
        local preview = button:AttachTexture()
        preview:SetTexture(choice.previewTexture)
        preview:SetDrawLayer("BACKGROUND", -1)
        preview:SetHeight(PREVIEW_HEIGHT)
        preview:SetPoint("LEFT", button.leftTexture1, "RIGHT", PREVIEW_GAP, 0)
        preview:SetPoint("RIGHT", button, "RIGHT", -ACTION_STYLE.inset, 0)
        preview:SetAlpha(choice.enabled == false and 0.4 or 1)

        local label = button.fontString
        label:ClearAllPoints()
        label:SetPoint("LEFT", preview, "LEFT", ACTION_STYLE.inset, 0)
        label:SetPoint("RIGHT", preview, "RIGHT", -ACTION_STYLE.inset, 0)
        label:SetFontObject(GameFontHighlightOutline)
        label:SetDrawLayer("OVERLAY")
        label:SetWordWrap(false)
        label:SetMaxLines(1)
        local width = button.leftTexture1:GetWidth()
            + PREVIEW_GAP
            + label:GetUnboundedStringWidth()
            + ACTION_STYLE.inset * 3
        return width, math.max(PREVIEW_ROW_HEIGHT, label:GetHeight())
    end)
end

local function configureDropdownButton(control)
    local dropdown = control.dropdown
    dropdown._libModernSettingsDropdownControl = control

    -- Keep the template's menu, selection text, tooltip and input behavior.
    -- The body shares text-input art; only the inset square presses down.
    dropdown.OnButtonStateChanged = onButtonStateChanged
    dropdown:SetHeight(DEFAULT_INPUT_HEIGHT)
    dropdown.Background:ClearAllPoints()
    dropdown.Background:SetAllPoints(dropdown)
    dropdown.Background:SetAtlas(INPUT_ATLAS, false)
    dropdown.focusTexture = dropdown.focusTexture
        or lib:_CreateEditBoxFocusTexture(dropdown)

    if not dropdown.arrowBackground then
        dropdown.arrowBackground = dropdown:CreateTexture(nil, "ARTWORK")
    end

    dropdown.arrowBackground:SetSize(ACTION_STYLE.size, ACTION_STYLE.size)
    lib:_SetLayoutPoint(
        dropdown.arrowBackground,
        "RIGHT",
        dropdown,
        "RIGHT",
        -ACTION_STYLE.inset,
        0
    )
    dropdown.Arrow:SetSize(ACTION_STYLE.iconSize, ACTION_STYLE.iconSize)
    dropdown.Text:ClearAllPoints()
    dropdown.Text:SetPoint("LEFT", dropdown, "LEFT", TEXT_INSET, 0)
    dropdown.Text:SetPoint(
        "RIGHT",
        dropdown.arrowBackground,
        "LEFT",
        -ACTION_STYLE.inset,
        0
    )
    dropdown.Text:SetHeight(DEFAULT_INPUT_HEIGHT)
    dropdown.Text:SetJustifyV("MIDDLE")
    dropdown.Text:SetWordWrap(false)
    dropdown.Text:SetMaxLines(1)
    dropdown.Text:SetDrawLayer("OVERLAY")
    control._libModernSettingsSelectionFont = control._libModernSettingsSelectionFont
        or dropdown.Text:GetFontObject()
end

local function configureDropdownMenu(control)
    local dropdown = control.dropdown

    if control._libModernSettingsNavigationHooked then return end

    control._libModernSettingsNavigationHooked = true
    dropdown:RegisterCallback(
        DropdownButtonMixin.Event.OnMenuOpen,
        function(_, openedDropdown)
            control:_OnMenuOpened(openedDropdown.menu)
        end,
        control
    )
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        control:_OnMenuClosed()
    end, control)

    if dropdown:IsMenuOpen() then
        control:_GenerateMenu()
        control:_OnMenuOpened(dropdown.menu)
    end
end

local function configureMenuDirection(control, direction)
    if direction == nil then return end

    local point = direction == "up" and "BOTTOMLEFT" or "TOPLEFT"
    local relativePoint = direction == "up" and "TOPLEFT" or "BOTTOMLEFT"
    control.dropdown:SetMenuAnchor(
        AnchorUtil.CreateAnchor(point, control.dropdown, relativePoint, 0, 0)
    )
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

        if not frame.ScrollBox:IsShown() then return end

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
    control.dropdown:SetWidth(math.max(1, width - leftInset - rightInset))
    layoutSelectionPreview(control)

    if control.label:IsShown() then
        return lib:_LayoutStackedLabel(
            control,
            control.label,
            control.dropdown,
            control._libModernSettingsLabelLayout
        )
    end

    lib:_SetLayoutPoint(control.dropdown, "LEFT", control, "LEFT", leftInset, 0)
    return DEFAULT_INPUT_HEIGHT
end

local function onDropdownShow(control)
    if control._libModernSettingsVisualRefreshPending then return end

    control._libModernSettingsVisualRefreshPending = true
    C_Timer.After(0, function()
        control._libModernSettingsVisualRefreshPending = nil

        if not control:IsVisible() then return end

        -- Canvas OnRefresh can run before its parent is shown and laid out.
        -- Native OnShow updates selection text, but not the arrow's state.
        control:RefreshLayout()
        control.dropdown:OnButtonStateChanged()
        control.dropdown:Update()
    end)
end

local function configureDropdownVisibility(control)
    if control._libModernSettingsVisibilityHooked then return end

    control._libModernSettingsVisibilityHooked = true
    control:HookScript("OnShow", onDropdownShow)

    if control:IsVisible() then onDropdownShow(control) end
end

local function createDropdown(parent, options)
    assert(
        options.caretIconTexture == nil
            or type(options.caretIconTexture) == "string"
            or type(options.caretIconTexture) == "number",
        "caretIconTexture must be a texture path, file ID, or nil"
    )
    assert(
        options.menuWidth == nil
            or (
                type(options.menuWidth) == "number"
                and options.menuWidth > 0
                and options.menuWidth < math.huge
            ),
        "menuWidth must be a positive finite number or nil"
    )
    assert(
        options.menuDirection == nil
            or options.menuDirection == "up"
            or options.menuDirection == "down",
        "menuDirection must be up, down, or nil"
    )
    assert(
        options.multiSelect == nil or type(options.multiSelect) == "boolean",
        "multiSelect must be a boolean or nil"
    )
    assert(
        options.selectionText == nil
            or type(options.selectionText) == "function",
        "selectionText must be a function or nil"
    )
    assert(
        options.placeholder == nil or type(options.placeholder) == "string",
        "placeholder must be a string or nil"
    )
    assert(
        options.choices == nil or type(options.choices) == "table",
        "choices must be a table or nil"
    )
    assert(
        options.getChoices == nil or type(options.getChoices) == "function",
        "getChoices must be a function or nil"
    )
    assert(
        options.onChanged == nil or type(options.onChanged) == "function",
        "onChanged must be a function or nil"
    )
    assert(
        options.height == nil
            or (type(options.height) == "number" and options.height > 0),
        "height must be a positive number or nil"
    )
    assert(
        options.leftInset == nil
            or (type(options.leftInset) == "number" and options.leftInset >= 0),
        "leftInset must be a non-negative number or nil"
    )
    assert(
        options.rightInset == nil
            or (
                type(options.rightInset) == "number"
                and options.rightInset >= 0
            ),
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
    control._libModernSettingsMenuWidth = options.menuWidth
    control._libModernSettingsOnChanged = options.onChanged
    control._libModernSettingsMultiSelect = options.multiSelect == true
    control._libModernSettingsLeftInset = leftInset
    control._libModernSettingsRightInset = rightInset
    control._libModernSettingsLabelLayout = { inputOffsetX = leftInset }

    local label = lib:CreateText(control, {
        fontObject = options.fontObject or GameFontHighlight,
        text = options.label,
        width = width,
    })

    local dropdown =
        CreateFrame("DropdownButton", nil, control, "WowStyle1DropdownTemplate")

    control.label = label
    control.dropdown = dropdown
    control.currentValue = options.multiSelect and copySelections(options.value)
        or options.value
    configureDropdownButton(control)
    configureMenuDirection(control, options.menuDirection)

    if options.placeholder then dropdown:SetDefaultText(options.placeholder) end

    if options.selectionText then
        dropdown:SetSelectionText(function()
            return options.selectionText(
                control:GetValue(),
                control:_GetChoices()
            )
        end)
    end

    if not hasLabel then label:Hide() end

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

function dropdownMethods:_RefreshButtonState()
    local dropdown = self.dropdown
    local enabled = dropdown:IsEnabled()
    local pressed = dropdown:IsDown() or dropdown:IsMenuOpen()
    local state = "normal"

    if not enabled then
        state = "disabled"
    elseif pressed then
        state = "pressed"
    elseif dropdown:IsOver() then
        state = "hover"
    end

    dropdown.focusTexture:SetShown(
        enabled
            and (
                self._libModernSettingsKeyboardFocused == true
                or dropdown:IsMenuOpen()
            )
    )
    dropdown.arrowBackground:SetAtlas(
        "common-button-tertiary-square-" .. state,
        false
    )
    local options = self._libModernSettingsAppearanceOptions
    lib:_ApplyCaretArtwork(
        dropdown.Arrow,
        options and options.caretIconTexture or lib._defaultIcons.caretDown,
        enabled
    )
    lib:_SetLayoutPoint(
        dropdown.Arrow,
        "CENTER",
        dropdown.arrowBackground,
        "CENTER",
        enabled and pressed and 1 or 0,
        enabled and pressed and 0 or 1
    )
    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
    dropdown.Text:SetTextColor(color.r, color.g, color.b)

    if dropdown.selectionPreview then
        dropdown.selectionPreview:SetAlpha(enabled and 1 or 0.4)
    end
end

function dropdownMethods:_RefreshSelectionPreview()
    local texture

    if not self._libModernSettingsMultiSelect then
        for _, choice in ipairs(self._libModernSettingsResolvedChoices or {}) do
            if
                (choice.type == nil or choice.type == "choice")
                and choice.value == self.currentValue
            then
                texture = choice.previewTexture
                break
            end
        end
    end

    self._libModernSettingsSelectionTexture = texture
    local dropdown = self.dropdown

    if texture and not dropdown.selectionPreview then
        dropdown.selectionPreview = dropdown:CreateTexture(nil, "ARTWORK")
    end

    if dropdown.selectionPreview then
        dropdown.selectionPreview:SetTexture(texture)
        dropdown.selectionPreview:SetAlpha(dropdown:IsEnabled() and 1 or 0.4)
        layoutSelectionPreview(self)
    end
end

function dropdownMethods:_OnMenuOpened(menu)
    self._libModernSettingsOpenMenu = menu
    lib:_SetNavigationFocus(self, menu)

    if self._libModernSettingsMultiSelect then
        self:_EnsureMenuFocus()
        self:_RefreshMenuFocus()
    end

    self:_ScrollSelectionIntoView()
    self:_RefreshButtonState()
end

function dropdownMethods:_OnMenuClosed()
    self._libModernSettingsOpenMenu = nil
    self._libModernSettingsMenuFocus = nil
    self:_RefreshButtonState()

    local keyboard = lib._navigationKeyboardFrame

    if keyboard and keyboard.control == self then
        -- Blizzard calls OnMenuClose before hiding/recycling the menu. Move the
        -- keyboard frame back to the input before its old parent disappears.
        self:_FocusForTab()
    end
end

function dropdownMethods:_ScrollSelectionIntoView()
    local menu = self._libModernSettingsOpenMenu

    if
        not menu
        or not menu.ScrollBox:IsShown()
        or not menu.ScrollBox:HasDataProvider()
    then
        return
    end

    local multiSelect = self._libModernSettingsMultiSelect
    local value

    if multiSelect then
        value = self._libModernSettingsMenuFocus
    else
        value = self:GetValue()
    end

    menu.ScrollBox:ScrollToElementDataByPredicate(
        function(frame)
            -- An onChanged callback can regenerate the menu, replacing descriptions.
            local description = frame:GetElementDescription()
            return (
                multiSelect and description:IsCheckbox()
                or description:IsRadio()
            ) and description:GetData() == value
        end,
        ScrollBoxConstants.AlignNearest,
        0,
        ScrollBoxConstants.NoScrollInterpolation
    )
end

function dropdownMethods:_StepSelection(direction)
    local dropdown = self.dropdown

    if
        not self:IsVisible()
        or not dropdown:IsEnabled()
        or not dropdown:IsMenuOpen()
    then
        return
    end

    if self._libModernSettingsMultiSelect then
        local choices, index = self:_EnsureMenuFocus()

        if index then
            local target = math.max(1, math.min(#choices, index + direction))
            self._libModernSettingsMenuFocus = choices[target]:GetData()
            self:_ScrollSelectionIntoView()
            self:_RefreshMenuFocus()
        end

        return true
    end

    local previous, following, selections = dropdown:CollectSelectionData()
    local description

    if #selections == 0 then
        for _, candidate in
            dropdown:GetMenuDescription():EnumerateElementDescriptions()
        do
            if candidate:IsRadio() and candidate:CanSelect() then
                description = candidate

                if direction > 0 then break end
            end
        end
    elseif direction > 0 then
        description = following
    else
        description = previous
    end

    if description then dropdown:Pick(description, MenuInputContext.None) end

    self:_ScrollSelectionIntoView()
    return true
end

function dropdownMethods:_EnsureMenuFocus()
    local choices, index, selected = {}, nil, nil

    for _, description in
        self.dropdown:GetMenuDescription():EnumerateElementDescriptions()
    do
        if description:IsCheckbox() and description:CanSelect() then
            choices[#choices + 1] = description

            if description:GetData() == self._libModernSettingsMenuFocus then
                index = #choices
            end

            if not selected and description:IsSelected() then
                selected = #choices
            end
        end
    end

    index = index or selected or (#choices > 0 and 1 or nil)
    self._libModernSettingsMenuFocus = nil

    if index then
        self._libModernSettingsMenuFocus = choices[index]:GetData()
    end

    return choices, index
end

function dropdownMethods:_RefreshMenuFocus()
    for button, description in pairs(self._libModernSettingsMenuRows or {}) do
        refreshMenuRowFocus(self, button, description)
    end
end

function dropdownMethods:_ToggleFocusedChoice()
    local choices, index = self:_EnsureMenuFocus()

    if index then
        self.dropdown:Pick(choices[index], MenuInputContext.None)
        self:_ScrollSelectionIntoView()
        self:_RefreshMenuFocus()
    end
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
    local menuWidth = self._libModernSettingsMenuWidth
    self._libModernSettingsResolvedChoices = choices

    rootDescription:SetScrollMode(getMaxMenuHeight())

    if menuWidth then
        menuWidth = math.min(menuWidth, UIParent:GetWidth())
        rootDescription:SetMinimumWidth(menuWidth)
        rootDescription:SetMaximumWidth(menuWidth)
    end

    rootDescription:AddMenuAcquiredCallback(centerScrollableMenuOnShow)

    local function isSelected(value)
        if control._libModernSettingsMultiSelect then
            return control.currentValue[value] == true
        end

        return control:GetValue() == value
    end

    local function setSelected(value, inputData)
        control:_SelectValue(value)

        if
            control._libModernSettingsMultiSelect
            or inputData.context ~= MenuInputContext.MouseButton
        then
            return MenuResponse.Refresh
        end
    end

    for i = 1, #choices do
        local choice = choices[i]

        if choice.type == "title" then
            rootDescription:CreateTitle(choice.label)
        elseif choice.type == "divider" then
            rootDescription:CreateDivider()
        else
            assert(
                choice.type == nil or choice.type == "choice",
                "unknown dropdown choice type"
            )
            assert(
                choice.previewTexture == nil
                    or type(choice.previewTexture) == "string"
                    or type(choice.previewTexture) == "number",
                "previewTexture must be a texture path, file ID, or nil"
            )
            local multiSelect = control._libModernSettingsMultiSelect
            local createChoice = multiSelect and rootDescription.CreateCheckbox
                or rootDescription.CreateRadio
            local description = createChoice(
                rootDescription,
                choice.label,
                isSelected,
                setSelected,
                choice.value
            )
            description:SetEnabled(choice.enabled ~= false)

            if choice.previewTexture then
                addTexturePreview(description, choice)
            end

            if menuWidth then
                -- With both width limits set, native layout can shrink hit targets
                -- back to the longest label. Supply the intended row extent after
                -- the compositor has measured text and optional preview artwork.
                description:SetFinalInitializer(function(button, _, menu)
                    local inset = menu:GetInset()
                    button:SetWidth(
                        math.max(1, menuWidth - inset.left - inset.right)
                    )
                end)
            end

            if multiSelect then
                assert(
                    type(choice.value) == "string"
                        or type(choice.value) == "number"
                        or type(choice.value) == "boolean",
                    "multi-select choice values must be strings, numbers or booleans"
                )
                control._libModernSettingsMenuRows = control._libModernSettingsMenuRows
                    or {}
                description:AddInitializer(function(button)
                    control._libModernSettingsMenuRows[button] = description
                    refreshMenuRowFocus(control, button, description)
                end)
                description:AddResetter(function(button)
                    control._libModernSettingsMenuRows[button] = nil
                    button.highlight:Hide()
                end)
            end

            if choice.tooltip then
                description:SetTitleAndTextTooltip(
                    choice.tooltipTitle or choice.label,
                    choice.tooltip
                )
            end

            if multiSelect then
                description:HookOnLeave(function(button)
                    refreshMenuRowFocus(control, button, description)
                end)
            end
        end
    end

    self:_RefreshSelectionPreview()
end

function dropdownMethods:_SelectValue(value)
    if self._libModernSettingsMultiSelect then
        local selections = copySelections(self.currentValue)
        local selected = not selections[value]
        selections[value] = selected or nil
        self.currentValue = selections
        self._libModernSettingsMenuFocus = value

        if self._libModernSettingsOnChanged then
            self._libModernSettingsOnChanged(
                copySelections(selections),
                value,
                selected
            )
        end

        return
    end

    self.currentValue = value
    self:_RefreshSelectionPreview()

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

    if self._libModernSettingsMultiSelect and self.dropdown:IsMenuOpen() then
        self:_EnsureMenuFocus()
        self:_RefreshMenuFocus()
    end

    if menu and menu.ScrollBox:HasDataProvider() then
        menu.ScrollBox:SetScrollPercentage(
            scrollPercentage,
            ScrollBoxConstants.NoScrollInterpolation
        )
    end
end

function dropdownMethods:SetValue(value)
    self.currentValue = self._libModernSettingsMultiSelect
            and copySelections(value)
        or value
    self:_GenerateMenu()
end

function dropdownMethods:GetValue()
    if self._libModernSettingsMultiSelect then
        return copySelections(self.currentValue)
    end

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

function dropdownMethods:GetInputAlignmentOffset()
    if self.label:IsShown() then
        return self._libModernSettingsLabelLayout.inputTop
            + self.dropdown:GetHeight() / 2
    end

    return self:GetHeight() / 2
end

function dropdownMethods:GetContentTopInset()
    if self.label:IsShown() then return 0 end

    return (self:GetHeight() - self.dropdown:GetHeight()) / 2
end

function dropdownMethods:SetControlEnabled(enabled, disabledTooltip)
    self.dropdown:SetEnabled(enabled == true)

    if not enabled then self:_ReleaseTabFocus() end

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
    dropdown:_RefreshButtonState()
    configureDropdownVisibility(dropdown)
end

local function refreshDropdownAppearance(control, options)
    control._libModernSettingsMenuWidth = options.menuWidth
    configureMenuDirection(control, options.menuDirection)
    lib:_ApplyInputWidth(control, options.width or DEFAULT_WIDTH)
    control._libModernSettingsLeftInset = options.leftInset or DEFAULT_INSET
    control._libModernSettingsRightInset = options.rightInset or DEFAULT_INSET
    control._libModernSettingsLabelLayout.inputOffsetX =
        control._libModernSettingsLeftInset
    control._libModernSettingsExplicitHeight = options.height
    lib:_ApplyDefaultFont(
        control.label,
        options.fontObject or GameFontHighlight
    )
    control:RefreshLayout()
end

-- Existing controls need their regions before prototype replacement can refresh
-- their appearance or navigation state through an older embed's callbacks.
for control, controlType in pairs(lib._controlInstances) do
    if controlType == "dropdown" then configureDropdownButton(control) end
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
            control:_RefreshButtonState()
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
            control._libModernSettingsLeftInset = control._libModernSettingsLeftInset
                or LEGACY_INSET
            control._libModernSettingsRightInset = control._libModernSettingsRightInset
                or LEGACY_INSET
            control._libModernSettingsLabelLayout = {
                inputOffsetX = control._libModernSettingsLeftInset,
            }
            control:RefreshLayout()
            lib:_WatchControlSize(control)
        end

        configureDropdownVisibility(control)
        configureDropdownMenu(control)
        control:RefreshLayout()
        control:_RefreshButtonState()
    end
end

function lib:CreateDropdown(parent, options)
    options = options or {}

    return self:CreateControl("dropdown", parent, options)
end
