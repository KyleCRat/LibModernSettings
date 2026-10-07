-- Compare live upgrades with fresh construction using different library defaults.
local MAJOR = "LibModernSettings-1.0"
local scripts = {
    "LibModernSettings-1.0.lua", "Utilities/Atlas.lua", "Utilities/EditBoxCommit.lua",
    "Elements/Text.lua", "Layouts/Control.lua", "Controls/Button.lua", "Controls/Checkbox.lua",
    "Controls/ExpandableHeader.lua", "Controls/Dropdown.lua",
    "Controls/Slider.lua", "Controls/TextInput.lua", "Layouts/Field.lua", "Layouts/Canvas.lua",
}
local sources = {}
for _, path in ipairs(scripts) do
    local file = assert(io.open(path, "rb"))
    sources[path] = file:read("*a")
    file:close()
end
local currentMinor = assert(tonumber(sources[scripts[1]]:match('MINOR = "LibModernSettings%-1%.0", (%d+)')))

local function newEnvironment()
    local libraries, minors, queue = {}, {}, {}
    local environment = setmetatable({ LibStub = {}, framesCreated = 0 }, { __index = _G })
    function environment.LibStub:NewLibrary(major, minor)
        if minors[major] and minors[major] >= minor then return end
        minors[major] = minor
        libraries[major] = libraries[major] or {}
        return libraries[major]
    end
    setmetatable(environment.LibStub, { __call = function(_, major)
        return libraries[major]
    end })
    environment.C_Timer = { After = function(_, callback) queue[#queue + 1] = callback end }
    function environment.Flush()
        local pending = queue
        queue = {}
        for _, callback in ipairs(pending) do callback() end
        assert(#queue == 0, "layout must settle without a repeating timer")
    end
    function environment.QueueSize() return #queue end
    function environment.CreateFrame(...)
        environment.framesCreated = environment.framesCreated + 1
        return CreateFrame(...)
    end
    environment.GameFontNormal = { height = 12 }
    environment.GameFontNormalLarge = { height = 16 }
    environment.GameFontNormalHuge = { height = 20 }
    environment.ScrollBoxConstants = { UpdateImmediately = 1 }
    function environment.CreateScrollBoxLinearView()
        return { SetPanExtent = function() end }
    end
    environment.ScrollUtil = { InitScrollBoxWithScrollBar = function(scrollBox)
        function scrollBox:FullUpdate()
            self.updateCount = (self.updateCount or 0) + 1
        end
    end }
    return environment
end

local function loadVersion(environment, old)
    local minor = old and currentMinor - 1 or currentMinor
    for _, path in ipairs(scripts) do
        local source = sources[path]:gsub('(MINOR = "LibModernSettings%-1%.0", )%d+', '%1' .. minor, 1)
        if old then
            source = source:gsub('DEFAULT_STACKED_GAP = 7', 'DEFAULT_STACKED_GAP = 11')
                :gsub('DEFAULT_DESCRIPTION_GAP = 4', 'DEFAULT_DESCRIPTION_GAP = 8')
                :gsub('DEFAULT_INPUT_HEIGHT = 34', 'DEFAULT_INPUT_HEIGHT = 25')
                :gsub('DEFAULT_INSET = 0', 'DEFAULT_INSET = 8')
                :gsub('DEFAULT_HEIGHT = 34', 'DEFAULT_HEIGHT = 40')
                :gsub('CHECKBOX_SIZE = 34', 'CHECKBOX_SIZE = 40')
                :gsub('height = 34,', 'height = 40,')
                :gsub('return GameFontNormalHuge', 'return GameFontNormalLarge')
                :gsub('return GameFontNormalLarge\n    elseif role == "description"',
                    'return GameFontNormal\n    elseif role == "description"')
                :gsub('columnGap = 15,', 'columnGap = 19,')
        end
        local chunk = assert(loadstring(source, '@' .. path))
        setfenv(chunk, environment)
        chunk()
        if path == scripts[1] then
            local lib = environment.LibStub(MAJOR)
            -- Tooltip behavior has its own suite; no game tooltip is needed here.
            lib.AddTooltipTarget = function() end
            lib.SetControlTooltipEnabled = function() end
        end
    end
    return environment.LibStub(MAJOR)
end

local function buildPage(environment)
    local lib = environment.LibStub(MAJOR)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, { width = 500, height = 180, scrollable = true })
    local root = layout:GetRootFlow()
    local title = layout:AddHeader("Settings", "Description")
    local columns = root:BeginColumns()
    local section = columns.left:AddSection("General")
    local dropdownOptions = { label = "Choice", choices = { { value = 1, label = "One" } }, value = 1 }
    local dropdown = columns.left:AddControl("dropdown", dropdownOptions)
    dropdownOptions.leftInset = 99 -- Caller mutations must not rewrite option intent.
    local explicit = columns.right:AddControl("dropdown", {
        label = "Custom", height = 80, leftInset = 0, rightInset = 2,
        fontObject = environment.GameFontNormal,
    }, { marginTop = 5, marginBottom = 9 })
    local checkbox = columns.right:AddControl("checkbox", { label = "Enabled", value = true })
    local field = columns.left:AddControl("field", {
        label = "Scale", description = "Original hint", controlType = "slider", controlOptions = {
            minValue = 0, maxValue = 100, step = 1, value = 50,
        },
    })
    local nested = columns.right:BeginColumns({ columnGap = 3 })
    nested.left:AddControl("textInput", { height = 34 })
    nested.right:AddText({ text = "Nested", fontObject = environment.GameFontNormal })
    nested:Finish({ marginBottom = 7 })
    columns:Finish({ marginBottom = 6 })
    root:AddSpacer(5)
    local following = root:AddControl("textInput", { value = "Saved", height = 38 })
    local automaticInput = root:AddControl("textInput", { value = "Automatic" })
    local explicitInput = root:AddControl("textInput", { height = 40 })
    local button = root:AddControl("button", { text = "Action" })
    local header = root:AddControl("expandableHeader", { text = "Details", expanded = false })
    local customFont = root:AddSection("Custom font", { fontObject = environment.GameFontNormal })
    layout:Finalize({ paddingBottom = 12 })
    environment.Flush()
    dropdown:SetControlEnabled(false)
    checkbox:SetValue(false)
    field:GetControl():SetValue(55)
    field:SetDescription("Updated hint")
    field:GetControl().valueBox:SetFocus()
    field:GetControl().valueBox:SetText("Uncommitted")
    button:SetButtonText("Updated action")
    header:SetExpanded(true)
    return {
        parent = parent, layout = layout, title = title, section = section,
        dropdown = dropdown, explicit = explicit, field = field,
        following = following, customFont = customFont,
        automaticInput = automaticInput, explicitInput = explicitInput, button = button, header = header,
        checkbox = checkbox,
    }
end

local function compareFlows(left, right)
    assert(left.cursor == right.cursor, "flow height differs after upgrade")
    assert(#left.entries == #right.entries)
    for index, entry in ipairs(left.entries) do
        local other = right.entries[index]
        if entry.frame then
            local frame, reference = entry.frame, other.frame
            assert(frame:GetWidth() == reference:GetWidth(), "frame width differs after upgrade")
            assert(frame:GetHeight() == reference:GetHeight(), "frame height differs after upgrade")
            assert(frame.point[4] == reference.point[4] and frame.point[5] == reference.point[5],
                "frame placement differs after upgrade")
        elseif entry.columns then
            for column, flow in ipairs(entry.columns.flows) do
                compareFlows(flow, other.columns.flows[column])
            end
        end
    end
end

local environment = newEnvironment()
loadVersion(environment, true)
local page = buildPage(environment)
local previousTop = page.following.point[5]
local framesBefore = environment.framesCreated
loadVersion(environment, false)
environment.Flush()
assert(environment.framesCreated == framesBefore, "appearance upgrades must not recreate controls")
assert(page.following.point[5] ~= previousTop, "updated headings must reflow later rows")
assert(page.dropdown._libModernSettingsLeftInset == 0)
assert(page.explicit:GetHeight() == 80 and page.explicit._libModernSettingsRightInset == 2)
assert(page.dropdown.dropdown.enabled == false)
assert(page.dropdown:GetValue() == 1)
assert(page.field:GetControl():GetValue() == 55)
assert(page.field:GetDescription() == "Updated hint")
assert(page.field.description.text == "Updated hint")
assert(page.field:GetControl().valueBox:GetText() == "Uncommitted")
assert(page.field:GetControl().valueBox:HasFocus())
assert(page.automaticInput:GetHeight() == 34)
assert(page.explicitInput:GetHeight() == 40, "explicit sizes matching an old default remain explicit")
assert(page.button:GetHeight() == 34 and page.header:GetHeight() == 34)
assert(page.button:GetText() == "Updated action")
assert(page.header:IsExpanded())
assert(page.checkbox:GetWidth() == 34 and page.checkbox:GetValue() == false)
assert(page.title:GetFontObject() == environment.GameFontNormalHuge)
assert(page.section:GetFontObject() == environment.GameFontNormalLarge)
assert(page.customFont:GetFontObject() == environment.GameFontNormal)

local freshEnvironment = newEnvironment()
loadVersion(freshEnvironment, false)
local fresh = buildPage(freshEnvironment)
compareFlows(page.layout.rootFlow, fresh.layout.rootFlow)
assert(page.layout.content:GetHeight() == fresh.layout.content:GetHeight())
local freshHeight = fresh.layout.content:GetHeight()
loadVersion(freshEnvironment, true)
freshEnvironment.Flush()
assert(fresh.layout.content:GetHeight() == freshHeight, "late older copy must not change layout")

-- Identical embeds must not re-register controls or replay appearance/layout work.
local freshLib = freshEnvironment.LibStub(MAJOR)
local refreshAppearance = freshLib._RefreshControlAppearance
local appearanceRefreshes = 0
freshLib._RefreshControlAppearance = function(self, control)
    appearanceRefreshes = appearanceRefreshes + 1
    return refreshAppearance(self, control)
end
local updatesBeforeCopy = fresh.layout.scrollBox.updateCount
local childSizeHandler = fresh.field:GetControl().scripts.OnSizeChanged
loadVersion(freshEnvironment, false)
assert(appearanceRefreshes == 0, "same-MINOR embeds must not refresh live controls")
assert(freshEnvironment.QueueSize() == 0, "same-MINOR embeds must not queue canvas reflows")
freshEnvironment.Flush()
assert(fresh.layout.scrollBox.updateCount == updatesBeforeCopy)
assert(fresh.field:GetControl().scripts.OnSizeChanged == childSizeHandler)
freshLib._RefreshControlAppearance = refreshAppearance

-- Native size rounding must not reflow a page or become an explicit width override.
for _, entry in ipairs(fresh.layout.rootFlow.entries) do
    if entry.frame == fresh.automaticInput then
        local input = entry.frame
        input.scripts.OnSizeChanged(input, entry.width - 0.0001, entry.height + 0.0001)
        assert(freshEnvironment.QueueSize() == 0, "negligible canvas size changes must be ignored")
        assert(entry.autoWidth, "native rounding must retain automatic canvas width")
    end
end
local titleEntry = fresh.layout.rootFlow.entries[1]
fresh.title:SetWidth(fresh.title:GetWidth() - 0.0001)
fresh.layout:RefreshLayout()
assert(titleEntry.autoWidth, "FontString rounding must also retain automatic width")

-- Dynamic sizes reflow once, retaining custom margins and explicit heights.
local updates = page.layout.scrollBox.updateCount
page.explicit:SetHeight(140)
page.explicit:SetHeight(150)
assert(environment.QueueSize() == 1)
environment.Flush()
assert(page.layout.scrollBox.updateCount == updates + 1)
assert(page.explicit:GetHeight() == 150)

-- Hidden canvases do no deferred work; showing them performs the pending layout.
page.parent.visible = false
page.explicit:SetHeight(180)
assert(environment.QueueSize() == 0)
page.parent.visible = true
page.parent.scripts.OnShow(page.parent)
environment.Flush()
assert(page.layout.scrollBox.updateCount == updates + 2)

page.dropdown:SetWidth(123)
environment.Flush()
assert(page.dropdown:GetWidth() == 123, "native width overrides must stop automatic canvas stretching")
local privateFont = { height = 13 }
page.section:SetFontObject(privateFont)
page.layout:RefreshLayout()
assert(page.section:GetFontObject() == privateFont, "direct font overrides must survive reflow")

-- FontStrings expose HookScript but have no OnSizeChanged handler.
page.title:SetWidth(123)
page.layout:RefreshLayout()
assert(page.title:GetWidth() == 123, "text width overrides must survive reflow without size hooks")
local previousCursor = page.layout.rootFlow:GetCursor()
page.parent.visible = false
page.title.stringHeight = page.title:GetHeight() + 8
assert(environment.QueueSize() == 0)
page.parent.visible = true
page.parent.scripts.OnShow(page.parent)
environment.Flush()
assert(page.layout.rootFlow:GetCursor() == previousCursor + 8, "visible layout must remeasure text")

-- Existing legacy flows still accept content/finalization after a method upgrade.
local legacy = environment.LibStub(MAJOR):CreateCanvasLayout(environment.CreateFrame("Frame"), { width = 500, height = 200 })
legacy.rootFlow.entries = nil
legacy.rootFlow.cursor = 75
legacy.rootFlow:AddSpacer(5)
legacy.rootFlow:AddControl("textInput", { height = 34 })
assert(legacy:Finalize() == 126)

-- Wrapped descriptions resize their Field and reflow only its containing page.
do
    local layout = freshLib:CreateCanvasLayout(freshEnvironment.CreateFrame("Frame"), {
        width = 300, height = 200, scrollable = true,
    })
    local flow = layout:GetRootFlow()
    local field = flow:AddControl("field", {
        label = "Skin", description = "Short hint", controlType = "dropdown",
    })
    local following = flow:AddControl("textInput", {})
    layout:Finalize()
    freshEnvironment.Flush()
    local originalTop = following.point[5]
    local updatesBefore = fresh.layout.scrollBox.updateCount

    field:SetDescription(string.rep("a", 150))
    assert(freshEnvironment.QueueSize() == 1)
    freshEnvironment.Flush()
    assert(following.point[5] < originalTop)
    assert(field.point[5] - field:GetHeight() - following.point[5] == 4)
    assert(fresh.layout.scrollBox.updateCount == updatesBefore, "other pages must not reflow")

    field:SetDescription("Short hint")
    freshEnvironment.Flush()
    assert(following.point[5] == originalTop)
    field:SetDescription("Short hint")
    assert(freshEnvironment.QueueSize() == 0, "unchanged descriptions need no layout work")
    field:SetDescription(nil)
    freshEnvironment.Flush()
    assert(following.point[5] > originalTop)
    assert(field.point[5] - field:GetHeight() - following.point[5] == 4)
end

-- Plain canvas text has no heading role and still needs a usable font.
do
    local layout = freshLib:CreateCanvasLayout(freshEnvironment.CreateFrame("Frame"), {
        width = 500, height = 200,
    })
    local root = layout:GetRootFlow()
    local text = root:AddText({ text = "Body text" })
    local empty = root:AddText({ text = "" })
    local customFont = { height = 18 }
    local custom = root:AddText({ text = "Custom text", fontObject = customFont })
    layout:Finalize()
    freshEnvironment.Flush()

    assert(text:GetFontObject() == GameFontHighlight and text.text == "Body text")
    assert(empty:GetFontObject() == GameFontHighlight and empty.text == "")
    assert(custom:GetFontObject() == customFont and custom.text == "Custom text")
end

print("LibModernSettings canvas upgrade tests passed")
