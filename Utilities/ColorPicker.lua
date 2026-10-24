local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/ColorPicker", MINOR)
then
    return
end

local Color = lib._colorUtils
local WIDTH = 520
local PAD = 18
local TOP = 42
local SQUARE = 240
local HUE_WIDTH = 24
local HUE_X = PAD + SQUARE + 14
local DETAIL_X = HUE_X + HUE_WIDTH + 18
local DETAIL_WIDTH = WIDTH - PAD - DETAIL_X
local CHANNEL_GAP = 4
local SWATCH_SIZE = 28
local SWATCH_GAP = 2
local SWATCH_STEP = SWATCH_SIZE + SWATCH_GAP
local PALETTE_LABEL_WIDTH = 60
local PALETTE_LABEL_GAP = 4
local ACTION_BUTTON_GAP = 8
local ACTION_BUTTON_WIDTH = (DETAIL_WIDTH - ACTION_BUTTON_GAP) / 2
local CHANNELS = {
    {
        key = "r",
        label = "R",
        max = 255,
    },
    {
        key = "g",
        label = "G",
        max = 255,
    },
    {
        key = "b",
        label = "B",
        max = 255,
    },
    {
        key = "a",
        label = "A (%)",
        max = 100,
    },
}

lib._colorPickerPrototype = lib._colorPickerPrototype or {}
local Picker = lib._colorPickerPrototype
Picker.__index = Picker

local function text(parent, label, x, y, width)
    local region = lib:CreateText(parent, {
        text = label,
        width = width,
        fontObject = GameFontHighlight,
    })
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    return region
end

local function gradient(parent, layer, orientation, first, second)
    local texture = parent:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient(orientation, first, second)
    return texture
end

local function position(frame, x, y)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", x, -y)
end

local function stopDrag(frame)
    frame:SetScript("OnUpdate", nil)
end

local function makeDragSurface(picker, width, height, x, y, update)
    local frame = CreateFrame("Frame", nil, picker.frame)
    frame:SetSize(width, height)
    position(frame, x, y)
    frame:EnableMouse(true)

    local function fromCursor()
        local cursorX, cursorY = GetCursorPosition()
        local scale = frame:GetEffectiveScale()
        update(
            Color.Clamp((cursorX / scale - frame:GetLeft()) / frame:GetWidth()),
            Color.Clamp((frame:GetTop() - cursorY / scale) / frame:GetHeight())
        )
    end

    frame:SetScript("OnMouseDown", function(self, button)
        local session = picker.session

        if
            not session
            or button ~= "LeftButton"
            or not picker:CommitInputs()
            or picker.session ~= session
        then
            return
        end

        fromCursor()

        if picker.session ~= session then return end

        self:SetScript("OnUpdate", function(surface)
            if not IsMouseButtonDown("LeftButton") then
                stopDrag(surface)
                return
            end

            fromCursor()
        end)
    end)
    frame:SetScript("OnMouseUp", stopDrag)
    frame:SetScript("OnHide", stopDrag)
    return frame
end

function Picker:ResizeToContent()
    if not self.paletteBottom then return end

    local height = self.paletteBottom + PAD
    self.frame:SetHeight(height)
    self.frame:SetScale(math.min(1, (UIParent:GetHeight() - 32) / height))
end

function Picker:SetError(message, input)
    self.inputError = message ~= nil
    self.errorInput = message and input or nil

    if message then self.messages:Show(message, "error") end
end

function Picker:Sync()
    local color = self.color
    local r, g, b = Color.FromHSV(self.hue, 1, 1)
    self.hueTexture:SetColorTexture(r, g, b, 1)
    self.cursor:ClearAllPoints()
    self.cursor:SetPoint(
        "CENTER",
        self.square,
        "TOPLEFT",
        self.saturation * SQUARE,
        -(1 - self.brightness) * SQUARE
    )
    self.hueCursor:ClearAllPoints()
    self.hueCursor:SetPoint(
        "CENTER",
        self.hueStrip,
        "TOP",
        0,
        -self.hue * SQUARE
    )
    self.current:SetValue(color)
    self.hex:SetValue(Color.Hex(color))

    for _, channel in ipairs(CHANNELS) do
        self.inputs[channel.key]:SetValue(
            tostring(math.floor(color[channel.key] * channel.max + 0.5))
        )
    end

    self.opacity:SetValue(color.a * 100)
    self:NotifyPreview()
