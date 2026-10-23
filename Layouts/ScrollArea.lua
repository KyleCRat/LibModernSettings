local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Layouts/ScrollArea", MINOR)
then
    return
end

lib._scrollAreaPrototype = lib._scrollAreaPrototype or {}
lib._scrollAreas = lib._scrollAreas or setmetatable({}, { __mode = "k" })
local Area = lib._scrollAreaPrototype

local BORDER_PRESETS = {
    inset = {
        left = 4,
        right = 6,
        top = 6,
        bottom = 5,
    },
    none = {
        left = 0,
        right = 0,
        top = 0,
        bottom = 0,
    },
}
local CONTENT_SPACING = {
    regular = {
        left = 16,
        top = 16,
        bottom = 16,
        gap = 16,
    },
    compact = {
        left = 8,
        top = 8,
        bottom = 8,
        gap = 4,
    },
}
local SCROLLBAR_WIDTH = 17 -- Includes the native arrows, not just the 8px track.

local function dimension(value, fallback, label, positive)
    if value == nil then value = fallback end

    assert(
        type(value) == "number" and value >= 0 and value < math.huge,
        label .. " must be finite and non-negative"
    )
    assert(not positive or value > 0, label .. " must be positive")

    return value
end

function lib:_CopyScrollAreaOptions(options)
    assert(type(options) == "table", "scroll area options must be a table")
    local copy = {}

    for key, value in pairs(options) do
        if key == "borderInsets" or key == "contentPadding" then
            assert(type(value) == "table", key .. " must be a table")
            copy[key] = {}

            for edge, inset in pairs(value) do
                copy[key][edge] = inset
            end
        else
            copy[key] = value
        end
    end

    return copy
end

-- Content margins are measured from the parent's edges; only the right margin
-- is measured from the scrollbar. Border clearance is not added on top of them.
-- A thicker border sets the minimum safe content inset on that edge.
function lib:_ResolveScrollAreaGeometry(options)
    assert(type(options) == "table", "scroll area options must be a table")
    local preset =
        BORDER_PRESETS[options.preset == nil and "inset" or options.preset]
    local spacing =
        CONTENT_SPACING[options.contentSpacing == nil and "regular" or options.contentSpacing]
    assert(preset, "unknown scroll area preset")
    assert(spacing, "unknown scroll area content spacing")

    local border = options.borderInsets == nil and {} or options.borderInsets
    local padding = options.contentPadding == nil and {}
        or options.contentPadding
    assert(type(border) == "table", "borderInsets must be a table")
    assert(type(padding) == "table", "contentPadding must be a table")

    local left = dimension(border.left, preset.left, "left border inset")
    local right = dimension(border.right, preset.right, "right border inset")
    local top = dimension(border.top, preset.top, "top border inset")
    local bottom =
        dimension(border.bottom, preset.bottom, "bottom border inset")
    local gap = dimension(options.scrollbarGap, spacing.gap, "scrollbar gap")
    local width = dimension(
        options.scrollbarWidth,
        SCROLLBAR_WIDTH,
        "scrollbar width",
        true
    )

    return {
        borderLeft = left,
        left = math.max(
            left,
            dimension(padding.left, spacing.left, "left content padding")
        ),
        right = right + width + gap,
        top = top,
        bottom = bottom,
        paddingTop = math.max(
            0,
            dimension(padding.top, spacing.top, "top content padding") - top
        ),
        paddingBottom = math.max(
            0,
            dimension(padding.bottom, spacing.bottom, "bottom content padding")
                - bottom
        ),
        scrollbarRight = right,
        scrollbarWidth = width,
        scrollbarGap = gap,
    }
end

function Area:GetScrollBox()
    return self.scrollBox
end

function Area:GetScrollBar()
    return self.scrollBar
end

function Area:GetContentWidth()
    return self.parent:GetWidth() - self.geometry.left - self.geometry.right
end

function Area:GetContentInsets()
    local geometry = self.geometry
    return geometry.left,
        geometry.right,
        geometry.top + geometry.paddingTop,
        geometry.bottom + geometry.paddingBottom
end

function Area:GetViewportHeight()
    local geometry = self.geometry
    local height = self.parent:GetHeight() - geometry.top - geometry.bottom

    if self.kind == "list" then
        height = height - geometry.paddingTop - geometry.paddingBottom
    end

    return height
end

function Area:GetContentPadding()
    if self.kind == "list" then return 0, 0 end

    return self.geometry.paddingTop, self.geometry.paddingBottom
