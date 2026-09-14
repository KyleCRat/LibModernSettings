local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Layouts/Control", MINOR) then
    return
end

local DEFAULT_STACKED_GAP = 7
local LAYOUT_SIZE_EPSILON = 0.001

-- Resolved frame edges can differ slightly from the requested dimensions.
function lib:_LayoutSizeMatches(measured, expected)
    return expected ~= nil and ApproximatelyEqual(measured, expected, LAYOUT_SIZE_EPSILON)
end

function lib:_ApplyInputWidth(control, width)
    control._libModernSettingsUpdatingLayout = true
    control:SetWidth(width)
    control._libModernSettingsUpdatingLayout = nil
end

function lib:_ApplyFixedControlSize(control, width, height)
    local previous = control._libModernSettingsAppliedSize
    if previous then
        if not self:_LayoutSizeMatches(control:GetWidth(), previous.width) then
            previous.widthOverride = control:GetWidth()
        end
        if not self:_LayoutSizeMatches(control:GetHeight(), previous.height) then
            previous.heightOverride = control:GetHeight()
        end
    else
        previous = {}
        control._libModernSettingsAppliedSize = previous
    end

    control:SetSize(previous.widthOverride or width, previous.heightOverride or height)
    previous.width, previous.height = control:GetWidth(), control:GetHeight()
end

-- Retain direct native font changes as well as constructor overrides. Keeping
-- the last library-applied font lets later embeds replace defaults only.
function lib:_ApplyDefaultFont(region, fontObject)
    local previous = region._libModernSettingsAppliedFont
    if previous and region:GetFontObject() ~= previous then
        return
    end

    region:SetFontObject(fontObject)
    region._libModernSettingsAppliedFont = region:GetFontObject()
end

local BUTTON_FONT_STATES = { "Normal", "Highlight", "Disabled" }

function lib:_ApplyButtonFonts(button, normal, highlight, disabled)
    local fonts = { normal, highlight, disabled }
    local previous = button._libModernSettingsAppliedFonts or {}
    button._libModernSettingsAppliedFonts = previous
    for index, state in ipairs(BUTTON_FONT_STATES) do
        local getter = button["Get" .. state .. "FontObject"]
        if not previous[index] or getter(button) == previous[index] then
            button["Set" .. state .. "FontObject"](button, fonts[index])
            previous[index] = getter(button)
        end
    end
end

-- Shared by built-in labels and stacked Fields. Offsets describe frames, not art.
function lib:_LayoutStackedLabel(owner, label, input, options)
    local gap = options.gap or DEFAULT_STACKED_GAP
    local topInset = options.contentTopInset or 0

    label:SetHeight(options.labelHeight or label:GetStringHeight())
    label:SetJustifyV("TOP")
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
    input:ClearAllPoints()
    input:SetPoint(
        "TOPLEFT", label, "BOTTOMLEFT", options.inputOffsetX or 0,
        topInset - gap
    )

    return label:GetHeight() + gap + input:GetHeight() - topInset
end

function lib:_RefreshControlLayout(control, layout)
    if control._libModernSettingsUpdatingLayout then
        return
    end

    control._libModernSettingsUpdatingLayout = true
    local height = layout(control)

    control:SetHeight(control._libModernSettingsExplicitHeight or height)
    control._libModernSettingsLayoutWidth = control:GetWidth()
    control._libModernSettingsLayoutHeight = control:GetHeight()
    control._libModernSettingsUpdatingLayout = nil
end

local function onControlSizeChanged(control, width, height)
    if control._libModernSettingsUpdatingLayout then
        return
    end
    local widthChanged = not lib:_LayoutSizeMatches(width, control._libModernSettingsLayoutWidth)
    local heightChanged = not lib:_LayoutSizeMatches(height, control._libModernSettingsLayoutHeight)
    if not widthChanged and not heightChanged then
        return
    end

    -- A native SetHeight/SetSize is an explicit height override, not an auto-fit.
    if heightChanged then
        control._libModernSettingsExplicitHeight = height
        if control._libModernSettingsAppearanceOptions then
            control._libModernSettingsAppearanceOptions.height = height
        end
    end
    if widthChanged and control._libModernSettingsAppearanceOptions then
        control._libModernSettingsAppearanceOptions.width = width
    end

    control:RefreshLayout()
end

function lib:_WatchControlSize(control)
    if control._libModernSettingsLayoutHooked then
        return
    end

    control._libModernSettingsLayoutHooked = true
    control:HookScript("OnSizeChanged", onControlSizeChanged)
end

function lib:_SetControlWidth(width)
    assert(
        type(width) == "number" and width > 0,
        "control width must be a positive number"
    )
    self:SetWidth(width)
    -- Keep the explicit sizing method synchronous even before native layout resolves.
    onControlSizeChanged(self, self:GetWidth(), self:GetHeight())
end

function lib:_SetControlHeight(height)
    assert(
        height == nil or (type(height) == "number" and height > 0),
        "control height must be a positive number or nil"
    )
    self._libModernSettingsExplicitHeight = height
    if self._libModernSettingsAppearanceOptions then
        self._libModernSettingsAppearanceOptions.height = height
    end
    self:RefreshLayout()
end
