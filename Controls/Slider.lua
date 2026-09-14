local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local INPUT_ATLAS = "common-button-tertiary-depressed-normal"
local DEFAULT_INPUT_WIDTH = 60
local INPUT_RIGHT_INSET = 2
-- MinimalSliderTemplate's track/thumb height, without the stepper wrapper's padding.
local TRACK_HEIGHT = 19

local function layoutSlider(control)
    local width = control:GetWidth()
    local slider = control.slider
    local inputRow = control.inputRow
    local valueBox = control.valueBox
    local inputGap = control._libModernSettingsInputGap
    local rowHeight = math.max(slider:GetHeight(), valueBox:GetHeight())

    control.label:SetWidth(width)
    inputRow:SetSize(width, rowHeight)
    slider:SetWidth(math.max(1, width - valueBox:GetWidth() - inputGap - INPUT_RIGHT_INSET))
    slider:ClearAllPoints()
    slider:SetPoint("LEFT", inputRow, "LEFT", 0, 0)

    if control.label:IsShown() then
        local layout = control._libModernSettingsLabelLayout

        layout.contentTopInset = (rowHeight - slider:GetHeight()) / 2
        return lib:_LayoutStackedLabel(control, control.label, inputRow, layout)
    end

    inputRow:ClearAllPoints()
    inputRow:SetPoint("LEFT", control, "LEFT", 0, 0)
    return rowHeight
end

local function finalizeSliderInput(valueBox)
    valueBox._libModernSettingsSlider:_FinalizeInput()
end

local function configureSliderInput(control)
    local valueBox = control.valueBox

    valueBox._libModernSettingsSlider = control
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
    end)
    valueBox:SetScript("OnEditFocusLost", function(self)
        self.focusTexture:Hide()
        EditBox_ClearHighlight(self)
        lib:_FinalizeEditBoxOnFocusLost(self, finalizeSliderInput)
    end)

    if valueBox:HasFocus() then
        valueBox.focusTexture:Show()
    else
        valueBox.focusTexture:Hide()
    end
end

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
    assert(
        options.height == nil or (type(options.height) == "number" and options.height > 0),
        "height must be a positive number or nil"
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
    local sliderWidth = math.max(1, width - inputWidth - inputGap - INPUT_RIGHT_INSET)
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
    local inputRow = CreateFrame("Frame", nil, control)
    local slider = CreateFrame(
        "Frame",
        nil,
        inputRow,
        "MinimalSliderWithSteppersTemplate"
    )
    slider:SetSize(sliderWidth, TRACK_HEIGHT)
    if not hasLabel then
        label:Hide()
    end

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
        inputRow,
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
    lib:_CancelPendingEditBoxCommit(self.valueBox)
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

function sliderMethods:GetContentTopInset()
    if self.label:IsShown() then
        return 0
    end

    -- The taller numeric input sets the row height; the track is centered in it.
    return (self:GetHeight() - self.slider:GetHeight()) / 2
end

function sliderMethods:SetControlEnabled(enabled, disabledTooltip)
    self.slider:SetEnabled(enabled == true)
    self.valueBox:SetEnabled(enabled == true)

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

function lib:CreateSlider(parent, options)
    options = options or {}

    return self:CreateControl("slider", parent, options)
end
