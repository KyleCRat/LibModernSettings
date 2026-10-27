local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Controls/ValueList", MINOR)
then
    return
end

local HEIGHT = 34
local DEFAULT_WIDTH = 270
local DEFAULT_ENTRY_WIDTH = 64
local GAP = 6

local function validValue(value)
    return type(value) == "string" and strtrim(value) ~= ""
        or type(value) == "number"
            and value == value
            and math.abs(value) < math.huge
end

local function copyValues(values, maximum)
    assert(type(values) == "table", "value list must be an array")
    local copy = {}

    for key, value in pairs(values) do
        assert(
            type(key) == "number"
                and key >= 1
                and key % 1 == 0
                and key <= #values,
            "value list must be a dense array"
        )
        assert(
            validValue(value),
            "list values must be non-empty strings or finite numbers"
        )
        copy[key] = value
    end

    for index = 1, #values do
        assert(copy[index] ~= nil, "value list must be a dense array")
    end

    assert(#copy <= maximum, "value list exceeds maxValues")
    return copy
end

local function sameValues(left, right)
    if #left ~= #right then return false end

    for index, value in ipairs(left) do
        if value ~= right[index] then return false end
    end

    return true
end

local function formatValue(control, value)
    if value == false then return "" end

    local text = tostring(value)

    if control.formatValue then text = control.formatValue(value) end

    assert(type(text) == "string", "formatValue must return a string")
    return text
end

local function createEntry(control, index)
    local input = lib:CreateTextInput(control, {
        width = control.entryWidth,
        height = HEIGHT,
        textInset = 4,
        justifyH = "CENTER",
        tooltip = control.entryTooltip,
        tooltipTitle = control.tooltipTitle,
        onCommit = function(text)
            return control:_CommitEntry(index, text)
        end,
        onError = function(message)
            if control.onError then control.onError(message) end
        end,
    })
    input:HookScript("OnEnterPressed", function(self)
        local revision = self._valueListSubmittedRevision
        self._valueListSubmittedRevision = nil

        if
            revision == control.revision
            and control.enabled
            and control:IsVisible()
        then
            control:_AdvanceEntry(index)
        end
    end)
    input:HookScript("OnEscapePressed", function()
        control.commitFailed = nil
    end)
    control.entries[index] = input
    return input
end

local function layoutValueList(control)
    local count = #control.slots
    local available = math.max(1, control:GetWidth())
    local entryWidth = math.min(control.entryWidth, available)
    local actionsWidth = HEIGHT + GAP

    if count > 1 then actionsWidth = actionsWidth + HEIGHT + GAP end

    local lastWidth = entryWidth + actionsWidth
    local keepActionsTogether = lastWidth <= available
        or lib:_LayoutSizeMatches(lastWidth, available)
    local x, y = 0, 0

    local function place(frame, width, reservedWidth)
        local right = x + (reservedWidth or width)

        if
            x > 0
            and right > available
            and not lib:_LayoutSizeMatches(right, available)
        then
            x = 0
            y = y + HEIGHT + GAP
        end

        frame:SetSize(width, HEIGHT)
        lib:_SetLayoutPoint(frame, "TOPLEFT", control, "TOPLEFT", x, -y)
        x = x + width + GAP
    end

    for index = 1, count do
        local input = control.entries[index]

        if not input then
            input = createEntry(control, index)
            input:SetValue(formatValue(control, control.slots[index]))
        end
        -- Keep the last field with its actions when the row can hold them together.
        local reservedWidth

        if index == count and keepActionsTogether then
            reservedWidth = lastWidth
        end

        place(input, entryWidth, reservedWidth)
        input:SetControlEnabled(control.enabled, control.disabledTooltip)
        input:Show()
    end

    for index = count + 1, #control.entries do
        control.entries[index]:CancelAndClearFocus()
        control.entries[index]:Hide()
    end

    control.removeButton:SetShown(count > 1)

    if count > 1 then place(control.removeButton, HEIGHT) end

    place(control.addButton, HEIGHT)
    control.removeButton:SetControlEnabled(
        control.enabled,
        control.disabledTooltip
    )
    control.addButton:SetControlEnabled(
        control.enabled and count < control.maxValues,
        control.enabled and "The maximum number of fields is already shown."
            or control.disabledTooltip
    )
    return y + HEIGHT
end

local function createValueList(parent, options)
    assert(
        options.addIconTexture == nil
            or type(options.addIconTexture) == "string"
            or type(options.addIconTexture) == "number",
        "addIconTexture must be a texture path, file ID, or nil"
    )
    for _, key in ipairs({ "parseValue", "formatValue", "onChanged", "onError" }) do
        assert(
            options[key] == nil or type(options[key]) == "function",
            key .. " must be a function or nil"
        )
    end

    assert(
        options.entryWidth == nil
            or type(options.entryWidth) == "number"
                and options.entryWidth > 0
                and options.entryWidth < math.huge,
        "entryWidth must be positive and finite"
    )
    assert(
        options.maxValues == nil
            or type(options.maxValues) == "number"
                and options.maxValues >= 1
                and options.maxValues < math.huge
                and options.maxValues % 1 == 0,
        "maxValues must be a positive integer"
    )

    if options.value ~= nil then
        copyValues(options.value, options.maxValues or math.huge)
    end

    local control = CreateFrame("Frame", nil, parent)
    control:SetSize(options.width or DEFAULT_WIDTH, HEIGHT)
    control.entryWidth = options.entryWidth or DEFAULT_ENTRY_WIDTH
    control.maxValues = options.maxValues or math.huge
    control.parseValue = options.parseValue
    control.formatValue = options.formatValue
    control.onChanged = options.onChanged
    control.onError = options.onError
    control.entryTooltip = options.tooltip
        or "Enter saves and moves to the next field. Clear a field to omit it."
    control.tooltipTitle = options.tooltipTitle
    control.entries = {}
    control.slots = { false }
    control.enabled = options.enabled ~= false
    control.disabledTooltip = options.disabledTooltip
    control.revision = 0
    control.addButton = lib:CreateButton(control, {
        variant = "square",
        iconTexture = options.addIconTexture or lib._defaultIcons.plus,
        tooltip = "Add a value",
        onClick = function()
            control:AddEntry()
        end,
    })
    control.removeButton = lib:CreateButton(control, {
        variant = "square",
        iconAtlas = "common-icon-delete",
        tooltip = "Remove the last field",
        onClick = function()
            control:RemoveLastEntry()
        end,
    })
    control:SetScript("OnHide", function(self)
        self:CancelAndClearFocus()
    end)
    lib:_WatchControlSize(control)
    return control
end

local valueListMethods = {}
valueListMethods.SetControlWidth = lib._SetControlWidth

function valueListMethods:RefreshLayout()
    lib:_RefreshControlLayout(self, layoutValueList)
end

function valueListMethods:GetInputAlignmentOffset()
    return HEIGHT / 2
end

function valueListMethods:GetValue()
    local values = {}

    for _, value in ipairs(self.slots) do
        if value ~= false then values[#values + 1] = value end
    end

    return values
end

function valueListMethods:SetValue(values)
    local copy = copyValues(values, self.maxValues)

    if self.notifying and sameValues(copy, self:GetValue()) then return end

    self:CancelAndClearFocus()
    self.revision = self.revision + 1
    self.slots = #copy > 0 and copy or { false }

    for index, input in ipairs(self.entries) do
        input:SetValue(formatValue(self, self.slots[index] or false))
    end

    self:RefreshLayout()
end

function valueListMethods:_NotifyChanged(previous)
    local values = self:GetValue()

    if self.onChanged and not sameValues(previous, values) then
        self.notifying = true
        self.onChanged(values)
        self.notifying = nil
    end
end

function valueListMethods:_CommitEntry(index, text)
    local input = self.entries[index]
    input._valueListSubmittedRevision = nil
    text = strtrim(text)
    local value = false

    if text ~= "" then
        local message
        value = text

        if self.parseValue then
            value, message = self.parseValue(text)
        end

        if value == nil or value == false then
            self.commitFailed = true
            return nil, message or "Enter a valid value."
        end

        assert(
            validValue(value),
            "parseValue must return a non-empty string, finite number, or nil with an error"
        )
    end

    self.commitFailed = nil
    local previous = self:GetValue()
    local revision = self.revision
    self.slots[index] = value
    self:_NotifyChanged(previous)

    if revision ~= self.revision then return input:GetValue() end

    input._valueListSubmittedRevision = revision
    return formatValue(self, value)
end

function valueListMethods:CommitAndClearFocus()
    for index = 1, #self.slots do
        if self.entries[index]:CommitAndClearFocus() == false then
            self.commitFailed = nil
            return false
        end
    end

    local success = not self.commitFailed
    self.commitFailed = nil
    return success
end

function valueListMethods:CancelAndClearFocus()
    for _, input in ipairs(self.entries) do
        input:CancelAndClearFocus()
        input._valueListSubmittedRevision = nil
    end

    self.commitFailed = nil
end

function valueListMethods:FocusValue(index)
    index = index or 1
    assert(
        type(index) == "number"
            and index % 1 == 0
            and index >= 1
            and index <= #self.slots,
        "value list focus index is outside its fields"
    )

    if self.enabled and self:IsVisible() then
        self.entries[index]:FocusValue()
        lib:_RequestControlReveal(self.entries[index])
    end
end

function valueListMethods:_AdvanceEntry(index)
    if index < #self.slots then
        self:FocusValue(index + 1)
    elseif self.slots[index] ~= false then
        self:AddEntry()
    else
        self:FocusValue(index)
    end
end

function valueListMethods:AddEntry()
    local revision = self.revision

    if not self.enabled or not self:IsVisible() then return false end

    if
        not self:CommitAndClearFocus()
        or self.revision ~= revision
        or not self.enabled
        or not self:IsVisible()
    then
        return false
    end

    local count = #self.slots

    if self.slots[count] ~= false and count < self.maxValues then
        count = count + 1
        self.slots[count] = false
        self:RefreshLayout()
        self.entries[count]:SetValue("")
    end

    self:FocusValue(count)
    return true
end

function valueListMethods:RemoveLastEntry()
    if not self.enabled or not self:IsVisible() or #self.slots == 1 then
        return false
    end

    local count = #self.slots
    local revision = self.revision
    self.entries[count]:CancelAndClearFocus()

    if
        not self:CommitAndClearFocus()
        or self.revision ~= revision
        or not self.enabled
        or not self:IsVisible()
    then
        return false
    end

    local previous = self:GetValue()
    self.slots[count] = nil
    self:RefreshLayout()
    self:_NotifyChanged(previous)

    if self.revision == revision then self:FocusValue(count - 1) end

    return true
end

function valueListMethods:SetControlEnabled(enabled, disabledTooltip)
    self.enabled = enabled == true
    self.disabledTooltip = disabledTooltip

    if not self.enabled then self:CancelAndClearFocus() end

    self:RefreshLayout()
end

function valueListMethods:SetOnChanged(callback)
    assert(
        callback == nil or type(callback) == "function",
        "onChanged must be a function or nil"
    )
    self.onChanged = callback
end

function valueListMethods:SetOnError(callback)
    assert(
        callback == nil or type(callback) == "function",
        "onError must be a function or nil"
    )
    self.onError = callback
end

local function initializeValueList(control, options)
    control:SetValue(options.value or {})
end

local function refreshValueListAppearance(control, options)
    lib:_ApplyInputWidth(control, options.width or DEFAULT_WIDTH)
    control.entryWidth = options.entryWidth or DEFAULT_ENTRY_WIDTH

    local button = control.addButton
    local buttonOptions = button._libModernSettingsAppearanceOptions
    buttonOptions.iconAtlas = nil
    buttonOptions.iconTexture = options.addIconTexture or lib._defaultIcons.plus
    lib:_RefreshControlAppearance(button)
    button.icon:SetVertexColor(
        NORMAL_FONT_COLOR.r,
        NORMAL_FONT_COLOR.g,
        NORMAL_FONT_COLOR.b
    )

    control:RefreshLayout()
end

lib:RegisterControlType(
    "valueList",
    createValueList,
    valueListMethods,
    initializeValueList,
    refreshValueListAppearance
)

function lib:CreateValueList(parent, options)
    return self:CreateControl("valueList", parent, options or {})
end
