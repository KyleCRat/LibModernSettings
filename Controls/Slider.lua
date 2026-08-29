local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local INPUT_ATLAS = "common-button-tertiary-depressed-normal"
local DEFAULT_INPUT_WIDTH = 60

local function validateOptions(options)
    assert(type(options.minValue) == "number", "minValue must be a number")
    assert(type(options.maxValue) == "number", "maxValue must be a number")
    assert(type(options.step) == "number", "step must be a number")
    assert(options.maxValue > options.minValue, "maxValue must exceed minValue")
    assert(options.step > 0, "step must be greater than zero")
    assert(
        options.inputFormatter == nil
            or type(options.inputFormatter) == "function",
        "inputFormatter must be a function or nil"
    )
    assert(
        options.inputParser == nil
            or type(options.inputParser) == "function",
        "inputParser must be a function or nil"
    )
    assert(
        options.onChanged == nil or type(options.onChanged) == "function",
        "onChanged must be a function or nil"
    )
end

local function createSlider(parent, options)
    validateOptions(options)

    local control = CreateFrame("Frame", nil, parent)
    local width = options.width or 270
    local inputAtlasInfo = C_Texture.GetAtlasInfo(INPUT_ATLAS)
    local inputWidth = options.inputWidth or DEFAULT_INPUT_WIDTH
    local inputHeight = options.inputHeight or inputAtlasInfo.height
    local inputGap = options.inputGap or 0
    local sliderWidth = width - inputWidth - inputGap - 2
    local stepCount = (options.maxValue - options.minValue) / options.step

    control:SetSize(width, options.height or 60)
    control._libModernSettingsSliderOptions = {
        minValue = options.minValue,
        maxValue = options.maxValue,
        step = options.step,
        inputFormatter = options.inputFormatter,
        inputParser = options.inputParser,
        suffix = options.suffix or "",
    }
    control._libModernSettingsOnChanged = options.onChanged

    local label = lib:CreateText(control, {
        fontObject = options.fontObject or GameFontHighlight,
        text = options.label,
        width = width,
    })
    label:SetPoint("TOPLEFT", control, "TOPLEFT", 0, 0)

    local slider = CreateFrame(
        "Frame",
        nil,
        control,
        "MinimalSliderWithSteppersTemplate"
    )
    slider:SetWidth(sliderWidth)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, 2)
    slider:Init(
        options.value or options.minValue,
        options.minValue,
        options.maxValue,
        stepCount,
        nil
    )

    local valueBox = CreateFrame(
        "EditBox",
        nil,
        control,
        "InputBoxScriptTemplate"
    )
    valueBox:SetSize(inputWidth, inputHeight)
    valueBox:SetPoint("LEFT", slider, "RIGHT", inputGap, 0)
    valueBox:SetAutoFocus(false)
    valueBox:SetFontObject(options.inputFontObject or GameFontHighlight)
    valueBox:SetMaxLetters(options.maxLetters or 5)
    valueBox:SetJustifyH("CENTER")
    valueBox:SetJustifyV("MIDDLE")
    valueBox:SetTextInsets(4, 4, 0, 0)

    local valueBoxBackground = valueBox:CreateTexture(nil, "BACKGROUND")

    valueBoxBackground:SetAllPoints(valueBox)
    valueBoxBackground:SetAtlas(INPUT_ATLAS, false)

    control.label = label
    control.slider = slider
    control.valueBox = valueBox
    control.currentValue = options.value or options.minValue
    control.callbackHandles = EventUtil.CreateCallbackHandleContainer()
    control.callbackHandles:RegisterCallback(
        slider,
        MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value)
            control:_HandleSliderValueChanged(value)
        end
    )

    valueBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    valueBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    valueBox:SetScript("OnEditFocusGained", EditBox_HighlightText)
    valueBox:SetScript("OnEditFocusLost", function(self)
        EditBox_ClearHighlight(self)
        control:_FinalizeInput()
    end)

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

function sliderMethods:_SnapValue(value)
    local options = self._libModernSettingsSliderOptions
    local stepIndex = math.floor(
        ((value - options.minValue) / options.step) + 0.5
    )

    return options.minValue + (stepIndex * options.step)
end

function sliderMethods:_GetTrackValue(value)
    local options = self._libModernSettingsSliderOptions

    return math.max(
        options.minValue,
        math.min(options.maxValue, value)
    )
end

function sliderMethods:_FormatValue(value)
    local options = self._libModernSettingsSliderOptions
    local text

    if options.inputFormatter then
        text = options.inputFormatter(value)
    else
        text = tostring(value)
    end

    return text .. options.suffix
end

function sliderMethods:_SyncValueBox(value)
    self.valueBox:SetText(self:_FormatValue(value))
    self.valueBox:SetCursorPosition(0)
end

function sliderMethods:_ParseInput()
    local options = self._libModernSettingsSliderOptions
    local text = self.valueBox:GetText()

    if options.inputParser then
        return options.inputParser(text)
    end

    local numericText = text:match("^%s*([+-]?%d*%.?%d+)")

    return numericText and tonumber(numericText) or nil
end

function sliderMethods:_HandleSliderValueChanged(value)
    if self._libModernSettingsSyncing then return end

    self:_SetCurrentValue(value, true)
end

function sliderMethods:_SetCurrentValue(value, notify)
    local normalized = self:_SnapValue(value)
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

    if type(value) ~= "number" then
        self:_SyncValueBox(self.currentValue)
        return
    end

    self:_SetCurrentValue(value, true)
end

function sliderMethods:SetValue(value)
    assert(type(value) == "number", "slider value must be a number")

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

function sliderMethods:SetControlEnabled(enabled, disabledTooltip)
    self.slider:SetEnabled(enabled == true)
    self.valueBox:SetEnabled(enabled == true)

    local color = enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR

    self.valueBox:SetTextColor(color.r, color.g, color.b)
    self.label:SetTextColor(color.r, color.g, color.b)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeSlider(slider, options)
    slider:SetValue(options.value or options.minValue)
    slider:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )
end

lib:RegisterControlType(
    "slider",
    createSlider,
    sliderMethods,
    initializeSlider
)

function lib:CreateSlider(parent, options)
    options = options or {}

    return self:CreateControl("slider", parent, options)
end
