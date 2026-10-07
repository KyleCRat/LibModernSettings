local lib = LibStub("LibModernSettings-1.0")

GameFontNormal = {}
GameFontHighlight = {}
GameFontDisable = {}
GameFontNormalSmall = {}
GameFontHighlightSmall = {}
GameFontDisableSmall = {}
GameFontNormalLarge = {}
GameFontNormalHuge = {}
GameFontHighlightLarge = {}
GameFontDisableLarge = {}
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
GRAY_FONT_COLOR = { r = 0.5, g = 0.5, b = 0.5 }
UIParent = { height = 1000 }
local mouseButtonDown = false
local deferredCallbacks = {}

function ApproximatelyEqual(first, second, epsilon)
    return math.abs(first - second) < epsilon
end

C_Timer = {
    After = function(delay, callback)
        assert(delay == 0)
        deferredCallbacks[#deferredCallbacks + 1] = callback
    end,
}

local function runDeferredCallbacks()
    local callbacks = deferredCallbacks
    deferredCallbacks = {}
    for _, callback in ipairs(callbacks) do
        callback()
    end
end

function UIParent:GetHeight()
    return self.height
end

local atlasSizes = {
    ["common-icon-plus"] = { 16, 16 },
    ["header-icon"] = { 40, 40 },
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

    function region:SetScale(scale) self.scale = scale end
    function region:SetVertexColor(...) self.vertexColor = { ... } end

    function region:SetBlendMode(blendMode)
        self.blendMode = blendMode
    end

    function region:SetRotation(rotation)
        self.rotation = rotation
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

    function fontString:HasScript()
        return false
    end

    function fontString:HookScript(script)
        error("FontString:HookScript(): unsupported script " .. script)
    end

    function fontString:GetHeight()
        return self.height or self:GetStringHeight()
    end

    function fontString:GetStringHeight()
        if self.stringHeight then return self.stringHeight end
        local height = (self.fontObject and self.fontObject.height) or 12
        if self.wordWrap and self.nonSpaceWrap and self.width and self.width > 0 then
            -- A simple unbroken-text wrap is sufficient for description layout tests.
            return height * math.max(1, math.ceil(self:GetStringWidth() / self.width))
        end
        return height
    end

    function fontString:SetFontObject(fontObject)
        self.fontObject = fontObject
    end

    function fontString:GetFontObject()
        return self.fontObject
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

    function fontString:SetNonSpaceWrap(nonSpaceWrap)
        self.nonSpaceWrap = nonSpaceWrap
    end

    function fontString:SetMaxLines(maxLines)
        self.maxLines = maxLines
    end

    function fontString:SetText(text)
        assert(not self.requiresFont or self.fontObject, "FontString:SetText(): Font not set")
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
        local changed = width ~= self.width or height ~= self.height
        self.width = width
        self.height = height
        if changed and self.scripts.OnSizeChanged then
            self.scripts.OnSizeChanged(self, width, height)
        end
    end

    function frame:SetWidth(width)
        self:SetSize(width, self.height)
    end

    function frame:SetHeight(height)
        self:SetSize(self.width, height)
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

    function frame:GetPoint()
        return unpack(self.point or {})
    end

    function frame:SetParent(parentFrame)
        self.parent = parentFrame
    end

    function frame:IsVisible()
        return self.visible ~= false
            and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible())
    end

    function frame:CreateTexture(_, drawLayer)
        local texture = makeRegion()

        texture.drawLayer = drawLayer

        return texture
    end

    function frame:CreateFontString(_, _, fontObject, ...)
        assert(select("#", ...) == 0)
        local fontString = makeFontString()
        fontString.requiresFont = true
        if fontObject then
            fontString:SetFontObject(fontObject)
        end
        return fontString
    end

    function frame:SetFontString(fontString)
        self.fontString = fontString
        if self.normalFontObject then
            fontString:SetFontObject(self.normalFontObject)
        end
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
        if self.fontString then
            self.fontString:SetFontObject(fontObject)
        end
    end

    function frame:GetNormalFontObject() return self.normalFontObject end
    function frame:GetHighlightFontObject() return self.highlightFontObject end
    function frame:GetDisabledFontObject() return self.disabledFontObject end

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

    function frame:SetCheckedTexture(texture) self.checkedTexture = texture end
    function frame:SetDisabledCheckedTexture(texture) self.disabledCheckedTexture = texture end
    function frame:SetChecked(checked) self.checked = checked end
    function frame:GetChecked() return self.checked end
    function frame:SetHitRectInsets(...) self.hitRectInsets = { ... } end

    function frame:SetScript(script, callback)
        self.scripts[script] = callback
    end

    function frame:HasScript()
        return true
    end

    function frame:HookScript(script, callback)
        local previous = self.scripts[script]
        self.scripts[script] = function(...)
            if previous then previous(...) end
            callback(...)
        end
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

    function frame:Update()
        self.renderedValue = self.parent:GetValue()
    end

    function frame:OnButtonStateChanged()
        self.visualRefreshCount = (self.visualRefreshCount or 0) + 1
        self.renderedEnabled = self.enabled
    end

    function frame:SetAutoFocus(autoFocus)
        self.autoFocus = autoFocus
    end

    function frame:SetFontObject(fontObject)
        self.fontObject = fontObject
    end

    function frame:GetFontObject()
        return self.fontObject
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

    if template == "WowStyle1DropdownTemplate" then
        frame:SetSize(120, 25)
    elseif template == "MinimalSliderWithSteppersTemplate" then
        frame:SetSize(250, 40)
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
    control.dropdown:SetSize(254, 25)
    return control
end, {
    SetControlEnabled = function() end,
})

