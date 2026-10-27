local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Model", MINOR)
then
    return
end

lib._iconUtils = lib._iconUtils or {}
local Icons = lib._iconUtils

function Icons.Normalize(value)
    if issecretvalue(value) then return nil, "This texture is not readable." end

    if value == nil or value == "" then return nil end

    if type(value) == "string" then
        value = strtrim(value)

        if value == "" then return nil end

        value = tonumber(value) or value:gsub("/", "\\")
    end

    if type(value) == "number" then
        if value <= 0 or value >= math.huge or value ~= math.floor(value) then
            return nil,
                "Enter a positive texture file ID or an Interface texture path."
        end

        return value
    end

    if type(value) ~= "string" then
        return nil, "Enter a texture file ID or path."
    end

    return value
end

function Icons.Key(value)
    return type(value) == "string" and value:lower() or value
end

function Icons.Text(value)
    return (
        tostring(value or ""):lower():gsub("[_%-%./\\]", " "):gsub("%s+", " ")
    )
end

-- The client may return an ID label instead of an actual filename. That label
-- must not be presented as a discovered name or become searchable metadata.
function Icons.Filename(value)
    if
        type(value) ~= "string"
        or value == ""
        or value:lower():match("^filedata id[:%s]+%d+$")
    then
        return nil
    end

    return value
end

