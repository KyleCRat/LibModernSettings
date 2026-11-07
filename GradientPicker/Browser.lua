local MAJOR, MINOR = "LibModernSettings-1.0", 14
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("GradientPicker/Browser", MINOR)
then
    return
end

lib._gradientPickerUI = lib._gradientPickerUI or {}
local UI = lib._gradientPickerUI
local Model = lib._gradientUtils
local WIDTH, BAR_WIDTH, HANDLE = 660, 584, 16
local corners = { { -1, 1 }, { -1, -1 }, { 1, 1 }, { 1, -1 } }

local function surface(parent, x, y, width, height)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    frame:SetSize(width, height)
    frame:SetClipsChildren(true)
    frame.fill = CreateFrame("Frame", nil, frame)
    frame.fill:SetAllPoints()
    frame.textures = {}
    -- A quiet checkerboard makes alpha visible without changing the gradient.
    local checker = frame:CreateTexture(nil, "BACKGROUND")
    checker:SetAllPoints()
    checker:SetColorTexture(0.2, 0.2, 0.2, 1)
    for row = 0, math.ceil(height / 16) - 1 do
        for column = 0, math.ceil(width / 16) - 1 do
            if (row + column) % 2 == 0 then
                local tile = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
                tile:SetPoint("TOPLEFT", column * 16, -row * 16)
                tile:SetSize(
                    math.min(16, width - column * 16),
                    math.min(16, height - row * 16)
                )
                tile:SetColorTexture(0.32, 0.32, 0.32, 1)
            end
        end
    end
    return frame
end

