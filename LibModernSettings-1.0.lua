local MAJOR, MINOR = "LibModernSettings-1.0", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then
    return
end

lib._implementationMinor = MINOR
lib._controlTypes = lib._controlTypes or {}
lib._controlInstances = lib._controlInstances
    or setmetatable({}, { __mode = "k" })
lib._methodDispatchers = lib._methodDispatchers or {}

local function getMethodDispatcher(methodName)
    local dispatcher = lib._methodDispatchers[methodName]

    if dispatcher then
        return dispatcher
    end

    dispatcher = function(control, ...)
        local controlType = control._libModernSettingsControlType
        local definition = lib._controlTypes[controlType]
        local method = definition and definition.methods[methodName]

        if not method then
            error((
                "LibModernSettings control type %q has no method %q"
            ):format(tostring(controlType), methodName), 2)
        end

        return method(control, ...)
    end
    lib._methodDispatchers[methodName] = dispatcher

    return dispatcher
end

local function installControlMethods(control, definition)
    for methodName in pairs(definition.methods) do
        control[methodName] = getMethodDispatcher(methodName)
    end
end

function lib:RegisterControlType(controlType, factory, methods)
    assert(
        type(controlType) == "string" and controlType ~= "",
        "controlType must be a non-empty string"
    )
    assert(type(factory) == "function", "factory must be a function")
    assert(type(methods) == "table", "methods must be a table")

    local definition = self._controlTypes[controlType]

    if not definition then
        definition = { methods = {} }
        self._controlTypes[controlType] = definition
    end

    definition.factory = factory

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
            installControlMethods(control, definition)
        end
    end
end

function lib:CreateControl(controlType, parent, options)
    local definition = self._controlTypes[controlType]

    if not definition then
        error((
            "LibModernSettings control type %q is not registered"
        ):format(tostring(controlType)), 2)
    end

    options = options or {}
    assert(type(options) == "table", "options must be a table")

    local control = definition.factory(parent, options)

    if not control then
        error((
            "LibModernSettings control factory %q returned no control"
        ):format(controlType), 2)
    end

    control._libModernSettingsControlType = controlType
    self._controlInstances[control] = controlType
    installControlMethods(control, definition)

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
