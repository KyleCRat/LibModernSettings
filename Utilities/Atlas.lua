local MAJOR, MINOR = "LibModernSettings-1.0", 11
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

function lib:_ApplyTertiarySquareMask(button, artwork, buttonSize)
    assert(type(buttonSize) == "number" and buttonSize > 0 and buttonSize < math.huge,
        "tertiary-square button size must be a positive finite number")

    local mask = artwork._libModernSettingsSquareMask

    if not mask then
        mask = button:CreateMaskTexture()
        artwork:AddMaskTexture(mask)
        artwork._libModernSettingsSquareMask = mask
    end

    -- Clip at the button's inner bevel, not at the icon's own corners. Small
    -- glyphs keep their shape; larger artwork cannot cover the frame's border.
    local size = math.max(1, math.floor(buttonSize * 0.7 + 0.5))
    mask:ClearAllPoints()
    mask:SetSize(size, size)
    mask:SetPoint("CENTER", button, "CENTER", 0, 1)
    mask:SetTexture(self._tertiarySquareMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    return mask
end

function lib:ApplyTertiarySquareArtwork(button, artwork, buttonSize)
    local mask = self:_ApplyTertiarySquareMask(button, artwork, buttonSize)

    -- Filled artwork uses the entire inset; ordinary button icons retain their
    -- requested size and aspect ratio while sharing this same clipping area.
    artwork:SetDrawLayer("OVERLAY", 1)
    artwork:ClearAllPoints()
    artwork:SetSize(mask:GetWidth(), mask:GetHeight())
    artwork:SetPoint("CENTER", mask, "CENTER", 0, 0)

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