function UI.Draw(surfaceFrame, value, angle)
    local width, height = surfaceFrame:GetSize()
    local radians = math.rad(angle)
    local dx, dy = math.cos(radians), math.sin(radians)
    local along = math.abs(dx) * width + math.abs(dy) * height
    local across = math.abs(dy) * width + math.abs(dx) * height
    local stops = value.stops
    local used = 0
    -- Render-only extensions cover the endpoints without adding draft stops.
    for index = 0, #stops do
        local first = stops[math.max(1, index)]
        local last = stops[math.min(#stops, index + 1)]
        local start = index == 0 and 0 or first.position
        local finish = index == #stops and 1 or last.position
        local extent = (finish - start) * along
        if extent > 0 then
            used = used + 1
            local texture = surfaceFrame.textures[used]
            if not texture then
                texture = surfaceFrame.fill:CreateTexture(nil, "ARTWORK")
                texture:SetColorTexture(1, 1, 1, 1)
                texture:SetSnapToPixelGrid(false)
                texture:SetTexelSnappingBias(0)
                surfaceFrame.textures[used] = texture
            end
            local center = ((start + finish) / 2 - 0.5) * along
            texture:ClearAllPoints()
            texture:SetPoint(
                "CENTER",
                surfaceFrame.fill,
                "CENTER",
                center * dx,
                center * dy
            )
            texture:SetSize(extent, across)
            texture:SetGradient(
                "HORIZONTAL",
                CreateColor(first.r, first.g, first.b, first.a),
                CreateColor(last.r, last.g, last.b, last.a)
            )
            for vertex, corner in ipairs(corners) do
                local x, y = corner[1] * extent / 2, corner[2] * across / 2
                texture:SetVertexOffset(
                    vertex,
                    x * dx - y * dy - x,
                    x * dy + y * dx - y
                )
            end
            texture:Show()
        end
    end
    for index = used + 1, #surfaceFrame.textures do
        surfaceFrame.textures[index]:Hide()
    end
end

local function createHandle(picker, index)
    local button = CreateFrame("Button", nil, picker.frame)
    button:SetSize(HANDLE, 26)
    button.border = button:CreateTexture(nil, "BACKGROUND")
    button.border:SetAllPoints()
    button.swatch = button:CreateTexture(nil, "ARTWORK")
    button.swatch:SetPoint("TOPLEFT", 2, -2)
    button.swatch:SetPoint("BOTTOMRIGHT", -2, 2)
    button.label = lib:CreateText(button, {
        text = tostring(index),
        fontObject = GameFontHighlightSmall,
    })
    button.label:SetPoint("CENTER")
    button:SetScript("OnMouseDown", function(_, key)
        if key == "LeftButton" then picker:StartDrag(index) end
    end)
    button:SetScript("OnMouseUp", function()
        picker:StopDrag()
    end)
    lib:SetTooltip(
        button,
        "Drag to move this stop. Stops stay at least 3% apart."
    )
    return button
end

function UI.Paint(picker)
    local value = picker.value
    UI.Draw(picker.preview, value, value.angle)
    UI.Draw(picker.bar, value, 0)
    for index, stop in ipairs(value.stops) do
        local button = picker.handles[index] or createHandle(picker, index)
        picker.handles[index] = button
        button:ClearAllPoints()
        button:SetPoint(
            "TOP",
            picker.bar,
            "BOTTOMLEFT",
            stop.position * BAR_WIDTH,
            -5
        )
        button.border:SetColorTexture(
            1,
            index == picker.selected and 0.8 or 1,
            index == picker.selected and 0.15 or 1,
            1
        )
        button.swatch:SetColorTexture(stop.r, stop.g, stop.b, stop.a)
        button:Show()
    end
    for index = #value.stops + 1, #picker.handles do
        picker.handles[index]:Hide()
    end
    picker.caption:SetText("Stop " .. picker.selected .. " of " .. #value.stops)
    picker.remove:SetControlEnabled(#value.stops > 2)
    picker.add:SetControlEnabled(#value.stops < Model.maximum)
end

local function field(picker, label, kind, x, y, options)
    local wrapper = lib:CreateField(picker.frame, {
        label = label,
        controlType = kind,
        controlOptions = options,
        width = 290,
    })
    wrapper:SetPoint("TOPLEFT", x, -y)
    return wrapper:GetControl()
end

function UI.Create(picker, parent, options)
    local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate")
    picker.frame = frame
    frame:Hide()
    frame:SetSize(WIDTH, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function() end)
    ButtonFrameTemplate_HidePortrait(frame)
    frame.TopTileStreaks:Hide()
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", 12, -30)
    frame.Inset:SetPoint("BOTTOMRIGHT", -12, 50)
    frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -1)
    frame.CloseButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.TitleContainer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.CloseButton:SetScript("OnClick", function()
        picker:Close()
    end)
    frame:SetScript("OnHide", function()
        if picker.session then picker:Close() end
    end)
    frame:SetScript("OnEvent", function(_, event, key)
        if event == "GLOBAL_MOUSE_UP" then
            if key == "LeftButton" then picker:StopDrag() end
        else
            picker:Close()
        end
    end)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key)
        frame:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then picker:Close() end
    end)
    picker.messages = lib:CreateFlashMessages(frame)
    local hint = lib:CreateText(frame, {
        width = 612,
        text = "Drag a numbered stop, or select it to edit its position and color. Stops stay at least 3% apart. Apply saves your changes.",
    })
    hint:SetPoint("TOPLEFT", 24, -38)
    picker.preview = surface(frame, 38, 78, BAR_WIDTH, 112)
    picker.bar = surface(frame, 38, 214, BAR_WIDTH, 16)
    picker.caption =
        lib:CreateText(frame, { text = "", fontObject = GameFontHighlight })
    picker.caption:SetPoint("TOPLEFT", 24, -272)
    picker.angle = field(picker, "Gradient angle", "slider", 24, 300, {
        minValue = 0,
        maxValue = 360,
        step = 1,
        value = 0,
        onChanged = function(value)
            picker:SetAngle(value)
        end,
    })
    picker.position = field(picker, "Stop position (%)", "slider", 346, 300, {
        minValue = 0,
        maxValue = 100,
        step = 0.1,
        snapToStep = false,
        value = 0,
        onChanged = function(value)
            picker:MoveStop(picker.selected, value / 100)
            if picker.session then
                picker.position:SetValue(
                    picker.value.stops[picker.selected].position * 100
                )
            end
        end,
    })
    picker.color = field(picker, "Stop color and opacity", "color", 24, 396, {
        hasOpacity = true,
        palette = options.palette,
        onChanged = function(value)
            picker:SetColor(value)
        end,
        onPreview = function(value)
            picker:SetColor(value)
        end,
    })
    picker.add = lib:CreateButton(frame, {
        text = "Add stop",
        width = 86,
        onClick = function()
            picker:AddStop()
        end,
    })
    picker.add:SetPoint("TOPLEFT", 346, -418)
    picker.remove = lib:CreateButton(frame, {
        text = "Remove",
        width = 86,
        onClick = function()
            picker:RemoveStop()
        end,
    })
    picker.remove:SetPoint("LEFT", picker.add, "RIGHT", 8, 0)
    local reverse = lib:CreateButton(frame, {
        text = "Reverse",
        width = 94,
        onClick = function()
            picker:Reverse()
        end,
    })
    reverse:SetPoint("LEFT", picker.remove, "RIGHT", 8, 0)
    local cancel = lib:CreateButton(frame, {
        text = "Cancel",
        onClick = function()
            picker:Close()
        end,
    })
    cancel:SetPoint("BOTTOMRIGHT", -24, 10)
    local apply = lib:CreateButton(frame, {
        text = "Apply",
        onClick = function()
            picker:Apply()
        end,
    })
    apply:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    local reset = lib:CreateButton(frame, {
        variant = "square",
        iconAtlas = "common-icon-undo",
        tooltip = "Preview the default gradient. Apply saves it; Cancel keeps the previous gradient.",
        onClick = function()
            picker:Reset()
        end,
    })
    reset:SetPoint("BOTTOMLEFT", 24, 10)
    lib:EnableTabNavigation(frame)
end
