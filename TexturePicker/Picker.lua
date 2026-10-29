local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("TexturePicker/Picker", MINOR)
then
    return
end

lib._texturePickerPrototype = lib._texturePickerPrototype or {}
local Picker = lib._texturePickerPrototype
Picker.__index = Picker
local Values = lib._iconUtils

function Picker:Validate()
    local session = self.session

    if not session then return false end

    if InCombatLockdown() or (session.isValid and not session.isValid()) then
        self:Close()
        return false
    end

    return self.session == session
end

function Picker:Error(message)
    self.messages:Show(message, "error")
end

function Picker:GetValue()
    if self.browser == "icons" then return self.icons:GetValue() end

    return self.value
end

function Picker:SetCategory(categoryID)
    local category = self.catalogue.byID[categoryID]
    assert(category, "unknown texture category")

    if not self:Validate() or self.browser ~= "textures" then return false end

    local session = self.session

    if
        not self.input:CommitAndClearFocus()
        or self.inputError
        or self.session ~= session
    then
        return false
    end

    if self.category ~= categoryID or not self.entries then
        self.category = categoryID
        self.entries = lib._texturePickerCatalogue.GetEntries(category)
        self.scrollBox:SetDataProvider(
            CreateIndexRangeDataProvider(#self.entries)
        )
    end

    lib._texturePickerUI.SelectCategory(self, category)
    return true
end

function Picker:SetValue(value, fromInput)
    if not self:Validate() then return false end

    local normalized, message = Values.Normalize(value)

    if message then
        self:Error(message)
        return false
    end

    self.value = normalized
    self.inputError = nil

    if self.browser == "icons" then return self.icons:SetValue(normalized) end

    if not fromInput then
        self.input:SetValue(normalized and tostring(normalized) or "")
    end

    lib._texturePickerUI.Paint(self)
    return true
end

function Picker:Reset()
    if self.browser == "icons" then return self.icons:Reset() end

    self.input:CancelAndClearFocus()
    return self:SetValue(nil)
end

function Picker:Accept(value)
    if not self:Validate() then return false end

    return self.session.onApply(value)
end

function Picker:Apply()
    if self.browser == "icons" then return self.icons:Apply() end

    local session = self.session

    if
        not self:Validate()
        or not self.input:CommitAndClearFocus()
        or self.inputError
        or self.session ~= session
    then
        return false
    end

    local accepted, message = self:Accept(self.value)

    if accepted == false then
        if self.session == session and message then self:Error(message) end

        return false
    end

    if self.session == session then self:Close(true) end

    return true
end

function Picker:Close(applied)
    local session = self.session
    self.session, self.value, self.browser = nil, nil, nil
    self.frame:UnregisterAllEvents()
    self.frame:StopMovingOrSizing()
    self.input:CancelAndClearFocus()
    self.frame:Hide()

    if self.icons then self.icons:Close() end

    if session and session.onClose then session.onClose(applied == true) end
end

function Picker:SetBrowser(browser)
    assert(browser == "textures" or browser == "icons", "unknown browser")

    if not self:Validate() then return false end
    if self.browser == browser then return true end

    local previous = self.browser == "icons" and self.icons or self
    local session = self.session

    -- Each browser keeps its own UI. Only the committed draft crosses tabs;
    -- this does not call Apply or write icon history.
    if
        not previous.input:CommitAndClearFocus()
        or previous.inputError
        or self.session ~= session
    then
        return false
    end

    self.value = previous:GetValue()

    if browser == "icons" and not self.icons then
        self.icons = lib:CreateIconPicker(self.parent, self.iconPickerOptions)
        self.icons.frame:SetClampRectInsets(0, -48, 0, 0)
        lib._texturePickerUI.AddTabs(self, self.icons.frame, "icons")
    end

    local destination = browser == "icons" and self.icons or self
    local point, relativeTo, relativePoint, x, y = previous.frame:GetPoint(1)
    destination.frame:ClearAllPoints()
    destination.frame:SetPoint(point, relativeTo, relativePoint, x, y)
    self.switching = true

    if self.browser == "icons" then
        self.icons:Close()
    else
        self.frame:Hide()
    end

    self.browser = browser

    if browser == "icons" then
        self.icons:Open({
            addonName = session.addonName,
            sourceName = session.sourceName,
            value = self.value,
            defaultIcon = session.defaultTexture,
            isValid = function()
                return self.session == session and self:Validate()
            end,
            onApply = function(value)
                return self:Accept(value)
            end,
            onClose = function(applied)
                if not self.switching and self.session == session then
                    self:Close(applied)
                end
            end,
        })
    else
        self.frame:Show()
        self.frame:Raise()
        self.frame:SetPropagateKeyboardInput(true)
        self:SetValue(self.value)
    end

    self.switching = nil
    return self.session == session
end

function Picker:Open(options)
    assert(
        type(options) == "table" and type(options.onApply) == "function",
        "texture picker Open requires an onApply function"
    )

    for _, key in ipairs({ "addonName", "sourceName" }) do
        assert(
            type(options[key]) == "string" and options[key] ~= "",
            key .. " must be non-empty text"
        )
    end

    for _, key in ipairs({ "isValid", "onClose" }) do
        assert(
            options[key] == nil or type(options[key]) == "function",
            key .. " must be a function"
        )
    end

    local value, message = Values.Normalize(options.value)
    assert(not message, message)

    if InCombatLockdown() then return false end

    self:Close()

    if self.session then return false end

    local session = {}

    for key, option in pairs(options) do
        session[key] = option
    end

    self.session, self.browser = session, "textures"

    if not self:Validate() then return false end

    self.frame:SetTitle(
        "Choose texture for "
            .. options.addonName
            .. " / "
            .. options.sourceName
    )
    self.frame:SetScale(
        math.min(
            1,
            (UIParent:GetHeight() - 32) / self.frame:GetHeight(),
            (UIParent:GetWidth() - 80) / self.frame:GetWidth()
        )
    )
    self.frame:Show()
    self.frame:Raise()
    self.frame:SetPropagateKeyboardInput(true)
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:SetValue(value)
    self:SetCategory(self.category or self.catalogue.categories[1].id)
    return true
end

function lib:CreateTexturePicker(parent, options)
    assert(not InCombatLockdown(), "create texture pickers outside combat")
    options = options or {}
    assert(
        options.styleCategoryTab == nil
            or type(options.styleCategoryTab) == "function",
        "styleCategoryTab must be a function"
    )
    local mediaPath = options.mediaPath or self._texturePath
    assert(
        type(mediaPath) == "string" and mediaPath ~= "",
        "mediaPath must be a non-empty texture directory"
    )
    mediaPath = mediaPath:gsub("/", "\\")

    if mediaPath:sub(-1) ~= "\\" then mediaPath = mediaPath .. "\\" end

    local picker = setmetatable({
        parent = parent,
        iconPickerOptions = options.iconPickerOptions,
        styleCategoryTab = options.styleCategoryTab,
        catalogue = self._texturePickerCatalogue.Get(mediaPath),
    }, Picker)
    self._texturePickerUI.Create(picker, parent)
    return picker
end
