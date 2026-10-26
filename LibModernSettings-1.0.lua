local addonName = ...
local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

-- Owned media follows the selected standalone package or canonical embed.
local libraryFolder = addonName == MAJOR and "" or "Libs\\" .. MAJOR .. "\\"
local texturePath = "Interface\\AddOns\\"
    .. addonName
    .. "\\"
    .. libraryFolder
    .. "Media\\Textures\\"
lib._tertiarySquareMask = texturePath
    .. "common-button-tertiary-square-mask.tga"
lib._defaultIcons = {
    caretUp = texturePath .. "Vertex-Caret-Up.tga",
    caretDown = texturePath .. "Vertex-Caret-Down.tga",
    search = texturePath .. "Vertex-Search.tga",
    close = texturePath .. "Vertex-Close.tga",
    plus = texturePath .. "Vertex-Plus.tga",
}

lib._implementationMinor = MINOR
lib._loadedModules = lib._loadedModules or {}
lib._controlTypes = lib._controlTypes or {}
lib._controlInstances = lib._controlInstances
    or setmetatable({}, { __mode = "k" })
lib._methodDispatchers = lib._methodDispatchers or {}

-- Module files retain their version guard and run once per accepted revision.
function lib:_BeginModule(moduleName, minor)
    if self._loadedModules[moduleName] == minor then return false end

    self._loadedModules[moduleName] = minor
    return true
end

local function getMethodDispatcher(methodName)
    local dispatcher = lib._methodDispatchers[methodName]

    if dispatcher then return dispatcher end

    dispatcher = function(control, ...)
        local controlType = control._libModernSettingsControlType
        local definition = lib._controlTypes[controlType]
        local navigationMethod = definition
            and definition.navigation
            and lib._navigationControlMethods[methodName]
        local method = navigationMethod
            or (definition and definition.methods[methodName])

        if not method then
            error(
                ("LibModernSettings control type %q has no method %q"):format(
                    tostring(controlType),
                    methodName
                ),
                2
            )
        end

        return method(control, ...)
    end

    lib._methodDispatchers[methodName] = dispatcher

    return dispatcher
end

function lib:_InstallControlMethods(control, definition)
    for methodName in pairs(definition.methods) do
        control[methodName] = getMethodDispatcher(methodName)
    end

    if definition.navigation then
        for methodName in pairs(self._navigationControlMethods) do
            control[methodName] = getMethodDispatcher(methodName)
        end
    end
end

function lib:_RefreshControlAppearance(control)
    local definition = self._controlTypes[control._libModernSettingsControlType]
    local options = control._libModernSettingsAppearanceOptions

    if
        not options
        or not definition.refreshAppearance
        or control._libModernSettingsRefreshingAppearance
    then
        return
    end

    control._libModernSettingsRefreshingAppearance = true
    definition.refreshAppearance(control, options)
    control._libModernSettingsRefreshingAppearance = nil

    if definition.navigation then control:_RefreshNavigationHover() end
end

function lib:RegisterControlType(
    controlType,
    factory,
    methods,
    initializer,
    refreshAppearance
)
    assert(
        type(controlType) == "string" and controlType ~= "",
        "controlType must be a non-empty string"
    )
    assert(type(factory) == "function", "factory must be a function")
    assert(type(methods) == "table", "methods must be a table")
    assert(
        initializer == nil or type(initializer) == "function",
        "initializer must be a function or nil"
    )
    assert(
        refreshAppearance == nil or type(refreshAppearance) == "function",
        "refreshAppearance must be a function or nil"
    )

    local definition = self._controlTypes[controlType]

    if not definition then
        definition = { methods = {} }
        self._controlTypes[controlType] = definition
    end

    definition.factory = factory
    definition.initializer = initializer
    definition.refreshAppearance = refreshAppearance

    for methodName in pairs(definition.methods) do
        definition.methods[methodName] = nil
    end

    for methodName, method in pairs(methods) do
        assert(
            type(methodName) == "string" and type(method) == "function",
            "control methods must use string keys and function values"
        )
        definition.methods[methodName] = method
    end

    for control, instanceType in pairs(self._controlInstances) do
        if instanceType == controlType then
            self:_InstallControlMethods(control, definition)
            -- Old releases did not retain option intent. Never guess whether
            -- their measured dimensions were defaults or addon overrides.
            if
                refreshAppearance
                and control._libModernSettingsAppearanceOptions
            then
                self:_RefreshControlAppearance(control)
            end
        end
    end
end

function lib:CreateControl(controlType, parent, options)
    local definition = self._controlTypes[controlType]

    if not definition then
        error(
            ("LibModernSettings control type %q is not registered"):format(
                tostring(controlType)
            ),
            2
        )
    end

    options = options or {}
    assert(type(options) == "table", "options must be a table")

    local appearanceOptions = {}

    for key, value in pairs(options) do
        appearanceOptions[key] = value
    end

    local control = definition.factory(parent, options)

    if not control then
        error(
            ("LibModernSettings control factory %q returned no control"):format(
                controlType
            ),
            2
        )
    end

    control._libModernSettingsControlType = controlType
    control._libModernSettingsAppearanceOptions = appearanceOptions
    self._controlInstances[control] = controlType
    self:_InstallControlMethods(control, definition)

    if definition.refreshAppearance then
        self:_RefreshControlAppearance(control)
    end

    if definition.initializer then definition.initializer(control, options) end

    if definition.navigation then self:_ConfigureControlNavigation(control) end

    return control
end

function lib:IsControlTypeRegistered(controlType)
    return self._controlTypes[controlType] ~= nil
end

function lib:GetRegisteredControlTypes()
    local controlTypes = {}

    for controlType in pairs(self._controlTypes) do
        controlTypes[#controlTypes + 1] = controlType
    end

    table.sort(controlTypes)

    return controlTypes
end
