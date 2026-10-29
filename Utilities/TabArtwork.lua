local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/TabArtwork", MINOR)
then
    return
end

lib._tabArtwork = lib._tabArtwork or {}
local Art = lib._tabArtwork
local LAYERS = {
    { key = "background", x = 0, y = 64, layer = "BACKGROUND", sublevel = 0 },
    { key = "accent", x = 112, y = 0, layer = "BACKGROUND", sublevel = 1 },
    { key = "border", x = 0, y = 0, layer = "BORDER" },
    { key = "hover", x = 112, y = 64, layer = "ARTWORK" },
    { key = "selected", x = 112, y = 128, layer = "ARTWORK" },
}
local COLUMNS = { { 0, 32 }, { 32, 33 }, { 80, 112 } }
local ROWS = { { 0, 32 }, { 32, 33 }, { 48, 64 } }
local COLORS = {
    border = { 162 / 255, 161 / 255, 158 / 255, 1 },
    accent = { 53 / 255, 47 / 255, 44 / 255, 1 },
    highlight = { 243 / 255, 221 / 255, 131 / 255, 1 },
    text = { 0.92, 0.92, 0.92, 1 },
    selectedText = { 1, 0.82, 0, 1 },
    flatAccent = { 1, 1, 1, 1 },
}

local function uv(offset, slice)
    if slice[2] - slice[1] == 1 then
        local center = (offset + slice[1] + 0.5) / 256
        return center, center
    end

    return (offset + slice[1]) / 256, (offset + slice[2]) / 256
end

function Art.Create(tab)
    tab.art = { layers = {}, visible = {}, columns = {}, rows = {}, flat = {} }

    for _, layer in ipairs(LAYERS) do
        local slices = {}
        tab.art.layers[layer.key] = slices

        for row, rowSlice in ipairs(ROWS) do
            local top, bottom = uv(layer.y, rowSlice)

            for column, columnSlice in ipairs(COLUMNS) do
                local left, right = uv(layer.x, columnSlice)
                local texture =
                    tab:CreateTexture(nil, layer.layer, nil, layer.sublevel)
                texture:SetTexCoord(left, right, top, bottom)
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
                slices[(row - 1) * 3 + column] = texture
            end
        end
    end

    for index = 1, 5 do
        local texture =
            tab:CreateTexture(nil, index == 1 and "BACKGROUND" or "BORDER")
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
        tab.art.flat[index] = texture
    end
end

function Art.SetTexture(tab)
    local path = tab.appearance.texture or lib._headerTabTexture

    if tab.art.path == path then return end

    tab.art.path = path

    for _, layer in ipairs(LAYERS) do
        local slices = tab.art.layers[layer.key]

        for row, rowSlice in ipairs(ROWS) do
            local top, bottom = uv(layer.y, rowSlice)

            for column, columnSlice in ipairs(COLUMNS) do
                local left, right = uv(layer.x, columnSlice)
                local texture = slices[(row - 1) * 3 + column]
                texture:SetTexture(path, "CLAMP", "CLAMP", "LINEAR")
                texture:SetTexCoord(left, right, top, bottom)
            end
        end
    end
end

local function place(texture, tab, x, y, width, height)
    texture:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", x, y)
    texture:SetSize(width, height)
end

