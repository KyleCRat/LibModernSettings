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

-- Inset action squares share the same footprint inside recessed inputs.
lib._inputActionSquareStyle = {
    size = 26,
    inset = 4,
    iconSize = 12,
}

function lib:_CreateAtlasTexture(owner, layer, atlas)
    local texture = owner:CreateTexture(nil, layer)

    texture:SetAllPoints(owner)
    texture:SetAtlas(atlas, false)

    return texture
end

function lib:_ApplyTertiarySquareMask(button, artwork, buttonSize, inset)
    assert(type(buttonSize) == "number" and buttonSize > 0 and buttonSize < math.huge,
        "tertiary-square button size must be a positive finite number")
    assert(inset == nil or (type(inset) == "number" and inset >= 0 and inset < math.huge),
        "tertiary-square mask inset must be finite and non-negative")

    local mask = artwork._libModernSettingsSquareMask

    if not mask then
        mask = button:CreateMaskTexture()
        artwork:AddMaskTexture(mask)
        artwork._libModernSettingsSquareMask = mask
    end

    -- Clip at the button's inner bevel, not at the icon's own corners. Small
    -- glyphs keep their shape; larger artwork cannot cover the frame's border.
    local size = inset and (buttonSize - inset * 2) or (buttonSize * 0.7)
    size = math.max(1, math.floor(size + 0.5))
    if not self:_LayoutSizeMatches(mask:GetWidth(), size)
        or not self:_LayoutSizeMatches(mask:GetHeight(), size) then
        mask:SetSize(size, size)
    end
    self:_SetLayoutPoint(mask, "CENTER", button, "CENTER", 0, 1)
    if mask._libModernSettingsMaskPath ~= self._tertiarySquareMask then
        mask:SetTexture(self._tertiarySquareMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask._libModernSettingsMaskPath = self._tertiarySquareMask
    end

    return mask
end

function lib:ApplyTertiarySquareArtwork(button, artwork, buttonSize)
    local mask = self:_ApplyTertiarySquareMask(button, artwork, buttonSize)

    -- Filled artwork uses the entire inset; ordinary button icons retain their
    -- requested size and aspect ratio while sharing this same clipping area.
    artwork:SetDrawLayer("OVERLAY", 1)
    artwork:SetSize(mask:GetWidth(), mask:GetHeight())
    self:_SetLayoutPoint(artwork, "CENTER", mask, "CENTER", 0, 0)

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
