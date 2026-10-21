return function(lib, picker, inputState, options, setCursor)
    picker:Open(options)
    picker:Update(0.02)
    picker:Update(0.02)

    local catalogue = picker.catalogue
    local describe = catalogue.Describe
    local setTooltip = lib.SetTooltip
    local textures, descriptions, tooltips = 0, 0, 0
    local watched, setters = {}, {}
    local preparation = { iconSizes = 0, maskSizes = 0, maskTextures = 0, fonts = 0 }
    local preparationMethods = {}
    local function watchPreparation(owner, method, counter)
        local original = owner[method]
        preparationMethods[#preparationMethods + 1] = { owner, method, original }
        owner[method] = function(self, ...)
            preparation[counter] = preparation[counter] + 1
            return original(self, ...)
        end
    end
    for _, wrapper in ipairs(picker.scrollBox.frames) do
        local button = wrapper.button
        watched[button] = true
        local texture = button.icon
        local setTexture = texture.SetTexture
        setters[texture] = setTexture
        texture.SetTexture = function(self, value, ...)
            assert(value ~= nil, "scrolling must not clear pooled textures")
            textures = textures + 1
            return setTexture(self, value, ...)
        end
        watchPreparation(texture, "SetSize", "iconSizes")
        watchPreparation(texture._libModernSettingsSquareMask, "SetSize", "maskSizes")
        watchPreparation(texture._libModernSettingsSquareMask, "SetTexture", "maskTextures")
        for _, state in ipairs({ "Normal", "Highlight", "Disabled" }) do
            watchPreparation(button, "Set" .. state .. "FontObject", "fonts")
        end
    end
    function catalogue:Describe(entry)
        descriptions = descriptions + 1
        return describe(self, entry)
    end
    function lib:SetTooltip(owner, value)
        if watched[owner] then
            tooltips = tooltips + 1
        end
        return setTooltip(self, owner, value)
    end

    local started = os.clock()
    for _ = 1, 100 do
        picker.scrollBox:FullUpdate()
        picker:Paint()
    end
    local elapsed = (os.clock() - started) * 1000
    assert(textures == 0 and descriptions == 0 and tooltips == 0,
        "unchanged visible entries must not repeat artwork, metadata or tooltip setup")
    assert(not picker.frame:GetScript("OnUpdate"), "ordinary rebinding must not start idle polling")
    print(string.format("Icon picker: 100 unchanged six-icon refreshes, 0 texture/metadata/tooltip writes (%.2f ms mocked)", elapsed))

    local first = picker.scrollBox:GetDataIndexBegin()
    for _, wrapper in ipairs(picker.scrollBox.frames) do
        picker.gridView.reset(wrapper)
        assert(not wrapper.button:IsShown() and wrapper.button.entry == nil)
    end
    picker.scrollBox:FullUpdate()
    assert(textures == 0 and descriptions == 0 and tooltips == 0,
        "reacquiring the same artwork must keep the pooled binding")

    picker.scrollBox.first = 700
    picker.scrollBox:FullUpdate()
    assert(textures == 6, "only newly visible artwork needs a texture update")
    local reads = descriptions
    picker.scrollBox.first = first
    picker.scrollBox:FullUpdate()
    assert(textures == 12 and descriptions == reads,
        "returning to seen icons must reuse metadata, while replacing different pooled artwork")
    assert(#picker.scrollBox.frames == 6, "browsing must not create a frame per seen icon")

    local button = picker.scrollBox.frames[1].button
    local entry = button.entry
    local oldTooltip = entry.pickerTooltip
    entry.name = "Updated artwork name"
    picker:Paint()
    assert(entry.pickerTooltip ~= oldTooltip and entry.pickerTooltip.title == entry.name,
        "metadata updates must invalidate a cached tooltip without reloading the artwork")
    assert(textures == 12)
    picker:ToggleFavorite(entry.texture)
    picker:SetValue(entry.texture)
    picker:Update(0.02)
    assert(button:IsSelected() and button.favorite:IsShown() and textures == 12,
        "selection/favorite changes must not reset grid textures")

    for counter in pairs(preparation) do
        preparation[counter] = 0
    end
    local previousTextures = textures
    started = os.clock()
    for index = 1, 100 do
        picker.scrollBox.first = index % 2 == 1 and 700 or first
        picker.scrollBox:FullUpdate()
    end
    elapsed = (os.clock() - started) * 1000
    assert(textures - previousTextures == 600, "each changed visible icon needs only one artwork swap")
    assert(preparation.iconSizes == 0 and preparation.maskSizes == 0
        and preparation.maskTextures == 0 and preparation.fonts == 0,
        "scrolling through different icons must reuse prepared geometry, masks and fonts")
    print(string.format(
        "Icon picker: 100 six-icon viewport changes: %d artwork, %d icon size, %d mask size, %d mask texture, %d font writes (%.2f ms mocked)",
        textures - previousTextures, preparation.iconSizes, preparation.maskSizes,
        preparation.maskTextures, preparation.fonts, elapsed
    ))

    for _, saved in ipairs(preparationMethods) do
        saved[1][saved[2]] = saved[3]
    end
    for texture, setter in pairs(setters) do
        texture.SetTexture = setter
    end
    catalogue.Describe = nil
    lib.SetTooltip = setTooltip
    picker:Close()

    -- Large native sources are read once, then deduplicated in bounded batches.
    -- Two windows share that work without sharing draft/session ownership.
    local cached = lib._defaultIconCatalogue
    lib._defaultIconCatalogue = nil
    local originalReaders = {}
    local calls = 0
    local nativeCount = 32768
    for _, name in ipairs({ "GetLooseMacroIcons", "GetMacroIcons", "GetLooseMacroItemIcons", "GetMacroItemIcons" }) do
        originalReaders[name] = _G[name]
        _G[name] = function(values)
            calls = calls + 1
            for index = 1, nativeCount do
                values[index] = 500000 + index
            end
        end
    end
    local windows = {
        lib:CreateIconPicker(UIParent, { includePlayerIcons = false }),
        lib:CreateIconPicker(UIParent, { includePlayerIcons = false }),
    }
    local loadingOptions = {
        addonName = "Test",
        sourceName = "Loading",
        value = 900,
        onApply = function()
            error("loading must not save a draft")
        end,
    }
    for _, window in ipairs(windows) do
        for _, shelf in pairs(window.shelves) do
            shelf:SetWidth(400)
        end
    end
    local firstWindow, secondWindow = unpack(windows)
    firstWindow:Open(loadingOptions)
    assert(firstWindow.frame:IsShown() and firstWindow.loading:IsShown() and calls == 0)
    firstWindow:Update(0.02)
    assert(calls == 0, "native work must wait until the new window can paint")
    firstWindow:Update(0.02)
    local job = lib._iconCatalogueBuild
    assert(calls == 1 and job and not lib._defaultIconCatalogue)
    assert(#job.catalogue.entries == 19, "native acquisition and entry processing need separate updates")
    firstWindow:Close()
    assert(not firstWindow.loading:IsShown() and not firstWindow.frame:GetScript("OnUpdate"))
    assert(lib._iconCatalogueBuild == job, "closure must retain useful partial work without an idle worker")

    firstWindow:Open(loadingOptions)
    secondWindow:Open(loadingOptions)
    setCursor({ "item", 100 })
    secondWindow:ReceiveDrag()
    assert(secondWindow:GetValue() == 101, "cursor input must work before a catalogue exists")
    firstWindow.search:SetValue("500123")
    firstWindow:QueueSearch(0)
    for _ = 1, 1200 do
        for _, window in ipairs(windows) do
            if window.frame:GetScript("OnUpdate") then
                local previous = #job.catalogue.entries
                window:Update(0.02)
                if lib._iconCatalogueBuild then
                    assert(#job.catalogue.entries - previous <= 128,
                        "a frame budget expiration must stop catalogue normalization after the current batch")
                end
            end
        end
        if not firstWindow.frame:GetScript("OnUpdate") and not secondWindow.frame:GetScript("OnUpdate") then
            break
        end
    end
    assert(calls == 4 and not lib._iconCatalogueBuild,
        "simultaneous pickers must share native reads and deduplication")
    assert(firstWindow.catalogue == secondWindow.catalogue and firstWindow.catalogue == job.catalogue)
    assert(not firstWindow.preparing and not secondWindow.preparing
        and not firstWindow.searchJob and not secondWindow.searchJob)
    assert(not firstWindow.loading:IsShown() and not secondWindow.loading:IsShown())
    assert(firstWindow.results[1].texture == 500123 and secondWindow:GetValue() == 101,
        "pending filters and drops must survive loading without leaking between windows")
    local shared = firstWindow.catalogue
    assert(shared.byTexture[500123].tags.spell and shared.byTexture[500123].tags.item)
    assert(shared.byTexture[101] and lib:GetIconCatalogue() == shared and calls == 4)
    firstWindow:Close()
    secondWindow:Close()
    firstWindow:Open(loadingOptions)
    firstWindow:Update(0.02)
    firstWindow:Update(0.02)
    assert(firstWindow.catalogue == shared and not firstWindow.preparing and calls == 4,
        "warm reopening must reuse the complete catalogue")
    firstWindow:Close()

    -- Interrupted first loads may resume, but combat and invalid owners must
    -- stop the session before doing any more work.
    lib._defaultIconCatalogue = nil
    local interrupted = lib:CreateIconPicker(UIParent, { includePlayerIcons = false })
    interrupted:Open(loadingOptions)
    interrupted:Update(0.02)
    interrupted:Update(0.02)
    local partial = lib._iconCatalogueBuild
    inputState.inCombat = true
    interrupted:Update(0.02)
    inputState.inCombat = false
    assert(not interrupted.session and not interrupted.loading:IsShown()
        and not interrupted.frame:GetScript("OnUpdate"))
    local previousCalls = calls
    interrupted:Open(loadingOptions)
    interrupted.session.isValid = function()
        return false
    end
    interrupted:Update(0.02)
    assert(not interrupted.session and calls == previousCalls and lib._iconCatalogueBuild == partial)
    assert(lib:GetIconCatalogue() == partial.catalogue and not lib._iconCatalogueBuild,
        "synchronous callers must complete the same shared job instead of restarting it")
    lib._defaultIconCatalogue = cached
    for name, read in pairs(originalReaders) do
        _G[name] = read
    end
    print("LibModernSettings incremental catalogue and pooled artwork performance tests passed")
end
