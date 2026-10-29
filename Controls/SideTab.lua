local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/SideTab", MINOR)
then
    return
end

local methods = {}

function methods:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be a boolean")
    self.selected = selected
    self.selection:SetShown(selected)
end

function methods:IsSelected()
    return self.selected == true
end

function methods:SetOnClick(callback)
    assert(
        callback == nil or type(callback) == "function",
        "onClick must be a function or nil"
    )
    self.onClick = callback
end

function methods:_HandleClick(...)
    if not lib:_FlushPendingEditBoxCommits() then return end

    if self.onClick then self.onClick(self, ...) end
end

function methods:SetControlEnabled(enabled, disabledTooltip)
    enabled = enabled == true
    self:SetEnabled(enabled)
    self.icon:SetDesaturated(not enabled)
    self.icon:SetAlpha(enabled and 1 or 0.5)
    self:_RefreshNavigationHover()
    lib:SetControlTooltipEnabled(self, enabled, disabledTooltip)
end

local function createSideTab(parent)
    local tab = CreateFrame("Button", nil, parent)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.background = tab:CreateTexture(nil, "BACKGROUND")
    tab.selection = tab:CreateTexture(nil, "OVERLAY")
    tab.hover = tab:CreateTexture(nil, "HIGHLIGHT")
    tab:SetHighlightTexture(tab.hover)
    tab:SetScript("OnClick", function(self, ...)
        self:_HandleClick(...)
    end)
    return tab
end

local function refreshAppearance(tab, options)
    -- Native side-tab artwork has a fixed aspect, unlike the title-tab slices.
    tab:SetSize(43, 55)

    for texture, atlas in pairs({
        [tab.background] = "common-sidetab",
        [tab.selection] = "common-sidetab-selected",
        [tab.hover] = "common-sidetab-hover",
    }) do
        texture:SetAtlas(atlas, false)
        texture:SetSize(45, 60)
        lib:_SetLayoutPoint(texture, "CENTER", tab, "CENTER", 0, 0)
    end

    assert(
        (options.iconAtlas ~= nil) ~= (options.iconTexture ~= nil),
        "side tabs require either iconAtlas or iconTexture"
    )
    local size = options.iconSize or 24
    assert(
        type(size) == "number" and size > 0 and size <= 32,
        "side-tab iconSize must be greater than zero and at most 32"
    )
    local width, height = size, size

    if options.iconAtlas then
        assert(type(options.iconAtlas) == "string", "iconAtlas must be text")
        local info = C_Texture.GetAtlasInfo(options.iconAtlas)

        if info and info.width > 0 and info.height > 0 then
            local scale = size / math.max(info.width, info.height)
            width, height = info.width * scale, info.height * scale
        end

        tab.icon:SetAtlas(options.iconAtlas, false)
    else
        assert(
            type(options.iconTexture) == "string"
                or type(options.iconTexture) == "number",
            "iconTexture must be a path or file ID"
        )
        tab.icon:SetTexture(options.iconTexture)
        tab.icon:SetTexCoord(0, 1, 0, 1)
    end

    tab.icon:SetSize(width, height)
    lib:_SetLayoutPoint(tab.icon, "CENTER", tab, "CENTER", -2, 0)
end

local function initialize(tab, options)
    tab:SetSelected(options.selected == true)
    tab:SetOnClick(options.onClick)
    tab:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)

    if options.tooltip then lib:SetTooltip(tab, options.tooltip) end
end

lib:RegisterControlType(
    "sideTab",
    createSideTab,
    methods,
    initialize,
    refreshAppearance
)
lib:RegisterControlNavigation("sideTab", {
    actions = lib._buttonNavigationActions,
    highlight = lib._SetButtonNavigationHighlight,
})

function lib:CreateSideTab(parent, options)
    return self:CreateControl("sideTab", parent, options or {})
end
