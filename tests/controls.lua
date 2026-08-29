local lib = LibStub("LibModernSettings-1.0")

GameFontNormal = {}
GameFontHighlight = {}
GameFontDisable = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}
GameFontDisableSmall = {}
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
UIParent = { height = 1000 }
local mouseButtonDown = false

function UIParent:GetHeight()
    return self.height
end

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

    function region:SetWidth(width)
        self.width = width
    end

    function region:SetHeight(height)
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
        self.points = nil
    end

    function region:SetPoint(...)
        self.point = { ... }
        self.points = self.points or {}
        self.points[#self.points + 1] = self.point
    end

    function region:SetDesaturated(desaturated)
        self.desaturated = desaturated
    end

    function region:SetAlpha(alpha)
        self.alpha = alpha
    end

    function region:SetBlendMode(blendMode)
        self.blendMode = blendMode
    end

    function region:SetTextColor(r, g, b)
        self.textColor = { r, g, b }
    end

    function region:Hide()
        self.shown = false
    end

    function region:Show()
        self.shown = true
    end

    function region:IsShown()
        return self.shown ~= false
    end

    return region
end

local function makeFontString()
    local fontString = makeRegion()

    function fontString:SetFontObject(fontObject)
        self.fontObject = fontObject
    end

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

    function frame:GetWidth()
        return self.width
    end

    function frame:GetHeight()
        return self.height
    end

    function frame:ClearAllPoints()
        self.point = nil
    end

    function frame:SetPoint(...)
        self.point = { ... }
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

    function frame:RegisterEvent(event)
        self.registeredEvents = self.registeredEvents or {}
        self.registeredEvents[event] = true
    end

    function frame:UnregisterEvent(event)
        if self.registeredEvents then
            self.registeredEvents[event] = nil
        end
    end

    function frame:SetEnabled(enabled)
        self.enabled = enabled
    end

    function frame:SetupMenu(callback)
        self.menuCallback = callback
    end

    function frame:GenerateMenu()
        self.generateMenuCount = (self.generateMenuCount or 0) + 1
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
        local hadFocus = self.hasFocus

        self.hasFocus = true

        if not hadFocus and self.scripts.OnEditFocusGained then
            self.scripts.OnEditFocusGained(self)
        end
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

    if template == "MinimalSliderWithSteppersTemplate" then
        frame.Slider = makeFrame("Slider", frame)
        frame.Back = makeFrame("Button", frame)
        frame.Forward = makeFrame("Button", frame)

        function frame:Init(value)
            self.value = value
        end

        function frame:SetValue(value)
            self.value = value
        end
    end

    return frame
end

function EditBox_HighlightText(editBox)
    editBox:HighlightText()
end

function EditBox_ClearHighlight(editBox)
    editBox.highlighted = false
end

function IsMouseButtonDown()
    return mouseButtonDown
end

C_Texture = {}

function C_Texture.GetAtlasInfo()
    return { width = 51, height = 39 }
end

MinimalSliderWithSteppersMixin = {
    Event = {
        OnValueChanged = "OnValueChanged",
    },
}

EventUtil = {}

function EventUtil.CreateCallbackHandleContainer()
    return {
        RegisterCallback = function() end,
    }
end

function lib:SetTooltip(owner, options)
    owner.tooltip = options
end

function lib:SetControlTooltipEnabled(owner, enabled, disabledTooltip)
    owner.tooltipEnabled = enabled == true
    owner.disabledTooltip = disabledTooltip
end

function lib:AddTooltipTarget(owner, target)
    owner.tooltipTargets = owner.tooltipTargets or {}
    owner.tooltipTargets[#owner.tooltipTargets + 1] = target
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

lib:RegisterControlType("dropdown", function(parent)
    local control = makeFrame("Frame", parent)

    control:SetSize(270, 60)
    control.label = makeFontString()
    control.label:SetWidth(270)
    control.dropdown = makeFrame("DropdownButton", control)
    control.dropdown:SetWidth(254)
    return control
end, {
    SetControlEnabled = function() end,
})

local oldDropdown = lib:CreateControl("dropdown", nil, {})

dofile("Utilities/Atlas.lua")
dofile("Utilities/EditBoxCommit.lua")
dofile("Controls/Button.lua")
dofile("Controls/Slider.lua")
dofile("Controls/TextInput.lua")
dofile("Elements/Text.lua")
dofile("Controls/Dropdown.lua")
dofile("Layouts/Field.lua")

oldButton:SetButtonText("Updated")
assert(oldButton.label.point[1] == "CENTER")
oldButton:FitToContents()
assert(oldButton.width == 65)

oldDropdown:SetControlWidth(180)
assert(oldDropdown.width == 180)
assert(oldDropdown.label.width == 180)
assert(oldDropdown.dropdown.width == 164)

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

local squareButton = lib:CreateButton(nil, {
    variant = "square",
    iconAtlas = "common-icon-plus",
})

assert(squareButton.width == 34)
assert(squareButton.height == 34)
assert(squareButton.icon:GetWidth() == 16)
assert(squareButton.icon:GetHeight() == 16)
assert(squareButton.icon.point[1] == "CENTER")
assert(squareButton.normalTexture.atlas ==
    "common-button-tertiary-square-normal")
assert(squareButton.pushedTexture.atlas ==
    "common-button-tertiary-square-pressed")
assert(squareButton.disabledTexture.atlas ==
    "common-button-tertiary-square-disabled")
assert(squareButton.highlightTexture.atlas ==
    "common-button-tertiary-square-normal")
assert(squareButton.highlightTexture.blendMode == "ADD")
assert(squareButton.scripts.OnEnter == nil)
assert(squareButton.scripts.OnLeave == nil)

local squareWithoutIconSucceeded = pcall(function()
    lib:CreateButton(nil, { variant = "square" })
end)

assert(squareWithoutIconSucceeded == false)

local squareWithTextSucceeded = pcall(function()
    lib:CreateButton(nil, {
        variant = "square",
        iconAtlas = "common-icon-plus",
        text = "Add",
    })
end)

assert(squareWithTextSucceeded == false)

local squareResize = lib:CreateButton(nil, {
    variant = "square",
    iconAtlas = "common-icon-plus",
    width = 42,
})

assert(squareResize.width == 42)
assert(squareResize.height == 42)

local mismatchedSquareSizeSucceeded = pcall(function()
    lib:CreateButton(nil, {
        variant = "square",
        iconAtlas = "common-icon-plus",
        width = 42,
        height = 34,
    })
end)

assert(mismatchedSquareSizeSucceeded == false)

local squareTextMutationSucceeded = pcall(function()
    squareButton:SetButtonText("Add")
end)

assert(squareTextMutationSucceeded == false)

local labeledDropdown = lib:CreateDropdown(nil, {
    label = "Profile",
    choices = {},
})

assert(labeledDropdown.width == 270)
assert(labeledDropdown.height == 60)
assert(labeledDropdown.label:IsShown() == true)
assert(labeledDropdown.label.point[1] == "TOPLEFT")
assert(labeledDropdown.dropdown.width == 254)
assert(labeledDropdown.dropdown.point[1] == "TOPLEFT")

local function buildDropdownMenu(control)
    local rootDescription = {
        menuAcquiredCallbacks = {},
        radioButtons = {},
    }

    function rootDescription:SetScrollMode(maxScrollExtent)
        self.maxScrollExtent = maxScrollExtent
    end

    function rootDescription:AddMenuAcquiredCallback(callback)
        self.menuAcquiredCallbacks[#self.menuAcquiredCallbacks + 1] = callback
    end

    function rootDescription:CreateRadio(...)
        self.radioButtons[#self.radioButtons + 1] = { ... }
    end

    control.dropdown.menuCallback(control.dropdown, rootDescription)
    return rootDescription
end

local labeledMenu = buildDropdownMenu(labeledDropdown)

assert(labeledMenu.maxScrollExtent == 750)

UIParent.height = 1200
labeledMenu = buildDropdownMenu(labeledDropdown)
assert(labeledMenu.maxScrollExtent == 900)
UIParent.height = 1000

local function createMenuFrame(scrollShown)
    local menuFrame = {
        left = 125,
        scripts = {},
        ScrollBox = {},
    }

    function menuFrame.ScrollBox:IsShown()
        return scrollShown
    end

    function menuFrame:SetScript(scriptName, script)
        self.scripts[scriptName] = script
    end

    function menuFrame:GetLeft()
        return self.left
    end

    function menuFrame:ClearAllPoints()
        self.clearedPoints = true
    end

    function menuFrame:SetPoint(...)
        self.point = { ... }
    end

    return menuFrame
end

local scrollingMenuFrame = createMenuFrame(true)
local menuAcquiredCallback = labeledMenu.menuAcquiredCallbacks[1]

assert(type(menuAcquiredCallback) == "function")
menuAcquiredCallback(scrollingMenuFrame)
scrollingMenuFrame.scripts.OnShow(scrollingMenuFrame)
assert(scrollingMenuFrame.scripts.OnShow == nil)
assert(scrollingMenuFrame.clearedPoints == true)
assert(scrollingMenuFrame.point[1] == "LEFT")
assert(scrollingMenuFrame.point[2] == UIParent)
assert(scrollingMenuFrame.point[3] == "BOTTOMLEFT")
assert(scrollingMenuFrame.point[4] == 125)
assert(scrollingMenuFrame.point[5] == 500)

local shortMenuFrame = createMenuFrame(false)

menuAcquiredCallback(shortMenuFrame)
shortMenuFrame.scripts.OnShow(shortMenuFrame)
assert(shortMenuFrame.scripts.OnShow == nil)
assert(shortMenuFrame.clearedPoints == nil)
assert(shortMenuFrame.point == nil)

local inlineDropdown = lib:CreateDropdown(nil, {
    label = "Field",
    showLabel = false,
    choices = {},
})

assert(inlineDropdown.width == 270)
assert(inlineDropdown.height == 34)
assert(inlineDropdown.label:IsShown() == false)
assert(inlineDropdown.dropdown.width == 254)
assert(inlineDropdown.dropdown.point[1] == "LEFT")
assert(inlineDropdown.dropdown.point[2] == inlineDropdown)
assert(inlineDropdown.dropdown.point[3] == "LEFT")
assert(inlineDropdown.dropdown.point[4] == 8)
assert(inlineDropdown.dropdown.point[5] == 0)

inlineDropdown:SetControlWidth(180)
assert(inlineDropdown.width == 180)
assert(inlineDropdown.label.width == 180)
assert(inlineDropdown.dropdown.width == 164)

local flushDropdown = lib:CreateDropdown(nil, {
    label = "Operator",
    showLabel = false,
    leftInset = 0,
    rightInset = 0,
    width = 180,
    choices = {},
})

assert(flushDropdown.width == 180)
assert(flushDropdown.dropdown.width == 180)
assert(flushDropdown.dropdown.point[4] == 0)

flushDropdown:SetControlWidth(220)
assert(flushDropdown.width == 220)
assert(flushDropdown.label.width == 220)
assert(flushDropdown.dropdown.width == 220)

local asymmetricDropdown = lib:CreateDropdown(nil, {
    label = "Value",
    showLabel = false,
    leftInset = 3,
    rightInset = 7,
    width = 180,
    choices = {},
})

assert(asymmetricDropdown.dropdown.width == 170)
assert(asymmetricDropdown.dropdown.point[4] == 3)

asymmetricDropdown:SetControlWidth(220)
assert(asymmetricDropdown.dropdown.width == 210)

local invalidLeftInsetSucceeded = pcall(function()
    lib:CreateDropdown(nil, {
        leftInset = -1,
        choices = {},
    })
end)

assert(invalidLeftInsetSucceeded == false)

local invalidRightInsetSucceeded = pcall(function()
    lib:CreateDropdown(nil, {
        rightInset = -1,
        choices = {},
    })
end)

assert(invalidRightInsetSucceeded == false)

local invalidDropdownWidthSucceeded = pcall(function()
    inlineDropdown:SetControlWidth(0)
end)

assert(invalidDropdownWidthSucceeded == false)

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
assert(textInput.focusTexture.atlas ==
    "common-button-tertiary-depressed-normal-glow")
assert(textInput.focusTexture.drawLayer == "BORDER")
assert(textInput.focusTexture.allPoints == nil)
assert(textInput.focusTexture.points[1][1] == "TOPLEFT")
assert(textInput.focusTexture.points[1][2] == textInput)
assert(textInput.focusTexture.points[1][3] == "TOPLEFT")
assert(textInput.focusTexture.points[1][4] == -2)
assert(textInput.focusTexture.points[1][5] == 3)
assert(textInput.focusTexture.points[2][1] == "BOTTOMRIGHT")
assert(textInput.focusTexture.points[2][2] == textInput)
assert(textInput.focusTexture.points[2][3] == "BOTTOMRIGHT")
assert(textInput.focusTexture.points[2][4] == 2)
assert(textInput.focusTexture.points[2][5] == -1)
assert(textInput.focusTexture:IsShown() == false)
assert(textInput.textInsets[1] == 12)
assert(textInput.textInsets[2] == 12)
assert(textInput.maxLetters == 0)
assert(textInput:GetValue() == "Other")
assert(textInput:GetText() == "Other")

local customHeightInput = lib:CreateTextInput(nil, { height = 30 })

assert(customHeightInput.height == 30)

local sliderControl = lib:CreateSlider(nil, {
    label = "Scale",
    minValue = 0,
    maxValue = 2,
    step = 0.1,
    value = 1,
})

assert(sliderControl.valueBox.focusTexture.atlas ==
    "common-button-tertiary-depressed-normal-glow")
assert(sliderControl.valueBox.focusTexture:IsShown() == false)
sliderControl.valueBox:SetFocus()
assert(sliderControl.valueBox.focusTexture:IsShown() == true)
sliderControl.valueBox:ClearFocus()
assert(sliderControl.valueBox.focusTexture:IsShown() == false)

textInput:FocusValue()
assert(textInput.focusTexture:IsShown() == true)
textInput:SetText("custom")
textInput.scripts.OnEnterPressed(textInput)
assert(textInput:GetValue() == "CUSTOM")
assert(textInput:GetText() == "CUSTOM")
assert(textInput:HasFocus() == false)
assert(textInput.focusTexture:IsShown() == false)
assert(commitCount == 1)

textInput:FocusValue()
textInput:SetText("focus loss")
textInput:ClearFocus()
assert(textInput:GetValue() == "FOCUS LOSS")
assert(textInput:GetText() == "FOCUS LOSS")
assert(commitCount == 2)

local clickedValue
local focusCommitButton = lib:CreateButton(nil, {
    text = "Apply",
    onClick = function()
        clickedValue = textInput:GetValue()
    end,
})

textInput:FocusValue()
textInput:SetText("button click")
mouseButtonDown = true
textInput:ClearFocus()
assert(textInput:GetValue() == "FOCUS LOSS")
assert(commitCount == 2)
mouseButtonDown = false
focusCommitButton.scripts.OnClick(focusCommitButton, "LeftButton")
assert(textInput:GetValue() == "BUTTON CLICK")
assert(clickedValue == "BUTTON CLICK")
assert(commitCount == 3)

textInput:FocusValue()
textInput:SetText("global mouse up")
mouseButtonDown = true
textInput:ClearFocus()
assert(textInput:GetValue() == "BUTTON CLICK")
mouseButtonDown = false
local commitFrame = lib._editBoxCommitFrame

commitFrame.scripts.OnEvent(
    commitFrame,
    "GLOBAL_MOUSE_UP",
    "LeftButton"
)
assert(textInput:GetValue() == "BUTTON CLICK")
commitFrame.scripts.OnUpdate(commitFrame, 0)
assert(textInput:GetValue() == "GLOBAL MOUSE UP")
assert(commitCount == 4)

local transferredValue
local focusTransferSource = lib:CreateTextInput(nil, {
    value = "Source",
    onCommit = function(value)
        transferredValue = value
        return value
    end,
})
local focusTransferTarget = lib:CreateTextInput(nil, {
    value = "Target",
})

focusTransferSource:FocusValue()
focusTransferSource:SetText("Transferred")
mouseButtonDown = true
focusTransferSource:ClearFocus()
focusTransferTarget:FocusValue()
mouseButtonDown = false
commitFrame.scripts.OnEvent(commitFrame, "GLOBAL_MOUSE_UP", "LeftButton")
commitFrame.scripts.OnUpdate(commitFrame, 0)
assert(transferredValue == "Transferred")
assert(focusTransferTarget:HasFocus() == true)
focusTransferTarget:CancelAndClearFocus()

textInput:FocusValue()
textInput:SetText("invalid")
textInput.scripts.OnEnterPressed(textInput)
assert(textInput:GetValue() == "GLOBAL MOUSE UP")
assert(textInput:GetText() == "GLOBAL MOUSE UP")
assert(reportedError == "INVALID")
assert(commitCount == 5)

textInput:FocusValue()
textInput:SetText("discarded")
textInput.scripts.OnEscapePressed(textInput)
assert(textInput:GetValue() == "GLOBAL MOUSE UP")
assert(textInput:GetText() == "GLOBAL MOUSE UP")
assert(commitCount == 5)

textInput:SetControlEnabled(false, "Disabled")
assert(textInput.enabled == false)
assert(textInput.focusTexture:IsShown() == false)
assert(textInput.tooltipEnabled == false)
assert(textInput.textColor[1] == GRAY_FONT_COLOR.r)

local stackedControlOptions = {
    value = "Stacked",
    width = 120,
}
local stackedField = lib:CreateField(nil, {
    label = "Name",
    controlType = "textInput",
    controlOptions = stackedControlOptions,
})
local stackedInput = stackedField:GetControl()

assert(stackedField.width == 270)
assert(stackedField.height == 60)
assert(stackedField.label.width == 270)
assert(stackedField.label.height == 18)
assert(stackedField.label.point[1] == "TOPLEFT")
assert(stackedField.label.point[2] == stackedField)
assert(stackedField.label.point[3] == "TOPLEFT")
assert(stackedInput.width == 270)
assert(stackedInput.point[1] == "TOPLEFT")
assert(stackedInput.point[2] == stackedField)
assert(stackedInput.point[3] == "TOPLEFT")
assert(stackedInput.point[4] == 0)
assert(stackedInput.point[5] == -26)
assert(stackedInput:GetValue() == "Stacked")
assert(stackedControlOptions.width == 120)

local inlineField = lib:CreateField(nil, {
    label = "Name",
    labelPosition = "left",
    labelWidth = 48,
    gap = 8,
    width = 300,
    controlType = "textInput",
    controlOptions = {
        value = "Inline",
        tooltip = "Rename this category.",
    },
})
local inlineInput = inlineField:GetControl()

assert(inlineField.width == 300)
assert(inlineField.height == 34)
assert(inlineField.label.width == 48)
assert(inlineField.label.height == 34)
assert(inlineField.label.justifyV == "MIDDLE")
assert(inlineField.label.point[1] == "LEFT")
assert(inlineField.label.point[2] == inlineField)
assert(inlineField.label.point[3] == "LEFT")
assert(inlineInput.width == 244)
assert(inlineInput.point[1] == "LEFT")
assert(inlineInput.point[2] == inlineField)
assert(inlineInput.point[3] == "LEFT")
assert(inlineInput.point[4] == 56)
assert(inlineInput.point[5] == 0)
assert(inlineInput:GetValue() == "Inline")
assert(inlineField.tooltip.text == "Rename this category.")
assert(inlineInput.tooltip.text == "Rename this category.")

inlineField:SetControlEnabled(false, "Disabled")
assert(inlineInput.enabled == false)
assert(inlineField.tooltipEnabled == false)
assert(inlineInput.tooltipEnabled == false)
assert(inlineField.label.textColor[1] == GRAY_FONT_COLOR.r)

local invalidFieldPositionSucceeded = pcall(function()
    lib:CreateField(nil, {
        label = "Name",
        labelPosition = "right",
        controlType = "textInput",
    })
end)

assert(invalidFieldPositionSucceeded == false)

local invalidFieldWidthSucceeded = pcall(function()
    lib:CreateField(nil, {
        label = "Name",
        labelPosition = "left",
        labelWidth = 270,
        width = 270,
        controlType = "textInput",
    })
end)

assert(invalidFieldWidthSucceeded == false)

local nestedFieldSucceeded = pcall(function()
    lib:CreateField(nil, {
        label = "Outer",
        controlType = "field",
    })
end)

assert(nestedFieldSucceeded == false)

print("LibModernSettings control tests passed")
