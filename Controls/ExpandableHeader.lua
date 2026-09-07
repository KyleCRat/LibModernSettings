local MAJOR, MINOR = "LibModernSettings-1.0", 6
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_WIDTH = 100
local DEFAULT_HEIGHT = 34
local DEFAULT_LEFT_PADDING = 12
local DEFAULT_RIGHT_PADDING = 12
local DEFAULT_ICON_GAP = 6
local DEFAULT_ICON_SIZE = 22
local DEFAULT_TOGGLE_SIZE = 17
local DEFAULT_TOGGLE_GAP = 4

local HEADER_ATLASES = {
    normal = "common-button-tertiary-normal",
    hover = "common-button-tertiary-hover",
    pressed = "common-button-tertiary-pressed",
    disabled = "common-button-tertiary-disabled",
}

local TOGGLE_ATLAS = "common-dropdown-icon-next"
local TOGGLE_DISABLED_ATLAS = "common-dropdown-icon-next-disabled"
local TOGGLE_COLLAPSED_ROTATION = math.pi * 0.5
local TOGGLE_EXPANDED_ROTATION = math.pi * 1.5
local TOGGLE_COLLAPSED_Y_OFFSET = -1
local TOGGLE_EXPANDED_Y_OFFSET = 2

local function assertPositiveOption(value, name)
    assert(
        value == nil or (type(value) == "number" and value > 0),
        name .. " must be a positive number or nil"
    )
end

local function sizeAtlasIcon(icon, size)
    local width = icon:GetWidth()
    local height = icon:GetHeight()
    local largestDimension = math.max(width, height)

    if largestDimension <= 0 then
        icon:SetSize(size, size)
        return
    end

    local scale = size / largestDimension

    icon:SetSize(
        math.floor((width * scale) + 0.5),
        math.floor((height * scale) + 0.5)
    )
end

local function updateHeaderLayout(header)
    local label = header.label

    label:ClearAllPoints()
    if header._libModernSettingsHeaderIconAtlas then
        label:SetPoint(
            "LEFT",
            header.icon,
            "RIGHT",
            DEFAULT_ICON_GAP,
            0
        )
    else
        label:SetPoint(
            "LEFT",
            header,
            "LEFT",
            DEFAULT_LEFT_PADDING,
            0
        )
    end
    label:SetPoint(
        "RIGHT",
        header.toggleIcon,
        "LEFT",
        -DEFAULT_TOGGLE_GAP,
        0
    )
end

local function updateHeaderIconState(header)
    if not header._libModernSettingsHeaderIconAtlas then
        return
    end

    local enabled = header._libModernSettingsHeaderEnabled ~= false

    header.icon:SetDesaturated(
        header._libModernSettingsHeaderIconDesaturated or not enabled
    )
    header.icon:SetAlpha(enabled and 1 or 0.5)
end

local function updateToggleState(header)
    local enabled = header._libModernSettingsHeaderEnabled ~= false
    local expanded = header._libModernSettingsHeaderExpanded == true

    header.toggleIcon:SetAtlas(
        enabled and TOGGLE_ATLAS or TOGGLE_DISABLED_ATLAS,
        true
    )
    header.toggleIcon:SetSize(DEFAULT_TOGGLE_SIZE, DEFAULT_TOGGLE_SIZE)
    header.toggleIcon:SetRotation(
        expanded and TOGGLE_EXPANDED_ROTATION or TOGGLE_COLLAPSED_ROTATION
    )
    header.toggleIcon:ClearAllPoints()
    header.toggleIcon:SetPoint(
        "RIGHT",
        header,
        "RIGHT",
        -DEFAULT_RIGHT_PADDING,
        expanded
            and TOGGLE_EXPANDED_Y_OFFSET
            or TOGGLE_COLLAPSED_Y_OFFSET
    )
    header.toggleIcon:SetDesaturated(false)
    header.toggleIcon:SetAlpha(1)
end