local oldDropdown = lib:CreateControl("dropdown", nil, {})

lib:RegisterControlType("slider", function(parent)
    local control = makeFrame("Frame", parent)

    control:SetSize(270, 60)
    control.label = makeFontString()
    control.slider = CreateFrame(
        "Frame",
        nil,
        control,
        "MinimalSliderWithSteppersTemplate"
    )
    control.valueBox = makeFrame(
        "EditBox",
        control,
        "InputBoxScriptTemplate"
    )
    control.valueBox:SetSize(60, 39)
    control.valueBox:SetPoint("LEFT", control.slider, "RIGHT", 0, 0)
    control.valueBox:SetText("60")
    control.currentValue = 60
    control._libModernSettingsSliderOptions = {
        minValue = 0,
        maxValue = 100,
        step = 1,
        suffix = "",
    }

    return control
end, {
    SetControlEnabled = function() end,
})

local oldSlider = lib:CreateControl("slider", nil, {})

lib:RegisterControlType("textInput", function(parent)
    local editBox = makeFrame(
        "EditBox",
        parent,
        "InputBoxScriptTemplate"
    )

    editBox._libModernSettingsCommittedValue = "Old"
    editBox:SetText("Old")

    return editBox
end, {
    SetControlEnabled = function() end,
})

local oldTextInput = lib:CreateControl("textInput", nil, {})

lib:RegisterControlType("field", function(parent)
    local field = makeFrame("Frame", parent)
    field:SetSize(270, 59)
    field.label = makeFontString()
    field.label:SetSize(270, 18)
    field.label:SetPoint("TOPLEFT", field, "TOPLEFT", 0, 0)
    field.control = makeFrame("EditBox", field)
    field.control:SetSize(270, 34)
    field.control:SetPoint("TOPLEFT", field, "TOPLEFT", 0, -25)
    return field
end, { SetControlEnabled = function() end })

local oldField = lib:CreateControl("field", nil, {})

-- These fixtures represent releases predating retained appearance options.
for _, control in ipairs({ oldButton, oldDropdown, oldSlider, oldTextInput, oldField }) do
    control._libModernSettingsAppearanceOptions = nil
end

dofile("Utilities/Atlas.lua")
dofile("Utilities/EditBoxCommit.lua")
dofile("Elements/Text.lua")
dofile("Layouts/Control.lua")
dofile("Controls/Button.lua")
dofile("Controls/ExpandableHeader.lua")
dofile("Controls/Slider.lua")
dofile("Controls/TextInput.lua")
dofile("Controls/Dropdown.lua")
dofile("Layouts/Field.lua")
runDeferredCallbacks()
assert(oldDropdown.dropdown.visualRefreshCount == 1)

oldButton:SetButtonText("Updated")
assert(oldButton.label.point[1] == "CENTER")
oldButton:FitToContents()
assert(oldButton.width == 65)

