local MAJOR, MINOR = "LibModernSettings-1.0", 10
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Color", MINOR) then
    return
end

local Color = lib._colorUtils
local SIZE = 34
local GAP = 4
local MODES = { "class", "accent", "custom" }
local MODE_LABELS = { class = "Class color", accent = "Accent color", custom = "Custom color" }

local function createSwatch(parent, options)
    local button = CreateFrame("Button", nil, parent)
    local size = options.size or SIZE
    button:SetSize(size, size)
    for method, state in pairs({
        SetNormalTexture = "normal",
        SetPushedTexture = "pressed",
        SetDisabledTexture = "disabled",
    }) do
        local texture = lib:_CreateAtlasTexture(button, "BACKGROUND",
            "common-button-tertiary-square-" .. state)
        button[method](button, texture)
    end
    button.selection = lib:_CreateAtlasTexture(button, "BORDER", "common-button-tertiary-square-selected")
    button.selection:Hide()
    button.swatch = button:CreateTexture(nil, "OVERLAY")
    button.onClick = options.onClick
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        lib:_FlushPendingEditBoxCommits()
        if self.onClick then
            self.onClick(mouseButton)
        end
    end)
    return button
end

local swatchMethods = {}

function swatchMethods:SetValue(value)
    self.color = Color.Copy(value)
    self.swatch:SetColorTexture(self.color.r, self.color.g, self.color.b, self.color.a)
end

function swatchMethods:SetSelected(selected)
    self.selection:SetShown(selected == true)
end

function swatchMethods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)
    self.swatch:SetAlpha(enabled and 1 or 0.35)
    self.selection:SetAlpha(enabled and 1 or 0.35)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function refreshSwatchAppearance(button)
    if not button.hover then
        -- Retire the native highlight when updating an existing swatch.
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetTexture(nil)
            highlight:Hide()
            button:UnlockHighlight()
        end
        button.hover = lib:_CreateAtlasTexture(button, "OVERLAY", "common-button-tertiary-square-hover")
        button.hover:Hide()
    end
    button.swatchMask = lib:ApplyTertiarySquareArtwork(button, button.swatch, button:GetWidth())
end

lib:RegisterControlType("_colorSwatch", createSwatch, swatchMethods, nil, refreshSwatchAppearance)
lib:RegisterControlNavigation("_colorSwatch", {
    actions = lib._buttonNavigationActions,
    hover = function(control, highlighted)
        control.hover:SetShown(highlighted)
    end,
})

function lib:_CreateColorSwatch(parent, options)
    return self:CreateControl("_colorSwatch", parent, options)
end

local function resolveSource(control, mode)
    local source = control.sources[mode]
    if source == true and mode == "class" then
        local _, class = UnitClass("player")
        source = C_ClassColor.GetClassColor(class)
    elseif type(source) == "function" then
        source = source()
    end
    return Color.Copy(source, control.hasOpacity)
end

local function layoutColor(control)
    local x = 0
    for _, mode in ipairs(MODES) do
        local button = control.buttons[mode]
        if button then
            button:ClearAllPoints()
            button:SetPoint("LEFT", control, "LEFT", x, 0)
            x = x + SIZE + GAP
        end
    end
    control.label:ClearAllPoints()
    control.label:SetPoint("LEFT", control, "LEFT", x, 0)
    control.label:SetWidth(math.max(1, control:GetWidth() - x))
    control.buttons.custom:SetHitRectInsets(0, -math.max(0, control:GetWidth() - x + GAP), 0, 0)
    return SIZE
end

