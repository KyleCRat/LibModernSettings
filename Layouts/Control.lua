local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_STACKED_GAP = 7

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
    if width == control._libModernSettingsLayoutWidth
        and height == control._libModernSettingsLayoutHeight then
        return
    end

    -- A native SetHeight/SetSize is an explicit height override, not an auto-fit.
    if height ~= control._libModernSettingsLayoutHeight then
        control._libModernSettingsExplicitHeight = height
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
    self:RefreshLayout()
end
