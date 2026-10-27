local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Filters", MINOR)
then
    return
end

local Icons = lib._iconUtils

local function tagged(tag)
    return function(entry)
        return entry.tags[tag] == true
    end
end

-- These describe where the artwork came from, independently of its filename.
Icons.Filters = {
    {
        value = "all",
        label = "All icons",
        tooltip = "All unique icons in the catalogue, plus discovered artwork.",
    },
    {
        value = "recent",
        label = "Recently used",
        tooltip = "Icons applied with this history. Reset and Cancel do not add entries.",
    },
    {
        value = "favorites",
        label = "Favorites",
        tooltip = "Right-click an icon to add or remove it.",
    },
    {
        value = "suggested",
        label = "Suggested",
        tooltip = "Artwork supplied by the addon for the selection you are editing.",
    },
    { type = "title", label = "Your character" },
    {
        value = "myspells",
        label = "My spellbook",
        match = tagged("myspells"),
        tooltip = "Current spellbook artwork, searchable by spell name and ID.",
    },
    {
        value = "equipped",
        label = "Equipped items",
        match = tagged("equipped"),
        tooltip = "Artwork from currently equipped items.",
    },
    {
        value = "bags",
        label = "Items in bags",
        match = tagged("bags"),
        tooltip = "Backpack, normal bags and reagent bag; excludes banks.",
    },
    { type = "title", label = "Blizzard catalogues" },
    {
        value = "spell",
        label = "Spell catalogue",
        match = tagged("spell"),
        tooltip = "Artwork offered by Blizzard's macro spell catalogue.",
    },
    {
        value = "item",
        label = "Item catalogue",
        match = tagged("item"),
        tooltip = "Artwork offered by Blizzard's macro item catalogue.",
    },
}

local function filenameWords(entry, catalogue)
    catalogue:Describe(entry)
    local filename = entry.filename

    if entry.artworkFilename ~= filename then
        local name = filename:match("([^\\/]+)$") or ""
        name = name:gsub("%.%a+$", "")
        name = name:gsub("(%u)(%u%l)", "%1 %2"):gsub("(%l)(%u)", "%1 %2")
        name = name:gsub("(%a)(%d)", "%1 %2"):gsub("(%d)(%a)", "%1 %2")
        entry.artworkWords = " " .. name:lower():gsub("[^%w]+", " ") .. " "
        entry.artworkFilename = filename
    end

    return entry.artworkWords
end

local function contains(words, terms)
    for _, term in ipairs(terms) do
        if words:find(term, 1, true) then return true end
    end

    return false
end

