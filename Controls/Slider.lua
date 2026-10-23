local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Slider", MINOR)
then
    return
end

local INPUT_ATLAS = "common-button-tertiary-depressed-normal"
local DEFAULT_INPUT_WIDTH = 60
local INPUT_RIGHT_INSET = 2
-- MinimalSliderTemplate's track/thumb height, without the stepper wrapper's padding.
local TRACK_HEIGHT = 19

local STEP_MODIFIERS = {
    wheel = {
        { modifier = "control", steps = 50 },
        { modifier = "shift", steps = 10 },
    },
}

local function getInputSteps(context)
    local rules = STEP_MODIFIERS[context.source]

    if rules then
        for _, rule in ipairs(rules) do
            if context.modifiers[rule.modifier] then
                return context.direction * rule.steps
            end
        end
    end

    return context.direction
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and math.abs(value) < math.huge
end

local function snapValue(value, options)
    if options.snapToStep == false then return value end

    local stepIndex =
        math.floor(((value - options.minValue) / options.step) + 0.5)

    return options.minValue + (stepIndex * options.step)
end

local function normalizeValueLabel(text)
    return text:match("^%s*(.-)%s*$"):lower()
end

local function prepareValueLabels(options)
    local maxLetters = options.maxLetters or 5

    if options.valueLabels == nil then return nil, nil, maxLetters end

    assert(
        type(options.valueLabels) == "table",
        "valueLabels must be a table or nil"
    )
    local labels, values = {}, {}

    for value, label in pairs(options.valueLabels) do
        assert(isFiniteNumber(value), "valueLabels keys must be finite numbers")
        assert(
            type(label) == "string" and label:find("%S"),
            "valueLabels must contain non-empty labels"
        )
        local normalizedValue = snapValue(value, options)
        local normalizedLabel = normalizeValueLabel(label)

        assert(
            isFiniteNumber(normalizedValue),
            "valueLabels must snap to finite values"
        )
        assert(
            labels[normalizedValue] == nil,
            "valueLabels must name distinct values"
        )
        assert(
            values[normalizedLabel] == nil,
            "valueLabels must have distinct labels ignoring case and whitespace"
        )
        labels[normalizedValue] = label
        values[normalizedLabel] = normalizedValue

        if maxLetters > 0 then maxLetters = math.max(maxLetters, #label) end
    end

    return labels, values, maxLetters
end

local function updateSliderWheel(control)
    local enabled = control.valueBox:IsEnabled() and control.valueBox:HasFocus()
    control:EnableMouseWheel(enabled)
    control.valueBox:EnableMouseWheel(enabled)
    control.slider.Slider:EnableMouseWheel(enabled)
    control.slider.Back:EnableMouseWheel(enabled)
    control.slider.Forward:EnableMouseWheel(enabled)
end

local function layoutSlider(control)
    local width = control:GetWidth()
    local slider = control.slider
    local inputRow = control.inputRow
    local valueBox = control.valueBox
    local inputGap = control._libModernSettingsInputGap
    local rowHeight = math.max(slider:GetHeight(), valueBox:GetHeight())

    control.label:SetWidth(width)
    inputRow:SetSize(width, rowHeight)
    slider:SetWidth(
        math.max(1, width - valueBox:GetWidth() - inputGap - INPUT_RIGHT_INSET)
    )
    lib:_SetLayoutPoint(slider, "LEFT", inputRow, "LEFT", 0, 0)

    if control.label:IsShown() then
        local layout = control._libModernSettingsLabelLayout

        layout.contentTopInset = (rowHeight - slider:GetHeight()) / 2
        return lib:_LayoutStackedLabel(control, control.label, inputRow, layout)
    end

    lib:_SetLayoutPoint(inputRow, "LEFT", control, "LEFT", 0, 0)
    return rowHeight
end

local function finalizeSliderInput(valueBox)
    valueBox._libModernSettingsSlider:_FinalizeInput()
end

local function configureSliderInput(control)
    local valueBox = control.valueBox

    valueBox._libModernSettingsSlider = control
    valueBox:SetAltArrowKeyMode(false)
    valueBox.focusTexture = valueBox.focusTexture
        or lib:_CreateEditBoxFocusTexture(valueBox)

    valueBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    valueBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    valueBox:SetScript("OnEditFocusGained", function(self)
        lib:_CancelPendingEditBoxCommit(self)
        self.focusTexture:Show()
        EditBox_HighlightText(self)
        updateSliderWheel(control)
    end)
    valueBox:SetScript("OnEditFocusLost", function(self)
        self.focusTexture:Hide()
        EditBox_ClearHighlight(self)
        updateSliderWheel(control)
        lib:_FinalizeEditBoxOnFocusLost(self, finalizeSliderInput)
    end)

    local function onMouseWheel(_, delta)
        if delta ~= 0 then
            control:_StepValue(
                lib:_CreateNavigationContext("wheel", delta > 0 and 1 or -1)
            )
        end
    end

    control:SetScript("OnMouseWheel", onMouseWheel)
    valueBox:SetScript("OnMouseWheel", onMouseWheel)

    for _, target in ipairs({
        control.slider.Slider,
        control.slider.Back,
        control.slider.Forward,
    }) do
        target:SetScript("OnMouseWheel", onMouseWheel)

        if not target._libModernSettingsFocusHooked then
            target._libModernSettingsFocusHooked = true
            -- Blizzard clears edit focus on global mouse-down outside the
            -- edit box. Focus after release when selecting the track/steppers.
            target:HookScript("OnMouseUp", function(_, button)
                if button == "LeftButton" and control.valueBox:IsEnabled() then
                    control.valueBox:SetFocus()
                end
            end)
        end
    end

    updateSliderWheel(control)

    if valueBox:HasFocus() then
        valueBox.focusTexture:Show()
    else
        valueBox.focusTexture:Hide()
    end
end

local function validateOptions(options)
    assert(isFiniteNumber(options.minValue), "minValue must be a finite number")
    assert(isFiniteNumber(options.maxValue), "maxValue must be a finite number")
    assert(isFiniteNumber(options.step), "step must be a finite number")
    assert(
        options.value == nil or isFiniteNumber(options.value),
        "value must be a finite number or nil"
    )
    assert(options.maxValue > options.minValue, "maxValue must exceed minValue")
    assert(options.step > 0, "step must be greater than zero")
    assert(
        options.snapToStep == nil or type(options.snapToStep) == "boolean",
        "snapToStep must be a boolean or nil"
    )
    assert(
        options.inputFormatter == nil
            or type(options.inputFormatter) == "function",
        "inputFormatter must be a function or nil"
    )
    assert(
        options.inputParser == nil or type(options.inputParser) == "function",
        "inputParser must be a function or nil"
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
end

local function createSlider(parent, options)
    validateOptions(options)
    local valueLabels, valuesByLabel, maxLetters = prepareValueLabels(options)

    local control = CreateFrame("Frame", nil, parent)
    local width = options.width or 270
    local inputAtlasInfo = C_Texture.GetAtlasInfo(INPUT_ATLAS)
    local inputWidth = options.inputWidth or DEFAULT_INPUT_WIDTH
    local inputHeight = options.inputHeight or inputAtlasInfo.height
    local inputGap = options.inputGap or 0
    local sliderWidth =
        math.max(1, width - inputWidth - inputGap - INPUT_RIGHT_INSET)
    local stepCount = (options.maxValue - options.minValue) / options.step
    local hasLabel = type(options.label) == "string" and options.label ~= ""

    control:SetWidth(width)
    control._libModernSettingsExplicitHeight = options.height
    control._libModernSettingsInputGap = inputGap
    control._libModernSettingsLabelLayout = {}

    control._libModernSettingsSliderOptions = {
        minValue = options.minValue,
        maxValue = options.maxValue,
        step = options.step,
        snapToStep = options.snapToStep,
        inputFormatter = options.inputFormatter,
        inputParser = options.inputParser,
        valueLabels = valueLabels,
        valuesByLabel = valuesByLabel,
        suffix = options.suffix or "",
    }
    control._libModernSettingsOnChanged = options.onChanged

    local label = lib:CreateText(control, {
        fontObject = options.fontObject or GameFontHighlight,
        text = options.label,
        width = width,
    })
    local inputRow = CreateFrame("Frame", nil, control)
    local slider =
        CreateFrame("Frame", nil, inputRow, "MinimalSliderWithSteppersTemplate")
    slider:SetSize(sliderWidth, TRACK_HEIGHT)

    if not hasLabel then label:Hide() end

    slider:Init(
        options.value or options.minValue,
        options.minValue,
        options.maxValue,
        stepCount,
        nil
    )

    local valueBox =
        CreateFrame("EditBox", nil, inputRow, "InputBoxScriptTemplate")
    valueBox:SetSize(inputWidth, inputHeight)
    valueBox:SetPoint("LEFT", slider, "RIGHT", inputGap, 0)
    valueBox:SetAutoFocus(false)
    valueBox:SetFontObject(options.inputFontObject or GameFontHighlight)
    valueBox:SetMaxLetters(maxLetters)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetJustifyV("MIDDLE")
    valueBox:SetTextInsets(4, 4, 0, 0)

    local valueBoxBackground = valueBox:CreateTexture(nil, "BACKGROUND")

    valueBoxBackground:SetAllPoints(valueBox)
    valueBoxBackground:SetAtlas(INPUT_ATLAS, false)

    control.label = label
    control.inputRow = inputRow
    control.slider = slider
    control.valueBox = valueBox
    lib:_RefreshControlLayout(control, layoutSlider)
    lib:_WatchControlSize(control)
    configureSliderInput(control)
    control.currentValue = options.value or options.minValue
    control.callbackHandles = EventUtil.CreateCallbackHandleContainer()
    control.callbackHandles:RegisterCallback(
        slider,
        MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value)
            control:_HandleSliderValueChanged(value)
        end
    )

    if options.tooltip then
        lib:SetTooltip(control, {
            title = options.tooltipTitle or options.label,
            text = options.tooltip,
        })
    end

    lib:AddTooltipTarget(control, slider.Slider)
    lib:AddTooltipTarget(control, slider.Back)
    lib:AddTooltipTarget(control, slider.Forward)
    lib:AddTooltipTarget(control, valueBox)

    return control
end

local sliderMethods = {}

sliderMethods.SetControlWidth = lib._SetControlWidth
sliderMethods.SetControlHeight = lib._SetControlHeight

function sliderMethods:RefreshLayout()
    lib:_RefreshControlLayout(self, layoutSlider)
end

function sliderMethods:_SnapValue(value)
    return snapValue(value, self._libModernSettingsSliderOptions)
end

function sliderMethods:_GetTrackValue(value)
    local options = self._libModernSettingsSliderOptions

    return math.max(options.minValue, math.min(options.maxValue, value))
end

function sliderMethods:_FormatValue(value)
    local options = self._libModernSettingsSliderOptions
    local label = options.valueLabels and options.valueLabels[value]

    if label then return label end

    local text

    if options.inputFormatter then
        text = options.inputFormatter(value)
    else
        text = tostring(value)
    end

    return text .. options.suffix
end

function sliderMethods:_SyncValueBox(value)
    lib:_CancelPendingEditBoxCommit(self.valueBox)
    self.valueBox:SetText(self:_FormatValue(value))
    self.valueBox:SetCursorPosition(0)
end

function sliderMethods:_ParseInput()
    local options = self._libModernSettingsSliderOptions
    local text = self.valueBox:GetText()
    local namedValue = options.valuesByLabel
        and options.valuesByLabel[normalizeValueLabel(text)]

    if namedValue ~= nil then return namedValue end

    if options.inputParser then return options.inputParser(text) end

    local numericText = text:match("^%s*([+-]?%d*%.?%d+)")

    return numericText and tonumber(numericText) or nil
end

function sliderMethods:_HandleSliderValueChanged(value)
    if self._libModernSettingsSyncing then return end

    self:_SetCurrentValue(value, true)
end

function sliderMethods:_SetCurrentValue(value, notify)
    local normalized = self:_SnapValue(value)

    if not isFiniteNumber(normalized) then
        self:_SyncValueBox(self.currentValue)
        return
    end

    local changed = self.currentValue ~= normalized

    self.currentValue = normalized
    self._libModernSettingsSyncing = true
    self.slider:SetValue(self:_GetTrackValue(normalized))
    self._libModernSettingsSyncing = false
    self:_SyncValueBox(normalized)

    if notify and changed and self._libModernSettingsOnChanged then
        self._libModernSettingsOnChanged(normalized)
    end
end

function sliderMethods:_FinalizeInput()
    local value = self:_ParseInput()

    if not isFiniteNumber(value) then
        self:_SyncValueBox(self.currentValue)
        return
    end

    self:_SetCurrentValue(value, true)
end

function sliderMethods:_StepValue(context)
    if
        not self:IsVisible()
        or not self.valueBox:IsEnabled()
        or not self.valueBox:HasFocus()
    then
        return
    end

    local value = self:_ParseInput()

    if not isFiniteNumber(value) then value = self.currentValue end

    local steps = getInputSteps(context)
    self:_SetCurrentValue(
        value + steps * self._libModernSettingsSliderOptions.step,
        true
    )
end

function sliderMethods:SetValue(value)
    assert(isFiniteNumber(value), "slider value must be a finite number")

    self:_SetCurrentValue(value, false)
end

function sliderMethods:GetValue()
    return self.currentValue
end

function sliderMethods:SetOnChanged(onChanged)
    assert(
        onChanged == nil or type(onChanged) == "function",
        "onChanged must be a function or nil"
    )
    self._libModernSettingsOnChanged = onChanged
end

function sliderMethods:GetInputAlignmentOffset()
    if self.label:IsShown() then
        return self._libModernSettingsLabelLayout.inputTop
            + self.inputRow:GetHeight() / 2
    end

    return self:GetHeight() / 2
end

function sliderMethods:GetContentTopInset()
    if self.label:IsShown() then return 0 end

    -- The taller numeric input sets the row height; the track is centered in it.
    return (self:GetHeight() - self.slider:GetHeight()) / 2
end

function sliderMethods:SetControlEnabled(enabled, disabledTooltip)
    self.slider:SetEnabled(enabled == true)
    self.valueBox:SetEnabled(enabled == true)
    updateSliderWheel(self)

    if enabled and self.valueBox:HasFocus() then
        self.valueBox.focusTexture:Show()
    else
        self.valueBox.focusTexture:Hide()
    end

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self.valueBox:SetTextColor(color.r, color.g, color.b)
    self.label:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeSlider(slider, options)
    slider:SetValue(options.value or options.minValue)
    slider:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)