local function createExpandableHeader(parent, options)
    assertPositiveOption(options.width, "width")
    assertPositiveOption(options.height, "height")
    assertPositiveOption(options.iconSize, "iconSize")

    local header = CreateFrame("Button", nil, parent)

    header:SetSize(
        options.width or DEFAULT_WIDTH,
        options.height or DEFAULT_HEIGHT
    )
    header._libModernSettingsHeaderIconSize = options.iconSize
        or DEFAULT_ICON_SIZE

    local label = header:CreateFontString(nil, "OVERLAY")

    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    header:SetFontString(label)
    header:SetNormalFontObject(options.normalFont or GameFontNormalLarge)
    header:SetHighlightFontObject(
        options.highlightFont or GameFontHighlightLarge
    )
    header:SetDisabledFontObject(
        options.disabledFont or GameFontDisableLarge
    )
    header.label = label

    local normalTexture = lib:_CreateAtlasTexture(
        header,
        "BACKGROUND",
        HEADER_ATLASES.normal
    )

    header:SetNormalTexture(normalTexture)
    header:SetPushedTexture(lib:_CreateAtlasTexture(
        header,
        "BACKGROUND",
        HEADER_ATLASES.pressed
    ))
    header:SetDisabledTexture(lib:_CreateAtlasTexture(
        header,
        "BACKGROUND",
        HEADER_ATLASES.disabled
    ))
    header._libModernSettingsHeaderNormalTexture = normalTexture

    local icon = header:CreateTexture(nil, "OVERLAY", nil, 2)

    icon:SetPoint("LEFT", header, "LEFT", DEFAULT_LEFT_PADDING, 0)
    icon:Hide()
    header.icon = icon

    local toggleIcon = header:CreateTexture(nil, "OVERLAY", nil, 2)

    toggleIcon:SetPoint(
        "RIGHT",
        header,
        "RIGHT",
        -DEFAULT_RIGHT_PADDING,
        0
    )
    header.toggleIcon = toggleIcon

    updateHeaderLayout(header)

    header:SetScript("OnEnter", function(self)
        if self._libModernSettingsHeaderEnabled ~= false then
            self._libModernSettingsHeaderNormalTexture:SetAtlas(
                HEADER_ATLASES.hover,
                false
            )
        end
    end)
    header:SetScript("OnLeave", function(self)
        self._libModernSettingsHeaderNormalTexture:SetAtlas(
            HEADER_ATLASES.normal,
            false
        )
    end)
    header:SetScript("OnClick", function(self, button)
        self:_HandleExpandableHeaderClick(button)
    end)

    return header
end

local expandableHeaderMethods = {}

function expandableHeaderMethods:_HandleExpandableHeaderClick(button)
    lib:_FlushPendingEditBoxCommits()

    local expanded = not self:IsExpanded()

    self:SetExpanded(expanded)

    local callback = self._libModernSettingsOnExpandedChanged
    if callback then
        callback(self, expanded, button)
    end
end

function expandableHeaderMethods:SetHeaderText(text)
    assert(type(text) == "string", "header text must be a string")
    self:SetText(text)
end

function expandableHeaderMethods:SetHeaderIcon(iconAtlas, desaturated)
    assert(
        iconAtlas == nil or type(iconAtlas) == "string",
        "iconAtlas must be a string or nil"
    )
    assert(
        desaturated == nil or type(desaturated) == "boolean",
        "desaturated must be a boolean or nil"
    )

    self._libModernSettingsHeaderIconAtlas = iconAtlas
    self._libModernSettingsHeaderIconDesaturated = desaturated == true

    if iconAtlas then
        self.icon:SetAtlas(iconAtlas, true)
        sizeAtlasIcon(
            self.icon,
            self._libModernSettingsHeaderIconSize
        )
        self.icon:Show()
        updateHeaderIconState(self)
    else
        self.icon:Hide()
    end

    updateHeaderLayout(self)
end

function expandableHeaderMethods:SetExpanded(expanded)
    assert(type(expanded) == "boolean", "expanded must be a boolean")
    self._libModernSettingsHeaderExpanded = expanded
    updateToggleState(self)
end

function expandableHeaderMethods:IsExpanded()
    return self._libModernSettingsHeaderExpanded == true
end

function expandableHeaderMethods:SetOnExpandedChanged(callback)
    assert(
        callback == nil or type(callback) == "function",
        "onExpandedChanged must be a function or nil"
    )
    self._libModernSettingsOnExpandedChanged = callback
end

function expandableHeaderMethods:SetControlEnabled(enabled, disabledTooltip)
    enabled = enabled == true
    self._libModernSettingsHeaderEnabled = enabled
    self:SetEnabled(enabled)
    self._libModernSettingsHeaderNormalTexture:SetAtlas(
        HEADER_ATLASES.normal,
        false
    )
    updateHeaderIconState(self)
    updateToggleState(self)
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function initializeExpandableHeader(header, options)
    assert(
        options.expanded == nil or type(options.expanded) == "boolean",
        "expanded must be a boolean or nil"
    )

    header:SetHeaderText(options.text or "")
    header:SetHeaderIcon(options.iconAtlas, options.iconDesaturated)
    header:SetOnExpandedChanged(options.onExpandedChanged)
    header:SetExpanded(options.expanded ~= false)
    header:SetControlEnabled(
        options.enabled ~= false,
        options.disabledTooltip
    )

    if options.tooltip then
        lib:SetTooltip(header, {
            title = options.tooltipTitle,
            text = options.tooltip,
        })
    end
end

lib:RegisterControlType(
    "expandableHeader",
    createExpandableHeader,
    expandableHeaderMethods,
    initializeExpandableHeader
)

function lib:CreateExpandableHeader(parent, options)
    options = options or {}

    return self:CreateControl("expandableHeader", parent, options)
end
