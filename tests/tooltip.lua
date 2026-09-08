local lib = LibStub("LibModernSettings-1.0")

local tooltip = {
    hideCount = 0,
    lines = {},
}

function tooltip:SetOwner(owner, anchor)
    self.owner = owner
    self.anchor = anchor
    self.lines = {}
end

function tooltip:GetOwner()
    return self.owner
end

function tooltip:AddLine(text, ...)
    self.lines[#self.lines + 1] = {
        text = text,
        colors = { ... },
    }
end

function tooltip:Show()
    self.shown = true
end

function tooltip:Hide()
    self.owner = nil
    self.shown = false
    self.hideCount = self.hideCount + 1
end

GameTooltip = tooltip

local function makeTarget()
    local target = { scripts = {} }

    function target:SetMotionScriptsWhileDisabled(enabled)
        self.motionScriptsWhileDisabled = enabled
    end

    function target:EnableMouse(enabled)
        self.mouseEnabled = enabled
    end

    function target:HookScript(scriptName, callback)
        self.scripts[scriptName] = callback
    end

    return target
end

dofile("Utilities/Tooltip.lua")

local owner = makeTarget()

lib:SetTooltip(owner, {
    title = "Obtained",
    text = "Mark the item obtained.",
})

assert(owner.motionScriptsWhileDisabled == true)
assert(owner.mouseEnabled == true)
assert(type(owner.scripts.OnEnter) == "function")
assert(type(owner.scripts.OnLeave) == "function")

owner.scripts.OnEnter(owner)
assert(tooltip:GetOwner() == owner)
assert(tooltip.anchor == "ANCHOR_RIGHT")
assert(tooltip.lines[1].text == "Obtained")
assert(tooltip.lines[2].text == "Mark the item obtained.")

lib:SetTooltip(owner, {
    title = "Obtained",
    text = "Mark the item not obtained.",
})

local hideCount = tooltip.hideCount

assert(lib:RefreshTooltip(owner) == true)
assert(tooltip.hideCount == hideCount + 1)
assert(tooltip:GetOwner() == owner)
assert(tooltip.lines[2].text == "Mark the item not obtained.")

local childTarget = makeTarget()

lib:AddTooltipTarget(owner, childTarget)
childTarget.scripts.OnEnter(childTarget)
assert(tooltip:GetOwner() == childTarget)

lib:SetTooltip(owner, {
    title = "Obtained",
    text = "Updated through a child target.",
})

assert(lib:RefreshTooltip(owner, childTarget) == true)
assert(tooltip:GetOwner() == childTarget)
assert(tooltip.lines[2].text == "Updated through a child target.")

local unrelated = makeTarget()

tooltip:SetOwner(unrelated, "ANCHOR_RIGHT")
hideCount = tooltip.hideCount
assert(lib:RefreshTooltip(owner) == false)
assert(lib:HideOwnedTooltip(owner) == false)
childTarget.scripts.OnLeave(childTarget)
assert(tooltip.hideCount == hideCount)
assert(tooltip:GetOwner() == unrelated)

tooltip:SetOwner(owner, "ANCHOR_RIGHT")
assert(lib:HideOwnedTooltip(owner) == true)
assert(tooltip:GetOwner() == nil)

local missingOwnerSucceeded = pcall(function()
    lib:RefreshTooltip(nil)
end)
local missingTargetSucceeded = pcall(function()
    lib:HideOwnedTooltip(nil)
end)

assert(missingOwnerSucceeded == false)
assert(missingTargetSucceeded == false)

print("LibModernSettings tooltip tests passed")
