local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/ControlNavigation", MINOR)
then
    return
end

local function getNavigation(control)
    return lib._controlTypes[control._libModernSettingsControlType].navigation
end

local function getInput(control, navigation)
    if navigation.input then return navigation.input(control) end

    return control
end

local DEFAULT_ACTIONS = {
    navigate = function(control, context)
        return lib:_NavigateTab(control, context)
    end,
    dismiss = function(control)
        control:_ReleaseTabFocus()
        return true
    end,
}

lib._buttonNavigationActions = {
    activate = function(control)
        control:Click("LeftButton")
        return true
    end,
}

function lib._SetButtonNavigationHighlight(control, focused)
    if focused then
        control:LockHighlight()
    else
        control:UnlockHighlight()
    end
end

local navigationMethods = {}
lib._navigationControlMethods = navigationMethods

function navigationMethods:_GetTabInput()
    local navigation = getNavigation(self)

    if navigation.mode == "editBox" or not InCombatLockdown() then
        return getInput(self, navigation)
    end
end

function navigationMethods:_FocusForTab()
    local navigation = getNavigation(self)
    local input = self:_GetTabInput()

    if
        not input
        or not self:IsVisible()
        or not input:IsVisible()
        or not input:IsEnabled()
    then
        return
    end

    if navigation.focus then
        navigation.focus(self)
    elseif navigation.mode == "editBox" then
        input:SetFocus()
        input:HighlightText()
    else
        lib:_SetNavigationFocus(self, input)
    end
end

function navigationMethods:_ReleaseTabFocus()
    local navigation = getNavigation(self)
    lib:_ClearNavigationFocus(self)

    if navigation.release then return navigation.release(self) end

    if navigation.mode == "editBox" then
        local input = getInput(self, navigation)
        input:ClearFocus()
        local _, committed = lib:_FlushPendingEditBoxCommit(input)
        return committed ~= false
    end
end

function navigationMethods:_HandleNavigationAction(action, context)
    local navigation = getNavigation(self)
    local handler = navigation.actions[action] or DEFAULT_ACTIONS[action]
    return handler and handler(self, context) == true or false
end

function navigationMethods:_RefreshNavigationHover()
    local navigation = getNavigation(self)

    if navigation.hover then
        local input = getInput(self, navigation)
        local highlighted = input:IsEnabled()
            and (
                self._libModernSettingsMouseOver
                or self._libModernSettingsKeyboardFocused
            )
        navigation.hover(self, highlighted == true)
    end
end

function navigationMethods:_SetNavigationHighlight(focused)
    local navigation = getNavigation(self)
    self._libModernSettingsKeyboardFocused = focused

    if navigation.highlight then navigation.highlight(self, focused) end

    self:_RefreshNavigationHover()
end

local function onEditBoxTab(input)
    if
        not lib:_HandleNavigationKey(
            input._libModernSettingsNavigationControl,
            "TAB"
        )
    then
        EditBox_OnTabPressed(input)
    end
end

local function onEditBoxArrow(input, key)
    lib:_HandleNavigationKey(input._libModernSettingsNavigationControl, key)
end

local function releaseInputFocus(input)
    local control = input._libModernSettingsNavigationControl
    control._libModernSettingsMouseOver = nil
    control:_ReleaseTabFocus()
    control:_RefreshNavigationHover()
end

function lib:_ConfigureControlNavigation(control)
    local navigation = getNavigation(control)
    local input = getInput(control, navigation)
    input._libModernSettingsNavigationControl = control

    if navigation.mode == "editBox" then
        input:SetScript("OnTabPressed", onEditBoxTab)

        if navigation.actions.previous or navigation.actions.next then
            input:SetScript("OnArrowPressed", onEditBoxArrow)
        end

        if not input._libModernSettingsEditNavigationHooked then
            input._libModernSettingsEditNavigationHooked = true
            input:HookScript("OnEditFocusGained", function()
                lib:_ClearNavigationFocus()
            end)
        end

        return
    end

    if not input._libModernSettingsInputNavigationHooked then
        input._libModernSettingsInputNavigationHooked = true
        input:HookScript("OnHide", releaseInputFocus)

        if input:HasScript("OnDisable") then
            input:HookScript("OnDisable", releaseInputFocus)
        end

        input:HookScript("OnEnter", function(self)
            local owner = self._libModernSettingsNavigationControl
            owner._libModernSettingsMouseOver = true
            owner:_RefreshNavigationHover()
        end)
        input:HookScript("OnLeave", function(self)
            local owner = self._libModernSettingsNavigationControl
            owner._libModernSettingsMouseOver = nil
            owner:_RefreshNavigationHover()
        end)
    end

    control._libModernSettingsMouseOver =
        DoesAncestryIncludeAny(input, GetMouseFoci())
    local keyboard = self._navigationKeyboardFrame
    control:_SetNavigationHighlight(
        keyboard and keyboard.control == control and keyboard:IsShown() or false
    )
end

function lib:RegisterControlNavigation(controlType, options)
    local definition = self._controlTypes[controlType]
    assert(definition, "navigation requires a registered control type")
    assert(type(options) == "table", "navigation options must be a table")
    assert(
        options.mode == nil
            or options.mode == "keyboard"
            or options.mode == "editBox",
        "navigation mode must be 'keyboard' or 'editBox'"
    )
    assert(
        options.actions == nil or type(options.actions) == "table",
        "navigation actions must be a table or nil"
    )

    local navigation = {
        mode = options.mode or "keyboard",
        actions = {},
    }

    for _, name in ipairs({ "input", "focus", "release", "highlight", "hover" }) do
        local callback = options[name]
        assert(
            callback == nil or type(callback) == "function",
            "navigation " .. name .. " must be a function or nil"
        )
        navigation[name] = callback
    end

    for action, handler in pairs(options.actions or {}) do
        assert(
            type(action) == "string" and type(handler) == "function",
            "navigation actions must map names to functions"
        )
        navigation.actions[action] = handler
    end

    definition.navigation = navigation

    for control, instanceType in pairs(self._controlInstances) do
        if instanceType == controlType then
            self:_InstallControlMethods(control, definition)
            self:_ConfigureControlNavigation(control)
        end
    end
end

-- Custom types may belong to an addon that has already finished loading.
for control, controlType in pairs(lib._controlInstances) do
    local definition = lib._controlTypes[controlType]

    if definition.navigation then
        lib:_InstallControlMethods(control, definition)
        lib:_ConfigureControlNavigation(control)
    end
end