function Art.Layout(tab)
    local x, y, width, height = tab:GetRect()

    if
        not x
        or not y
        or not width
        or not height
        or width <= 0
        or height <= 0
    then
        return
    end

    local unit = PixelUtil.GetPixelToUIUnitFactor() / tab:GetEffectiveScale()
    local art = tab.art

    if
        art.x == x
        and art.y == y
        and art.width == width
        and art.height == height
        and art.unit == unit
    then
        return
    end

    art.x, art.y, art.width, art.height, art.unit = x, y, width, height, unit
    local left = math.floor(x / unit + 0.5)
    local bottom = math.floor(y / unit + 0.5)
    local right = math.floor((x + width) / unit + 0.5)
    local top = math.floor((y + height) / unit + 0.5)
    local pixelWidth, pixelHeight = right - left, top - bottom

    if pixelWidth <= 0 or pixelHeight <= 0 then
        art.collapsed = true
        Art.Paint(tab)
        return
    end

    art.collapsed = false
    art.flatSidesVisible = pixelHeight > 2

    local corner = math.min(
        math.max(1, math.floor(32 / unit + 0.5)),
        math.floor(pixelWidth / 2),
        math.floor(pixelHeight / 2 + 0.5)
    )
    local foot = math.min(pixelHeight - corner, math.floor(corner / 2 + 0.5))
    local columns, rows = art.columns, art.rows
    columns[1], columns[2], columns[3], columns[4] =
        left, left + corner, right - corner, right
    rows[1], rows[2], rows[3], rows[4] =
        top, top - corner, bottom + foot, bottom

    -- One set of physical edges joins every layer. Single-texel UV strips
    -- preserve the authored corners without sampling neighbouring atlas art.
    for row = 1, 3 do
        for column = 1, 3 do
            local index = (row - 1) * 3 + column
            local drawWidth = (columns[column + 1] - columns[column]) * unit
            local drawHeight = (rows[row] - rows[row + 1]) * unit
            art.visible[index] = drawWidth > 0 and drawHeight > 0

            if art.visible[index] then
                for _, slices in pairs(art.layers) do
                    place(
                        slices[index],
                        tab,
                        columns[column] * unit - x,
                        rows[row + 1] * unit - y,
                        drawWidth,
                        drawHeight
                    )
                end
            end
        end
    end

    local offsetX, offsetY = left * unit - x, bottom * unit - y
    local fullWidth, fullHeight = pixelWidth * unit, pixelHeight * unit
    place(art.flat[1], tab, offsetX, offsetY, fullWidth, fullHeight)
    place(art.flat[2], tab, offsetX, offsetY, fullWidth, unit)
    place(
        art.flat[3],
        tab,
        offsetX,
        offsetY + fullHeight - unit,
        fullWidth,
        unit
    )
    place(
        art.flat[4],
        tab,
        offsetX,
        offsetY + unit,
        unit,
        math.max(unit, fullHeight - unit * 2)
    )
    place(
        art.flat[5],
        tab,
        offsetX + fullWidth - unit,
        offsetY + unit,
        unit,
        math.max(unit, fullHeight - unit * 2)
    )
    Art.Paint(tab)
end

local function color(tab, key)
    return tab.appearance.colors and tab.appearance.colors[key] or COLORS[key]
end

local function paintLayer(tab, key, shown, tint, opacity)
    for index, texture in ipairs(tab.art.layers[key]) do
        texture:SetVertexColor(
            tint[1],
            tint[2],
            tint[3],
            (tint[4] or 1) * opacity
        )
        texture:SetShown(
            shown and not tab.art.collapsed and tab.art.visible[index] == true
        )
    end
end

function Art.Paint(tab)
    local enabled, selected = tab:IsEnabled(), tab:IsSelected()
    local hovered, pressed =
        enabled and tab.hovered, enabled and tab.pressed and not selected
    local flat = tab.appearance.mode == "flat"
    local opacity = enabled and 1 or 0.4
    local background = selected and 0.10 or (pressed and 0.035 or 0.06)
    local gray = tab.art.backgroundColor or {}
    tab.art.backgroundColor = gray
    gray[1], gray[2], gray[3], gray[4] =
        background, background, background, 0.95
    paintLayer(tab, "background", not flat, gray, 1)
    paintLayer(tab, "accent", not flat, color(tab, "accent"), opacity)
    paintLayer(tab, "border", not flat, color(tab, "border"), opacity)
    paintLayer(
        tab,
        "hover",
        not flat and not selected and (hovered or pressed),
        color(tab, "highlight"),
        opacity
    )
    paintLayer(
        tab,
        "selected",
        not flat and selected,
        color(tab, "highlight"),
        opacity
    )

    for index, texture in ipairs(tab.art.flat) do
        texture:SetShown(
            flat
                and not tab.art.collapsed
                and (index < 4 or tab.art.flatSidesVisible)
        )
    end

    if flat then
        local fill = not enabled and 0.07
            or (
                selected and 0.12
                or (pressed and 0.06 or (hovered and 0.18 or 0.10))
            )
        tab.art.flat[1]:SetVertexColor(fill, fill, fill, 0.95)
        local border = not enabled and 0.25 or (hovered and 0.7 or 0.45)

        for index = 2, 5 do
            if enabled and selected then
                tab.art.flat[index]:SetVertexColor(
                    unpack(color(tab, "flatAccent"))
                )
            else
                tab.art.flat[index]:SetVertexColor(border, border, border, 1)
            end
        end
    end

    local text = color(tab, selected and "selectedText" or "text")
    tab.Text:SetTextColor(
        enabled and text[1] or 0.5,
        enabled and text[2] or 0.5,
        enabled and text[3] or 0.5,
        text[4] or 1
    )
    tab.Text:SetPoint(
        "CENTER",
        tab,
        "CENTER",
        pressed and 1 or 0,
        (flat and 0 or -2) - (pressed and 1 or 0)
    )
end
