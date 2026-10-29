local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("TexturePicker/Catalogue", MINOR)
then
    return
end

lib._texturePickerCatalogue = lib._texturePickerCatalogue or {}
local Catalogue = lib._texturePickerCatalogue
local Values = lib._iconUtils
local catalogues = {}
local atlasEntries

local function bundled(file, name, width, height)
    return { file = file, name = name, width = width, height = height }
end

local function createCategories()
    return {
        {
            id = "circles",
            name = "Circles",
            tooltip = "Circles, rings and circular gradients. Ring thickness is measured in the original 256px artwork and scales with your display.",
            entries = {
                bundled("Ring_10px.tga", "Ring 10px", 256, 256),
                bundled("Ring_20px.tga", "Ring 20px", 256, 256),
                bundled("Ring_30px.tga", "Ring 30px", 256, 256),
                bundled("Ring_40px.tga", "Ring 40px", 256, 256),
                bundled("Circle_White.tga", "Circle", 256, 256),
                bundled(
                    "Circle_White_Border.tga",
                    "Circle with Border",
                    256,
                    256
                ),
                bundled("Circle_Smooth.tga", "Smooth Circle", 256, 256),
                bundled(
                    "Circle_Smooth_Border.tga",
                    "Smooth Circle with Border",
                    256,
                    256
                ),
                bundled("circle_border5.tga", "Circle Border", 64, 64),
                bundled("ring_glow3.tga", "Circle Border Glow", 128, 128),
                bundled(
                    "Circle_AlphaGradient_In.tga",
                    "Circle Gradient In",
                    256,
                    256
                ),
                bundled(
                    "Circle_AlphaGradient_Out.tga",
                    "Circle Gradient Out",
                    256,
                    256
                ),
            },
        },
        {
            id = "shapes",
            name = "Shapes",
            tooltip = "Squares, borders, triangles and targeting shapes. Pixel labels describe the original artwork; resizing also scales its border.",
            entries = {
                {
                    texture = "Interface\\Buttons\\WHITE8X8",
                    name = "Solid White",
                },
                bundled("Square_White.tga", "Square", 256, 256),
                bundled(
                    "Square_White_Border.tga",
                    "Square with Border",
                    256,
                    256
                ),
                bundled("Square_Smooth.tga", "Smooth Square", 256, 256),
                bundled(
                    "Square_Smooth_Border.tga",
                    "Smooth Square with Border",
                    256,
                    256
                ),
                bundled(
                    "Square_AlphaGradient.tga",
                    "Square Gradient",
                    256,
                    256
                ),
                bundled("square_border_1px.tga", "Square Border 1px", 64, 64),
                bundled("square_border_5px.tga", "Square Border 5px", 64, 64),
                bundled("square_border_10px.tga", "Square Border 10px", 64, 64),
                bundled("Triangle45.tga", "45 Degree Triangle", 128, 128),
                bundled("triangle.tga", "Triangle", 128, 128),
                bundled("triangle-border.tga", "Triangle Border", 128, 128),
                bundled("Trapezoid.tga", "Trapezoid", 256, 256),
                bundled("target_indicator.tga", "Target Indicator", 64, 64),
                bundled(
                    "target_indicator_glow.tga",
                    "Target Indicator Glow",
                    64,
                    64
                ),
                bundled("arrows_target.tga", "Target Arrows", 256, 64),
            },
        },
        {
            id = "bars",
            name = "Bars",
            tooltip = "Striped and rainbow bars, sparks and beams.",
            entries = {
                bundled("StripedTexture.tga", "Striped Bar", 256, 32),
                bundled("stripe-bar.tga", "Striped Bar 2", 256, 32),
                bundled("rainbowbar.tga", "Rainbow Bar", 256, 32),
                bundled("stripe-rainbow-bar.tga", "Rainbow Bar 2", 256, 32),
                { texture = 130877, name = "Spark" },
                { texture = "Insanity-Spark", name = "Insanity Spark" },
                { texture = "XPBarAnim-OrangeSpark", name = "Orange Spark" },
                {
                    texture = "GarrMission_EncounterBar-Spark",
                    name = "Mission Spark",
                },
                { texture = "Legionfall_BarSpark", name = "Legionfall Spark" },
                { texture = "honorsystem-bar-spark", name = "Honor Spark" },
                {
                    texture = "bonusobjectives-bar-spark",
                    name = "Bonus Objective Spark",
                },
                { texture = 167096, name = "Gold Chain" },
                { texture = 167097, name = "Iron Chain" },
                { texture = 167098, name = "Green Fire Beam" },
                { texture = 167099, name = "Red Fire Beam" },
                { texture = 167104, name = "Blue Water Beam" },
                { texture = 186185, name = "Purple Beam" },
                { texture = 186198, name = "Lightning" },
                { texture = 186205, name = "Mana Burn Beam" },
            },
        },
        {
            id = "alerts",
            name = "Alerts",
            tooltip = "Blizzard spell-activation artwork, including generic arcs and class alerts.",
            entries = {
                { texture = 450917, name = "Generic Arc 1" },
                { texture = 450918, name = "Generic Arc 2" },
                { texture = 450919, name = "Generic Arc 3" },
                { texture = 450920, name = "Generic Arc 4" },
                { texture = 450921, name = "Generic Arc 5" },
                { texture = 450922, name = "Generic Arc 6" },
                { texture = 450923, name = "Generic Top 1" },
                { texture = 450924, name = "Generic Top 2" },
                { texture = 449486, name = "Arcane Missiles" },
                { texture = 449488, name = "Brain Freeze" },
                { texture = 449489, name = "Fingers of Frost" },
                { texture = 449490, name = "Hot Streak" },
                { texture = 449492, name = "Nightfall" },
                { texture = 449493, name = "Sudden Death" },
                { texture = 450914, name = "Eclipse Moon" },
                { texture = 450915, name = "Eclipse Sun" },
                { texture = 450926, name = "Lock and Load" },
                { texture = 450927, name = "Maelstrom Weapon" },
                { texture = 450933, name = "Surge of Light" },
                { texture = 458740, name = "Killing Machine" },
            },
        },
        {
            id = "runes",
            name = "Runes",
            tooltip = "Blizzard circular, square and magical rune artwork.",
            entries = {
                { texture = 165630, name = "Ringed Aura Rune" },
                { texture = 165631, name = "Square Aura Rune" },
                { texture = 165633, name = "Tri-Circle Aura Rune" },
                { texture = 165634, name = "Tri-Circle Ringed Rune" },
                { texture = 165635, name = "Spike-Ringed Rune" },
                { texture = 165639, name = "Sliced Aura Rune" },
                { texture = 165881, name = "Dark Summon" },
                { texture = 165885, name = "Death Rune" },
                { texture = 165922, name = "Demonic Summon" },
                { texture = 166340, name = "Holy Rune" },
                { texture = 166341, name = "Holy Cross Rune" },
                { texture = 166748, name = "Filled Circular Rune" },
                { texture = 166749, name = "Ringed Circular Rune" },
                { texture = 166750, name = "Sparse Circular Rune" },
                { texture = 166757, name = "Circular Frost Rune" },
                { texture = 166979, name = "Star Rune" },
            },
        },
        {
            id = "atlases",
            name = "Atlases",
            tooltip = "The complete Blizzard atlas catalogue, in alphabetical order.",
        },
    }
end

function Catalogue.Get(mediaPath)
    if catalogues[mediaPath] then return catalogues[mediaPath] end

    local catalogue =
        { categories = createCategories(), byID = {}, byValue = {} }

    for index, category in ipairs(catalogue.categories) do
        category.index = index
        catalogue.byID[category.id] = category

        for _, entry in ipairs(category.entries or {}) do
            if entry.file then
                entry.texture = mediaPath .. "WeakAuras\\" .. entry.file
            end

            catalogue.byValue[Values.Key(entry.texture)] = entry
        end
    end

    catalogues[mediaPath] = catalogue
    return catalogue
end

function Catalogue.GetEntries(category)
    if category.entries then return category.entries end

    -- Build the large native catalogue only when its tab is first requested.
    if not atlasEntries then
        atlasEntries = {}

        for _, atlas in ipairs(C_Texture.GetAtlasElements()) do
            atlasEntries[#atlasEntries + 1] = { texture = atlas, name = atlas }
        end

        table.sort(atlasEntries, function(first, second)
            return first.name < second.name
        end)
    end

    category.entries = atlasEntries
    return atlasEntries
end