oldDropdown:SetControlWidth(180)
assert(oldDropdown.width == 180)
assert(oldDropdown.label.width == 180)
assert(oldDropdown.dropdown.width == 164)
assert(oldDropdown.height == 60)
oldField:SetWidth(320)
assert(oldField.control.width == 320 and oldField.label.width == 320)
assert(oldField.height == 59)
assert(oldField.control.point[5] == -7)

assert(oldSlider.valueBox._libModernSettingsSlider == oldSlider)
assert(oldSlider.valueBox.focusTexture.atlas ==
    "common-button-tertiary-depressed-normal-glow")
oldSlider:SetControlEnabled(false, "Disabled")
assert(oldSlider.valueBox.focusTexture:IsShown() == false)
oldSlider:SetControlEnabled(true)
oldSlider.valueBox:SetFocus()
assert(oldSlider.valueBox.focusTexture:IsShown() == true)
oldSlider.valueBox:ClearFocus()
assert(oldSlider.valueBox.focusTexture:IsShown() == false)

assert(oldTextInput.focusTexture.atlas ==
    "common-button-tertiary-depressed-normal-glow")
oldTextInput:SetControlEnabled(false, "Disabled")
assert(oldTextInput.focusTexture:IsShown() == false)
oldTextInput:SetControlEnabled(true)
oldTextInput:FocusValue()
assert(oldTextInput.focusTexture:IsShown() == true)
oldTextInput:CancelAndClearFocus()
assert(oldTextInput.focusTexture:IsShown() == false)

local oldSliderFocusTexture = oldSlider.valueBox.focusTexture
local oldTextInputFocusTexture = oldTextInput.focusTexture

dofile("Controls/Slider.lua")
dofile("Controls/TextInput.lua")

assert(oldSlider.valueBox.focusTexture == oldSliderFocusTexture)
assert(oldTextInput.focusTexture == oldTextInputFocusTexture)

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

local expandedChanges = {}
local expandableHeader = lib:CreateExpandableHeader(nil, {
    text = "Mythic",
    width = 300,
    expanded = false,
    iconAtlas = "header-icon",
    iconSize = 20,
    onExpandedChanged = function(header, expanded, button)
        expandedChanges[#expandedChanges + 1] = {
            header = header,
            expanded = expanded,
            button = button,
        }
    end,
})

assert(expandableHeader.width == 300)
assert(expandableHeader.height == 34)
assert(expandableHeader:GetText() == "Mythic")
assert(expandableHeader._libModernSettingsHeaderNormalTexture.atlas ==
    "common-button-tertiary-normal")
assert(expandableHeader.pushedTexture.atlas ==
    "common-button-tertiary-pressed")
assert(expandableHeader.disabledTexture.atlas ==
    "common-button-tertiary-disabled")
assert(expandableHeader.icon.atlas == "header-icon")
assert(expandableHeader.icon.drawLayer == "OVERLAY")
assert(expandableHeader.icon:GetWidth() == 20)
assert(expandableHeader.icon:GetHeight() == 20)
assert(expandableHeader.icon:IsShown())
assert(expandableHeader.label.points[1][2] == expandableHeader.icon)
assert(expandableHeader.toggleIcon.drawLayer == "OVERLAY")
assert(expandableHeader.toggleIcon.atlas ==
    "common-dropdown-icon-next")
assert(expandableHeader.toggleIcon:GetWidth() == 17)
assert(expandableHeader.toggleIcon:GetHeight() == 17)
assert(expandableHeader.toggleIcon.rotation == math.pi * 0.5)
local collapsedToggleYOffset = expandableHeader.toggleIcon.point[5]
assert(type(collapsedToggleYOffset) == "number")
assert(expandableHeader:IsExpanded() == false)

expandableHeader.scripts.OnEnter(expandableHeader)
assert(expandableHeader._libModernSettingsHeaderNormalTexture.atlas ==
    "common-button-tertiary-hover")
expandableHeader.scripts.OnLeave(expandableHeader)
assert(expandableHeader._libModernSettingsHeaderNormalTexture.atlas ==
    "common-button-tertiary-normal")

