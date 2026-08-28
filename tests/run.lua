local libraries = {}
local minors = {}

LibStub = {}

function LibStub:NewLibrary(major, minor)
    local oldMinor = minors[major]

    if oldMinor and oldMinor >= minor then
        return
    end

    minors[major] = minor
    libraries[major] = libraries[major] or {}

    return libraries[major], oldMinor
end

function LibStub:GetLibrary(major, silent)
    if not libraries[major] and not silent then
        error("missing library " .. tostring(major), 2)
    end

    return libraries[major], minors[major]
end

setmetatable(LibStub, { __call = LibStub.GetLibrary })

dofile("LibModernSettings-1.0.lua")

local lib = LibStub("LibModernSettings-1.0")

assert(lib:IsControlTypeRegistered("example") == false)

local function factory(parent, options)
    return {
        parent = parent,
        initialValue = options.value,
    }
end

lib:RegisterControlType("example", factory, {
    SetValue = function(self, value)
        self.value = "first:" .. value
    end,
})

local control = lib:CreateControl("example", "parent", { value = "initial" })

assert(control.parent == "parent")
assert(control.initialValue == "initial")
control:SetValue("one")
assert(control.value == "first:one")

lib:RegisterControlType("example", factory, {
    SetValue = function(self, value)
        self.value = "updated:" .. value
    end,
    GetValue = function(self)
        return self.value
    end,
})

control:SetValue("two")
assert(control:GetValue() == "updated:two")

lib:RegisterControlType("alpha", factory, {})

local controlTypes = lib:GetRegisteredControlTypes()

assert(controlTypes[1] == "alpha")
assert(controlTypes[2] == "example")

local succeeded = pcall(function()
    lib:CreateControl("missing", nil, {})
end)

assert(succeeded == false)

print("LibModernSettings core tests passed")

dofile("tests/controls.lua")
dofile("tests/load_order.lua")
