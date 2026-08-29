local MAJOR, MINOR = "LibModernSettings-1.0", 6
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local EDIT_BOX_FOCUS_ATLAS =
    "common-button-tertiary-depressed-normal-glow"
local EDIT_BOX_FOCUS_LEFT_OFFSET = -2
local EDIT_BOX_FOCUS_TOP_OFFSET = 3
local EDIT_BOX_FOCUS_RIGHT_OFFSET = 2
local EDIT_BOX_FOCUS_BOTTOM_OFFSET = -1

function lib:_CreateAtlasTexture(owner, layer, atlas)
    local texture = owner:CreateTexture(nil, layer)

    texture:SetAllPoints(owner)
    texture:SetAtlas(atlas, false)

    return texture
end

function lib:_CreateEditBoxFocusTexture(editBox)
    local texture = editBox:CreateTexture(nil, "BORDER")

    texture:SetAtlas(EDIT_BOX_FOCUS_ATLAS, false)
    texture:SetPoint(
        "TOPLEFT",
        editBox,
        "TOPLEFT",
        EDIT_BOX_FOCUS_LEFT_OFFSET,
        EDIT_BOX_FOCUS_TOP_OFFSET
    )
    texture:SetPoint(
        "BOTTOMRIGHT",
        editBox,
        "BOTTOMRIGHT",
        EDIT_BOX_FOCUS_RIGHT_OFFSET,
        EDIT_BOX_FOCUS_BOTTOM_OFFSET
    )
    texture:Hide()

    return texture
end
