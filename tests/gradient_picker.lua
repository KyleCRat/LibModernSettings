return function(lib, inputState)
    local originalCreateFrame, originalTimer, originalCursor =
        CreateFrame, C_Timer.NewTimer, GetCursorPosition
    local timers, cursor = {}, 1000
    function C_Timer.NewTimer(_, callback)
        local timer = { callback = callback }
        function timer:Cancel()
            self.cancelled = true
        end
        timers[#timers + 1] = timer
        return timer
    end
    local function flush()
        local pending = timers
        timers = {}
        for _, timer in ipairs(pending) do
            if not timer.cancelled then timer.callback() end
        end
    end
    function GetCursorPosition()
        return cursor, 500
    end
    function CreateFrame(frameType, name, parent, template)
        local frame = originalCreateFrame(frameType, name, parent, template)
        function frame:Raise()
            self.raised = true
        end
        function frame:UnregisterAllEvents()
            self.registeredEvents = {}
        end
        function frame:SetClipsChildren(value)
            self.clipsChildren = value
        end
        function frame:GetSize()
            return self:GetWidth(), self:GetHeight()
        end
        local createTexture = frame.CreateTexture
        function frame:CreateTexture(...)
            local texture = createTexture(self, ...)
            function texture:SetVertexOffset(index, x, y)
                self.vertices = self.vertices or {}
                self.vertices[index] = { x, y }
            end
            return texture
        end
        return frame
    end
    dofile("GradientPicker/Model.lua")
    dofile("GradientPicker/Browser.lua")
    dofile("GradientPicker/Picker.lua")
    local Model = lib._gradientUtils
    local original = {
        angle = 30,
        stops = {
            { position = 0, r = 1, g = 0, b = 0, a = 0.5 },
            { position = 0.5, r = 0, g = 1, b = 0, a = 1 },
            { position = 1, r = 0, g = 0, b = 1, a = 0.25 },
        },
    }
    local function near(actual, expected)
        assert(
            math.abs(actual - expected) < 0.000001,
            tostring(actual) .. " ~= " .. tostring(expected)
        )
    end
    local function separated(value)
        for index, stop in ipairs(value.stops) do
            assert(stop.position >= 0 and stop.position <= 1)
            if index > 1 then
                assert(
                    stop.position - value.stops[index - 1].position
                        >= Model.gap - 0.000001
                )
            end
        end
    end
    local duplicate = Model.Copy(original)
    duplicate.stops[1].position, duplicate.stops[2].position = 1, 1
    local repaired = assert(Model.Normalize(duplicate))
    separated(repaired)
    assert(#repaired.stops == 3 and duplicate.stops[1].position == 1)
    assert(repaired.stops[1].r == 1 and repaired.stops[2].g == 1)
    assert(not Model.Normalize({ angle = 0 / 0, stops = original.stops }))
    assert(not Model.Normalize({ stops = {} }))
    local invalid = Model.Copy(original)
    invalid.stops[2].r = math.huge
    assert(not Model.Normalize(invalid))
    local default = assert(Model.Normalize())
    for _ = 1, 50 do
        Model.Add(default)
        separated(default)
    end
    assert(#default.stops <= Model.maximum)
    local narrow = Model.Normalize()
    narrow.stops[2].position = 0.03
    assert(
        Model.Add(narrow) == 3,
        "Add must also use space outside the end stops"
    )
    separated(narrow)

    local picker = lib:CreateGradientPicker(UIParent)
    local writes, previews, closes, saved, valid, accepted =
        0, 0, 0, nil, true, true
    local options = {
        addonName = "Test",
        sourceName = "Background",
        value = original,
        defaultValue = Model.Normalize(),
        isValid = function()
            return valid
        end,
        onPreview = function(value)
            previews = previews + 1
            separated(value)
            value.stops[1].r = 0.123 -- Consumer mutation cannot alter the draft.
        end,
        onApply = function(value)
            if not accepted then return false, "Rejected" end
            writes, saved = writes + 1, value
        end,
        onClose = function()
            closes = closes + 1
        end,
    }
    assert(picker:Open(options))
    assert(picker.frame.raised and picker.preview.clipsChildren)
    assert(picker.value ~= original and picker.value.stops ~= original.stops)
    local copy = picker:GetValue()
    copy.stops[1].r = 0.25
    assert(picker:GetValue().stops[1].r == 1)
    assert(picker:Select(2))
    picker.position.valueBox:SetFocus()
    picker.position.valueBox:SetText("60")
    assert(picker:Select(3))
    near(picker:GetValue().stops[2].position, 0.6)
    near(picker:GetValue().stops[3].position, 1)
    picker:SetValue(original)
    picker:Select(2)
    picker.position.valueBox:SetFocus()
    picker.position.valueBox:SetText("80")
    picker:SetValue(original)
    near(picker:GetValue().stops[2].position, 0.5)
    for _ = 1, 20 do
        picker:MoveStop(2, 2)
        near(picker:GetValue().stops[2].position, 0.97)
        picker:MoveStop(2, -1)
        near(picker:GetValue().stops[2].position, 0.03)
        assert(#picker:GetValue().stops == 3 and picker.selected == 2)
    end
    assert(previews == 0 and writes == 0)
    flush()
    assert(previews == 1 and picker:GetValue().stops[1].r == 1)
    assert(original.stops[2].position == 0.5)
    picker.position._libModernSettingsOnChanged(150)
    near(picker.position:GetValue(), 97)
    picker.position._libModernSettingsOnChanged(-50)
    near(picker.position:GetValue(), 3)

    picker:SetValue(original)
    picker.bar.GetEffectiveScale = function()
        return 0.8
    end
    picker.handles[2].scripts.OnMouseDown(picker.handles[2], "LeftButton")
    near(picker:GetValue().stops[2].position, 0.5)
    cursor = cursor + 584 * 0.8 * 0.1
    picker:UpdateDrag()
    near(picker:GetValue().stops[2].position, 0.6)
    cursor = cursor + 10000
    picker:UpdateDrag()
    near(picker:GetValue().stops[2].position, 0.97)
    cursor = cursor - 20000
    picker.frame.scripts.OnEvent(picker.frame, "GLOBAL_MOUSE_UP", "LeftButton")
    near(picker:GetValue().stops[2].position, 0.03)
    assert(not picker.drag and not picker.frame:GetScript("OnUpdate"))
    local handle = picker.handles[2]
    local textures = #picker.preview.textures
    picker:SetAngle(725)
    near(picker:GetValue().angle, 360)
    assert(picker.handles[2] == handle and #picker.preview.textures == textures)
    assert(picker:AddStop())
    assert(#picker:GetValue().stops == 4)
    picker:Reverse()
    separated(picker:GetValue())
    assert(picker:RemoveStop() and #picker:GetValue().stops == 3)

    picker:SetValue(original)
    picker:Select(2)
    picker.color:OpenPicker()
    lib._colorPicker:SetColor({ r = 0.2, g = 0.3, b = 0.4, a = 0.5 })
    near(picker:GetValue().stops[2].a, 0.5)
    picker.color:ClosePicker()
    near(picker:GetValue().stops[2].g, 1)
    picker.color:OpenPicker()
    lib._colorPicker:SetColor({ r = 0.2, g = 0.3, b = 0.4, a = 0.5 })
    lib:_CloseColorPicker(picker.color, true)
    near(picker:GetValue().stops[2].g, 0.3)
    picker:Reset()
    assert(#picker:GetValue().stops == 2 and writes == 0)
    picker:Close()
    flush()
    assert(closes == 1 and writes == 0 and not picker.session)
    assert(not picker.frame:GetScript("OnUpdate"))
    picker:Close()
    assert(closes == 1)
    assert(picker:Open(options))
    picker:SetAngle(90)
    accepted = false
    assert(not picker:Apply() and picker.session)
    accepted = true
    assert(picker:Apply() and saved.angle == 90 and writes == 1 and closes == 2)
    assert(picker:Open(options))
    valid = false
    assert(not picker:Apply() and not picker.session and writes == 1)
    valid = true
    assert(picker:Open(options))
    inputState.inCombat = true
    picker.frame.scripts.OnEvent(picker.frame, "PLAYER_REGEN_DISABLED")
    assert(not picker.session and not picker:Open(options))
    inputState.inCombat = false
    assert(picker:Open(options))
    picker.frame.scripts.OnKeyDown(picker.frame, "ESCAPE")
    assert(not picker.session and writes == 1)
    assert(picker:Open(options))
    picker:StartDrag(1)
    local oldMethod = picker.MoveStop
    lib._loadedModules["GradientPicker/Picker"] = nil
    dofile("GradientPicker/Picker.lua")
    assert(picker.MoveStop ~= oldMethod and picker.drag and picker.session)
    picker:Close()
    flush()
    assert(not picker.frame:GetScript("OnUpdate") and not picker.previewTimer)
    assert(picker:Open(options))
    picker:SetAngle(120)
    local previousPreviews = previews
    picker:SetValue(original)
    flush()
    assert(
        previews == previousPreviews,
        "SetValue must cancel pending previews"
    )
    picker:Close()
    assert(not pcall(function()
        picker:Open({})
    end))
    CreateFrame, C_Timer.NewTimer, GetCursorPosition =
        originalCreateFrame, originalTimer, originalCursor
    print(
        "LibModernSettings gradient picker separation, cursor, draft, color, lifecycle and reuse tests passed"
    )
end