local function createColor(parent, options)
    assert(options.onChanged == nil or type(options.onChanged) == "function", "onChanged must be a function or nil")
    for _, key in ipairs({ "classColor", "accentColor" }) do
        local source = options[key]
        assert(source == nil or type(source) == "table" or type(source) == "function"
            or (key == "classColor" and source == true), key .. " must be a color or resolver function")
    end
    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(options.width or 270, SIZE)
    control.hasOpacity = options.hasOpacity == true
    control.sources = { class = options.classColor, accent = options.accentColor }
    control.palette = options.palette or lib._defaultColorPalette
    assert(type(control.palette) == "table" and type(control.palette.GetColors) == "function"
        and type(control.palette.Record) == "function" and type(control.palette.ToggleFavorite) == "function",
        "palette must provide GetColors, Record, and ToggleFavorite")
    control.onChanged = options.onChanged
    control.buttons = {}
    for _, mode in ipairs(MODES) do
        if mode == "custom" or control.sources[mode] then
            local button = lib:_CreateColorSwatch(control, {
                onClick = function(mouseButton)
                    if mouseButton == "LeftButton" then
                        control:_SelectMode(mode)
                    end
                end,
            })
            control.buttons[mode] = button
            lib:SetTooltip(button, { title = MODE_LABELS[mode], text = options.tooltip })
        end
    end
    control.label = lib:CreateText(control, {
        text = options.label or "Color",
        fontObject = options.fontObject or GameFontHighlight,
        justifyV = "MIDDLE",
    })
    control.label:SetWordWrap(false)
    control.label:SetMaxLines(1)
    control:SetScript("OnHide", function(self)
        self:ClosePicker()
    end)
    lib:_WatchControlSize(control)
    return control
end

local colorMethods = {}
colorMethods.SetControlWidth = lib._SetControlWidth
colorMethods.SetControlHeight = lib._SetControlHeight

function colorMethods:RefreshLayout()
    lib:_RefreshControlLayout(self, layoutColor)
end

function colorMethods:GetValue()
    local value = self.mode == "custom" and Color.Copy(self.value, self.hasOpacity) or resolveSource(self, self.mode)
    value.mode = self.mode
    if self.mode ~= "custom" then
        value.custom = Color.Copy(self.value, self.hasOpacity)
    end
    return value
end

function colorMethods:SetValue(value)
    local mode = value.mode or "custom"
    assert(self.buttons[mode], "color mode must be enabled on this input")
    local copy = Color.Copy(value, self.hasOpacity)
    if mode ~= "custom" and value.custom then
        copy = Color.Copy(value.custom, self.hasOpacity)
    end
    self:ClosePicker()
    self.mode = mode
    self.value = copy
    self:RefreshColors()
end

function colorMethods:RefreshColors()
    for mode, button in pairs(self.buttons) do
        button:SetValue(mode == "custom" and self.value or resolveSource(self, mode))
        button:SetSelected(mode == self.mode)
    end
end

function colorMethods:_NotifyColorChanged()
    self:RefreshColors()
    if self.onChanged then
        self.onChanged(self:GetValue())
    end
end

function colorMethods:_SelectMode(mode)
    self:ClosePicker()
    local changed = self.mode ~= mode
    self.mode = mode
    if changed or mode ~= "custom" then
        self:_NotifyColorChanged()
    end
    if mode == "custom" then
        self:OpenPicker()
    end
end

function colorMethods:_AcceptPickerColor(color)
    self.mode = "custom"
    self.value = Color.Copy(color, self.hasOpacity)
    self:_NotifyColorChanged()
end

function colorMethods:OpenPicker()
    if not self.enabled or not self:IsVisible() then
        return
    end
    if self.mode ~= "custom" then
        self:_SelectMode("custom")
        return
    end
    lib:_OpenColorPicker(self)
end

function colorMethods:ClosePicker()
    lib:_CloseColorPicker(self)
end

function colorMethods:SetOnChanged(callback)
    assert(callback == nil or type(callback) == "function", "onChanged must be a function or nil")
    self.onChanged = callback
end

function colorMethods:SetControlEnabled(enabled, disabledTooltip)
    self.enabled = enabled == true
    if not self.enabled then
        self:ClosePicker()
    end
    for _, button in pairs(self.buttons) do
        button:SetControlEnabled(self.enabled, disabledTooltip)
    end
    local color = self.enabled and HIGHLIGHT_FONT_COLOR or GRAY_FONT_COLOR
    self.label:SetTextColor(color.r, color.g, color.b)
end

local function initializeColor(control, options)
    control:SetValue(options.value or { r = 1, g = 1, b = 1 })
    control:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)
end

local function refreshColorAppearance(control, options)
    lib:_ApplyDefaultFont(control.label, options.fontObject or GameFontHighlight)
    control:RefreshLayout()
end

lib:RegisterControlType("color", createColor, colorMethods, initializeColor, refreshColorAppearance)

function lib:CreateColor(parent, options)
    return self:CreateControl("color", parent, options or {})
end
