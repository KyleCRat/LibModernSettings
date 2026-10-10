local MAJOR, MINOR = "LibModernSettings-1.0", 8
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/FlashMessages", MINOR) then
    return
end

local STYLES = {
    success = {
        label = "Success",
        textColor = { 0.6, 0.95, 0.65 },
        backgroundColor = { 0.04, 0.16, 0.06, 0.97 },
    },
    info = {
        label = "Info",
        textColor = { 0.65, 0.85, 1 },
        backgroundColor = { 0.045, 0.105, 0.2, 0.97 },
    },
    error = {
        label = "Error",
        textColor = { 1, 0.65, 0.65 },
        backgroundColor = { 0.2, 0.045, 0.045, 0.97 },
    },
}
local SCREEN_MARGIN = 12
local OWNER_GAP = 8
local MESSAGE_GAP = 4
local PADDING_X = 16
local PADDING_Y = 8
local TEXT_CLOSE_GAP = 8
local CLOSE_SIZE = 24
local CORNER_OVERLAP = 8

lib._flashMessagesPrototype = lib._flashMessagesPrototype or {}
local Stack = lib._flashMessagesPrototype
Stack.__index = Stack

local function positiveOption(options, key, default)
    local value = options[key]
    if value == nil then
        return default
    end
    assert(type(value) == "number" and value > 0 and value < math.huge,
        key .. " must be a finite positive number")
    return value
end

local function createMessage(stack)
    local frame = CreateFrame("Frame", nil, stack.frame)
    frame:EnableMouseMotion(true)
    local border = CreateFrame("Frame", nil, frame, "DialogBorderOpaqueTemplate")
    border:SetFrameLevel(frame:GetFrameLevel())
    local text = lib:CreateText(frame)
    text:SetPoint("LEFT", PADDING_X, 0)
    text:SetWordWrap(true)
    text:SetNonSpaceWrap(true)

    local leftCornerHeight = border.TopLeftCorner:GetHeight() + border.BottomLeftCorner:GetHeight()
    local rightCornerHeight = border.TopRightCorner:GetHeight() + border.BottomRightCorner:GetHeight()
    local entry = {
        frame = frame,
        border = border,
        text = text,
        leftCornerHeight = leftCornerHeight,
        rightCornerHeight = rightCornerHeight,
        minHeight = math.max(
            leftCornerHeight - CORNER_OVERLAP,
            rightCornerHeight - CORNER_OVERLAP,
            CLOSE_SIZE + PADDING_Y * 2
        ),
    }
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButtonNoScripts")
    close:SetSize(CLOSE_SIZE, CLOSE_SIZE)
    close:SetPoint("RIGHT", -PADDING_X, 0)
    -- The native template has a fixed frame level; keep it with its message.
    close:SetFrameLevel(frame:GetFrameLevel() + 1)
    close:SetScript("OnClick", function()
        stack:Dismiss(entry.id)
    end)
    entry.close = close
    return entry
end

function Stack:_Release(index)
    local entry = table.remove(self.messages, index)
    entry.frame:Hide()
    entry.text:SetText("")
    entry.id = nil
    entry.message = nil
    self.pool[#self.pool + 1] = entry
end

function Stack:Clear()
    for index = #self.messages, 1, -1 do
        self:_Release(index)
    end
    self.frame:SetScript("OnUpdate", nil)
    self.frame:Hide()
end

function Stack:Dismiss(id)
    for index, entry in ipairs(self.messages) do
        if entry.id == id then
            self:_Release(index)
            if #self.messages == 0 then
                self:Clear()
            else
                self:_Layout()
                self:_Position()
            end
            return true
        end
    end
    return false
end

function Stack:_Layout()
    local offset = 0
    for _, entry in ipairs(self.messages) do
        entry.text:SetWidth(math.max(1, self.layoutWidth - PADDING_X * 2 - CLOSE_SIZE - TEXT_CLOSE_GAP))
        local height = math.max(entry.minHeight, entry.text:GetStringHeight() + PADDING_Y * 2)
        entry.frame:SetSize(self.layoutWidth, height)
        -- Corner tails can overlap; native edges anchor between them and must not invert.
        entry.border.LeftEdge:SetShown(height > entry.leftCornerHeight)
        entry.border.RightEdge:SetShown(height > entry.rightCornerHeight)
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -offset)
        offset = offset + height + MESSAGE_GAP
    end
    self.height = math.max(0, offset - MESSAGE_GAP)
    self.frame:SetSize(self.layoutWidth, self.height)
end

