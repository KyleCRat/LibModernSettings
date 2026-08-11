local lib = LibStub("LibModernSettings-1.0")

GameFontNormal = {}
GameFontHighlight = {}
GameFontDisable = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}
GameFontDisableSmall = {}
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }

local atlasSizes = {
    ["common-icon-plus"] = { 16, 16 },
    ["wide-icon"] = { 20, 10 },
}

local function makeRegion()
    local region = {}

    function region:SetAllPoints(owner)
        self.allPoints = owner or true
    end

    function region:SetAtlas(atlas, useAtlasSize)
        self.atlas = atlas

        if useAtlasSize and atlasSizes[atlas] then
            self.width = atlasSizes[atlas][1]
            self.height = atlasSizes[atlas][2]
        end
    end

    function region:SetSize(width, height)
        self.width = width
        self.height = height
    end

    function region:GetWidth()
        return self.width or 0
    end

    function region:GetHeight()
        return self.height or 0
    end

    function region:ClearAllPoints()
        self.point = nil
    end

    function region:SetPoint(...)
        self.point = { ... }
    end

    function region:SetDesaturated(desaturated)
        self.desaturated = desaturated
    end

    function region:SetAlpha(alpha)
        self.alpha = alpha
    end

    return region
end

local function makeFontString()
    local fontString = makeRegion()

    function fontString:SetJustifyH(justify)
        self.justifyH = justify
    end

    function fontString:SetJustifyV(justify)
        self.justifyV = justify
    end

    function fontString:SetWordWrap(wordWrap)
        self.wordWrap = wordWrap
    end

    function fontString:SetMaxLines(maxLines)
        self.maxLines = maxLines
    end

    function fontString:SetText(text)
        self.text = text
    end

    function fontString:GetStringWidth()
        return #(self.text or "") * 6
    end

    return fontString
end

local function makeFrame(frameType, parent, template)
    local frame = {
        frameType = frameType,
        parent = parent,
        template = template,
        scripts = {},
        hasFocus = false,
    }

    function frame:SetSize(width, height)
        self.width = width
        self.height = height
    end

    function frame:SetWidth(width)
        self.width = width
    end

    function frame:GetHeight()
        return self.height
    end

    function frame:CreateTexture(_, drawLayer)
        local texture = makeRegion()

        texture.drawLayer = drawLayer

        return texture
    end

    function frame:CreateFontString(_, _, _, ...)
        assert(select("#", ...) == 0)
        return makeFontString()
    end

    function frame:SetFontString(fontString)
        self.fontString = fontString
    end

    function frame:GetFontString()
        return self.fontString
    end

    function frame:SetText(text)
        self.text = text

        if self.fontString then
            self.fontString:SetText(text)
        end
    end

    function frame:GetText()
        return self.text or ""
    end

    function frame:SetNormalFontObject(fontObject)
        self.normalFontObject = fontObject
    end

    function frame:SetHighlightFontObject(fontObject)
        self.highlightFontObject = fontObject
    end

    function frame:SetDisabledFontObject(fontObject)
        self.disabledFontObject = fontObject
    end

    function frame:SetNormalTexture(texture)
        self.normalTexture = texture
    end

    function frame:GetNormalTexture()
        return self.normalTexture
    end

    function frame:SetHighlightTexture(texture)
        self.highlightTexture = texture
    end

    function frame:SetPushedTexture(texture)
        self.pushedTexture = texture
    end

    function frame:SetDisabledTexture(texture)
        self.disabledTexture = texture
    end

    function frame:SetScript(script, callback)
        self.scripts[script] = callback
    end

    function frame:SetEnabled(enabled)
        self.enabled = enabled
    end

    function frame:SetAutoFocus(autoFocus)
        self.autoFocus = autoFocus
    end

    function frame:SetFontObject(fontObject)
        self.fontObject = fontObject
    end

    function frame:SetJustifyH(justify)
        self.justifyH = justify
    end

    function frame:SetJustifyV(justify)
        self.justifyV = justify
    end

    function frame:SetMaxLetters(maxLetters)
        self.maxLetters = maxLetters
    end

    function frame:SetTextInsets(left, right, top, bottom)
        self.textInsets = { left, right, top, bottom }
    end

    function frame:SetCursorPosition(position)
        self.cursorPosition = position
    end

    function frame:HasFocus()
        return self.hasFocus
    end

    function frame:SetFocus()
        self.hasFocus = true
    end

    function frame:ClearFocus()
        local hadFocus = self.hasFocus

        self.hasFocus = false

        if hadFocus and self.scripts.OnEditFocusLost then
            self.scripts.OnEditFocusLost(self)
        end
    end

    function frame:HighlightText()
        self.highlighted = true
    end

    function frame:SetTextColor(r, g, b)
        self.textColor = { r, g, b }
    end

    return frame
end

function CreateFrame(frameType, _, parent, template)
    local frame = makeFrame(frameType, parent, template)

    return frame
end

function EditBox_HighlightText(editBox)
    editBox:HighlightText()
end

function EditBox_ClearHighlight(editBox)
    editBox.highlighted = false
end