end

function Picker:NotifyPreview()
    local session = self.session

    if not session or not session.onPreview then return end

    local color = self.color
    local previous = session.previewColor or session.original

    if
        color.r == previous.r
        and color.g == previous.g
        and color.b == previous.b
        and color.a == previous.a
    then
        return
    end

    session.previewColor = Color.Copy(color, session.owner.hasOpacity)
    local value = Color.Copy(session.previewColor)
    value.mode = "custom"
    session.onPreview(value)
end

function Picker:SetColor(value)
    if not self.session then return end

    self.color = Color.Copy(value, self.session.owner.hasOpacity)
    local hue, saturation, brightness = Color.ToHSV(self.color)
    -- Achromatic colors have no hue; retain the user's hue-strip position.
    self.hue = saturation > 0 and hue or self.hue
    self.saturation = saturation
    self.brightness = brightness
    self:SetError()
    self:Sync()
end

function Picker:SetHSV(hue, saturation, brightness)
    if not self.session then return end

    self.hue, self.saturation, self.brightness = hue, saturation, brightness
    self.color.r, self.color.g, self.color.b =
        Color.FromHSV(hue, saturation, brightness)
    self:SetError()
    self:Sync()
end

function Picker:CommitInputs()
    local session = self.session
    local valid = self.hex:CommitAndClearFocus()

    for _, channel in ipairs(CHANNELS) do
        if self.session ~= session then return false end

        if not self.inputs[channel.key]:CommitAndClearFocus() then
            valid = false
        end
    end

    local input = self.opacity.valueBox

    if input:HasFocus() then input:ClearFocus() end

    lib:_FlushPendingEditBoxCommit(input)
    return valid
end

function Picker:DiscardInputs()
    self.hex:CancelAndClearFocus()

    for _, input in pairs(self.inputs) do
        input:CancelAndClearFocus()
    end

    self.opacity:SetValue(self.opacity:GetValue())
    self.opacity.valueBox:ClearFocus()
end

function Picker:ToggleFavorite(color)
    local _, message = self.session.owner.palette:ToggleFavorite(color)
    self:SetError(message)
    self:RefreshPalettes()
end

function Picker:Apply()
    local session = self.session

    if not session then return end

    local valid = self:CommitInputs()

    if self.session ~= session then return end

    if not valid or self.inputError then
        self.inputError = nil
        local input = self.errorInput
        local focused = GetCurrentKeyBoardFocus()

        if
            input
            and input:IsVisible()
            and input:IsEnabled()
            and (not focused or focused == input)
        then
            input:FocusValue()
        end

        return
    end

    lib:_CloseColorPicker(self.session.owner, true, true)
end

function Picker:Cancel()
    if self.session then
        lib:_CloseColorPicker(self.session.owner, false, true)
    end
end

