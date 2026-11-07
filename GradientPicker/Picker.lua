local MAJOR, MINOR = "LibModernSettings-1.0", 14
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("GradientPicker/Picker", MINOR)
then
    return
end

lib._gradientPickerPrototype = lib._gradientPickerPrototype or {}
local Picker = lib._gradientPickerPrototype
Picker.__index = Picker
local Model = lib._gradientUtils

function Picker:Validate()
    local session = self.session
    if not session then return false end
    if InCombatLockdown() or (session.isValid and not session.isValid()) then
        self:Close()
        return false
    end
    return self.session == session
end

function Picker:GetValue()
    if self.value then return Model.Copy(self.value) end
end

function Picker:Sync()
    if not self.session then return end
    if not self.angle.valueBox:HasFocus() then
        self.angle:SetValue(self.value.angle)
    end
    if not self.position.valueBox:HasFocus() then
        self.position:SetValue(self.value.stops[self.selected].position * 100)
    end
    lib._gradientPickerUI.Paint(self)
end

function Picker:NotifyPreview()
    if not self:Validate() then return end
    if self.session.onPreview then self.session.onPreview(self:GetValue()) end
end

function Picker:Changed()
    self:Sync()
    if not self.previewTimer then
        self.previewTimer = C_Timer.NewTimer(1 / 30, function()
            self.previewTimer = nil
            self:NotifyPreview()
        end)
    end
end

function Picker:CommitInputs()
    if not self:Validate() then return false end
    local session = self.session
    for _, control in ipairs({ self.angle, self.position }) do
        if control.valueBox:HasFocus() then control.valueBox:ClearFocus() end
        lib:_FlushPendingEditBoxCommit(control.valueBox)
        if self.session ~= session then return false end
    end
    return true
end

function Picker:DiscardInputs()
    for _, control in ipairs({ self.angle, self.position }) do
        control:SetValue(control:GetValue())
        control.valueBox:ClearFocus()
    end
end

function Picker:Select(index)
    if not self:Validate() or not self.value.stops[index] then return false end
    if not self:CommitInputs() then return false end
    self.color:ClosePicker()
    self.selected = index
    self.color:SetValue(self.value.stops[index])
    self:Sync()
    return true
end

