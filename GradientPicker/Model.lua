local MAJOR, MINOR = "LibModernSettings-1.0", 14
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("GradientPicker/Model", MINOR)
then
    return
end

lib._gradientUtils = lib._gradientUtils or {}
local Model = lib._gradientUtils
Model.gap, Model.maximum = 0.03, 24

local function finite(value)
    return type(value) == "number"
        and value == value
        and value > -math.huge
        and value < math.huge
end
Model.Finite = finite

function Model.Copy(value)
    local result = { angle = value.angle, stops = {} }
    for index, stop in ipairs(value.stops) do
        result.stops[index] = {
            position = stop.position,
            r = stop.r,
            g = stop.g,
            b = stop.b,
            a = stop.a,
        }
    end
    return result
end

function Model.Normalize(value)
    value = value
        or {
            angle = 0,
            stops = {
                { position = 0, r = 0, g = 0, b = 0, a = 1 },
                { position = 1, r = 1, g = 1, b = 1, a = 1 },
            },
        }
    if
        type(value) ~= "table"
        or not finite(value.angle or 0)
        or type(value.stops) ~= "table"
    then
        return nil, "A gradient requires an angle and color stops."
    end
    if #value.stops < 2 or #value.stops > Model.maximum then
        return nil, "Use between 2 and 24 gradient stops."
    end
    local result, order =
        { angle = math.max(0, math.min(360, value.angle or 0)), stops = {} }, {}
    for index, stop in ipairs(value.stops) do
        if type(stop) ~= "table" or not finite(stop.position) then
            return nil, "Each stop requires a finite position."
        end
        local copy = { position = math.max(0, math.min(1, stop.position)) }
        for _, key in ipairs({ "r", "g", "b", "a" }) do
            local channel = stop[key]
            if key == "a" and channel == nil then channel = 1 end
            if not finite(channel) then
                return nil, "Stop colors must be finite RGBA values."
            end
            copy[key] = math.max(0, math.min(1, channel))
        end
        result.stops[index], order[copy] = copy, index
    end
    table.sort(result.stops, function(a, b)
        if a.position == b.position then return order[a] < order[b] end
        return a.position < b.position
    end)
    -- Separate legacy coincident stops in the draft, retaining every color.
    local previous = -Model.gap
    for index, stop in ipairs(result.stops) do
        stop.position = math.min(
            1 - (#result.stops - index) * Model.gap,
            math.max(previous + Model.gap, stop.position)
        )
        previous = stop.position
    end
    return result
end

function Model.Move(value, index, position)
    if not finite(position) or not value.stops[index] then return false end
    local before, after = value.stops[index - 1], value.stops[index + 1]
    local low = before and before.position + Model.gap or 0
    local high = after and after.position - Model.gap or 1
    local stop = value.stops[index]
    position = math.max(low, math.min(high, position))
    if math.abs(position - stop.position) < 0.000001 then return false end
    stop.position = position
    return true
end

function Model.Add(value)
    if #value.stops >= Model.maximum then return end
    local index, width = nil, 0
    for cursor = 0, #value.stops do
        local first, last = value.stops[cursor], value.stops[cursor + 1]
        local gap = (last and last.position or 1)
            - (first and first.position or 0)
        if gap >= Model.gap * 2 and gap > width then
            index, width = cursor, gap
        end
    end
    if not index then return end
    local first, last =
        value.stops[math.max(1, index)],
        value.stops[math.min(#value.stops, index + 1)]
    local start = index == 0 and 0 or first.position
    local finish = index == #value.stops and 1 or last.position
    local stop = { position = (start + finish) / 2 }
    for _, key in ipairs({ "r", "g", "b", "a" }) do
        stop[key] = (first[key] + last[key]) / 2
    end
    table.insert(value.stops, index + 1, stop)
    return index + 1
end

function Model.Reverse(value)
    local stops = {}
    for index = #value.stops, 1, -1 do
        local stop = value.stops[index]
        stop.position = 1 - stop.position
        stops[#stops + 1] = stop
    end
    value.stops = stops
end
