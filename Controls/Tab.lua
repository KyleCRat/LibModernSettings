local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/Tab", MINOR)
then
    return
end

local methods = {}

local function positive(value)
    return type(value) == "number" and value > 0 and value < math.huge
end

local function copyAppearance(options)
    options = options or {}
    assert(type(options) == "table", "tab appearance must be a table")
    assert(
        options.mode == nil
            or options.mode == "header"
            or options.mode == "flat",
        "tab appearance mode must be header or flat"
    )
    assert(
        options.texture == nil
            or type(options.texture) == "string"
            or type(options.texture) == "number",
        "tab texture must be a path or file ID"
    )
    assert(
        options.font == nil
            or type(options.font) == "string" and options.font ~= "",
        "tab font must be a path"
    )
    assert(
        options.fontSize == nil or positive(options.fontSize),
        "tab fontSize must be positive and finite"
    )
    assert(
        options.fontFlags == nil or type(options.fontFlags) == "string",
        "tab fontFlags must be text"
    )
    assert(
        options.colors == nil or type(options.colors) == "table",
        "tab colors must be a table"
    )
    local appearance = {
        mode = options.mode or "header",
        texture = options.texture,
        font = options.font,
        fontSize = options.fontSize or 13,
        fontFlags = options.fontFlags or "",
        fontObject = options.fontObject,
        colors = {},
    }

    for key, tint in pairs(options.colors or {}) do
        assert(
            key == "border"
                or key == "accent"
                or key == "highlight"
                or key == "text"
                or key == "selectedText"
                or key == "flatAccent",
            "unknown tab color"
        )
        assert(type(tint) == "table", "tab colors must be RGBA arrays")
        local copy = {}

        for channel = 1, 4 do
            local value = tint[channel]

            if channel == 4 and value == nil then value = 1 end

            assert(
                type(value) == "number" and value >= 0 and value <= 1,
                "tab color channels must be between zero and one"
            )
            copy[channel] = value
        end

        appearance.colors[key] = copy
    end

    return appearance
end

function methods:SetTabAppearance(options)
    local appearance = copyAppearance(options)
    self.appearance = appearance
    lib._tabArtwork.SetTexture(self)

    if appearance.fontObject then
        self.Text:SetFontObject(appearance.fontObject)
    elseif appearance.font then
        self.Text:SetFont(
            appearance.font,
            appearance.fontSize,
            appearance.fontFlags
        )
    else
        self.Text:SetFontObject(GameFontNormal)
    end

    self:RefreshTabGeometry()
    lib._tabArtwork.Paint(self)
end

function methods:RefreshTabGeometry()
    if self.appearance then lib._tabArtwork.Layout(self) end
end

function methods:SetSelected(selected)
    assert(type(selected) == "boolean", "selected must be a boolean")

    if self.selected == selected then return end

    self.selected = selected
    lib._tabArtwork.Paint(self)
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
    if not self:IsEnabled() or not lib:_FlushPendingEditBoxCommits() then
        return
    end

    if self.onClick then self.onClick(self, ...) end
end

function methods:SetControlEnabled(enabled, disabledTooltip)
    self:SetEnabled(enabled == true)
    self:_RefreshNavigationHover()
    lib:SetControlTooltipEnabled(self, enabled == true, disabledTooltip)
end

local function createTab(parent)
    local tab = CreateFrame("Button", nil, parent)
    tab.Text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.Text:SetJustifyH("CENTER")
    tab.Text:SetJustifyV("MIDDLE")
    tab.Text:SetWordWrap(false)
    tab:SetFontString(tab.Text)
    tab:SetPushedTextOffset(0, 0)
    lib._tabArtwork.Create(tab)
    tab:SetScript("OnClick", function(self, ...)
        self:_HandleClick(...)
    end)
    tab:SetScript("OnMouseDown", function(self, button)
        self.pressed = button == "LeftButton" and self:IsEnabled()
        lib._tabArtwork.Paint(self)
    end)
    tab:SetScript("OnMouseUp", function(self)
        self.pressed = false
        lib._tabArtwork.Paint(self)
    end)
    tab:HookScript("OnHide", function(self)
        self.pressed = false
    end)
    tab:HookScript("OnDisable", function(self)
        self.pressed = false
        lib._tabArtwork.Paint(self)
    end)
    tab:HookScript("OnEnable", function(self)
        lib._tabArtwork.Paint(self)
    end)
    tab:HookScript("OnShow", function(self)
        self:RefreshTabGeometry()
    end)
    tab:HookScript("OnSizeChanged", function(self)
        self:RefreshTabGeometry()
    end)
    -- Parent movement has no geometry event. Visible tabs compare public bounds;
    -- unchanged bounds allocate nothing and perform no texture writes.
    tab:SetScript("OnUpdate", function(self)
        self:RefreshTabGeometry()
    end)
    return tab
end

local function refreshAppearance(tab, options)
    local width, height = options.width or 100, options.height or 32
    assert(
        positive(width) and positive(height),
        "tab size must be positive and finite"
    )
    lib:_ApplyFixedControlSize(tab, width, height)
    tab:SetTabAppearance(tab.appearance or options.appearance)
end

local function initialize(tab, options)
    assert(
        options.text == nil or type(options.text) == "string",
        "tab text must be text"
    )
    tab:SetText(options.text or "")
    tab:SetSelected(options.selected == true)
    tab:SetOnClick(options.onClick)
    tab:SetControlEnabled(options.enabled ~= false, options.disabledTooltip)

    if options.tooltip then lib:SetTooltip(tab, options.tooltip) end
end

lib:RegisterControlType(
    "tab",
    createTab,
    methods,
    initialize,
    refreshAppearance
)
lib:RegisterControlNavigation("tab", {
    actions = lib._buttonNavigationActions,
    hover = function(tab, highlighted)
        tab.hovered = highlighted
        lib._tabArtwork.Paint(tab)
    end,
})

function lib:CreateTab(parent, options)
    return self:CreateControl("tab", parent, options or {})
end