function Stack:_Position()
    local owner = self.owner
    local bottom = owner:GetBottom()
    local center = owner:GetCenter()
    if not bottom or not center then
        return
    end

    -- Match the owner's effective scale, including scaled input-group parents.
    -- The overlay lives outside that hierarchy so scroll clipping cannot cut it off.
    local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if self.scale ~= scale then
        self.scale = scale
        self.frame:SetScale(scale)
    end
    local screenWidth = UIParent:GetWidth() / scale
    local screenHeight = UIParent:GetHeight() / scale
    local width = math.min(self.width, math.max(1, screenWidth - SCREEN_MARGIN * 2))
    if self.layoutWidth ~= width then
        self.layoutWidth = width
        self:_Layout()
    end

    local x = math.max(SCREEN_MARGIN, math.min(center - width / 2,
        screenWidth - SCREEN_MARGIN - width))
    local top = bottom - OWNER_GAP
    if top - self.height < SCREEN_MARGIN then
        top = owner:GetTop() + OWNER_GAP + self.height
    end
    top = math.min(top, screenHeight - SCREEN_MARGIN)
    if self.x ~= x or self.top ~= top then
        self.x, self.top = x, top
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
    end

    local strata = owner:GetFrameStrata()
    local level = owner:GetFrameLevel() + 20
    if self.strata ~= strata or self.level ~= level then
        self.strata, self.level = strata, level
        self.frame:SetFrameStrata(strata)
        self.frame:SetFrameLevel(level)
    end
end

function Stack:_Update(elapsed)
    if not self.owner:IsVisible() then
        self:Clear()
        return
    end
    local changed = false
    for index = #self.messages, 1, -1 do
        local entry = self.messages[index]
        if not entry.frame:IsMouseMotionFocus() and not entry.close:IsMouseMotionFocus() then
            entry.age = entry.age + elapsed
        end
        if entry.age >= self.duration + self.fadeDuration then
            self:_Release(index)
            changed = true
        elseif entry.age > self.duration then
            entry.frame:SetAlpha(1 - (entry.age - self.duration) / self.fadeDuration)
        end
    end
    if #self.messages == 0 then
        self:Clear()
        return
    end
    if changed then
        self:_Layout()
    end
    -- Only active stacks update: follow movement and screen/scale changes while fading.
    self:_Position()
end

function Stack:Show(message, state)
    assert(type(message) == "string" and message ~= "", "message must be a nonempty string")
    state = state or "info"
    local style = assert(STYLES[state], "state must be 'success', 'info', or 'error'")
    if not self.owner:IsVisible() then
        return nil
    end

    for index, entry in ipairs(self.messages) do
        if entry.message == message and entry.state == state then
            self:_Release(index)
            break
        end
    end
    if #self.messages >= self.maxMessages then
        self:_Release(1)
    end

    local entry = table.remove(self.pool) or createMessage(self)
    self.nextID = self.nextID + 1
    entry.id = self.nextID
    entry.message = message
    entry.state = state
    entry.age = 0
    entry.text:SetText(style.label .. ": " .. message)
    entry.text:SetTextColor(unpack(style.textColor))
    entry.border.Bg:SetColorTexture(unpack(style.backgroundColor))
    entry.frame:SetAlpha(1)
    entry.frame:Show()
    self.messages[#self.messages + 1] = entry
    self:_Layout()
    self:_Position()
    self.frame:Show()
    self.frame:SetScript("OnUpdate", self.onUpdate)
    return entry.id
end

function lib:CreateFlashMessages(owner, options)
    assert(owner and owner.HookScript and owner.GetEffectiveScale,
        "flash messages require an ordinary owner frame")
    options = options or {}
    assert(type(options) == "table", "flash message options must be a table")
    local width = positiveOption(options, "width", 360)
    local duration = positiveOption(options, "duration", 6)
    local fadeDuration = positiveOption(options, "fadeDuration", 0.35)
    local maxMessages = positiveOption(options, "maxMessages", 4)
    assert(maxMessages == math.floor(maxMessages), "maxMessages must be an integer")

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    local stack = setmetatable({
        owner = owner,
        frame = frame,
        width = width,
        layoutWidth = width,
        duration = duration,
        fadeDuration = fadeDuration,
        maxMessages = maxMessages,
        nextID = 0,
        messages = {},
        pool = {},
    }, Stack)
    stack.onUpdate = function(_, elapsed)
        stack:_Update(elapsed)
    end
    owner:HookScript("OnHide", function()
        stack:Clear()
    end)
    return stack
end
