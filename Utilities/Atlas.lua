local MAJOR, MINOR = "LibModernSettings-1.0", 2
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

function lib:_CreateAtlasTexture(owner, layer, atlas)
    local texture = owner:CreateTexture(nil, layer)

    texture:SetAllPoints(owner)
    texture:SetAtlas(atlas, false)

    return texture
end
