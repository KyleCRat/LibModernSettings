local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/SearchBox", MINOR)
then
    return
end

local ACTION_STYLE = lib._inputActionSquareStyle

local function validateOptions(options)
    assert(
        options.value == nil or type(options.value) == "string",
        "value must be a string or nil"
    )
    assert(
        options.placeholder == nil or type(options.placeholder) == "string",
        "placeholder must be a string or nil"
    )
    assert(
        options.onChanged == nil or type(options.onChanged) == "function",
        "onChanged must be a function or nil"
    )
    assert(
        options.maxLetters == nil
            or (
                type(options.maxLetters) == "number"
                and options.maxLetters >= 0
            ),
        "maxLetters must be non-negative or nil"
    )

    for _, key in ipairs({ "searchIconTexture", "clearIconTexture" }) do
        local value = options[key]
        assert(
            value == nil or type(value) == "string" or type(value) == "number",
            key .. " must be a texture path, file ID, or nil"
        )
    end

    for _, key in ipairs({ "width", "height" }) do
        local value = options[key]
        assert(
            value == nil
                or (type(value) == "number" and value > 0 and value < math.huge),
            key .. " must be positive and finite"
        )
    end
end

local function createSearchBox(parent, options)
    validateOptions(options)
    local input =
        CreateFrame("EditBox", nil, parent, "SearchBoxNineSliceTemplate")
    input:SetJustifyV("MIDDLE")
    input:SetMaxLetters(options.maxLetters or 0)
    input.instructionText = options.placeholder or SEARCH
    input.Instructions:SetText(input.instructionText)
    input.focusTexture = lib:_CreateEditBoxFocusTexture(input)
    input.focusTexture:Hide()
    input._libModernSettingsSearchText = ""
    input._libModernSettingsOnChanged = options.onChanged

    -- Native search scripts address clearButton dynamically. Replace that
    -- child so its old icon-shift/alpha scripts cannot fight LMS button states.
    input.clearButton:Hide()
    input.clearButton = lib:CreateButton(input, {
        variant = "square",
        width = ACTION_STYLE.size,
        height = ACTION_STYLE.size,
        iconSize = ACTION_STYLE.iconSize,
        iconTexture = options.clearIconTexture or lib._defaultIcons.close,
        tooltip = "Clear search",
        onClick = function()
            input:SetText("")
            input:ClearFocus()
        end,
    })
    input.clearButton.icon:SetVertexColor(
        NORMAL_FONT_COLOR.r,
        NORMAL_FONT_COLOR.g,
        NORMAL_FONT_COLOR.b
    )
    input.clearButton:SetShown(input:HasFocus() or input:GetText() ~= "")

    -- Preserve native text, placeholder and focus behavior. Dispatch hooks
    -- through retained control methods across embed upgrades.
    input:HookScript("OnTextChanged", function(self, userInput)
        self:_NotifySearchChanged(userInput)
    end)

    for _, script in ipairs({
        "OnEditFocusGained",
        "OnEditFocusLost",
        "OnEnable",
        "OnDisable",
    }) do
        input:HookScript(script, function(self)
            self:_RefreshSearchState()
        end)
    end

    if options.tooltip then
        lib:SetTooltip(input, {
            title = options.tooltipTitle,
            text = options.tooltip,
        })
    end

    return input
end

local searchMethods = {}

function searchMethods:_NotifySearchChanged(userInput)
    local value = self:GetText()
    local changed = value ~= self._libModernSettingsSearchText
    self._libModernSettingsSearchText = value

    if
        changed
        and not self._libModernSettingsSettingSearchValue
        and self._libModernSettingsOnChanged
    then
        self._libModernSettingsOnChanged(value, userInput == true)
    end
end

function searchMethods:_RefreshSearchState()
    local enabled = self:IsEnabled()
    self.clearButton:SetControlEnabled(enabled)
    self.focusTexture:SetShown(enabled and self:HasFocus())
    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
    self:SetTextColor(color.r, color.g, color.b)
end

function searchMethods:SetValue(value)
    assert(type(value) == "string", "search value must be a string")
    self._libModernSettingsSettingSearchValue = true
    self:SetText(value)
    self:SetCursorPosition(0)
    self._libModernSettingsSearchText = value
    self._libModernSettingsSettingSearchValue = nil
end

function searchMethods:GetValue()
    return self:GetText()
end

function searchMethods:SetOnChanged(callback)
    assert(
        callback == nil or type(callback) == "function",
        "onChanged must be a function or nil"
    )
    self._libModernSettingsOnChanged = callback
end

function searchMethods:FocusValue()
    self:SetFocus()
    self:HighlightText()
end

function searchMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)
    self:_RefreshSearchState()
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeSearchBox(input, options)
    input:SetValue(options.value or "")
    input:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)
end

local function refreshSearchAppearance(input, options)
    lib:_ApplyFixedControlSize(
        input,
        options.width or 270,
        options.height or 34
    )
    lib:_ApplyDefaultFont(input, options.fontObject or GameFontHighlight)
    lib:_ApplyDefaultFont(
        input.Instructions,
        options.fontObject or GameFontHighlight
    )
    input.Background:SetAtlas("common-button-tertiary-depressed-normal", false)

    input.searchIcon:SetTexture(
        options.searchIconTexture or lib._defaultIcons.search
    )
    input.searchIcon:SetTexCoord(0, 1, 0, 1)

    input.searchIcon:SetSize(16, 16)
    input.searchIcon:ClearAllPoints()
    input.searchIcon:SetPoint("LEFT", input, "LEFT", 8, 0)
    local clear = input.clearButton
    local clearOptions = clear._libModernSettingsAppearanceOptions
    clearOptions.width = ACTION_STYLE.size
    clearOptions.height = ACTION_STYLE.size
    clearOptions.iconSize = ACTION_STYLE.iconSize
    clearOptions.iconTexture = options.clearIconTexture
        or lib._defaultIcons.close
    clearOptions.iconAtlas = nil
    lib:_RefreshControlAppearance(clear)
    lib:_SetLayoutPoint(clear, "RIGHT", input, "RIGHT", -ACTION_STYLE.inset, 0)
    local rightInset = ACTION_STYLE.size + ACTION_STYLE.inset * 2
    input:SetTextInsets(30, rightInset, 0, 0)
    input.Instructions:ClearAllPoints()
    input.Instructions:SetPoint("LEFT", input, "LEFT", 30, 0)
    input.Instructions:SetPoint("RIGHT", input, "RIGHT", -rightInset, 0)
end

lib:RegisterControlType(
    "searchBox",
    createSearchBox,
    searchMethods,
    initializeSearchBox,
    refreshSearchAppearance
)
lib:RegisterControlNavigation("searchBox", {
    mode = "editBox",
    focus = function(control)
        control:FocusValue()
    end,
})

function lib:CreateSearchBox(parent, options)
    return self:CreateControl("searchBox", parent, options or {})
end