function lib:_CreateAtlasTexture(owner, layer, atlas)
    local texture = owner:CreateTexture(nil, layer)

    texture:SetAllPoints(owner)
    texture:SetAtlas(atlas, false)

    return texture
end

function lib:SetTooltip(owner, options)
    owner.tooltip = options
end

function lib:SetControlTooltipEnabled(owner, enabled, disabledTooltip)
    owner.tooltipEnabled = enabled == true
    owner.disabledTooltip = disabledTooltip
end

lib:RegisterControlType("button", function(parent)
    local button = makeFrame("Button", parent)
    local label = makeFontString()

    button:SetSize(80, 22)
    button:SetFontString(label)
    button:SetText("Old")

    return button
end, {
    SetControlEnabled = function() end,
})

local oldButton = lib:CreateControl("button", nil, {})

dofile("Controls/Button.lua")
dofile("Controls/TextInput.lua")

oldButton:SetButtonText("Updated")
assert(oldButton.label.point[1] == "CENTER")
oldButton:FitToContents()
assert(oldButton.width == 65)

local button = lib:CreateButton(nil, {
    text = "Add Category",
    variant = "small",
    iconAtlas = "common-icon-plus",
    fitToContent = true,
})

assert(button.width == 108)
assert(button.height == 25)
assert(button.icon.atlas == "common-icon-plus")
assert(button.icon:GetWidth() == 14)
assert(button.icon:GetHeight() == 14)
assert(button.icon.drawLayer == "OVERLAY")
assert(button.icon.point[1] == "CENTER")
assert(button.icon.point[4] == -38)
assert(button.label.point[1] == "CENTER")
assert(button.label.point[4] == 9)
assert(button.label.justifyV == "MIDDLE")

button.scripts.OnEnter(button)
assert(button.normalTexture.atlas == "common-button-tertiary-hover-small")
button.scripts.OnLeave(button)
assert(button.normalTexture.atlas == "common-button-tertiary-normal-small")

button:SetButtonText("Add")
assert(button.width == 65)

local wideIconButton = lib:CreateButton(nil, {
    text = "Wide",
    variant = "small",
    iconAtlas = "wide-icon",
})

assert(wideIconButton.icon:GetWidth() == 14)
assert(wideIconButton.icon:GetHeight() == 7)

local regularIconButton = lib:CreateButton(nil, {
    text = "Add Category",
    iconAtlas = "common-icon-plus",
    fitToContent = true,
})

assert(regularIconButton.height == 34)
assert(regularIconButton.icon:GetWidth() == 16)
assert(regularIconButton.icon:GetHeight() == 16)

local explicitIconButton = lib:CreateButton(nil, {
    text = "Explicit",
    variant = "small",
    iconAtlas = "common-icon-plus",
    iconSize = 18,
})

assert(explicitIconButton.icon:GetWidth() == 18)
assert(explicitIconButton.icon:GetHeight() == 18)

local commitCount = 0
local reportedError
local textInput = lib:CreateTextInput(nil, {
    value = "Other",
    width = 300,
    onCommit = function(value)
        commitCount = commitCount + 1

        if value == "invalid" then
            return nil, "INVALID"
        end

        return string.upper(value)
    end,
    onError = function(errorCode)
        reportedError = errorCode
    end,
})

assert(textInput.template == "InputBoxScriptTemplate")
assert(textInput.width == 300)
assert(textInput.height == 34)
assert(textInput.background.atlas ==
    "common-button-tertiary-depressed-normal")
assert(textInput.background.drawLayer == "BACKGROUND")
assert(textInput.background.allPoints == textInput)
assert(textInput.textInsets[1] == 12)
assert(textInput.textInsets[2] == 12)
assert(textInput.maxLetters == 0)
assert(textInput:GetValue() == "Other")
assert(textInput:GetText() == "Other")

local customHeightInput = lib:CreateTextInput(nil, { height = 30 })

assert(customHeightInput.height == 30)

textInput:FocusValue()
textInput:SetText("custom")
textInput.scripts.OnEnterPressed(textInput)
assert(textInput:GetValue() == "CUSTOM")
assert(textInput:GetText() == "CUSTOM")
assert(textInput:HasFocus() == false)
assert(commitCount == 1)

textInput:FocusValue()
textInput:SetText("focus loss")
textInput:ClearFocus()
assert(textInput:GetValue() == "FOCUS LOSS")
assert(textInput:GetText() == "FOCUS LOSS")
assert(commitCount == 2)

textInput:FocusValue()
textInput:SetText("invalid")
textInput.scripts.OnEnterPressed(textInput)
assert(textInput:GetValue() == "FOCUS LOSS")
assert(textInput:GetText() == "FOCUS LOSS")
assert(reportedError == "INVALID")
assert(commitCount == 3)

textInput:FocusValue()
textInput:SetText("discarded")
textInput.scripts.OnEscapePressed(textInput)
assert(textInput:GetValue() == "FOCUS LOSS")
assert(textInput:GetText() == "FOCUS LOSS")
assert(commitCount == 3)

textInput:SetControlEnabled(false, "Disabled")
assert(textInput.enabled == false)
assert(textInput.tooltipEnabled == false)
assert(textInput.textColor[1] == GRAY_FONT_COLOR.r)

print("LibModernSettings control tests passed")
