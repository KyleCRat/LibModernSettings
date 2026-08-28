local MAJOR = "LibModernSettings-1.0"

local function createLibStub()
    local libraries = {}
    local minors = {}
    local libStub = {}

    function libStub:NewLibrary(major, minor)
        local oldMinor = minors[major]

        if oldMinor and oldMinor >= minor then
            return
        end

        minors[major] = minor
        libraries[major] = libraries[major] or {}
        return libraries[major], oldMinor
    end

    function libStub:GetLibrary(major, silent)
        if not libraries[major] and not silent then
            error("missing library " .. tostring(major), 2)
        end

        return libraries[major], minors[major]
    end

    setmetatable(libStub, { __call = libStub.GetLibrary })
    return libStub
end

local function readMainSource()
    local file = assert(io.open("LibModernSettings-1.0.lua", "rb"))
    local source = file:read("*a")

    file:close()
    return source
end

local MAIN_SOURCE = readMainSource()
local CURRENT_MINOR = assert(tonumber(MAIN_SOURCE:match(
    'local MAJOR, MINOR = "LibModernSettings%-1%.0", (%d+)'
)))
local PREVIOUS_MINOR = CURRENT_MINOR - 1

assert(PREVIOUS_MINOR > 0)

local function loadLibraryMinor(environment, minor)
    local source
    local replacements

    source, replacements = MAIN_SOURCE:gsub(
        '(local MAJOR, MINOR = "LibModernSettings%-1%.0", )%d+',
        "%1" .. tostring(minor),
        1
    )
    assert(replacements == 1)

    local chunk, errorMessage = loadstring(
        source,
        "@LibModernSettings-1.0.lua"
    )

    assert(chunk, errorMessage)
    setfenv(chunk, environment)
    chunk()
end

local function createEnvironment()
    local environment = {
        LibStub = createLibStub(),
    }

    setmetatable(environment, { __index = _G })
    return environment
end

local function registerExampleControl(environment, minor, prefix)
    local lib = environment.LibStub(MAJOR, true)

    if not lib or lib._implementationMinor ~= minor then
        return false
    end

    lib:RegisterControlType("example", function(_, options)
        return { initialValue = options.value }
    end, {
        SetValue = function(self, value)
            self.value = prefix .. ":" .. value
        end,
    })
    return true
end

local function testOldFirst()
    local environment = createEnvironment()

    loadLibraryMinor(environment, PREVIOUS_MINOR)
    assert(registerExampleControl(
        environment,
        PREVIOUS_MINOR,
        "old"
    ) == true)

    local lib = environment.LibStub(MAJOR)
    local control = lib:CreateControl("example", nil, {
        value = "initial",
    })

    control:SetValue("before")
    assert(control.value == "old:before")

    loadLibraryMinor(environment, CURRENT_MINOR)
    assert(environment.LibStub(MAJOR) == lib)
    assert(lib._implementationMinor == CURRENT_MINOR)
    assert(registerExampleControl(
        environment,
        CURRENT_MINOR,
        "new"
    ) == true)

    control:SetValue("after")
    assert(control.value == "new:after")
    assert(registerExampleControl(
        environment,
        PREVIOUS_MINOR,
        "late-old"
    ) == false)
end

local function testNewFirst()
    local environment = createEnvironment()

    loadLibraryMinor(environment, CURRENT_MINOR)
    assert(registerExampleControl(
        environment,
        CURRENT_MINOR,
        "new"
    ) == true)

    local lib = environment.LibStub(MAJOR)
    local control = lib:CreateControl("example", nil, {})

    loadLibraryMinor(environment, PREVIOUS_MINOR)
    assert(environment.LibStub(MAJOR) == lib)
    assert(lib._implementationMinor == CURRENT_MINOR)
    assert(registerExampleControl(
        environment,
        PREVIOUS_MINOR,
        "late-old"
    ) == false)

    control:SetValue("after")
    assert(control.value == "new:after")
end

testOldFirst()
testNewFirst()

print("LibModernSettings mixed load-order tests passed")