function Picker:Populate(row, colors, y)
    position(row.frame, PAD, y)

    for index, entry in ipairs(colors) do
        local button = row.buttons[index]

        if not button then
            button = lib:_CreateColorSwatch(row.frame, { size = SWATCH_SIZE })
            row.buttons[index] = button

            button.onClick = function(mouseButton)
                if mouseButton == "RightButton" then
                    self:ToggleFavorite(button.color)
                else
                    local color = Color.Copy(button.color)

                    if button.preserveOpacity then color.a = self.color.a end

                    self:SetColor(color)
                end
            end
        end

        button.preserveOpacity = entry.preserveOpacity
        button:SetValue(entry.color or entry)
        button:SetSelected(false)
        position(
            button,
            row.swatchOffset + ((index - 1) % row.columns) * SWATCH_STEP,
            math.floor((index - 1) / row.columns) * SWATCH_STEP
        )
        lib:SetTooltip(button, {
            title = entry.label or ("#" .. Color.Hex(button.color)),
            text = "Left-click to use. Right-click to toggle favorite.",
        })
        button:Show()
    end

    for index = #colors + 1, #row.buttons do
        row.buttons[index]:Hide()
    end

    row.empty:SetShown(#colors == 0)
    local rows = math.max(1, math.ceil(#colors / row.columns))
    local height = SWATCH_SIZE + (rows - 1) * SWATCH_STEP
    row.frame:SetHeight(height)
    return y + height + SWATCH_GAP
end

function Picker:RefreshPalettes()
    local owner = self.session.owner
    local y = TOP + SQUARE + 10
    y = self:Populate(self.favorites, owner.palette:GetColors("favorites"), y)
    y = self:Populate(self.recent, owner.palette:GetColors("recent"), y)
    y = self:Populate(self.classes, self.classColors, y)
    y = self:Populate(self.qualities, self.qualityColors, y)
    self.paletteBottom = y - SWATCH_GAP
    self:ResizeToContent()
end

local function createPaletteRow(picker, label, emptyText)
    local frame = CreateFrame("Frame", nil, picker.frame)
    local width = WIDTH - PAD * 2
    local swatchOffset = PALETTE_LABEL_WIDTH
    frame:SetWidth(width)
    local caption = text(frame, label, 0, 0, swatchOffset - PALETTE_LABEL_GAP)
    caption:SetFontObject(GameFontHighlightSmall)
    caption:SetHeight(SWATCH_SIZE)
    caption:SetJustifyH("RIGHT")
    caption:SetJustifyV("MIDDLE")
    local empty =
        text(frame, emptyText or "", swatchOffset, 0, width - swatchOffset)
    empty:SetFontObject(GameFontHighlightSmall)
    empty:SetHeight(SWATCH_SIZE)
    empty:SetJustifyV("MIDDLE")
    empty:SetTextColor(0.6, 0.6, 0.6)
    return {
        frame = frame,
        empty = empty,
        buttons = {},
        swatchOffset = swatchOffset,
        columns = math.floor((width - swatchOffset + SWATCH_GAP) / SWATCH_STEP),
    }
end

local function createPicker()
    local frame = CreateFrame(
        "Frame",
        "LibModernSettingsColorPicker1",
        UIParent,
        "ButtonFrameTemplate"
    )
    frame:Hide()
    frame:SetSize(WIDTH, 660)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetTitle("Color Picker")
    ButtonFrameTemplate_HidePortrait(frame)
    frame.TopTileStreaks:Hide()
    frame.Bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -21)
    frame.Inset:ClearAllPoints()
    frame.Inset:SetPoint("TOPLEFT", 8, -30)
    frame.Inset:SetPoint("BOTTOMRIGHT", -6, 8)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    UISpecialFrames[#UISpecialFrames + 1] = "LibModernSettingsColorPicker1"

    local picker = setmetatable({
        frame = frame,
        inputs = {},
        classColors = {},
        qualityColors = {},
        messages = lib:CreateFlashMessages(frame),
        hue = 0,
    }, Picker)
    lib:EnableTabNavigation(frame)
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
        picker:Cancel()
    end)
    frame:SetScript("OnHide", function()
        if picker.session then lib:_CloseColorPicker(picker.session.owner) end

        frame:StopMovingOrSizing()
    end)

    picker.square = makeDragSurface(
        picker,
        SQUARE,
        SQUARE,
        PAD,
        TOP,
        function(x, y)
            picker:SetHSV(picker.hue, x, 1 - y)
        end
    )
    picker.hueTexture = picker.square:CreateTexture(nil, "BACKGROUND")
    picker.hueTexture:SetAllPoints()
    gradient(
        picker.square,
        "BORDER",
        "HORIZONTAL",
        CreateColor(1, 1, 1, 1),
        CreateColor(1, 1, 1, 0)
    )
    gradient(
        picker.square,
        "ARTWORK",
        "VERTICAL",
        CreateColor(0, 0, 0, 1),
        CreateColor(0, 0, 0, 0)
    )
    picker.cursor = picker.square:CreateTexture(nil, "OVERLAY")
    picker.cursor:SetTexture("Interface\\Buttons\\UI-ColorPicker-Buttons")
    picker.cursor:SetTexCoord(0, 0.15625, 0, 0.625)
    picker.cursor:SetSize(10, 10)

    picker.hueStrip = makeDragSurface(
        picker,
        HUE_WIDTH,
        SQUARE,
        HUE_X,
        TOP,
        function(_, y)
            picker:SetHSV(y, picker.saturation, picker.brightness)
        end
    )

    for index = 0, 5 do
        local r1, g1, b1 = Color.FromHSV(index / 6, 1, 1)
        local r2, g2, b2 = Color.FromHSV((index + 1) / 6, 1, 1)
        local segment = gradient(
            picker.hueStrip,
            "BACKGROUND",
            "VERTICAL",
            CreateColor(r2, g2, b2, 1),
            CreateColor(r1, g1, b1, 1)
        )
        segment:ClearAllPoints()
        segment:SetPoint("TOPLEFT", 0, -index * SQUARE / 6)
        segment:SetSize(HUE_WIDTH, SQUARE / 6)
    end

    picker.hueCursor = picker.hueStrip:CreateTexture(nil, "OVERLAY")
    picker.hueCursor:SetSize(HUE_WIDTH + 6, 3)
    picker.hueCursor:SetColorTexture(1, 1, 1, 1)

    for index, definition in ipairs({
        { key = "current", label = "New" },
        { key = "previous", label = "Previous" },
    }) do
        local button = lib:_CreateColorSwatch(frame, {
            onClick = function(mouseButton)
                local color = definition.key == "current" and picker.color
                    or picker.session.original

                if mouseButton == "RightButton" then
                    picker:ToggleFavorite(color)
                elseif definition.key == "previous" then
                    picker:SetColor(color)
                end
            end,
        })
        local sampleWidth = DETAIL_WIDTH / 2
        local x = DETAIL_X + (index - 1) * sampleWidth
        position(button, x, TOP)
        text(frame, definition.label, x + 38, TOP + 10, sampleWidth - 38)
        lib:SetTooltip(button, {
            title = definition.label,
            text = "Right-click to toggle favorite.",
        })
        picker[definition.key] = button
    end

    text(frame, "Hex", DETAIL_X, TOP + 40, DETAIL_WIDTH)
    picker.hex = lib:CreateTextInput(frame, {
        width = DETAIL_WIDTH,
        maxLetters = 9, -- Eight hex digits plus an optional # prefix.
        onCommit = function(value)
            if not picker.session then return value end

            local color, message = Color.ParseHex(value, picker.color.a)

            if not color then return nil, message end

            picker:SetColor(color)
            return Color.Hex(picker.color)
        end,
        onError = function(message)
            picker:SetError(message, picker.hex)
        end,
    })
    position(picker.hex, DETAIL_X, TOP + 58)

    for _, channel in ipairs(CHANNELS) do
        local input = lib:CreateTextInput(frame, {
            width = 44,
            textInset = 4,
            justifyH = "CENTER",
            maxLetters = 8,
            onCommit = function(value)
                if not picker.session then return value end

                local number = tonumber(value)

                if
                    not number
                    or number ~= number
                    or number < 0
                    or number > channel.max
                then
                    return nil,
                        channel.label
                            .. " must be between 0 and "
                            .. channel.max
                            .. "."
                end

                number = math.floor(number + 0.5)
                local color = Color.Copy(picker.color)
                color[channel.key] = number / channel.max
                picker:SetColor(color)
                return tostring(math.floor(number + 0.5))
            end,
            onError = function(message)
                picker:SetError(message, picker.inputs[channel.key])
            end,
        })
        input.caption = text(frame, channel.label, DETAIL_X, TOP + 98, 44)
        input.caption:SetJustifyH("CENTER")
        picker.inputs[channel.key] = input
    end

    picker.opacity = lib:CreateSlider(frame, {
        label = "Opacity (%)",
        width = DETAIL_WIDTH,
        minValue = 0,
        maxValue = 100,
        step = 1,
        value = 100,
        inputWidth = 44,
        inputHeight = 34,
        onChanged = function(value)
            if picker.session then
                picker.color.a = Color.Clamp(value / 100)
                picker:SetError()
                picker:Sync()
            end
        end,
    })
    position(picker.opacity, DETAIL_X, TOP + 158)

    picker.favorites =
        createPaletteRow(picker, "Favorites", "No favorites yet.")
    picker.recent =
        createPaletteRow(picker, "Recent", "Applied colors will appear here.")
    picker.classes = createPaletteRow(picker, "Class")
    picker.qualities = createPaletteRow(picker, "Quality")
    -- RAID_CLASS_COLORS also includes non-playable ADVENTURER/TRAVELER tokens.
    for _, class in ipairs(CLASS_SORT_ORDER) do
        picker.classColors[#picker.classColors + 1] = {
            label = LOCALIZED_CLASS_NAMES_MALE[class] or class,
            color = Color.Copy(RAID_CLASS_COLORS[class]),
            preserveOpacity = true,
        }
    end

    table.sort(picker.classColors, function(a, b)
        return a.label < b.label
    end)

    for quality = Enum.ItemQuality.Poor, Enum.ItemQuality.WoWToken do
        local r, g, b = C_Item.GetItemQualityColor(quality)
        picker.qualityColors[#picker.qualityColors + 1] = {
            label = _G["ITEM_QUALITY" .. quality .. "_DESC"],
            color = { r = r, g = g, b = b, a = 1 },
            preserveOpacity = true,
        }
    end

    picker.cancel = lib:CreateButton(frame, {
        text = "Cancel",
        variant = "small",
        width = ACTION_BUTTON_WIDTH,
        onClick = function()
            picker:Cancel()
        end,
    })
    position(picker.cancel, DETAIL_X, TOP + SQUARE - picker.cancel:GetHeight())
    picker.apply = lib:CreateButton(frame, {
        text = "Apply",
        variant = "small",
        width = ACTION_BUTTON_WIDTH,
        onClick = function()
            picker:Apply()
        end,
    })
    position(
        picker.apply,
        DETAIL_X + ACTION_BUTTON_WIDTH + ACTION_BUTTON_GAP,
        TOP + SQUARE - picker.apply:GetHeight()
    )
    return picker
end

function lib:_OpenColorPicker(owner)
    self:_NotifyInteraction(owner, "open")

    if self._colorPicker and self._colorPicker.session then
        self:_CloseColorPicker(self._colorPicker.session.owner)
    end

    self._colorPicker = self._colorPicker or createPicker()
    local picker = self._colorPicker
    local original = owner:GetValue()
    picker.session = {
        owner = owner,
        original = original,
        onPreview = owner.onPreview,
    }
    picker.hue = 0
    picker:SetColor(original)
    picker.previous:SetValue(original)
    picker.opacity:SetShown(owner.hasOpacity)
    picker.inputs.a:SetShown(owner.hasOpacity)
    picker.inputs.a.caption:SetShown(owner.hasOpacity)
    local count = owner.hasOpacity and 4 or 3
    local width = (DETAIL_WIDTH - (count - 1) * CHANNEL_GAP) / count

    for index = 1, count do
        local input = picker.inputs[CHANNELS[index].key]
        local x = DETAIL_X + (index - 1) * (width + CHANNEL_GAP)
        input:SetWidth(width)
        position(input, x, TOP + 116)
        input.caption:SetWidth(width)
        input.caption:ClearAllPoints()
        input.caption:SetPoint(
            "TOPLEFT",
            picker.frame,
            "TOPLEFT",
            x,
            -(TOP + 98)
        )
    end

    picker:RefreshPalettes()
    picker.frame:SetFrameLevel(owner:GetFrameLevel() + 20)
    picker.frame:Show()
    picker.hex:FocusValue()
end

function lib:_CloseColorPicker(owner, apply, returnFocus)
    local picker = self._colorPicker

    if not picker or not picker.session or picker.session.owner ~= owner then
        return
    end

    local session = picker.session
    local color = Color.Copy(picker.color, owner.hasOpacity)
    picker.session = nil
    stopDrag(picker.square)
    stopDrag(picker.hueStrip)
    picker:DiscardInputs()
    picker.messages:Clear()
    picker.frame:Hide()

    if session.previewColor then session.onPreview(nil) end

    if apply and owner.enabled and owner:IsVisible() then
        owner.palette:Record(color)
        owner:_AcceptPickerColor(color)
    end

    if
        returnFocus
        and not picker.session
        and owner.enabled
        and owner:IsVisible()
    then
        owner.buttons.custom:_FocusForTab()
    end
end