-- One insertion, deletion, substitution or transposition. This is bounded,
-- unlike edit-distance matrices over every filename in a large catalogue.
local function nearWord(first, second)
    if #first < 4 or math.abs(#first - #second) > 1 then return false end

    local index = 1

    while
        index <= math.min(#first, #second)
        and first:sub(index, index) == second:sub(index, index)
    do
        index = index + 1
    end

    if #first == #second then
        return first:sub(index + 1) == second:sub(index + 1)
            or (
                first:sub(index, index) == second:sub(index + 1, index + 1)
                and first:sub(index + 1, index + 1) == second:sub(index, index)
                and first:sub(index + 2) == second:sub(index + 2)
            )
    elseif #first > #second then
        return first:sub(index + 1) == second:sub(index)
    end

    return first:sub(index) == second:sub(index + 1)
end

function Icons.Score(text, tokens)
    local score = 0

    for _, token in ipairs(tokens) do
        local start = text:find(token, 1, true)

        if start then
            score = score + (start == 1 and 0 or 1)
        else
            local matched = false

            for word in text:gmatch("%S+") do
                if nearWord(token, word) then
                    matched = true
                    break
                end
            end

            if not matched then return nil end

            score = score + 10
        end
    end

    return score
end

lib._iconHistoryPrototype = lib._iconHistoryPrototype or {}
local History = lib._iconHistoryPrototype
History.__index = History

local function copyIcons(values)
    local result, seen = {}, {}

    for _, value in ipairs(values or {}) do
        local icon = Icons.Normalize(value)
        local key = Icons.Key(icon)

        if key and not seen[key] then
            seen[key] = true
            result[#result + 1] = icon
        end
    end

    return result
end

local function copyHistory(data)
    return {
        recent = copyIcons(data and data.recent),
        favorites = copyIcons(data and data.favorites),
    }
end

function History:_GetSnapshot()
    return copyHistory(self.get and self.get() or self.data)
end

function History:GetIcons(kind)
    assert(kind == "recent" or kind == "favorites", "unknown icon history list")
    local data = self.get and self.get() or self.data
    return copyIcons(data and data[kind])
end

function History:_Save(data)
    if self.set then
        self.set(copyHistory(data))
    else
        self.data = data
    end

    self.revision = (self.revision or 0) + 1
end

local function findIcon(values, icon)
    local key = Icons.Key(icon)

    for index, value in ipairs(values) do
        if Icons.Key(value) == key then return index end
    end
end

function History:Record(value)
    local icon, message = Icons.Normalize(value)
    assert(not message, message)

    if not icon then return end

    local data = self:_GetSnapshot()
    local index = findIcon(data.recent, icon)

    if index then table.remove(data.recent, index) end

    table.insert(data.recent, 1, icon)

    while #data.recent > self.maxRecent do
        table.remove(data.recent)
    end

    self:_Save(data)
end

function History:ToggleFavorite(value)
    local icon, message = Icons.Normalize(value)
    assert(icon and not message, message or "favorite requires an icon")
    local data = self:_GetSnapshot()
    local index = findIcon(data.favorites, icon)

    if index then
        table.remove(data.favorites, index)
    else
        if #data.favorites >= self.maxFavorites then
            return nil,
                "You can save up to " .. self.maxFavorites .. " favorite icons."
        end

        data.favorites[#data.favorites + 1] = icon
    end

    self:_Save(data)
    return index == nil
end

function lib:CreateIconHistory(options)
    options = options or {}
    assert(
        (options.get == nil and options.set == nil)
            or (
                type(options.get) == "function"
                and type(options.set) == "function"
            ),
        "icon history get and set must both be functions or omitted"
    )
    local history = setmetatable({
        get = options.get,
        set = options.set,
        data = {
            recent = {},
            favorites = {},
        },
        maxRecent = options.maxRecent or 30,
        maxFavorites = options.maxFavorites or 120,
    }, History)

    for _, limit in ipairs({ history.maxRecent, history.maxFavorites }) do
        assert(
            type(limit) == "number"
                and limit > 0
                and limit < math.huge
                and limit == math.floor(limit),
            "icon history limits must be positive integers"
        )
    end

    return history
end

lib._iconCataloguePrototype = lib._iconCataloguePrototype or {}
local Catalogue = lib._iconCataloguePrototype
Catalogue.__index = Catalogue
lib._iconSearchPrototype = lib._iconSearchPrototype or {}
local Search = lib._iconSearchPrototype
Search.__index = Search

function lib:CreateIconCatalogue(options)
    options = options or {}
    assert(
        options.getFilename == nil or type(options.getFilename) == "function",
        "getFilename must be a function"
    )
    local catalogue = setmetatable({
        entries = {},
        byTexture = {},
        getFilename = options.getFilename,
    }, Catalogue)
    catalogue:AddIcons(options.icons or {})
    return catalogue
end

-- Data providers supply public metadata, not UI callbacks or saved selections.
-- An icon may have several names and tags (the same artwork is often reused).
local function addAlias(entry, text)
    if text == nil or text == "" then return end

    assert(type(text) == "string", "icon names and keywords must be text")
    entry.names = entry.names or {}

    for _, name in ipairs(entry.names) do
        if name == text then return end
    end

    entry.names[#entry.names + 1] = text
    entry.searchText = nil
    return true
end

function Catalogue:AddIcon(data)
    local value, message = Icons.Normalize(data.texture)
    assert(
        value and not message,
        message or "catalogue entry requires a texture"
    )
    local key = Icons.Key(value)
    local entry = self.byTexture[key]
    local changed = false

    if not entry then
        entry = {
            texture = value,
            index = #self.entries + 1,
            tags = {},
        }
        self.entries[entry.index] = entry
        self.byTexture[key] = entry
        changed = true
    end

    if addAlias(entry, data.name) then changed = true end

    if addAlias(entry, data.keywords) then changed = true end

    if data.filename then
        assert(type(data.filename) == "string", "icon filename must be text")
        local filename = Icons.Filename(data.filename) or ""

        if entry.filename ~= filename then
            entry.filename = filename
            entry.searchText = nil
            changed = true
        end

        entry.filenameProvided = true
        entry.filenameRead = true
    end

    if not entry.name and data.name and data.name ~= "" then
        entry.name = data.name
        changed = true
    end

    for _, tag in ipairs(data.tags or {}) do
        assert(type(tag) == "string", "icon tags must be strings")

        if not entry.tags[tag] then
            entry.tags[tag] = true
            changed = true
        end
    end

    return entry, changed
end

function Catalogue:AddIcons(entries)
    local added = {}

    for _, data in ipairs(entries) do
        added[#added + 1] = self:AddIcon(data)
    end

    return added
end

function Catalogue:Describe(entry)
    if not entry.filenameRead then
        entry.filenameRead = true
        local filename = type(entry.texture) == "string" and entry.texture
            or (self.getFilename and self.getFilename(entry.texture))
        entry.filename = Icons.Filename(filename) or ""
    end

    if not entry.searchText then
        entry.searchText = Icons.Text(
            tostring(entry.texture)
                .. " "
                .. entry.filename
                .. " "
                .. (entry.names and table.concat(entry.names, " ") or "")
        )
    end

    return entry.searchText
end

function Catalogue:BeginSearch(query, filter, entries)
    local tokens = {}

    for token in Icons.Text(strtrim(query or "")):gmatch("%S+") do
        tokens[#tokens + 1] = token
    end

    return setmetatable({
        catalogue = self,
        entries = entries or self.entries,
        tokens = tokens,
        filter = filter,
        nextIndex = 1,
        results = {},
        scores = {},
        buckets = {},
    }, Search)
end

function Search:_Merge(limit)
    local written = 0

    while written < limit and self.mergeScore <= #self.scores do
        local bucket = self.buckets[self.scores[self.mergeScore]]
        self.results[#self.results + 1] = bucket[self.mergeIndex]
        written = written + 1
        self.mergeIndex = self.mergeIndex + 1

        if self.mergeIndex > #bucket then
            self.mergeIndex = 1
            self.mergeScore = self.mergeScore + 1
        end
    end

    self.complete = self.mergeScore > #self.scores

    if self.complete then
        self.buckets, self.scores = nil, nil
    end

    return self.complete
end

function Search:Step(limit)
    assert(
        type(limit) == "number"
            and limit > 0
            and limit < math.huge
            and limit == math.floor(limit),
        "search batch size must be a positive integer"
    )

    if self.complete or self.cancelled then return self.complete end

    if self.mergeScore then return self:_Merge(limit) end

    local last = math.min(#self.entries, self.nextIndex + limit - 1)

    for index = self.nextIndex, last do
        local entry = self.entries[index]
        local matches = not self.filter or self.filter(entry, self.catalogue)

        if matches then
            local score = #self.tokens == 0 and 0
                or Icons.Score(self.catalogue:Describe(entry), self.tokens)

            if score then
                if #self.tokens == 0 then
                    self.results[#self.results + 1] = entry
                else
                    local bucket = self.buckets[score]

                    if not bucket then
                        bucket = {}
                        self.buckets[score] = bucket
                        self.scores[#self.scores + 1] = score
                    end

                    bucket[#bucket + 1] = entry
                end
            end
        end
    end

    self.nextIndex = last + 1

    if last == #self.entries then
        if #self.tokens > 0 then
            -- Sort the few distinct scores, then emit bounded batches. Sorting
            -- every match at once can stall a broad search over a large catalogue.
            table.sort(self.scores)
            self.mergeScore, self.mergeIndex = 1, 1
            return self:_Merge(limit)
        end

        self.complete = true
    end

    return self.complete
end

function Search:Cancel()
    self.cancelled = true
end