expandableHeader.scripts.OnClick(expandableHeader, "LeftButton")
assert(expandableHeader:IsExpanded() == true)
assert(expandableHeader.toggleIcon.rotation == math.pi * 1.5)
local expandedToggleYOffset = expandableHeader.toggleIcon.point[5]
assert(type(expandedToggleYOffset) == "number")
assert(#expandedChanges == 1)
assert(expandedChanges[1].header == expandableHeader)
assert(expandedChanges[1].expanded == true)
assert(expandedChanges[1].button == "LeftButton")

expandableHeader:SetExpanded(false)
assert(expandableHeader.toggleIcon.point[5] == collapsedToggleYOffset)
assert(#expandedChanges == 1)
expandableHeader:SetHeaderText("Heroic")
assert(expandableHeader:GetText() == "Heroic")

expandableHeader:SetHeaderIcon(nil)
assert(expandableHeader.icon:IsShown() == false)
assert(expandableHeader.label.points[1][2] == expandableHeader)
expandableHeader:SetHeaderIcon("header-icon", false)
assert(expandableHeader.icon:IsShown())

expandableHeader:SetControlEnabled(false, "Unavailable")
assert(expandableHeader.enabled == false)
assert(expandableHeader.icon.desaturated == true)
assert(expandableHeader.icon.alpha == 0.5)
assert(expandableHeader.toggleIcon.atlas ==
    "common-dropdown-icon-next-disabled")
assert(expandableHeader.toggleIcon.desaturated == false)
assert(expandableHeader.toggleIcon.alpha == 1)
assert(expandableHeader.disabledTooltip == "Unavailable")

expandableHeader:SetControlEnabled(true)
assert(expandableHeader.enabled == true)
assert(expandableHeader.icon.desaturated == false)
assert(expandableHeader.icon.alpha == 1)
assert(expandableHeader.toggleIcon.atlas ==
    "common-dropdown-icon-next")
assert(expandableHeader.toggleIcon.desaturated == false)
assert(expandableHeader.toggleIcon.alpha == 1)

local labeledDropdown = lib:CreateDropdown(nil, {
    label = "Profile",
    choices = {},
})

assert(labeledDropdown.width == 270)
assert(labeledDropdown.height == 48.5)
assert(labeledDropdown.dropdown.height == 25, "layout spacing must not stretch dropdown artwork")
assert(labeledDropdown.label:IsShown() == true)
assert(labeledDropdown.label.point[1] == "TOPLEFT")
assert(labeledDropdown.dropdown.width == 270)
assert(labeledDropdown.dropdown.point[1] == "TOPLEFT")
assert(labeledDropdown.dropdown.point[4] == 0)
assert(labeledDropdown:GetContentTopInset() == 0)
labeledDropdown:SetControlWidth(180)
assert(labeledDropdown.dropdown.width == 180)

local insetLabeledDropdown = lib:CreateDropdown(nil, {
    label = "Profile",
    leftInset = 3,
    rightInset = 7,
})

assert(insetLabeledDropdown.dropdown.width == 260)
assert(insetLabeledDropdown.dropdown.point[4] == 3)
insetLabeledDropdown:SetControlWidth(180)
assert(insetLabeledDropdown.dropdown.width == 170)

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
    choices = {},
})

assert(inlineDropdown.width == 270)
assert(inlineDropdown.height == 34)
assert(inlineDropdown.dropdown.height == 25)
assert(inlineDropdown.label:IsShown() == false)
assert(inlineDropdown.dropdown.width == 270)
assert(inlineDropdown.dropdown.point[1] == "LEFT")
assert(inlineDropdown.dropdown.point[2] == inlineDropdown)
assert(inlineDropdown.dropdown.point[3] == "LEFT")
assert(inlineDropdown.dropdown.point[4] == 0)
assert(inlineDropdown.dropdown.point[5] == 0)
assert(inlineDropdown:GetContentTopInset() == 4.5)

inlineDropdown:SetControlWidth(180)
assert(inlineDropdown.width == 180)
assert(inlineDropdown.label.width == 180)
assert(inlineDropdown.dropdown.width == 180)

