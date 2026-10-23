local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/KeyboardNavigation", MINOR)
then
    return
end

local KEY_ACTIONS = {
    TAB = "navigate",
    ENTER = "activate",
    SPACE = "activate",
    ESCAPE = "dismiss",
    UP = "previous",
    DOWN = "next",
}

local ACTION_DIRECTIONS = {
    previous = -1,
    next = 1,
}

function lib:_CreateNavigationContext(source, direction)
    return {
        source = source,
        direction = direction,
        modifiers = {
            shift = IsShiftKeyDown(),
            control = IsControlKeyDown(),
            alt = IsAltKeyDown(),
            meta = IsMetaKeyDown(),
        },
    }
end

function lib:_HandleNavigationKey(control, key)
    local action = KEY_ACTIONS[key]

    if not action then return false end

    return control:_HandleNavigationAction(
        action,
        self:_CreateNavigationContext("keyboard", ACTION_DIRECTIONS[action])
    )
end

local function isActive(control)
    if not control or not control:IsVisible() then return false end

    local input = control:_GetTabInput()
    return input and input:IsVisible() and input:IsEnabled()
end

local function setHighlight(control, focused)
    if control then control:_SetNavigationHighlight(focused) end
end

function lib:_ClearNavigationFocus(control)
    local frame = self._navigationKeyboardFrame

    if not frame or (control and frame.control ~= control) then return end

    local previous = frame.control
    frame.control = nil
    frame.owner = nil
    frame:Hide()
    frame:SetParent(UIParent)
    frame:ClearAllPoints()
    setHighlight(previous, false)
end

function lib:_RefreshNavigationKeyboard()
    local frame = self._navigationKeyboardFrame

    if not frame then return end

    if InCombatLockdown() then
        -- Resume an eligible control's keyboard focus after combat.
        frame.suspended = true
        frame:Hide()
        frame.suspended = nil
        setHighlight(frame.control, false)
        return
    end

    if not isActive(frame.control) or GetCurrentKeyBoardFocus() then
        self:_ClearNavigationFocus()
        return
    end

    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    setHighlight(frame.control, true)
    frame:Show()
end

local function isMouseInside(frame)
    local foci = GetMouseFoci()
    return DoesAncestryIncludeAny(frame.owner, foci)
        or DoesAncestryIncludeAny(frame.control, foci)
end

local function configureKeyboard(frame)
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    frame:SetScript("OnHide", function(self)
        if self.control and not self.suspended then
            lib:_ClearNavigationFocus()
        end
    end)
    frame:SetScript("OnEvent", function(self, event)
        if event == "GLOBAL_MOUSE_DOWN" then
            if self.control and not isMouseInside(self) then
                lib:_ClearNavigationFocus()
            end
        else
            lib:_RefreshNavigationKeyboard()
        end
    end)
    frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            lib:_RefreshNavigationKeyboard()
            return
        end

        if not isActive(self.control) then
            self:SetPropagateKeyboardInput(true)
            lib:_ClearNavigationFocus()
            return
        end

        if GetCurrentKeyBoardFocus() then
            self:SetPropagateKeyboardInput(true)
            return
        end

        local handled = lib:_HandleNavigationKey(self.control, key)
        -- Activation can hide/disable a control or open an edit dialog. Tab can
        -- transfer this same keyboard frame to another control or native menu.
        if not isActive(self.control) or GetCurrentKeyBoardFocus() then
            lib:_ClearNavigationFocus()
        end

        self:SetPropagateKeyboardInput(not handled)
    end)
end

function lib:_SetNavigationFocus(control, owner)
    self:_ClearNavigationFocus()

    if
        InCombatLockdown()
        or not isActive(control)
        or GetCurrentKeyBoardFocus()
    then
        return
    end

    local frame = self._navigationKeyboardFrame

    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        self._navigationKeyboardFrame = frame
        configureKeyboard(frame)
    end

    frame.control = control
    frame.owner = owner
    frame:SetParent(owner)
    frame:SetAllPoints(owner)
    frame:SetFrameLevel(owner:GetFrameLevel() + 1)
    self:_RefreshNavigationKeyboard()
end

-- Reuse the keyboard frame when upgrading an embed with dropdown-only navigation.
lib._navigationKeyboardFrame = lib._navigationKeyboardFrame
    or lib._dropdownKeyboardFrame
lib._dropdownKeyboardFrame = nil

if lib._navigationKeyboardFrame then
    local frame = lib._navigationKeyboardFrame
    frame.owner = frame.owner or frame:GetParent()
    configureKeyboard(frame)
end
