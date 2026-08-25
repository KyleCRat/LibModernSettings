local MAJOR, MINOR = "LibModernSettings-1.0", 3
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

    editBox:SetScript("OnEnterPressed", function(self)
        self:CommitAndClearFocus()
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:CancelAndClearFocus()
    end)
    editBox:SetScript("OnEditFocusGained", EditBox_HighlightText)
    editBox:SetScript("OnEditFocusLost", function(self)
        EditBox_ClearHighlight(self)

        if not self._libModernSettingsSuppressCommit then
            self:Commit()
        end
    end)

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
    restoreCommittedValue(self)
    self._libModernSettingsSuppressCommit = true
    self:ClearFocus()
    self._libModernSettingsSuppressCommit = nil
end

function textInputMethods:SetValue(value)
    assert(type(value) == "string", "text input value must be a string")
    self._libModernSettingsCommittedValue = value
    restoreCommittedValue(self)
end

function textInputMethods:GetValue()
    return self._libModernSettingsCommittedValue
end

function textInputMethods:FocusValue()
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

function lib:CreateTextInput(parent, options)
    options = options or {}

    return self:CreateControl("textInput", parent, options)
end
