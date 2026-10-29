return function(lib, makeFrame, inputState)
    local originalCreateFrame = CreateFrame
    local originalScrollUtil = ScrollUtil
    local originalAtlasElements = C_Texture.GetAtlasElements
    local originalAtlasInfo = C_Texture.GetAtlasInfo
    local originalIconPicker = lib.CreateIconPicker
    local originalHideOwnedTooltip = lib.HideOwnedTooltip
    local catalogueReads = 0

    function lib:HideOwnedTooltip(owner)
        owner.tooltipHidden = true
    end

    function C_Texture.GetAtlasElements()
        catalogueReads = catalogueReads + 1
        return { "wide-texture", "tall-texture", "small-texture" }
    end

    function C_Texture.GetAtlasInfo(value)
        if value == "wide-texture" then return { width = 512, height = 64 } end
        if value == "tall-texture" then return { width = 64, height = 512 } end
        if value == "small-texture" then return { width = 20, height = 10 } end

        return originalAtlasInfo(value)
    end

    function CreateFrame(frameType, name, parent, template)
        local frame = originalCreateFrame(frameType, name, parent, template)

        function frame:Raise() end
        function frame:SetClampRectInsets() end
        function frame:SetResizable() end
        function frame:SetResizeBounds() end
        function frame:UnregisterAllEvents()
            self.registeredEvents = {}
        end

        return frame
    end

    ScrollUtil = {
        InitScrollBoxListWithScrollBar = function(box, _, view)
            box.frames = {}

            function box:SetDataProvider(count)
                for _, wrapper in ipairs(self.frames) do
                    view.reset(wrapper)
                end

                local previous = self.frames
                self.frames = {}

                for index = 1, count do
                    local wrapper = previous[index] or makeFrame("Frame", self)
                    self.frames[index] = wrapper
                    view.initialize(wrapper, index)
                end
            end

            function box:ForEachFrame(callback)
                for _, wrapper in ipairs(self.frames) do
                    callback(wrapper)
                end
            end
        end,
    }

    -- Exercise the coordinator through the icon picker's public draft API.
    -- Its independent full suite covers the actual icon window and catalogue.
    function lib:CreateIconPicker(parent, options)
        local browser = {
            frame = CreateFrame("Frame", nil, parent),
            input = self:CreateTextInput(parent),
            options = options,
        }

        function browser:Open(session)
            self.session = session
            self:SetValue(session.value)
            self.frame:Show()
        end

        function browser:Close()
            local session = self.session
            self.session, self.value = nil, nil
            self.frame:Hide()

            if session then session.onClose(false) end
        end

        function browser:GetValue()
            return self.value
        end

        function browser:SetValue(value)
            self.value = value
            self.input:SetValue(value and tostring(value) or "")
            return true
        end

        function browser:Reset()
            return self:SetValue(nil)
        end

        function browser:Apply()
            local session = self.session

            if not session.isValid() then return false end
            if session.onApply(self.value) == false then return false end

            self.session = nil
            session.onClose(true)
            return true
        end

        return browser
    end

    dofile("TexturePicker/Catalogue.lua")
    dofile("TexturePicker/Browser.lua")
    dofile("TexturePicker/Picker.lua")
    local picker = lib:CreateTexturePicker(UIParent)
    local writes, closes, saved, valid = 0, 0, nil, true
    local options = {
        addonName = "Test",
        sourceName = "Aura",
        value = "wide-texture",
        defaultTexture = "small-texture",
        isValid = function()
            return valid
        end,
        onApply = function(value)
            writes, saved = writes + 1, value
        end,
        onClose = function()
            closes = closes + 1
        end,
    }
    assert(picker:Open(options))
    assert(picker.category == "circles" and catalogueReads == 0)
    assert(picker.categoryTabs[1]:IsSelected())
    local ring = picker.entries[1]
    picker:SetValue(ring.texture)
    assert(picker.preview.texture == ring.texture)
    assert(
        picker.preview:GetWidth() == 128 and picker.preview:GetHeight() == 128
    )
    assert(picker:SetCategory("bars"))
    assert(picker:GetValue() == ring.texture and writes == 0)
    local stripe = picker.entries[1]
    picker:SetValue(stripe.texture)
    assert(
        picker.preview:GetWidth() == 236 and picker.preview:GetHeight() == 29.5
    )
    assert(picker:SetCategory("atlases"))
    assert(catalogueReads == 1 and #picker.entries == 3)
    assert(#picker.scrollBox.frames == 3, "category changes release old rows")
    assert(picker:GetValue() == stripe.texture and writes == 0)
    assert(picker.entries[1].name == "small-texture")
    picker:SetValue("wide-texture")
    assert(picker:GetValue() == "wide-texture" and writes == 0)
    assert(
        picker.preview:GetWidth() == 236 and picker.preview:GetHeight() == 29.5
    )
    picker:SetValue("tall-texture")
    assert(
        picker.preview:GetWidth() == 16 and picker.preview:GetHeight() == 128
    )
    picker:SetValue("small-texture")
    assert(picker.preview:GetWidth() == 20 and picker.preview:GetHeight() == 10)
    picker.input:FocusValue()
    picker.input:SetText("Interface/Custom/Wide.tga")
    assert(picker:SetCategory("shapes"))
    assert(picker:GetValue() == "Interface\\Custom\\Wide.tga")
    assert(picker:SetCategory("runes"))
    assert(picker:SetCategory("alerts"))
    assert(picker:GetValue() == "Interface\\Custom\\Wide.tga" and writes == 0)
    assert(picker:SetBrowser("icons"))
    assert(picker:GetValue() == "Interface\\Custom\\Wide.tga")
    assert(writes == 0 and closes == 0 and not picker.frame:IsShown())
    picker:SetValue(134400)
    assert(picker:SetBrowser("textures"))
    assert(picker:GetValue() == 134400 and picker.frame:IsShown())
    assert(picker.category == "alerts", "browser switches retain the category")
    assert(picker.input:GetValue() == "134400" and writes == 0)
    picker:Reset()
    assert(picker:GetValue() == nil and writes == 0)
    assert(picker:Apply())
    assert(saved == nil and writes == 1 and closes == 1)
    assert(not picker.session and not picker.frame:IsShown())

    assert(picker:Open(options))
    picker.input:FocusValue()
    picker.input:SetText("-1")
    local previousCategory = picker.category
    picker.categoryTabs[1]:Click("LeftButton")
    assert(picker.category == previousCategory)
    assert(picker.categoryTabs[4]:IsSelected())
    picker.input:FocusValue()
    picker.input:SetText("-1")
    assert(not picker:SetCategory("shapes"))
    picker.input:FocusValue()
    picker.input:SetText("-1")
    assert(
        not picker:SetBrowser("icons"),
        "invalid edits must prevent tab changes"
    )
    assert(picker.browser == "textures" and writes == 1)
    picker.input:SetText("-1")
    picker.input:ClearFocus()
    assert(
        not picker:Apply(),
        "a failed blur commit must not apply an older draft"
    )
    picker:Close()
    assert(closes == 2 and writes == 1)
    assert(picker:Open(options))
    assert(catalogueReads == 1, "reopening must reuse catalogue metadata")
    assert(picker:SetBrowser("icons"))
    picker:SetValue(136098)
    assert(picker:Apply())
    assert(saved == 136098 and writes == 2 and closes == 3)

    assert(picker:Open(options))
    valid = false
    assert(not picker:Apply())
    assert(not picker.session and writes == 2 and closes == 4)
    valid = true
    assert(picker:Open(options))
    assert(picker:SetBrowser("icons"))
    inputState.inCombat = true
    picker.frame.scripts.OnEvent(picker.frame, "PLAYER_REGEN_DISABLED")
    assert(not picker.session and not picker.icons.session and closes == 5)
    assert(not picker:Open(options))
    inputState.inCombat = false

    -- Existing objects retain their shared prototype across compatible loads.
    local prototype = getmetatable(picker)
    lib._loadedModules["TexturePicker/Picker"] = nil
    dofile("TexturePicker/Picker.lua")
    assert(prototype == getmetatable(picker))
    assert(picker:Open(options))
    picker:SetValue(134400)
    assert(picker:Apply() and writes == 3)

    local previousCloses = closes
    assert(picker:Open(options))
    assert(picker:SetBrowser("icons"))
    picker.icons:Close()
    assert(not picker.session and closes == previousCloses + 1 and writes == 3)

    options.onApply = function()
        return false, "Rejected"
    end
    assert(picker:Open(options))
    assert(
        not picker:Apply() and picker.session,
        "rejection must keep the draft open"
    )
    picker:Close()
    assert(not pcall(function()
        picker:Open({})
    end))
    assert(not pcall(function()
        picker:SetBrowser("unknown")
    end))
    assert(not pcall(function()
        picker:SetCategory("unknown")
    end))
    assert(not pcall(function()
        lib:CreateTexturePicker(UIParent, { mediaPath = 123 })
    end))

    -- A consumer can persist paths to its own copy, regardless of LibStub's
    -- selected embed. Known file dimensions are checked against shipped art.
    local owned = lib:CreateTexturePicker(UIParent, {
        mediaPath = "Interface/AddOns/Test/Libs/LibModernSettings-1.0/Media/Textures",
    })
    local prefix =
        "Interface\\AddOns\\Test\\Libs\\LibModernSettings-1.0\\Media\\Textures\\WeakAuras\\"

    for _, category in ipairs(owned.catalogue.categories) do
        for _, entry in ipairs(category.entries or {}) do
            if entry.file then
                assert(entry.texture == prefix .. entry.file)
                local file = assert(
                    io.open("Media/Textures/WeakAuras/" .. entry.file, "rb")
                )
                local header = file:read(18)
                file:close()
                local width = header:byte(13) + 256 * header:byte(14)
                local height = header:byte(15) + 256 * header:byte(16)
                assert(
                    width == entry.width and height == entry.height,
                    entry.file
                )
            end
        end
    end

    local repeated = lib:CreateTexturePicker(UIParent)
    assert(repeated.catalogue == picker.catalogue)
    assert(owned.catalogue ~= picker.catalogue)
    assert(owned:Open(options) and owned:SetCategory("atlases"))
    assert(catalogueReads == 1, "all owners share the native atlas catalogue")
    owned:Close()

    local customButtons = {}
    local custom = lib:CreateTexturePicker(UIParent, {
        styleCategoryTab = function(button, window)
            assert(window == button:GetParent():GetParent())
            customButtons[#customButtons + 1] = button
            button:SetTabAppearance({ mode = "flat" })
        end,
    })
    assert(#customButtons == 6)
    assert(custom:Open(options))
    assert(custom.categoryTabs[1]:IsSelected())
    customButtons[3]:Click("LeftButton")
    assert(custom.category == "bars" and custom:GetValue() == options.value)

    for index, tab in ipairs(custom.categoryTabs) do
        assert(tab:IsSelected() == (index == 3))
    end

    custom.input:FocusValue()
    custom.input:SetText("-1")
    customButtons[2]:Click("LeftButton")
    assert(custom.category == "bars")
    assert(custom.categoryTabs[3]:IsSelected())
    assert(not custom.categoryTabs[2]:IsSelected())
    custom:SetValue("wide-texture")
    assert(custom:SetBrowser("icons") and custom:SetBrowser("textures"))
    assert(custom.category == "bars" and custom.categoryTabs[3]:IsSelected())
    assert(custom:GetValue() == "wide-texture" and writes == 3)
    custom:Close()
    assert(not pcall(function()
        lib:CreateTexturePicker(UIParent, { styleCategoryTab = true })
    end))

    lib.CreateIconPicker = originalIconPicker
    lib.HideOwnedTooltip = originalHideOwnedTooltip
    CreateFrame, ScrollUtil = originalCreateFrame, originalScrollUtil
    C_Texture.GetAtlasElements = originalAtlasElements
    C_Texture.GetAtlasInfo = originalAtlasInfo
    print("LibModernSettings texture picker tests passed")
end
