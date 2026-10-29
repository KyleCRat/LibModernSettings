local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Sources", MINOR)
then
    return
end

local Icons = lib._iconUtils

local RAID_MARKERS = {
    { name = "Star", keywords = "yellow" },
    { name = "Circle", keywords = "orange" },
    { name = "Diamond", keywords = "purple" },
    { name = "Triangle", keywords = "green" },
    { name = "Moon", keywords = "silver white" },
    { name = "Square", keywords = "blue" },
    { name = "Cross", keywords = "red x" },
    { name = "Skull", keywords = "white" },
}

local NUMBER_NAMES = {
    "zero",
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
}

local function fileTexture(value)
    local texture = Icons.Normalize(value)
    local filename

    if type(texture) == "string" then
        if not texture:find("\\", 1, true) then
            texture = "Interface\\Icons\\" .. texture
        end

        filename = texture
        -- Resolve legacy filenames once so spell/item catalogues share an entry.
        local fileID = GetFileIDFromPath(texture)

        if fileID and fileID > 0 then texture = fileID end
    end

    return texture, filename
end

local function getFilename(fileID)
    return lib:_GetIconFilename(fileID)
end

-- Native raid markers live outside Interface/Icons, so they are not in the
-- generated name index. Resolve Blizzard's targeting paths to the client's IDs.
local function addNativeArtwork(catalogue)
    catalogue:AddIcon({ texture = 134400, name = "Question mark" })

    for index, marker in ipairs(RAID_MARKERS) do
        local texture, filename = fileTexture(
            "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
        )
        catalogue:AddIcon({
            texture = texture,
            filename = filename,
            name = "Raid target: "
                .. (_G["RAID_TARGET_" .. index] or marker.name),
            keywords = "raid target marker "
                .. marker.name
                .. " "
                .. marker.keywords
                .. " rt"
                .. index,
        })
    end

    for number = 0, 9 do
        catalogue:AddIcon({
            texture = 6033345 + number,
            filename = "Interface\\Icons\\INV_MISC_Number_" .. number,
            name = "Number " .. number,
            keywords = "digit numeral " .. NUMBER_NAMES[number + 1],
        })
    end
end

-- A compatible embed upgrade can carry a newer name snapshot. Retain catalogue
-- and entry identity, but discard filename/search caches from the old provider.
if lib._defaultIconCatalogue then
    local catalogue = lib._defaultIconCatalogue
    catalogue.getFilename = getFilename

    for _, entry in ipairs(catalogue.entries) do
        if not entry.filenameProvided then
            entry.filenameRead = nil
            entry.searchText = nil
        end
    end

    addNativeArtwork(catalogue)
end

local CATALOGUE_SOURCES = {
    { read = "GetLooseMacroIcons", tag = "spell" },
    { read = "GetMacroIcons", tag = "spell" },
    { read = "GetLooseMacroItemIcons", tag = "item" },
    { read = "GetMacroItemIcons", tag = "item" },
}

-- Pickers advance this shared job only while visible. Keep completed work when
-- the last picker closes, but publish the catalogue only after every source.
function lib:_AdvanceIconCatalogue()
    if self._defaultIconCatalogue then return self._defaultIconCatalogue end

    local job = self._iconCatalogueBuild

    if not job then
        job = {
            catalogue = self:CreateIconCatalogue({ getFilename = getFilename }),
            sourceIndex = 1,
            data = { tags = {} },
        }
        addNativeArtwork(job.catalogue)
        self._iconCatalogueBuild = job
    end

    if not job.values then
        local source = CATALOGUE_SOURCES[job.sourceIndex]
        job.values = {}
        job.nextIndex = 1
        job.data.tags[1] = source.tag
        -- A native catalogue read cannot be subdivided. Give each its own
        -- update, separately from normalizing and deduplicating its records.
        _G[source.read](job.values)
        return
    end

    local started = debugprofilestop()

    for _ = 1, 16 do
        local last = math.min(job.nextIndex + 127, #job.values)

        for index = job.nextIndex, last do
            local texture, filename = fileTexture(job.values[index])

            if texture then
                job.data.texture = texture
                job.data.filename = filename
                job.catalogue:AddIcon(job.data)
            end
        end

        job.nextIndex = last + 1

        if job.nextIndex > #job.values then
            job.values = nil
            job.sourceIndex = job.sourceIndex + 1

            if job.sourceIndex > #CATALOGUE_SOURCES then
                self._defaultIconCatalogue = job.catalogue
                self._iconCatalogueBuild = nil
                return job.catalogue
            end

            return
        end

        if debugprofilestop() - started >= 3 then return end
    end
end

-- Preserve the synchronous API for callers that explicitly request all data.
-- The browser uses the incremental path after its window has painted.
function lib:GetIconCatalogue()
    local catalogue

    repeat
        catalogue = self:_AdvanceIconCatalogue()
    until catalogue

    return catalogue
end

local function addPlayerIcon(catalogue, source, texture, name, identity)
    if
        issecretvalue(texture)
        or issecretvalue(name)
        or issecretvalue(identity)
        or not texture
    then
        return
    end

    local entry, changed = catalogue:AddIcon({
        texture = texture,
        name = name,
        keywords = identity and tostring(identity) or "",
    })
    source.entries[entry] = true
    source.changed = source.changed or changed
end

local function addPlayerItem(catalogue, source, texture, link, itemID)
    if issecretvalue(itemID) or not itemID then return end

    local name = not issecretvalue(link) and link and link:match("%[(.-)%]")
        or nil

    if not name or issecretvalue(texture) or not texture then
        source.pendingItems[itemID] = true
    end

    addPlayerIcon(catalogue, source, texture, name, itemID)
end

local function readSpellbook(catalogue, source)
    for lineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)

        if line then
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local info = C_SpellBook.GetSpellBookItemInfo(
                    slot,
                    Enum.SpellBookSpellBank.Player
                )

                if info then
                    addPlayerIcon(
                        catalogue,
                        source,
                        info.iconID,
                        info.name,
                        info.spellID
                    )
                end
            end
        end
    end