end

local function refreshSliderAppearance(control, options)
    lib:_ApplyInputWidth(control, options.width or 270)
    control._libModernSettingsExplicitHeight = options.height
    control._libModernSettingsInputGap = options.inputGap or 0
    control.slider:SetHeight(TRACK_HEIGHT)
    control.valueBox:SetSize(
        options.inputWidth or DEFAULT_INPUT_WIDTH,
        options.inputHeight or C_Texture.GetAtlasInfo(INPUT_ATLAS).height
    )
    lib:_SetLayoutPoint(
        control.valueBox,
        "LEFT",
        control.slider,
        "RIGHT",
        control._libModernSettingsInputGap,
        0
    )
    lib:_ApplyDefaultFont(
        control.label,
        options.fontObject or GameFontHighlight
    )
    lib:_ApplyDefaultFont(
        control.valueBox,
        options.inputFontObject or GameFontHighlight
    )
    control:RefreshLayout()
end

lib:RegisterControlType(
    "slider",
    createSlider,
    sliderMethods,
    initializeSlider,
    refreshSliderAppearance
)

-- Compatible upgrades preserve controls but not construction-owned regions.
for control, controlType in pairs(lib._controlInstances) do
    if controlType == "slider" then
        if not control.inputRow then
            control._libModernSettingsExplicitHeight = control:GetHeight()
            local _, _, _, inputGap = control.valueBox:GetPoint(1)

            control._libModernSettingsInputGap = inputGap
            control._libModernSettingsLabelLayout = {}
            control.inputRow = CreateFrame("Frame", nil, control)
            control.slider:SetParent(control.inputRow)
            control.slider:SetHeight(TRACK_HEIGHT)
            control.valueBox:SetParent(control.inputRow)
            control:RefreshLayout()
            lib:_WatchControlSize(control)
        end

        configureSliderInput(control)
    end
end

local function stepWithKeyboard(control, context)
    -- Up selects the previous row in a list, but increases a numeric value.
    control:_StepValue({
        source = context.source,
        direction = -context.direction,
        modifiers = context.modifiers,
    })
    return true
end

lib:RegisterControlNavigation("slider", {
    mode = "editBox",
    input = function(control)
        return control.valueBox
    end,
    actions = {
        previous = stepWithKeyboard,
        next = stepWithKeyboard,
    },
})

function lib:CreateSlider(parent, options)
    options = options or {}

    return self:CreateControl("slider", parent, options)
end