local function spaced(terms)
    local result = {}

    for _, term in ipairs(terms or {}) do
        result[#result + 1] = " " .. term .. " "
    end

    return result
end

local function matchName(definition)
    if definition.textures then
        local textures = {}

        for _, texture in ipairs(definition.textures) do
            textures[texture] = true
        end

        return function(_, texture)
            return textures[texture] == true
        end
    end

    local terms = spaced(definition.words)
    local excluded = spaced(definition.exclude)
    local prefix = definition.prefix and (" " .. definition.prefix .. " ")
    return function(words)
        if prefix then
            return words:sub(1, #prefix) == prefix
                and not contains(words, excluded)
        end

        return contains(words, terms) and not contains(words, excluded)
    end
end

local function matchEntry(match)
    return function(entry, catalogue)
        return match(filenameWords(entry, catalogue), entry.texture)
    end
end

-- Categories, type choices, explanations and matchers share one definition.
-- Whole filename words/phrases keep ore/core, ice/justice and bow/rainbow apart.
-- Class names and color variants describe artwork naming, not gameplay or pixels.
local categories = {
    {
        value = "equipment",
        label = "Equipment",
        description = "Weapon, armor-slot and accessory names",
        types = {
            { type = "title", label = "Weapons" },
            {
                value = "swords",
                label = "Swords",
                words = { "sword", "swords" },
            },
            {
                value = "axes",
                label = "Axes",
                words = { "axe", "axes" },
            },
            {
                value = "maces",
                label = "Maces and hammers",
                words = { "mace", "hammer", "hammers" },
            },
            {
                value = "daggers",
                label = "Daggers and knives",
                words = { "dagger", "knife", "knives" },
            },
            {
                value = "staves",
                label = "Staves and wands",
                words = { "staff", "stave", "staves", "wand" },
            },
            {
                value = "ranged",
                label = "Bows, guns and crossbows",
                words = {
                    "bow",
                    "crossbow",
                    "cross bow",
                    "gun",
                    "rifle",
                    "firearm",
                },
            },
            {
                value = "polearms",
                label = "Polearms and glaives",
                words = {
                    "polearm",
                    "spear",
                    "glaive",
                    "warglaive",
                    "war glaive",
                },
            },
            {
                value = "fists",
                label = "Fist weapons",
                words = { "fist", "hand weapon", "handweapon" },
            },
            {
                value = "offhands",
                label = "Shields and off-hands",
                words = {
                    "shield",
                    "offhand",
                    "off hand",
                    "held in offhand",
                    "holdable",
                },
            },
            { type = "title", label = "Armor" },
            {
                value = "head",
                label = "Helms and headwear",
                words = {
                    "helm",
                    "helmet",
                    "hood",
                    "hat",
                    "head",
                    "crown",
                    "circlet",
                },
            },
            {
                value = "shoulders",
                label = "Shoulders",
                words = { "shoulder", "shoulders", "pauldron" },
            },
            {
                value = "chest",
                label = "Chest armor and robes",
                words = { "chest", "robe", "robes", "tunic", "vest" },
            },
            {
                value = "hands",
                label = "Gloves and gauntlets",
                words = { "glove", "gloves", "gauntlet", "gauntlets" },
            },
            {
                value = "waist",
                label = "Belts",
                words = { "belt", "waist" },
            },
            {
                value = "legs",
                label = "Leg armor",
                words = { "pant", "pants", "leg", "legs", "leggings" },
            },
            {
                value = "feet",
                label = "Boots",
                words = { "boot", "boots", "feet" },
            },
            {
                value = "wrists",
                label = "Bracers",
                words = { "bracer", "bracers", "wrist" },
            },
            {
                value = "back",
                label = "Capes and cloaks",
                words = { "cape", "cloak", "back" },
            },
            { type = "title", label = "Accessories" },
            {
                value = "jewelry",
                label = "Rings and necklaces",
                words = { "jewelry", "ring", "necklace", "amulet" },
            },
            {
                value = "trinkets",
                label = "Trinkets and relics",
                words = { "trinket", "relic", "idol", "libram" },
            },
            {
                value = "tabards",
                label = "Tabards",
                words = { "tabard" },
            },
        },
    },
    {
        value = "consumables",
        label = "Consumables",
        description = "Food, drink and consumable names",
        types = {
            {
                value = "food",
                label = "Food and feasts",
                words = {
                    "food",
                    "feast",
                    "cooking",
                    "bread",
                    "meat",
                    "fruit",
                    "cheese",
                },
            },
            {
                value = "drink",
                label = "Drinks",
                words = { "drink", "beverage", "beer", "wine", "tea", "coffee" },
            },
            {
                value = "potions",
                label = "Potions and flasks",
                words = { "potion", "flask", "elixir" },
            },
            {
                value = "bandages",
                label = "Bandages",
                words = { "bandage", "bandages" },
            },
            {
                value = "enhancements",
                label = "Oils, stones and runes",
                words = {
                    "oil",
                    "sharpening",
                    "weightstone",
                    "weight stone",
                    "whetstone",
                    "rune",
                },
            },
        },
    },
    {
        value = "crafting",
        label = "Crafting",
        description = "Profession, ingredient and material names",
        types = {
            {
                value = "alchemy",
                label = "Alchemy",
                words = {
                    "alchemy",
                    "alchemist",
                    "potion",
                    "flask",
                    "elixir",
                    "vial",
                },
            },
            {
                value = "blacksmithing",
                label = "Blacksmithing",
                words = {
                    "blacksmith",
                    "blacksmithing",
                    "black smithing",
                    "anvil",
                },
            },
            {
                value = "enchanting",
                label = "Enchanting",
                words = {
                    "enchant",
                    "enchanting",
                    "disenchant",
                    "dust",
                    "shard",
                },
            },
            {
                value = "engineering",
                label = "Engineering",
                words = {
                    "engineering",
                    "engineer",
                    "bomb",
                    "dynamite",
                    "gizmo",
                    "gear",
                    "cog",
                },
            },
            {
                value = "herbalism",
                label = "Herbalism",
                words = { "herb", "herbalism", "flower" },
            },
            {
                value = "inscription",
                label = "Inscription",
                words = { "inscription", "ink", "pigment", "glyph" },
            },
            {
                value = "jewelcrafting",
                label = "Jewelcrafting",
                words = { "jewelcrafting", "jewel crafting", "gem", "jewel" },
            },
            {
                value = "leatherworking",
                label = "Leatherworking",
                words = {
                    "leatherworking",
                    "leather working",
                    "leather",
                    "hide",
                    "skinning",
                },
            },
            {
                value = "mining",
                label = "Mining and metals",
                words = { "mining", "ore", "ingot", "metal" },
            },
            {
                value = "tailoring",
                label = "Tailoring",
                words = { "tailoring", "thread", "cloth", "fabric", "bolt" },
            },
            {
                value = "cooking",
                label = "Cooking",
                words = { "cooking", "spice", "food", "feast" },
            },
            {
                value = "fishing",
                label = "Fishing",
                words = { "fishing", "fish", "fishingpole", "lure", "bait" },
            },
            {
                value = "archaeology",
                label = "Archaeology",
                words = { "archaeology", "archeology" },
            },
        },
    },
    {
        value = "creatures",
        label = "Mounts and creatures",
        description = "Mount, pet and creature names",
        types = {
            {
                value = "mounts",
                label = "Mounts",
                words = { "mount", "mounts" },
            },
            {
                value = "pets",
                label = "Pets and companions",
                words = {
                    "pet",
                    "pets",
                    "companion",
                    "battlepet",
                    "battle pet",
                },
            },
            {
                value = "portraits",
                label = "Creatures and portraits",
                words = {
                    "creature",
                    "creatureportrait",
                    "creature portrait",
                    "portrait",
                },
            },
        },
    },
    {
        value = "classes",
        label = "Class artwork",
        description = "Class names in ability, equipment and class-icon filenames",
        tooltip = "Artwork with a class name in its filename. Includes named equipment and symbols; usable spell lists still come from My spellbook.",
        types = {
            {
                value = "deathknight",
                label = "Death Knight",
                words = { "deathknight", "death knight" },
            },
            {
                value = "demonhunter",
                label = "Demon Hunter",
                words = { "demonhunter", "demon hunter" },
            },
            {
                value = "druid",
                label = "Druid",
                words = { "druid" },
            },
            {
                value = "evoker",
                label = "Evoker",
                words = { "evoker" },
            },
            {
                value = "hunter",
                label = "Hunter",
                words = { "hunter" },
                exclude = { "demonhunter", "demon hunter" },
            },
            {
                value = "mage",
                label = "Mage",
                words = { "mage" },
            },
            {
                value = "monk",
                label = "Monk",
                words = { "monk" },
            },
            {
                value = "paladin",
                label = "Paladin",
                words = { "paladin" },
            },
            {
                value = "priest",
                label = "Priest",
                words = { "priest" },
            },
            {
                value = "rogue",
                label = "Rogue",
                words = { "rogue" },
            },
            {
                value = "shaman",
                label = "Shaman",
                words = { "shaman" },
            },
            {
                value = "warlock",
                label = "Warlock",
                words = { "warlock" },
            },
            {
                value = "warrior",
                label = "Warrior",
                words = { "warrior" },
            },
        },
    },
    {
        value = "magic",
        label = "Magic themes",
        description = "Named magic and elemental themes",
        tooltip = "Themes named in the artwork filename. Categories may overlap and do not determine a spell's damage school.",
        types = {
            {
                value = "fire",
                label = "Fire and lava",
                words = {
                    "fire",
                    "flame",
                    "flames",
                    "lava",
                    "burn",
                    "burning",
                    "fireball",
                    "firestorm",
                    "flamestrike",
                },
            },
            {
                value = "frost",
                label = "Frost and ice",
                words = {
                    "frost",
                    "ice",
                    "snow",
                    "frozen",
                    "icy",
                    "frostbolt",
                    "blizzard",
                },
            },
            {
                value = "nature",
                label = "Nature and earth",
                words = {
                    "nature",
                    "earth",
                    "leaf",
                    "roots",
                    "root",
                    "vine",
                    "vines",
                },
            },
            {
                value = "storm",
                label = "Lightning and storms",
                words = { "lightning", "storm", "thunder", "wind", "cyclone" },
            },
            {
                value = "holy",
                label = "Holy and light",
                words = { "holy", "light", "radiant", "divine" },
            },
            {
                value = "shadow",
                label = "Shadow and void",
                words = { "shadow", "void", "darkness", "shadowbolt" },
            },
            {
                value = "fel",
                label = "Fel and demons",
                words = { "fel", "demon", "demonic", "demonology", "hellfire" },
            },
            {
                value = "arcane",
                label = "Arcane and mana",
                words = { "arcane", "mana" },
            },
            {
                value = "blood",
                label = "Blood and death",
                words = { "blood", "death", "bone", "unholy", "necrotic" },
            },
            {
                value = "poison",
                label = "Poison and disease",
                words = { "poison", "venom", "plague", "disease", "toxic" },
            },
        },
    },
    {
        value = "objects",
        label = "Objects and currency",
        description = "Container, document, key and currency names",
        types = {
            {
                value = "containers",
                label = "Bags and containers",
                words = { "bag", "bags", "box", "crate", "satchel", "pouch" },
            },
            {
                value = "documents",
                label = "Books and scrolls",
                words = {
                    "book",
                    "books",
                    "scroll",
                    "scrolls",
                    "parchment",
                    "letter",
                    "map",
                },
            },
            {
                value = "keys",
                label = "Keys and locks",
                words = { "key", "keys", "lock", "padlock" },
            },
            {
                value = "currency",
                label = "Coins and currency",
                words = { "coin", "coins", "currency", "money", "token" },
            },
            {
                value = "tools",
                label = "Tools and gadgets",
                words = {
                    "tool",
                    "tools",
                    "gadget",
                    "gizmo",
                    "wrench",
                    "pickaxe",
                    "shovel",
                },
            },
        },
    },
    {
        value = "achievements",
        label = "Achievements",
        description = "Achievement filenames",
        words = { "achievement", "achievements" },
        types = {
            {
                value = "raids",
                label = "Raids and dungeons",
                words = { "raid", "dungeon", "heroic" },
            },
            {
                value = "pvp",
                label = "PvP",
                words = { "pvp", "arena", "battleground", "honor" },
            },
            {
                value = "exploration",
                label = "Exploration",
                words = { "explore", "exploration", "zone" },
            },
            {
                value = "quests",
                label = "Quests",
                words = { "quest", "quests" },
            },
            {
                value = "reputation",
                label = "Reputation",
                words = { "reputation", "faction" },
            },
        },
    },
    {
        value = "symbols",
        label = "Symbols and interface",
        description = "Interface, marker and symbol names",
        types = {
            {
                value = "interface",
                label = "Interface icons",
                prefix = "ui",
                tooltip = "Artwork with a UI filename prefix. Generic Icon names on items and decorations do not qualify.",
            },
            {
                value = "classes",
                label = "Class symbols",
                words = { "classicon", "class icon" },
            },
            {
                value = "markers",
                label = "Raid markers",
                textures = {
                    137001,
                    137002,
                    137003,
                    137004,
                    137005,
                    137006,
                    137007,
                    137008,
                },
                tooltip = "Only the eight raid-target markers: Star, Circle, Diamond, Triangle, Moon, Square, Cross and Skull.",
            },
            {
                value = "numbers",
                label = "Numbers",
                words = {
                    "number",
                    "numbers",
                    "numeral",
                    "numerals",
                    "digit",
                    "digits",
                },
            },
            {
                value = "questions",
                label = "Question marks",
                words = { "questionmark", "question mark" },
            },
        },
    },
    {
        value = "colors",
        label = "Named color variants",
        description = "Color words in filenames",
        tooltip = "Matches color names written in filenames. This does not inspect the image's pixels or find every icon of that color.",
        types = {
            {
                value = "black",
                label = "Black",
                words = { "black" },
            },
            {
                value = "white",
                label = "White",
                words = { "white" },
            },
            {
                value = "grey",
                label = "Gray / grey",
                words = { "gray", "grey" },
            },
            {
                value = "red",
                label = "Red",
                words = { "red" },
            },
            {
                value = "orange",
                label = "Orange",
                words = { "orange" },
            },
            {
                value = "yellow",
                label = "Yellow / gold",
                words = { "yellow", "gold", "golden" },
            },
            {
                value = "green",
                label = "Green",
                words = { "green" },
            },
            {
                value = "blue",
                label = "Blue",
                words = { "blue" },
            },
            {
                value = "purple",
                label = "Purple / violet",
                words = { "purple", "violet" },
            },
            {
                value = "pink",
                label = "Pink",
                words = { "pink" },
            },
            {
                value = "brown",
                label = "Brown",
                words = { "brown" },
            },
        },
    },
}

Icons.ArtworkCategories = {
    {
        value = "all",
        label = "All artwork",
        tooltip = "Show every artwork category within the chosen source and search.",
        types = { { value = "all", label = "All types" } },
    },
}

for _, category in ipairs(categories) do
    local types = { { value = "all", label = "All types" } }
    local matches = {}
    local parentMatch = category.words and matchName(category)

    for _, definition in ipairs(category.types) do
        if definition.value then
            local childMatch = matchName(definition)
            local combinedMatch = childMatch

            if parentMatch then
                combinedMatch = function(words, texture)
                    return parentMatch(words, texture)
                        and childMatch(words, texture)
                end
            end

            definition.match = matchEntry(combinedMatch)
            definition.tooltip = definition.tooltip
                or category.tooltip
                or (
                    category.description
                    .. "; this choice matches "
                    .. definition.label:lower()
                    .. " artwork by filename."
                )
            matches[#matches + 1] = combinedMatch
        end

        types[#types + 1] = definition
    end

    category.match = matchEntry(function(words, texture)
        if parentMatch then return parentMatch(words, texture) end

        for _, match in ipairs(matches) do
            if match(words, texture) then return true end
        end

        return false
    end)
    category.tooltip = category.tooltip
        or (
            category.description
            .. ". Based on filenames; artwork may appear in more than one category."
        )
    category.types = types
    Icons.ArtworkCategories[#Icons.ArtworkCategories + 1] = category
end

function Icons.GetArtworkCategory(value)
    for _, definition in ipairs(Icons.ArtworkCategories) do
        if definition.value == value then return definition end
    end

    error("unknown icon artwork category " .. tostring(value))
end

function Icons.GetArtworkFilter(categoryValue, typeValue)
    local category = Icons.GetArtworkCategory(categoryValue)

    for _, definition in ipairs(category.types) do
        if definition.value == typeValue then
            if typeValue == "all" then return category.match end

            return definition.match
        end
    end

    error("unknown icon artwork type " .. tostring(typeValue))
end