function Picker:SetValue(value)
    if not self:Validate() then return false end
    local normalized, message = Model.Normalize(value)
    if not normalized then
        self.messages:Show(message, "error")
        return false
    end
    self:StopDrag()
    self.color:ClosePicker()
    self:DiscardInputs()
    self.value = normalized
    self:Select(math.min(self.selected or 1, #normalized.stops))
    if self.previewTimer then self.previewTimer:Cancel() end
    self.previewTimer = nil
    return true
end

function Picker:MoveStop(index, position)
    if not self:Validate() then return false end
    if not Model.Move(self.value, index, position) then return false end
    self:Changed()
    return true
end

function Picker:SetAngle(angle)
    if not self:Validate() or not Model.Finite(angle) then return false end
    self.value.angle = math.max(0, math.min(360, angle))
    self.angle:SetValue(self.value.angle)
    self:Changed()
    return true
end

function Picker:SetColor(color)
    if not self:Validate() then return end
    local stop = self.value.stops[self.selected]
    -- A nil preview ends the color transaction; restore the input's committed
    -- value before an optional Apply callback supplies the new color.
    color = color or self.color:GetValue()
    for _, key in ipairs({ "r", "g", "b", "a" }) do
        stop[key] = color[key]
    end
    self:Changed()
end

function Picker:AddStop()
    if not self:CommitInputs() then return false end
    self:StopDrag()
    self.color:ClosePicker()
    local index = Model.Add(self.value)
    if not index then
        self.messages:Show(
            "No room for another stop. Move or remove a stop first.",
            "error"
        )
        return false
    end
    self:Select(index)
    self:Changed()
    return true
end

function Picker:RemoveStop()
    if not self:CommitInputs() or #self.value.stops <= 2 then return false end
    self:StopDrag()
    self.color:ClosePicker()
    table.remove(self.value.stops, self.selected)
    self:Select(math.min(self.selected, #self.value.stops))
    self:Changed()
    return true
end

function Picker:Reverse()
    if not self:CommitInputs() then return end
    self:StopDrag()
    self.color:ClosePicker()
    Model.Reverse(self.value)
    self:Select(#self.value.stops + 1 - self.selected)
    self:Changed()
end

function Picker:Reset()
    if not self:Validate() then return end
    self:SetValue(self.session.defaultValue)
    self:Changed()
end

function Picker:StartDrag(index)
    if not self:Select(index) then return end
    local x = GetCursorPosition()
    self.drag = {
        index = index,
        cursor = x,
        position = self.value.stops[index].position,
        span = self.bar:GetWidth() * self.bar:GetEffectiveScale(),
    }
    self.frame:RegisterEvent("GLOBAL_MOUSE_UP")
    self.frame:SetScript("OnUpdate", function()
        if not IsMouseButtonDown("LeftButton") then
            self:StopDrag()
        else
            self:UpdateDrag()
        end
    end)
end

function Picker:UpdateDrag()
    local drag = self.drag
    if not drag or drag.span <= 0 or not self:Validate() then return end
    local x = GetCursorPosition()
    self:MoveStop(drag.index, drag.position + (x - drag.cursor) / drag.span)
end

function Picker:StopDrag()
    if self.drag then self:UpdateDrag() end
    self.drag = nil
    self.frame:SetScript("OnUpdate", nil)
    self.frame:UnregisterEvent("GLOBAL_MOUSE_UP")
end

function Picker:Apply()
    if not self:Validate() then return false end
    self:StopDrag()
    local session = self.session
    if not self:CommitInputs() then return false end
    self.color:ClosePicker()
    local accepted, message = session.onApply(self:GetValue())
    if accepted == false then
        if message and self.session == session then
            self.messages:Show(message, "error")
        end
        return false
    end
    if self.session == session then self:Close(true) end
    return true
end

function Picker:Close(applied)
    local session = self.session
    self.session, self.drag = nil, nil
    self.frame:SetScript("OnUpdate", nil)
    self.frame:UnregisterAllEvents()
    if self.previewTimer then self.previewTimer:Cancel() end
    self.previewTimer = nil
    self.color:ClosePicker()
    self:DiscardInputs()
    self.frame:StopMovingOrSizing()
    self.frame:Hide()
    self.value = nil
    if session and session.onClose then session.onClose(applied == true) end
end

function Picker:Open(options)
    assert(
        type(options) == "table" and type(options.onApply) == "function",
        "gradient picker Open requires an onApply function"
    )
    for _, key in ipairs({ "addonName", "sourceName" }) do
        assert(
            type(options[key]) == "string" and options[key] ~= "",
            key .. " must be non-empty text"
        )
    end
    for _, key in ipairs({ "onPreview", "onClose", "isValid" }) do
        assert(
            options[key] == nil or type(options[key]) == "function",
            key .. " must be a function"
        )
    end
    local value, message = Model.Normalize(options.value)
    assert(value, message)
    local default, defaultError = Model.Normalize(options.defaultValue)
    assert(default, defaultError)
    if InCombatLockdown() then return false end
    self:Close()
    if self.session then return false end
    local session = {}
    for key, option in pairs(options) do
        session[key] = option
    end
    session.defaultValue = default
    self.session = session
    if not self:Validate() then return false end
    self.frame:SetTitle(
        "Edit gradient for " .. options.addonName .. " / " .. options.sourceName
    )
    self.frame:SetScale(
        math.min(
            1,
            (UIParent:GetWidth() - 40) / self.frame:GetWidth(),
            (UIParent:GetHeight() - 32) / self.frame:GetHeight()
        )
    )
    self.frame:Show()
    self.frame:Raise()
    self.frame:SetPropagateKeyboardInput(true)
    self.frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.selected = 1
    self:SetValue(value)
    return true
end

function lib:CreateGradientPicker(parent, options)
    assert(not InCombatLockdown(), "create gradient pickers outside combat")
    local picker = setmetatable({ handles = {} }, Picker)
    self._gradientPickerUI.Create(picker, parent, options or {})
    return picker
end
