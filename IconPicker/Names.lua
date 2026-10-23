local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("IconPicker/Names", MINOR)
then
    return
end

function lib:_GetIconFilename(fileID)
    local blocks = self._iconNameIndex.blocks
    local first, last = 1, #blocks

    while first <= last do
        local middle = math.floor((first + last) / 2)
        local block = blocks[middle]

        if fileID < block[1] then
            last = middle - 1
        elseif fileID > block[2] then
            first = middle + 1
        else
            if not block.names then
                local names = {}

                for id, name in block[3]:gmatch("(%d+);([^\n]+)") do
                    names[tonumber(id)] = name
                end

                block.names = names
                block[3] = nil
            end

            local name = block.names[fileID]

            if name then return "Interface\\Icons\\" .. name end

            break
        end
    end

    return self._iconUtils.Filename(C_Texture.GetFilenameFromFileDataID(fileID))
end
