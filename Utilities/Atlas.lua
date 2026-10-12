local MAJOR, MINOR = "LibModernSettings-1.0", 9
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/Atlas", MINOR) then
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

function lib:ApplyTertiarySquareArtwork(button, artwork, buttonSize)
    assert(type(buttonSize) == "number" and buttonSize > 0 and buttonSize < math.huge,
        "tertiary-square button size must be a positive finite number")

    -- Keep artwork above the state textures' opaque centers and inside the bevel.
    local size = math.max(1, math.floor(buttonSize * 0.7 + 0.5))
    artwork:SetDrawLayer("OVERLAY", 1)
    artwork:ClearAllPoints()
    artwork:SetSize(size, size)
    artwork:SetPoint("CENTER", button, "CENTER", 0, 1)

    local mask = artwork._libModernSettingsSquareMask
    if not mask then
        mask = button:CreateMaskTexture()
        mask:SetAllPoints(artwork)
        artwork:AddMaskTexture(mask)
        artwork._libModernSettingsSquareMask = mask
    end
    mask:SetTexture(self._tertiarySquareMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    return mask
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