-- Direct category opening may refresh values before the canvas becomes visible.
do
    runDeferredCallbacks()
    local canvas = makeFrame("Frame")
    canvas.visible = false
    local dropdown = lib:CreateDropdown(canvas, {
        value = "old",
        onChanged = function() error("visual refresh must not submit a selection") end,
    })
    assert(#deferredCallbacks == 0)
    dropdown.scripts.OnShow(dropdown)
    dropdown:SetValue("latest")
    dropdown:SetControlEnabled(false)
    canvas.visible = true
    dropdown.scripts.OnShow(dropdown)
    assert(#deferredCallbacks == 1)
    assert(dropdown.dropdown.visualRefreshCount == nil)
    runDeferredCallbacks()
    assert(dropdown.dropdown.visualRefreshCount == 1)
    assert(dropdown.dropdown.renderedValue == "latest")
    assert(dropdown.dropdown.renderedEnabled == false)

    dropdown.scripts.OnShow(dropdown)
    canvas.visible = false
    runDeferredCallbacks()
    assert(dropdown.dropdown.visualRefreshCount == 1)
    canvas.visible = true
    dropdown.scripts.OnShow(dropdown)
    runDeferredCallbacks()
    assert(dropdown.dropdown.visualRefreshCount == 2)
    assert(#deferredCallbacks == 0)
end

local flushDropdown = lib:CreateDropdown(nil, {
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

do
    local labelCases = {
        { visible = false },
        { label = "", visible = false },
        { label = "Setting", visible = true },
        -- Retired visibility flags must not override the actual label text.
        { label = "Setting", showLabel = false, visible = true },
        { showLabel = true, visible = false },
    }

    for _, case in ipairs(labelCases) do
        local dropdown = lib:CreateDropdown(nil, {
            label = case.label,
            showLabel = case.showLabel,
        })
        local slider = lib:CreateSlider(nil, {
            label = case.label,
            showLabel = case.showLabel,
            minValue = 0,
            maxValue = 100,
            step = 5,
            value = 50,
        })

        assert(dropdown.label:IsShown() == case.visible)
        assert(dropdown.height == (case.visible and 48.5 or 34))
        assert(slider.label:IsShown() == case.visible)
        assert(slider.height == (case.visible and 48 or 39))
        assert(slider.slider.height == 19)
        assert(slider.slider.point[1] == "LEFT")
        assert(slider.slider.point[2] == slider.inputRow)
        assert(slider.inputRow.point[1] == (case.visible and "TOPLEFT" or "LEFT"))
        assert(slider.inputRow.point[2] == (case.visible and slider.label or slider))
        slider:SetValue(66)
        assert(slider:GetValue() == 65)
        slider:SetControlEnabled(false)
        assert(slider.slider.enabled == false and slider.valueBox.enabled == false)
        slider:SetControlEnabled(true)
        assert(slider.slider.enabled == true and slider.valueBox.enabled == true)
    end

    local tallInputSlider = lib:CreateSlider(nil, {
        minValue = 0,
        maxValue = 100,
        step = 1,
        inputHeight = 48,
    })

    assert(tallInputSlider.height == 48)
    assert(tallInputSlider:GetContentTopInset() == 14.5)

    local paddedSlider = lib:CreateSlider(nil, {
        minValue = 0,
        maxValue = 100,
        step = 1,
        height = 64,
    })

    assert(paddedSlider.height == 64)
    assert(paddedSlider:GetContentTopInset() == 22.5)

end

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
assert(stackedField.height == 53)
assert(stackedField.label.width == 270)
assert(stackedField.label:GetHeight() == 12)
assert(stackedField.label.point[1] == "TOPLEFT")
assert(stackedField.label.point[2] == stackedField)
assert(stackedField.label.point[3] == "TOPLEFT")
assert(stackedInput.width == 270)
assert(stackedInput.point[1] == "TOPLEFT")
assert(stackedInput.point[2] == stackedField.label)
assert(stackedInput.point[3] == "BOTTOMLEFT")
assert(stackedInput.point[4] == 0)
assert(stackedInput.point[5] == -7)
assert(stackedInput:GetValue() == "Stacked")
assert(stackedControlOptions.width == 120)

local stackedDropdownField = lib:CreateField(nil, {
    label = "Profile",
    controlType = "dropdown",
})
local stackedDropdown = stackedDropdownField:GetControl()

assert(stackedDropdownField.label:GetHeight() == labeledDropdown.label:GetHeight())
assert(stackedDropdownField.height == labeledDropdown.height)
assert(stackedDropdown.dropdown.width == stackedDropdownField.width)
assert(stackedDropdown.point[2] == stackedDropdownField.label)
assert(stackedDropdown.point[3] == "BOTTOMLEFT")
assert(stackedDropdown.point[5] - stackedDropdown:GetContentTopInset()
    == labeledDropdown.dropdown.point[5])

local customStackedField = lib:CreateField(nil, {
    label = "Profile",
    labelHeight = 24,
    gap = 11,
    controlType = "dropdown",
    controlOptions = { height = 40 },
})
local customStackedDropdown = customStackedField:GetControl()

assert(customStackedField.label:GetHeight() == 24)
assert(customStackedField.height == 67.5)
assert(customStackedDropdown.point[5]
    - customStackedDropdown:GetContentTopInset() == -11)

do
    local sliderOptions = { minValue = 0, maxValue = 100, step = 1, value = 50 }

    for _, labelPosition in ipairs({ "left", "top" }) do
        local field = lib:CreateField(nil, {
            label = "Slider",
            labelPosition = labelPosition,
            controlType = "slider",
            controlOptions = sliderOptions,
        })
        local slider = field:GetControl()

        assert(slider.label:IsShown() == false)
        assert(slider.height == slider.valueBox:GetHeight())
        assert(field.height == (labelPosition == "left" and 39 or 48))
        if labelPosition == "top" then
            assert(field.height == sliderControl.height)
            assert(slider.point[5] - slider:GetContentTopInset()
                == sliderControl.inputRow.point[5]
                    - (sliderControl.inputRow.height - sliderControl.slider.height) / 2)
        end
        assert(slider:GetValue() == 50)
        slider:SetValue(75)
        assert(slider:GetValue() == 75)
    end

    assert(sliderOptions.label == nil and sliderOptions.width == nil)

    local customField = lib:CreateField(nil, {
        label = "Slider",
        gap = 11,
        controlType = "slider",
        controlOptions = { minValue = 0, maxValue = 100, step = 1, height = 64 },
    })
    local slider = customField:GetControl()

    assert(slider.height == 64)
    assert(slider.point[5] - slider:GetContentTopInset() == -11)
end

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

-- Descriptions belong to the Field's content height, including when inline.
do
    for _, position in ipairs({ "left", "top" }) do
        local field = lib:CreateField(nil, {
            label = "Name", labelPosition = position, width = 240,
            controlType = "textInput", controlOptions = { value = "Saved" },
        })
        local input = field:GetControl()
        local inputHeight = field:GetHeight()
        input:FocusValue()
        input:SetText("Draft")
        assert(field.description == nil and field:GetDescription() == "")

        field:SetDescription(string.rep("a", 40))
        local description = field.description
        assert(description.fontObject == GameFontHighlightSmall)
        assert(description.wordWrap and description.nonSpaceWrap and description.width == 240)
        assert(field:GetHeight() == inputHeight + 4 + 12)
        assert(description.point[5] == -inputHeight - 4)
        if position == "left" then
            assert(input.point[1] == "TOPLEFT" and input.point[5] == 0)
            assert(field.label.height == inputHeight)
        end

        field:SetControlWidth(120)
        assert(description.width == 120 and field:GetHeight() == inputHeight + 4 + 24)
        field:SetDescription("Short")
        assert(field:GetHeight() == inputHeight + 4 + 12)
        assert(field._libModernSettingsAppearanceOptions.description == "Short")
        description.stringHeight = 24
        field.scripts.OnShow(field)
        assert(field:GetHeight() == inputHeight + 4 + 24, "show must remeasure description text")
        field:SetDescription(nil)
        assert(field:GetHeight() == inputHeight and not description:IsShown())
        assert(field:GetDescription() == "" and field.description == description)
        assert(field:GetControl() == input and input:HasFocus())
        assert(input:GetText() == "Draft" and input:GetValue() == "Saved")
        assert(not pcall(field.SetDescription, field, {}))
    end

    local field = lib:CreateField(nil, {
        label = "Name", description = "Hint", descriptionGap = 0,
        descriptionFontObject = { height = 10 }, controlType = "textInput",
    })
    assert(field:GetDescription() == "Hint" and field:GetHeight() == 53 + 10)
    field:SetControlHeight(100)
    field:SetDescription(nil)
    assert(field:GetHeight() == 100, "explicit Field heights remain addon-owned")
    field:SetControlHeight(nil)
    assert(field:GetHeight() == 53)
end

-- Size changes reflow existing content, not its value/focus or callback state.
do
    labeledDropdown:SetSize(320, 80)
    labeledDropdown:SetWidth(300)
    assert(labeledDropdown.label.width == 300)
    assert(labeledDropdown.dropdown.width == 300)
    assert(labeledDropdown.height == 80)
    labeledDropdown:SetControlHeight(nil)
    assert(labeledDropdown.height == 48.5)
    labeledDropdown.label.stringHeight = 24
    labeledDropdown:RefreshLayout()
    assert(labeledDropdown.height == 60.5)

    stackedDropdownField:SetWidth(360)
    assert(stackedDropdownField.label.width == 360)
    assert(stackedDropdown.width == 360 and stackedDropdown.dropdown.width == 360)
    stackedDropdown:SetControlHeight(40)
    assert(stackedDropdownField.height == 51.5)
    stackedDropdown:SetControlHeight(nil)
    assert(stackedDropdownField.height == 48.5)

    sliderControl.valueBox:SetFocus()
    sliderControl.valueBox:SetText("1.3")
    sliderControl:SetWidth(400)
    assert(sliderControl.slider.width == 338)
    assert(sliderControl.valueBox.width == 60)
    assert(sliderControl.valueBox:HasFocus())
    assert(sliderControl.valueBox:GetText() == "1.3")
    assert(sliderControl:GetValue() == 1)
    sliderControl.label.stringHeight = 24
    sliderControl:RefreshLayout()
    assert(sliderControl.height == 60)

    inlineField:SetWidth(350)
    assert(inlineField:GetControl() == inlineInput and inlineInput.width == 294)
    assert(inlineInput:GetValue() == "Inline")
    inlineInput:SetHeight(42)
    assert(inlineField.height == 42 and inlineField.label.height == 42)

    stackedInput:FocusValue()
    stackedInput:SetText("In progress")
    stackedField:SetWidth(320)
    assert(stackedField:GetControl() == stackedInput)
    assert(stackedInput.width == 320 and stackedField.label.width == 320)
    assert(stackedInput:HasFocus() and stackedInput:GetText() == "In progress")
    stackedField.label.stringHeight = 24
    stackedField:RefreshLayout()
    assert(stackedField.height == 65)
    stackedInput:SetHeight(40)
    assert(stackedField.height == 71)
    stackedField:SetControlHeight(90)
    stackedField:SetControlWidth(340)
    assert(stackedField.height == 90 and stackedInput.width == 340)
    stackedField:SetControlHeight(nil)
    assert(stackedField.height == 71)

    for _, control in ipairs({ labeledDropdown, sliderControl, stackedField }) do
        assert(not pcall(control.SetControlHeight, control, 0))
        assert(not pcall(control.SetControlWidth, control, 0))
    end
end

-- Native layout can report settled sizes again, with minor coordinate rounding.
-- These notifications must not re-anchor a focused input or create overrides.
do
    for _, position in ipairs({ "left", "top" }) do
        local field = lib:CreateField(nil, {
            label = "Name", labelPosition = position, width = 418,
            controlType = "textInput", controlOptions = { value = "Saved" },
        })
        local input = field:GetControl()
        input:FocusValue()
        input:SetText("Draft")
        local inputPoint = input.point
        local height = field:GetHeight()

        input.scripts.OnSizeChanged(input, input:GetWidth(), input:GetHeight())
        input.scripts.OnSizeChanged(input, input:GetWidth() - 0.0001, input:GetHeight() - 0.0001)
        field.scripts.OnSizeChanged(field, field:GetWidth() - 0.0001, height - 0.0001)
        assert(input.point == inputPoint, "settled size notifications must not invalidate input geometry")
        assert(field._libModernSettingsExplicitHeight == nil)
        assert(field._libModernSettingsAppearanceOptions.height == nil)

        input:SetHeight(40)
        assert(field:GetHeight() == height + 6, "real child height changes must still reflow the field")
        assert(input:HasFocus() and input:GetText() == "Draft" and input:GetValue() == "Saved")
    end
end

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

-- Ordinary text must set its font before SetText, including empty labels.
do
    local parent = makeFrame("Frame")
    local text = lib:CreateText(parent, { text = "Body text" })
    assert(text:GetFontObject() == GameFontHighlight)
    assert(text.text == "Body text")

    local empty = lib:CreateText(parent)
    assert(empty:GetFontObject() == GameFontHighlight and empty.text == "")

    local customFont = { height = 18 }
    local custom = lib:CreateText(parent, { text = "Custom text", fontObject = customFont })
    assert(custom:GetFontObject() == customFont and custom.text == "Custom text")
end

print("LibModernSettings control tests passed")
