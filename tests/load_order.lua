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

local function loadLibraryMinor(environment, minor, addonName)
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
    chunk(addonName or MAJOR)
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

    if not lib or lib._implementationMinor ~= minor
        or not lib:_BeginModule("Controls/Example", minor) then
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

local function testDuplicateCopy()
    local environment = createEnvironment()

    loadLibraryMinor(environment, CURRENT_MINOR)
    assert(registerExampleControl(environment, CURRENT_MINOR, "first"))
    local lib = environment.LibStub(MAJOR)
    local factory = lib._controlTypes.example.factory
    local control = lib:CreateControl("example", nil, {})

    loadLibraryMinor(environment, CURRENT_MINOR)
    assert(not registerExampleControl(environment, CURRENT_MINOR, "duplicate"))
    assert(lib._controlTypes.example.factory == factory)
    control:SetValue("after")
    assert(control.value == "first:after")

    -- A duplicate core must not suppress a module that has not loaded yet.
    assert(lib:_BeginModule("Controls/LateModule", CURRENT_MINOR))
    assert(not lib:_BeginModule("Controls/LateModule", CURRENT_MINOR))
end

testOldFirst()
testNewFirst()
testDuplicateCopy()

-- Textures belong to the accepted embed, even when another copy loads later.
do
    local environment = createEnvironment()
    loadLibraryMinor(environment, PREVIOUS_MINOR, "OlderConsumer")
    local lib = environment.LibStub(MAJOR)
    assert(lib._tertiarySquareMask == "Interface\\AddOns\\OlderConsumer\\Libs\\" .. MAJOR
        .. "\\Media\\Textures\\common-button-tertiary-square-mask.tga")

    loadLibraryMinor(environment, CURRENT_MINOR, "NewerConsumer")
    local selectedPath = "Interface\\AddOns\\NewerConsumer\\Libs\\" .. MAJOR
        .. "\\Media\\Textures\\common-button-tertiary-square-mask.tga"
    assert(lib._tertiarySquareMask == selectedPath)
    loadLibraryMinor(environment, PREVIOUS_MINOR, "LateOlderConsumer")
    loadLibraryMinor(environment, CURRENT_MINOR, "EqualConsumer")
    assert(lib._tertiarySquareMask == selectedPath)

    local standalone = createEnvironment()
    loadLibraryMinor(standalone, CURRENT_MINOR)
    assert(standalone.LibStub(MAJOR)._tertiarySquareMask == "Interface\\AddOns\\" .. MAJOR
        .. "\\Media\\Textures\\common-button-tertiary-square-mask.tga")
end

-- Picker models survive compatible embed upgrades; duplicate/older modules
-- cannot replace methods or discard histories and their catalogue metadata.
do
    local environment = createEnvironment()
    local function loadIconModule(path, minor)
        local file = assert(io.open(path, "rb"))
        local source = file:read("*a")
        file:close()
        source = source:gsub('(local MAJOR, MINOR = "LibModernSettings%-1%.0", )%d+',
            "%1" .. tostring(minor), 1)
        local chunk = assert(loadstring(source, "@" .. path))
        setfenv(chunk, environment)
        chunk()
    end
    loadLibraryMinor(environment, PREVIOUS_MINOR)
    loadIconModule("IconPicker/Model.lua", PREVIOUS_MINOR)
    local lib = environment.LibStub(MAJOR)
    local history = lib:CreateIconHistory()
    history:Record(10)
    local catalogue = lib:CreateIconCatalogue({ icons = { { texture = 10, name = "Retained" } } })
    loadIconModule("IconPicker/NameData.lua", PREVIOUS_MINOR)
    loadIconModule("IconPicker/Names.lua", PREVIOUS_MINOR)
    loadIconModule("IconPicker/Filters.lua", PREVIOUS_MINOR)
    local oldIndex = lib._iconNameIndex
    local namedCatalogue = lib:CreateIconCatalogue({
        getFilename = function()
            return "Outdated_INV_Knife_Blue"
        end,
        icons = { { texture = 6997112 }, { texture = 137008 } },
    })
    local namedEntry = namedCatalogue.entries[1]
    local markerEntry = namedCatalogue.entries[2]
    assert(namedCatalogue:Describe(namedEntry):find("outdated", 1, true))
    namedCatalogue:Describe(markerEntry)
    assert(lib._iconUtils.GetArtworkFilter("equipment", "daggers")(namedEntry, namedCatalogue))
    lib._defaultIconCatalogue = namedCatalogue
    loadLibraryMinor(environment, CURRENT_MINOR)
    loadIconModule("IconPicker/Model.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/NameData.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/Names.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/Sources.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/Filters.lua", CURRENT_MINOR)
    local selectedIndex = lib._iconNameIndex
    local selectedCategories = lib._iconUtils.ArtworkCategories
    assert(selectedIndex ~= oldIndex)
    assert(lib:GetIconCatalogue() == namedCatalogue and namedCatalogue.entries[1] == namedEntry)
    assert(namedCatalogue.byTexture[137008] == markerEntry and markerEntry.name == "Raid target: Skull")
    assert(lib._iconUtils.GetArtworkFilter("symbols", "markers")(markerEntry, namedCatalogue),
        "retained native markers must acquire current metadata without replacing their entry")
    assert(namedCatalogue:Describe(namedEntry):find("manaforgeomega", 1, true),
        "a retained catalogue must invalidate filenames after a provider upgrade")
    assert(not lib._iconUtils.GetArtworkFilter("equipment", "daggers")(namedEntry, namedCatalogue))
    assert(lib._iconUtils.GetArtworkFilter("achievements", "raids")(namedEntry, namedCatalogue),
        "a provider upgrade must refresh cached artwork classifications")
    local record = lib._iconHistoryPrototype.Record
    history:Record(20)
    assert(history:GetIcons("recent")[2] == 10)
    local search = catalogue:BeginSearch("retained")
    assert(search:Step(1) and #search.results == 1)
    loadIconModule("IconPicker/Model.lua", PREVIOUS_MINOR)
    loadIconModule("IconPicker/Model.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/NameData.lua", PREVIOUS_MINOR)
    loadIconModule("IconPicker/NameData.lua", CURRENT_MINOR)
    loadIconModule("IconPicker/Filters.lua", PREVIOUS_MINOR)
    loadIconModule("IconPicker/Filters.lua", CURRENT_MINOR)
    assert(lib._iconNameIndex == selectedIndex,
        "older and duplicate embeds must not replace the selected name snapshot")
    assert(lib._iconHistoryPrototype.Record == record and #catalogue.entries == 1)
    assert(lib._iconUtils.ArtworkCategories == selectedCategories)
end

print("LibModernSettings mixed load-order tests passed")