end

local function onMarginMouseWheel(frame, delta)
    local area = frame.scrollArea

    if not area.initialized then return end

    local scrollBox = area.scrollBox
    local handler = scrollBox:GetScript("OnMouseWheel")

    if handler then handler(scrollBox, delta) end
end

function Area:_ConfigureMouseWheel()
    -- Keep the pane's gaps wheel-active below its widgets. Clicks and motion
    -- still reach the caller's frame; focused child controls own their wheel.
    local frame = self.scrollBox._libModernSettingsWheelFrame

    if not frame then
        frame = CreateFrame("Frame", nil, self.parent)
        self.scrollBox._libModernSettingsWheelFrame = frame
    end

    frame.scrollArea = self
    frame:SetAllPoints(self.parent)
    frame:SetFrameLevel(self.parent:GetFrameLevel())
    frame:EnableMouse(false)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", onMarginMouseWheel)
end

function Area:_ApplyGeometry(geometry)
    self.geometry = geometry
    local top, bottom = geometry.top, geometry.bottom

    -- Native lists own their view's padding. Keep the requested content margins
    -- outside that viewport rather than modifying the caller's list view.
    if self.kind == "list" then
        top = top + geometry.paddingTop
        bottom = bottom + geometry.paddingBottom
    end

    self.scrollBox:ClearAllPoints()
    self.scrollBox:SetPoint(
        "TOPLEFT",
        self.parent,
        "TOPLEFT",
        geometry.left - (geometry.overflowLeft or 0),
        -top
    )
    self.scrollBox:SetPoint(
        "BOTTOMRIGHT",
        self.parent,
        "BOTTOMRIGHT",
        -geometry.right + (geometry.overflowRight or 0),
        bottom
    )

    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetWidth(geometry.scrollbarWidth)
    self.scrollBar:SetPoint(
        "TOPRIGHT",
        self.parent,
        "TOPRIGHT",
        -geometry.scrollbarRight,
        -geometry.top
    )
    self.scrollBar:SetPoint(
        "BOTTOMRIGHT",
        self.parent,
        "BOTTOMRIGHT",
        -geometry.scrollbarRight,
        geometry.bottom
    )
end

-- Initialize after configuring the native list view or creating canvas children.
-- Scrolling, wheel input, thumb dragging and list virtualization stay Blizzard-owned.
function Area:Init(view)
    assert(view, "scroll area view is required")
    assert(not self.initialized, "scroll area is already initialized")

    if self.kind == "list" then
        ScrollUtil.InitScrollBoxListWithScrollBar(
            self.scrollBox,
            self.scrollBar,
            view
        )
    else
        ScrollUtil.InitScrollBoxWithScrollBar(
            self.scrollBox,
            self.scrollBar,
            view
        )
    end

    self.initialized = true
end

-- Canvas layouts also use this constructor to adopt existing native widgets
-- during an embed upgrade. Adoption preserves the widgets and their initialized view.
function lib:_CreateScrollArea(parent, geometry, options)
    local kind = options.kind == nil and "list" or options.kind
    assert(
        kind == "list" or kind == "canvas",
        "scroll area kind must be list or canvas"
    )
    local area = setmetatable(
        { parent = parent, kind = kind },
        { __index = Area }
    )

    if options.scrollBox then
        area.scrollBox, area.scrollBar = options.scrollBox, options.scrollBar
        area.initialized = true
    else
        area.scrollBox = CreateFrame(
            "Frame",
            nil,
            parent,
            kind == "list" and "WowScrollBoxList" or "WowScrollBox"
        )
        area.scrollBar =
            CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    end

    area:_ConfigureMouseWheel()
    area:_ApplyGeometry(geometry)
    self._scrollAreas[area] = true
    return area
end

-- The caller owns the parent, its border and its size. Anchored children follow
-- resizing without changing the parent's anchors or installing size handlers.
-- The scrollbar column stays reserved even when all content fits.
function lib:CreateScrollArea(parent, options)
    assert(parent, "scroll area parent is required")
    options = self:_CopyScrollAreaOptions(options == nil and {} or options)
    local geometry = self:_ResolveScrollAreaGeometry(options)
    local area =
        self:_CreateScrollArea(parent, geometry, { kind = options.kind })
    area.options = options
    return area
end

for area in pairs(lib._scrollAreas) do
    area:_ConfigureMouseWheel()

    if area.options then
        area:_ApplyGeometry(lib:_ResolveScrollAreaGeometry(area.options))
    end
end
