local MAJOR, MINOR = "LibModernSettings-1.0", 10
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/Color", MINOR) then
    return
end

lib._colorUtils = lib._colorUtils or {}
local Color = lib._colorUtils

function Color.Clamp(value)
    return math.max(0, math.min(1, value))
end

function Color.Copy(value, hasOpacity)
    assert(type(value) == "table", "color must be an RGB or RGBA table")
    local result = {}
    for _, channel in ipairs({ "r", "g", "b", "a" }) do
        local number = value[channel]
        if channel == "a" and (number == nil or hasOpacity == false) then
            number = 1
        end
        assert(type(number) == "number" and number == number and math.abs(number) < math.huge,
            "color channels must be finite numbers")
        result[channel] = Color.Clamp(number)
    end
    return result
end

function Color.Hex(value, hasOpacity)
    local hex = string.format("%02X%02X%02X",
        math.floor(value.r * 255 + 0.5),
        math.floor(value.g * 255 + 0.5),
        math.floor(value.b * 255 + 0.5))
    if hasOpacity then
        hex = hex .. string.format("%02X", math.floor(value.a * 255 + 0.5))
    end
    return hex
end

function Color.ParseHex(text, alpha)
    local hex = text:match("^%s*#?(%x+)%s*$")
    if not hex or (#hex ~= 6 and #hex ~= 8) then
        return nil, "Enter RRGGBB or RRGGBBAA."
    end
    if #hex == 8 then
        alpha = tonumber(hex:sub(7, 8), 16) / 255
    end
    return {
        r = tonumber(hex:sub(1, 2), 16) / 255,
        g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255,
        a = alpha or 1,
    }
end

function Color.FromHSV(hue, saturation, value)
    local sector = (hue % 1) * 6
    local index = math.floor(sector)
    local fraction = sector - index
    local low = value * (1 - saturation)
    local falling = value * (1 - saturation * fraction)
    local rising = value * (1 - saturation * (1 - fraction))
    if index == 0 then
        return value, rising, low
    elseif index == 1 then
        return falling, value, low
    elseif index == 2 then
        return low, value, rising
    elseif index == 3 then
        return low, falling, value
    elseif index == 4 then
        return rising, low, value
    end
    return value, low, falling
end

function Color.ToHSV(color)
    local high = math.max(color.r, color.g, color.b)
    local low = math.min(color.r, color.g, color.b)
    local delta = high - low
    if delta == 0 then
        return 0, 0, high
    end
    local hue
    if high == color.r then
        hue = ((color.g - color.b) / delta) % 6
    elseif high == color.g then
        hue = (color.b - color.r) / delta + 2
    else
        hue = (color.r - color.g) / delta + 4
    end
    return hue / 6, delta / high, high
end

lib._colorPalettePrototype = lib._colorPalettePrototype or {}
local Palette = lib._colorPalettePrototype
Palette.__index = Palette

local function copyPalette(data)
    local copy = { recent = {}, favorites = {} }
    for kind, colors in pairs(copy) do
        for _, value in ipairs(data[kind] or {}) do
            colors[#colors + 1] = Color.Copy(value)
        end
    end
    return copy
end

function Palette:GetColors(kind)
    assert(kind == "recent" or kind == "favorites", "unknown color palette list")
    return copyPalette(self.get and self.get() or self.data)[kind]
end

function Palette:_Save(data)
    if self.set then
        self.set(copyPalette(data))
    else
        self.data = data
    end
end

local function findColor(colors, color)
    local key = Color.Hex(color, true)
    for index, candidate in ipairs(colors) do
        if Color.Hex(candidate, true) == key then
            return index
        end
    end
end

function Palette:Record(color)
    color = Color.Copy(color)
    local data = copyPalette(self.get and self.get() or self.data)
    local index = findColor(data.recent, color)
    if index then
        table.remove(data.recent, index)
    end
    table.insert(data.recent, 1, color)
    while #data.recent > self.maxRecent do
        table.remove(data.recent)
    end
    self:_Save(data)
end

function Palette:ToggleFavorite(color)
    color = Color.Copy(color)
    local data = copyPalette(self.get and self.get() or self.data)
    local index = findColor(data.favorites, color)
    if index then
        table.remove(data.favorites, index)
    else
        if #data.favorites >= self.maxFavorites then
            return nil, "You can save up to " .. self.maxFavorites .. " favorite colors."
        end
        table.insert(data.favorites, color)
    end
    self:_Save(data)
    return index == nil
end

function lib:CreateColorPalette(options)
    options = options or {}
    assert((options.get == nil and options.set == nil)
        or (type(options.get) == "function" and type(options.set) == "function"),
        "palette get and set must both be functions or omitted")
    local palette = setmetatable({
        get = options.get,
        set = options.set,
        data = { recent = {}, favorites = {} },
        maxRecent = options.maxRecent or 13,
        maxFavorites = options.maxFavorites or 26,
    }, Palette)
    for _, limit in ipairs({ palette.maxRecent, palette.maxFavorites }) do
        assert(type(limit) == "number" and limit > 0 and limit < math.huge and limit == math.floor(limit),
            "palette limits must be positive integers")
    end
    return palette
end

lib._defaultColorPalette = lib._defaultColorPalette or lib:CreateColorPalette()
