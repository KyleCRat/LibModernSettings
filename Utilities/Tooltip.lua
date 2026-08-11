local MAJOR, MINOR = "LibModernSettings-1.0", 2
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local function normalizeTooltipOptions(options)
    if type(options) == "string" then
        return nil, options
    end

    assert(type(options) == "table", "tooltip options must be a table")

    return options.title, options.text
end

function lib:_ShowTooltip(owner, target)
    local tooltip = owner and owner._libModernSettingsTooltip

    if not tooltip then
        return
    end

    local title
    local text

    if tooltip.enabled == false then
        title = tooltip.disabledTitle
        text = tooltip.disabledText
    else
        title = tooltip.enabledTitle
        text = tooltip.enabledText
    end

    if not title and not text then
        return
    end

    GameTooltip:SetOwner(target, "ANCHOR_RIGHT")

    if title then
        GameTooltip:AddLine(title, 1, 1, 1)
    end

    if text then
        GameTooltip:AddLine(text, nil, nil, nil, true)
    end

    GameTooltip:Show()
end

function lib:AddTooltipTarget(owner, target)
    assert(owner, "tooltip owner is required")
    assert(target, "tooltip target is required")

    target._libModernSettingsTooltipOwner = owner

    if target.SetMotionScriptsWhileDisabled then
        target:SetMotionScriptsWhileDisabled(true)
    end

    if target.EnableMouse then
        target:EnableMouse(true)
    end

    if target._libModernSettingsTooltipHooked then
        return
    end

    target._libModernSettingsTooltipHooked = true
    target:HookScript("OnEnter", function(self)
        lib:_ShowTooltip(
            self._libModernSettingsTooltipOwner,
            self
        )
    end)
    target:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function lib:SetTooltip(owner, options)
    local title, text = normalizeTooltipOptions(options)
    local tooltip = owner._libModernSettingsTooltip or {}

    tooltip.enabledTitle = title
    tooltip.enabledText = text
    tooltip.enabled = tooltip.enabled ~= false
    owner._libModernSettingsTooltip = tooltip

    self:AddTooltipTarget(owner, owner)
end

function lib:SetControlTooltipEnabled(owner, enabled, disabledOptions)
    local tooltip = owner._libModernSettingsTooltip or {}

    tooltip.enabled = enabled == true

    if disabledOptions ~= nil then
        tooltip.disabledTitle, tooltip.disabledText =
            normalizeTooltipOptions(disabledOptions)
    end

    owner._libModernSettingsTooltip = tooltip
    self:AddTooltipTarget(owner, owner)
end