end

local function readEquipment(catalogue, source)
    for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local itemID = GetInventoryItemID("player", slot)

        if not issecretvalue(itemID) and itemID then
            addPlayerItem(
                catalogue,
                source,
                GetInventoryItemTexture("player", slot),
                GetInventoryItemLink("player", slot),
                itemID
            )
        end
    end
end

local function readBags(catalogue, source)
    local bags = { Enum.BagIndex.Backpack }

    for bag = 1, NUM_BAG_SLOTS do
        bags[#bags + 1] = bag
    end

    if NUM_REAGENTBAG_SLOTS > 0 then
        bags[#bags + 1] = Enum.BagIndex.ReagentBag
    end

    for _, bag in ipairs(bags) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)

            if info then
                addPlayerItem(
                    catalogue,
                    source,
                    info.iconFileID,
                    info.hyperlink,
                    info.itemID
                )
            end
        end
    end
end

local PLAYER_SOURCES = {
    { tag = "myspells", read = readSpellbook },
    { tag = "equipped", read = readEquipment },
    { tag = "bags", read = readBags },
}

local PLAYER_EVENTS = {
    SPELLS_CHANGED = "myspells",
    PLAYER_EQUIPMENT_CHANGED = "equipped",
    BAG_UPDATE_DELAYED = "bags",
}

local function queuePlayerSource(catalogue, tag)
    catalogue.playerRefresh = catalogue.playerRefresh or {}
    catalogue.playerRefresh[tag] = true
end

-- Dirty sources belong to the catalogue so simultaneous pickers share scans.
-- Item-info notifications only retry artwork/names a previous scan could not read.
function lib:_QueuePlayerIconRefresh(catalogue, event, itemID, success)
    if not event then
        for _, source in ipairs(PLAYER_SOURCES) do
            queuePlayerSource(catalogue, source.tag)
        end
    elseif PLAYER_EVENTS[event] then
        queuePlayerSource(catalogue, PLAYER_EVENTS[event])
    elseif
        event == "GET_ITEM_INFO_RECEIVED"
        and catalogue.playerSources
        and not issecretvalue(itemID)
        and not issecretvalue(success)
        and success == true
    then
        for tag, source in pairs(catalogue.playerSources) do
            if source.pendingItems[itemID] then
                queuePlayerSource(catalogue, tag)
            end
        end
    end

    return catalogue.playerRefresh ~= nil
end

-- These are browsing shortcuts, not tracking facts. Reconcile membership without
-- removing and restoring unchanged tags, preserving other sources on that icon.
function lib:_RefreshPlayerIconCatalogue(catalogue)
    local pending = catalogue.playerRefresh

    if InCombatLockdown() or not pending then return end

    catalogue.playerRefresh = nil
    catalogue.playerSources = catalogue.playerSources or {}
    local changed = false

    for _, definition in ipairs(PLAYER_SOURCES) do
        local tag = definition.tag

        if pending[tag] then
            local source = {
                entries = {},
                pendingItems = {},
            }
            definition.read(catalogue, source)
            local previous = catalogue.playerSources[tag]

            for entry in pairs(previous and previous.entries or {}) do
                if not source.entries[entry] then
                    entry.tags[tag] = nil
                    changed = true
                end
            end

            for entry in pairs(source.entries) do
                if not entry.tags[tag] then
                    entry.tags[tag] = true
                    changed = true
                end
            end

            changed = changed or source.changed
            catalogue.playerSources[tag] = source
        end
    end

    if changed then
        catalogue.playerRevision = (catalogue.playerRevision or 0) + 1
    end

    return changed == true
end

-- Match Blizzard's icon selector cursor identities. Read only artwork; never
-- cast/use, move inventory, rewrite an action slot, or edit a macro here.
function lib:GetCursorIcon()
    if InCombatLockdown() then
        return nil, "Icon selection is unavailable in combat."
    end

    local kind, id, _, spellID = GetCursorInfo()

    if issecretvalue(kind) or issecretvalue(id) or issecretvalue(spellID) then
        return nil, "This cursor icon is not readable."
    end

    if not kind then return nil end

    local texture

    if kind == "item" then
        texture = C_Item.GetItemIconByID(id)
    elseif kind == "spell" and spellID then
        texture = C_Spell.GetSpellTexture(spellID)
    elseif kind == "mount" then
        texture = select(3, C_MountJournal.GetMountInfoByID(id))
    elseif kind == "battlepet" then
        texture = select(9, C_PetJournal.GetPetInfoByPetID(id))
    elseif kind == "macro" then
        texture = select(2, GetMacroInfo(id))
    elseif kind == "equipmentset" then
        local setID = id

        if type(id) == "string" then
            setID = C_EquipmentSet.GetEquipmentSetID(id)
        end

        if not issecretvalue(setID) and type(setID) == "number" then
            texture = select(2, C_EquipmentSet.GetEquipmentSetInfo(setID))
        end
    elseif kind == "outfit" then
        local info = C_TransmogOutfitInfo.GetOutfitInfo(id)
        texture = info and info.icon
    elseif kind == "petaction" then
        texture = C_Spell.GetSpellTexture(id)
    end

    local icon = Icons.Normalize(texture)
    return icon,
        not icon
                and "This drag does not provide a readable icon. Try a spell, item, macro, mount or pet."
            or nil
end
