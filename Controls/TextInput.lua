local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 270
local DEFAULT_HEIGHT = 34
local DEFAULT_TEXT_INSET = 12
local INPUT_ATLAS = "common-button-tertiary-depressed-normal"

local function validateOptions(options)
    assert(
        options.value == nil or type(options.value) == "string",
        "value must be a string or nil"
    )
    assert(
        options.onCommit == nil or type(options.onCommit) == "function",
        "onCommit must be a function or nil"
    )
    assert(
        options.onError == nil or type(options.onError) == "function",
        "onError must be a function or nil"
    )
    assert(
        options.maxLetters == nil
            or (type(options.maxLetters) == "number"
                and options.maxLetters >= 0),
        "maxLetters must be a non-negative number or nil"
    )
    assert(
        options.height == nil
            or (type(options.height) == "number" and options.height > 0),
        "height must be a positive number or nil"
    )
end

local function restoreCommittedValue(editBox)
    editBox:SetText(editBox._libModernSettingsCommittedValue)
    editBox:SetCursorPosition(0)
end

local function finalizeTextInput(editBox)
    return editBox:Commit()
end

local function configureTextInput(editBox)
    editBox.focusTexture = editBox.focusTexture
        or lib:_CreateEditBoxFocusTexture(editBox)

    editBox:SetScript("OnEnterPressed", function(self)
        self:CommitAndClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:CancelAndClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        lib:_CancelPendingEditBoxCommit(self)
        self.focusTexture:Show()
        EditBox_HighlightText(self)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self.focusTexture:Hide()
        EditBox_ClearHighlight(self)

        if not self._libModernSettingsSuppressCommit then
            lib:_FinalizeEditBoxOnFocusLost(self, finalizeTextInput)
        end
    end)

    if editBox:HasFocus() then
        editBox.focusTexture:Show()
    else
        editBox.focusTexture:Hide()
    end
end

local function createTextInput(parent, options)
    validateOptions(options)

    local editBox = CreateFrame(
        "EditBox",
        nil,
        parent,
        "InputBoxScriptTemplate"
    )
    local textInset = options.textInset or DEFAULT_TEXT_INSET

    editBox:SetSize(
        options.width or DEFAULT_WIDTH,
        options.height or DEFAULT_HEIGHT
    )
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(options.fontObject or GameFontHighlight)
    editBox:SetJustifyH(options.justifyH or "LEFT")
    editBox:SetJustifyV("MIDDLE")
    editBox:SetMaxLetters(options.maxLetters or 0)
    editBox:SetTextInsets(textInset, textInset, 0, 0)
    editBox._libModernSettingsCommittedValue = ""
    editBox._libModernSettingsOnCommit = options.onCommit
    editBox._libModernSettingsOnError = options.onError
    editBox.background = lib:_CreateAtlasTexture(
        editBox,
        "BACKGROUND",
        INPUT_ATLAS
    )
    configureTextInput(editBox)

    if options.tooltip then
        lib:SetTooltip(editBox, {
            title = options.tooltipTitle,
            text = options.tooltip,
        })
    end

    return editBox
end

local textInputMethods = {}

function textInputMethods:Commit()
    lib:_CancelPendingEditBoxCommit(self)

    local text = self:GetText()
    local value = text
    local errorCode

    if self._libModernSettingsOnCommit then
        value, errorCode = self._libModernSettingsOnCommit(text)
    end

    if value == nil or value == false then
        restoreCommittedValue(self)

        if self._libModernSettingsOnError then
            self._libModernSettingsOnError(errorCode)
        end

        return false, errorCode
    end

    assert(
        type(value) == "string",
        "onCommit must return a string, false, or nil"
    )

    self._libModernSettingsCommittedValue = value
    restoreCommittedValue(self)

    return true, value
end

function textInputMethods:CommitAndClearFocus()
    local pending, committed, value =
        lib:_FlushPendingEditBoxCommit(self)

    if pending then
        return committed ~= false, value
    end

    if not self:HasFocus() then
        return true, self._libModernSettingsCommittedValue
    end

    local committed, value = self:Commit()

    self._libModernSettingsSuppressCommit = true
    self:ClearFocus()
    self._libModernSettingsSuppressCommit = nil

    return committed, value
end

function textInputMethods:CancelAndClearFocus()
    lib:_CancelPendingEditBoxCommit(self)
    restoreCommittedValue(self)
    self._libModernSettingsSuppressCommit = true
    self:ClearFocus()
    self._libModernSettingsSuppressCommit = nil
end

function textInputMethods:SetValue(value)
    assert(type(value) == "string", "text input value must be a string")
    lib:_CancelPendingEditBoxCommit(self)
    self._libModernSettingsCommittedValue = value
    restoreCommittedValue(self)
end

function textInputMethods:GetValue()
    return self._libModernSettingsCommittedValue
end

function textInputMethods:FocusValue()
    lib:_CancelPendingEditBoxCommit(self)
    self:SetFocus()
    self:HighlightText()
end

function textInputMethods:SetOnCommit(onCommit)
    assert(
        onCommit == nil or type(onCommit) == "function",
        "onCommit must be a function or nil"
    )
    self._libModernSettingsOnCommit = onCommit
end

function textInputMethods:SetOnError(onError)
    assert(
        onError == nil or type(onError) == "function",
        "onError must be a function or nil"
    )
    self._libModernSettingsOnError = onError
end

function textInputMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)

    if enabled and self:HasFocus() then
        self.focusTexture:Show()
    else
        self.focusTexture:Hide()
    end

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeTextInput(editBox, options)
    editBox:SetValue(options.value or "")
    editBox:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
end

lib:RegisterControlType(
    "textInput",
    createTextInput,
    textInputMethods,
    initializeTextInput
)

-- Compatible upgrades preserve controls but not construction-owned regions.
for control, controlType in pairs(lib._controlInstances) do
    if controlType == "textInput" then
        configureTextInput(control)
    end
end

function lib:CreateTextInput(parent, options)
    options = options or {}

    return self:CreateControl("textInput", parent, options)
end
