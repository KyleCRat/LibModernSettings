-- Compare live upgrades with fresh construction using different library defaults.
local MAJOR = "LibModernSettings-1.0"
local scripts = {
    "LibModernSettings-1.0.lua",
    "Utilities/Atlas.lua",
    "Utilities/EditBoxCommit.lua",
    "Utilities/KeyboardNavigation.lua",
    "Utilities/ControlNavigation.lua",
    "Utilities/TabNavigation.lua",
    "Elements/Text.lua",
    "Layouts/Control.lua",
    "Controls/Button.lua",
    "Controls/Checkbox.lua",
    "Controls/ExpandableHeader.lua",
    "Controls/Dropdown.lua",
    "Controls/Slider.lua",
    "Controls/TextInput.lua",
    "Controls/SearchBox.lua",
    "Controls/ValueList.lua",
    "Layouts/Field.lua",
    "Utilities/Color.lua",
    "Controls/Color.lua",
    "Utilities/ColorPicker.lua",
    "Layouts/ScrollArea.lua",
    "Layouts/CanvasNavigation.lua",
    "Layouts/Canvas.lua",
}
local sources = {}

for _, path in ipairs(scripts) do
    local file = assert(io.open(path, "rb"))
    sources[path] = file:read("*a")
    file:close()
end

local currentMinor = assert(
    tonumber(
        sources[scripts[1]]:match('MINOR = "LibModernSettings%-1%.0", (%d+)')
    )
)

local function newEnvironment()
    local libraries, minors, queue = {}, {}, {}
    local environment = setmetatable({
        LibStub = {},
        framesCreated = 0,
    }, { __index = _G })

    function environment.LibStub:NewLibrary(major, minor)
        if minors[major] and minors[major] >= minor then return end

        minors[major] = minor
        libraries[major] = libraries[major] or {}
        return libraries[major]
    end

    setmetatable(environment.LibStub, {
        __call = function(_, major)
            return libraries[major]
        end,
    })
    environment.C_Timer = {
        After = function(_, callback)
            queue[#queue + 1] = callback
        end,
    }

    function environment.Flush(maxPasses)
        for _ = 1, maxPasses or 1 do
            local pending = queue
            queue = {}

            for _, callback in ipairs(pending) do
                callback()
            end

            if #queue == 0 then break end
        end

        assert(#queue == 0, "layout must settle without a repeating timer")
    end

    function environment.QueueSize()
        return #queue
    end

    function environment.CreateFrame(...)
        environment.framesCreated = environment.framesCreated + 1
        return CreateFrame(...)
    end

    environment.GameFontNormal = { height = 12 }
    environment.GameFontNormalLarge = { height = 16 }
    environment.GameFontNormalHuge = { height = 20 }
    environment.ScrollBoxConstants =
        { UpdateImmediately = 1, NoScrollInterpolation = 0 }
    environment.BaseScrollBoxEvents = { OnScroll = "OnScroll" }

    function environment.CreateScrollBoxLinearView()
        local view = {
            frames = {},
            SetPanExtent = function() end,
        }

        function view:GetFrames()
            return self.frames
        end

        function view:Layout(scrollBox)
            for _, frame in ipairs(self.frames) do
                -- Blizzard's linear view clears/rebuilds child anchors on a full update.
                frame:ClearAllPoints()
                frame:SetPoint(
                    "TOPLEFT",
                    scrollBox:GetScrollTarget(),
                    "TOPLEFT",
                    0,
                    0
                )
                frame:SetPoint(
                    "TOPRIGHT",
                    scrollBox:GetScrollTarget(),
                    "TOPRIGHT",
                    0,
                    0
                )
            end
        end

        return view
    end

    environment.ScrollUtil = {
        InitScrollBoxWithScrollBar = function(scrollBox, _scrollBar, view)
            scrollBox.nativeView = view
            scrollBox.initCount = (scrollBox.initCount or 0) + 1
            scrollBox.scrollTarget =
                environment.CreateFrame("Frame", nil, scrollBox)
            scrollBox.scrollTarget:SetSize(1, 1)
            scrollBox.scrollTarget:SetPoint(
                "TOPLEFT",
                scrollBox,
                "TOPLEFT",
                0,
                0
            )

            function scrollBox:GetScrollTarget()
                return self.scrollTarget
            end

            function scrollBox:GetView()
                return self.nativeView
            end

            if view.frames then
                for _, child in ipairs({ scrollBox:GetChildren() }) do
                    if child.scrollable then
                        child:SetParent(scrollBox.scrollTarget)
                        view.frames[#view.frames + 1] = child
                    end
                end

                view:Layout(scrollBox)
            end

            function scrollBox:FullUpdate()
                self.updateCount = (self.updateCount or 0) + 1

                if view.Layout then
                    view:Layout(self)
                    self:ScrollToOffset(
                        self:GetDerivedScrollOffset(),
                        environment.ScrollBoxConstants.NoScrollInterpolation
                    )
                end
            end

            function scrollBox:GetDerivedScrollOffset()
                return self.scrollOffset or 0
            end

            function scrollBox:GetVisibleExtent()
                return self:GetParent():GetHeight()
            end

            function scrollBox:ScrollToOffset(offset, interpolation)
                assert(
                    interpolation
                        == environment.ScrollBoxConstants.NoScrollInterpolation
                )
                local content = self.nativeView:GetFrames()[1]
                self.scrollOffset = math.max(
                    0,
                    math.min(
                        offset,
                        content:GetHeight() - self:GetVisibleExtent()
                    )
                )
                self.scrollTarget:SetPoint(
                    "TOPLEFT",
                    self,
                    "TOPLEFT",
                    0,
                    self.scrollOffset
                )
                self:TriggerEvent(environment.BaseScrollBoxEvents.OnScroll)
            end
        end,
    }
    environment.ScrollUtil.InitScrollBoxListWithScrollBar =
        environment.ScrollUtil.InitScrollBoxWithScrollBar
    return environment
end

local function loadVersion(environment, old)
    local minor = old and currentMinor - 1 or currentMinor

    for _, path in ipairs(scripts) do
        local source = sources[path]:gsub(
            '(MINOR = "LibModernSettings%-1%.0", )%d+',
            "%1" .. minor,
            1
        )

        if old then
            source = source
                :gsub("DEFAULT_STACKED_GAP = 7", "DEFAULT_STACKED_GAP = 11")
                :gsub(
                    "DEFAULT_DESCRIPTION_GAP = 4",
                    "DEFAULT_DESCRIPTION_GAP = 8"
                )
                :gsub("DEFAULT_INPUT_HEIGHT = 34", "DEFAULT_INPUT_HEIGHT = 25")
                :gsub("DEFAULT_INSET = 0", "DEFAULT_INSET = 8")
                :gsub("DEFAULT_HEIGHT = 34", "DEFAULT_HEIGHT = 40")
                :gsub("CHECKBOX_SIZE = 34", "CHECKBOX_SIZE = 40")
                :gsub("height = 34,", "height = 40,")
                :gsub("return GameFontNormalHuge", "return GameFontNormalLarge")
                :gsub(
                    'return GameFontNormalLarge\n    elseif role == "description"',
                    'return GameFontNormal\n    elseif role == "description"'
                )
                :gsub("columnGap = 15,", "columnGap = 19,")
        end

        local chunk = assert(loadstring(source, "@" .. path))
        setfenv(chunk, environment)
        chunk(MAJOR)

        if path == scripts[1] then
            local lib = environment.LibStub(MAJOR)
            -- Tooltip behavior has its own suite; no game tooltip is needed here.
            lib.SetTooltip = function() end

            lib.AddTooltipTarget = function() end

            lib.SetControlTooltipEnabled = function() end
        end
    end

    return environment.LibStub(MAJOR)
end

local function buildPage(environment)
    local lib = environment.LibStub(MAJOR)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, {
        width = 500,
        height = 180,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local title = layout:AddHeader("Settings", "Description")
    local columns = root:BeginColumns()
    local section = columns.left:AddSection("General")
    local dropdownOptions = {
        label = "Choice",
        choices = { { value = 1, label = "One" } },
        value = 1,
    }
    local dropdown = columns.left:AddControl("dropdown", dropdownOptions)
    dropdownOptions.leftInset = 99 -- Caller mutations must not rewrite option intent.
    local explicit = columns.right:AddControl("dropdown", {
        label = "Custom",
        height = 80,
        leftInset = 0,
        rightInset = 2,
        fontObject = environment.GameFontNormal,
    }, { marginTop = 5, marginBottom = 9 })
    local checkbox = columns.right:AddControl(
        "checkbox",
        { label = "Enabled", value = true }
    )
    local field = columns.left:AddControl("field", {
        label = "Scale",
        description = "Original hint",
        controlType = "slider",
        controlOptions = {
            minValue = 0,
            maxValue = 100,
            step = 1,
            value = 50,
        },
    })
    local nested = columns.right:BeginColumns({ columnGap = 3 })
    nested.left:AddControl("textInput", { height = 34 })
    nested.right:AddText({
        text = "Nested",
        fontObject = environment.GameFontNormal,
    })
    nested:Finish({ marginBottom = 7 })
    columns:Finish({ marginBottom = 6 })
    local group = root:BeginGroup({ indent = 1, marginTop = 3 })
    group:AddControl("textInput", { value = "Grouped input" })
    local hiddenGroup = group:BeginGroup()
    hiddenGroup:AddText({ text = "Hidden child" })
    hiddenGroup:SetShown(false)
    hiddenGroup:Finish()
    group:Finish({ marginBottom = 5 })
    root:AddSpacer(5)
    local following =
        root:AddControl("textInput", { value = "Saved", height = 38 })
    local automaticInput = root:AddControl("textInput", { value = "Automatic" })
    local explicitInput = root:AddControl("textInput", { height = 40 })
    local button = root:AddControl("button", { text = "Action" })
    local header = root:AddControl(
        "expandableHeader",
        { text = "Details", expanded = false }
    )
    local customFont = root:AddSection(
        "Custom font",
        { fontObject = environment.GameFontNormal }
    )
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
        parent = parent,
        layout = layout,
        title = title,
        section = section,
        dropdown = dropdown,
        explicit = explicit,
        field = field,
        following = following,
        customFont = customFont,
        automaticInput = automaticInput,
        explicitInput = explicitInput,
        button = button,
        header = header,
        checkbox = checkbox,
        hiddenGroup = hiddenGroup,
    }
end

local function compareFlows(left, right)
    assert(left.cursor == right.cursor, "flow height differs after upgrade")
    assert(#left.entries == #right.entries)

    for index, entry in ipairs(left.entries) do
        local other = right.entries[index]

        if entry.frame then
            local frame, reference = entry.frame, other.frame
            assert(
                frame:GetWidth() == reference:GetWidth(),
                "frame width differs after upgrade"
            )
            assert(
                frame:GetHeight() == reference:GetHeight(),
                "frame height differs after upgrade"
            )
            assert(
                frame.point[4] == reference.point[4]
                    and frame.point[5] == reference.point[5],
                "frame placement differs after upgrade"
            )
        elseif entry.columns then
            for column, flow in ipairs(entry.columns.flows) do
                compareFlows(flow, other.columns.flows[column])
            end
        elseif entry.group then
            assert(entry.group.shown == other.group.shown)

            if entry.group.shown ~= false then
                compareFlows(entry.group, other.group)
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
assert(
    environment.framesCreated == framesBefore,
    "appearance upgrades must not recreate controls"
)
assert(
    page.following.point[5] ~= previousTop,
    "updated headings must reflow later rows"
)
assert(page.dropdown._libModernSettingsLeftInset == 0)
assert(
    page.explicit:GetHeight() == 80
        and page.explicit._libModernSettingsRightInset == 2
)
assert(page.dropdown.dropdown.enabled == false)
assert(page.dropdown:GetValue() == 1)
assert(page.field:GetControl():GetValue() == 55)
assert(page.field:GetDescription() == "Updated hint")
assert(page.field.description.text == "Updated hint")
assert(page.field:GetControl().valueBox:GetText() == "Uncommitted")
assert(page.field:GetControl().valueBox:HasFocus())
assert(page.automaticInput:GetHeight() == 34)
assert(
    page.explicitInput:GetHeight() == 40,
    "explicit sizes matching an old default remain explicit"
)
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
page.hiddenGroup:SetShown(true)
fresh.hiddenGroup:SetShown(true)
environment.Flush()
freshEnvironment.Flush()
compareFlows(page.layout.rootFlow, fresh.layout.rootFlow)
assert(page.layout.content:GetHeight() == fresh.layout.content:GetHeight())
local freshHeight = fresh.layout.content:GetHeight()
loadVersion(freshEnvironment, true)
freshEnvironment.Flush()
assert(
    fresh.layout.content:GetHeight() == freshHeight,
    "late older copy must not change layout"
)

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
assert(
    appearanceRefreshes == 0,
    "same-MINOR embeds must not refresh live controls"
)
assert(
    freshEnvironment.QueueSize() == 0,
    "same-MINOR embeds must not queue canvas reflows"
)
freshEnvironment.Flush()
assert(fresh.layout.scrollBox.updateCount == updatesBeforeCopy)
assert(fresh.field:GetControl().scripts.OnSizeChanged == childSizeHandler)
freshLib._RefreshControlAppearance = refreshAppearance

-- Native size rounding must not reflow a page or become an explicit width override.
for _, entry in ipairs(fresh.layout.rootFlow.entries) do
    if entry.frame == fresh.automaticInput then
        local input = entry.frame
        input.scripts.OnSizeChanged(
            input,
            entry.width - 0.0001,
            entry.height + 0.0001
        )
        assert(
            freshEnvironment.QueueSize() == 0,
            "negligible canvas size changes must be ignored"
        )
        assert(
            entry.autoWidth,
            "native rounding must retain automatic canvas width"
        )
    end
end

local titleEntry = fresh.layout.rootFlow.entries[1]
fresh.title:SetWidth(fresh.title:GetWidth() - 0.0001)
fresh.layout:RefreshLayout()
assert(
    titleEntry.autoWidth,
    "FontString rounding must also retain automatic width"
)

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
assert(
    page.dropdown:GetWidth() == 123,
    "native width overrides must stop automatic canvas stretching"
)
local privateFont = { height = 13 }
page.section:SetFontObject(privateFont)
page.layout:RefreshLayout()
assert(
    page.section:GetFontObject() == privateFont,
    "direct font overrides must survive reflow"
)

-- FontStrings expose HookScript but have no OnSizeChanged handler.
page.title:SetWidth(123)
page.layout:RefreshLayout()
assert(
    page.title:GetWidth() == 123,
    "text width overrides must survive reflow without size hooks"
)
local previousCursor = page.layout.rootFlow:GetCursor()
page.parent.visible = false
page.title.stringHeight = page.title:GetHeight() + 8
assert(environment.QueueSize() == 0)
page.parent.visible = true
page.parent.scripts.OnShow(page.parent)
environment.Flush()
assert(
    page.layout.rootFlow:GetCursor() == previousCursor + 8,
    "visible layout must remeasure text"
)

-- Existing legacy flows still accept content/finalization after a method upgrade.
local legacy = environment.LibStub(MAJOR):CreateCanvasLayout(
    environment.CreateFrame("Frame"),
    { width = 500, height = 200 }
)
legacy.rootFlow.entries = nil
legacy.rootFlow.cursor = 75
legacy.rootFlow:AddSpacer(5)
legacy.rootFlow:AddControl("textInput", { height = 34 })
assert(legacy:Finalize() == 126)

-- Nested non-scrolling sections can fill their parent without a scrollbar inset.
do
    local sectionEnvironment = newEnvironment()
    local sectionLib = loadVersion(sectionEnvironment, false)
    local parent = sectionEnvironment.CreateFrame("Frame")
    local layout = sectionLib:CreateCanvasLayout(parent, {
        width = 500,
        height = 200,
        scrollable = false,
        style = {
            paddingLeft = 0,
            scrollbarGap = 0,
            scrollbarWidth = 0,
        },
    })
    local input = layout:GetRootFlow():AddControl("textInput", {})
    layout:Finalize()

    for _, width in ipairs({ 500, 320, 760 }) do
        layout:SetSize(width, 200)
        sectionEnvironment.Flush()
        local left, right = layout:GetContentInsets()
        assert(
            left == 0 and right == 0,
            "non-scrolling sections must allow zero side insets"
        )
        assert(
            layout:GetContentWidth() == width and input:GetWidth() == width,
            "full-width content must remain aligned after resizing"
        )
        assert(layout:GetScrollBox() == nil)
    end

    for _, options in ipairs({
        {
            width = 500,
            height = 200,
            scrollable = true,
            style = { scrollbarWidth = 0 },
        },
        {
            width = 500,
            height = 200,
            scrollable = false,
            style = { scrollbarWidth = -1 },
        },
    }) do
        local success, message =
            pcall(sectionLib.CreateCanvasLayout, sectionLib, parent, options)
        assert(
            not success and message:find("canvas scrollbar width", 1, true),
            "scrolling layouts need a positive scrollbar width; negative widths are always invalid"
        )
    end
end

-- Wrapped descriptions resize their Field and reflow only its containing page.
do
    local layout =
        freshLib:CreateCanvasLayout(freshEnvironment.CreateFrame("Frame"), {
            width = 300,
            height = 200,
            scrollable = true,
        })
    local flow = layout:GetRootFlow()
    local field = flow:AddControl("field", {
        label = "Skin",
        description = "Short hint",
        controlType = "dropdown",
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
    assert(
        fresh.layout.scrollBox.updateCount == updatesBefore,
        "other pages must not reflow"
    )

    field:SetDescription("Short hint")
    freshEnvironment.Flush()
    assert(following.point[5] == originalTop)
    field:SetDescription("Short hint")
    assert(
        freshEnvironment.QueueSize() == 0,
        "unchanged descriptions need no layout work"
    )
    field:SetDescription(nil)
    freshEnvironment.Flush()
    assert(following.point[5] > originalTop)
    assert(field.point[5] - field:GetHeight() - following.point[5] == 4)
end

-- Plain canvas text has no heading role and still needs a usable font.
do
    local layout =
        freshLib:CreateCanvasLayout(freshEnvironment.CreateFrame("Frame"), {
            width = 500,
            height = 200,
        })
    local root = layout:GetRootFlow()
    local text = root:AddText({ text = "Body text" })
    local empty = root:AddText({ text = "" })
    local customFont = { height = 18 }
    local custom =
        root:AddText({ text = "Custom text", fontObject = customFont })
    layout:Finalize()
    freshEnvironment.Flush()

    assert(
        text:GetFontObject() == GameFontHighlight and text.text == "Body text"
    )
    assert(empty:GetFontObject() == GameFontHighlight and empty.text == "")
    assert(
        custom:GetFontObject() == customFont and custom.text == "Custom text"
    )
end

-- Responsive columns reuse controls and remove hidden cells from geometry.
do
    local parent = freshEnvironment.CreateFrame("Frame")
    local layout = freshLib:CreateCanvasLayout(parent, {
        width = 800,
        height = 200,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local row = root:BeginColumns({ minColumnWidth = 260 })
    local changes = 0
    local input = row.left:AddControl("field", {
        label = "Anchor from",
        controlType = "textInput",
        controlOptions = {
            value = "Saved",
            onCommit = function(text)
                changes = changes + 1
                return text
            end,
        },
    })
    local checkbox =
        row.right:AddControl("checkbox", { label = "Advanced", value = true })
    row:Finish()
    local following = root:AddControl("textInput", {})
    layout:Finalize()
    freshEnvironment.Flush()
    local frames = freshEnvironment.framesCreated
    local wideY = following.point[5]
    assert(
        input.point[5] == checkbox.point[5]
            and checkbox.point[4] > input.point[4]
    )

    local edit = input:GetControl()
    edit:SetFocus()
    edit:SetText("Pending edit")
    local updatesBeforeResize = layout.scrollBox.updateCount
    layout:SetSize(520, 220)
    layout:SetSize(500, 220)
    assert(freshEnvironment.QueueSize() == 1)
    freshEnvironment.Flush()
    assert(layout.scrollBox.updateCount == updatesBeforeResize + 1)
    assert(layout:GetCanvasWidth() == 500 and layout:GetCanvasHeight() == 220)
    assert(parent:GetWidth() == 500 and parent:GetHeight() == 220)
    assert(input:GetWidth() == layout:GetContentWidth())
    assert(
        checkbox.point[4] == input.point[4]
            and checkbox.point[5] < input.point[5]
    )
    assert(following.point[5] < wideY, "stacking must move following rows down")
    assert(checkbox:GetWidth() == 34, "checkbox artwork must remain square")
    assert(checkbox.label:GetWidth() == layout:GetContentWidth() - 36)

    row.right:SetShown(false)
    freshEnvironment.Flush()
    assert(not checkbox:IsShown() and input:IsShown())
    assert(following.point[5] == wideY, "hidden cells must reserve no height")
    row.left:SetShown(false)
    freshEnvironment.Flush()
    assert(
        following.point[5] == -layout:GetStyleValue("paddingTop"),
        "empty rows must leave no gap"
    )
    row.right:SetShown(true)
    freshEnvironment.Flush()
    assert(
        checkbox.point[4] == 0,
        "remaining cells must move to the first column"
    )

    row.left:SetShown(true)
    layout:SetSize(800, 600)
    freshEnvironment.Flush()
    assert(
        following.point[5] == wideY and layout:GetContent():GetHeight() >= 600
    )
    assert(edit:GetText() == "Pending edit" and edit:HasFocus())
    assert(checkbox:GetValue() and changes == 0)
    assert(
        freshEnvironment.framesCreated == frames,
        "reflow must not recreate controls"
    )
    layout:SetSize(800.0001, 600.0001)
    row.left:SetShown(true)
    assert(
        freshEnvironment.QueueSize() == 0,
        "unchanged geometry must not queue work"
    )

    parent.visible = false
    layout:SetSize(500, 200)
    assert(freshEnvironment.QueueSize() == 0)
    parent.visible = true
    parent.scripts.OnShow(parent)
    freshEnvironment.Flush()
    assert(
        checkbox.point[5] < input.point[5],
        "hidden resizes must apply on show"
    )

    for _, size in ipairs({
        { 0, 200 },
        { 20, 200 },
        { 500, 0 },
        { math.huge, 200 },
        { 0 / 0, 200 },
    }) do
        assert(not pcall(layout.SetSize, layout, size[1], size[2]))
        assert(
            layout:GetCanvasWidth() == 500 and layout:GetCanvasHeight() == 200
        )
    end

    assert(not pcall(root.BeginColumns, root, { minColumnWidth = 0 }))
    assert(not pcall(row.left.SetShown, row.left, "false"))

    root:SetShown(false)
    row.left:SetShown(false)
    row.left:SetShown(true)
    assert(not input:IsShown())
    local added = row.left:AddText({ text = "Added while hidden" })
    assert(not added:IsShown())
    root:SetShown(true)
    assert(input:IsShown() and added:IsShown())
    freshEnvironment.Flush()

    local inset =
        freshLib:CreateCanvasLayout(freshEnvironment.CreateFrame("Frame"), {
            width = 300,
            height = 200,
            scrollable = true,
            viewportMarginTop = 10,
            viewportMarginBottom = 10,
        })
    assert(not pcall(inset.SetSize, inset, 300, 20))
end

-- Column alignment follows measured heights without changing flow order or size.
for _, alignment in ipairs({ "top", "center", "bottom" }) do
    local alignmentEnvironment = newEnvironment()
    local lib = loadVersion(alignmentEnvironment, false)
    local parent = alignmentEnvironment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, { width = 800, height = 1 })
    local root = layout:GetRootFlow()
    local row = root:BeginColumns({
        verticalAlign = alignment,
        minColumnWidth = 260,
        marginTop = 7,
    })
    local group = row.left:BeginGroup()
    local content =
        alignmentEnvironment.CreateFrame("Frame", nil, layout:GetContent())
    content:SetSize(100, 40)
    group:AddFrame(content, { fillWidth = true, marginBottom = 0 })
    group:Finish()
    local checkbox = row.right:AddControl(
        "checkbox",
        { label = "Show on login" },
        { marginBottom = 0 }
    )
    row:Finish({ marginBottom = 5 })
    local following = root:AddControl("textInput", {})
    layout:Finalize()
    alignmentEnvironment.Flush()

    local factor = alignment == "center" and 0.5
        or alignment == "bottom" and 1
        or 0
    local start = layout:GetStyleValue("paddingTop") + 7
    assert(
        content.point[5] == -start
            and checkbox.point[5] == -(start + 6 * factor),
        "shorter columns align within the tallest measured column"
    )
    local followingY = following.point[5]
    assert(
        followingY == -(start + 40 + 5),
        "alignment adds no height to the column region"
    )
    layout:RefreshLayout()
    assert(
        following.point[5] == followingY
            and checkbox.point[5] == -(start + 6 * factor),
        "repeated layout does not accumulate alignment offsets"
    )

    content:SetHeight(20)
    alignmentEnvironment.Flush()
    assert(
        content.point[5] == -(start + 14 * factor)
            and checkbox.point[5] == -start,
        "dynamic measurement can change which column is tallest, including nested groups"
    )

    row.left:SetShown(false)
    alignmentEnvironment.Flush()
    assert(
        checkbox.point[5] == -start,
        "hidden columns reserve no alignment space"
    )
    row.right:SetShown(false)
    alignmentEnvironment.Flush()
    assert(
        following.point[5] == -layout:GetStyleValue("paddingTop"),
        "fully hidden aligned columns leave no margins"
    )

    row.left:SetShown(true)
    row.right:SetShown(true)
    layout:SetSize(500, 1)
    alignmentEnvironment.Flush()
    assert(
        content.point[5] == -start and checkbox.point[5] == -(start + 20),
        "stacked columns ignore vertical alignment and keep sequential placement"
    )
    assert(
        following.point[5] == -(start + 20 + 34 + 5),
        "stacking includes each column exactly once"
    )
    layout:SetSize(800, 1)
    alignmentEnvironment.Flush()
    assert(
        content.point[5] == -(start + 14 * factor)
            and checkbox.point[5] == -start,
        "returning to side-by-side columns restores alignment without rebuilding controls"
    )
    assert(not pcall(root.BeginColumns, root, { verticalAlign = "middle" }))
end

-- Groups provide full-width geometry immediately and retain nested layout/visibility.
do
    local groupEnvironment = newEnvironment()
    local groupLib = loadVersion(groupEnvironment, false)
    local parent = groupEnvironment.CreateFrame("Frame")
    local layout = groupLib:CreateCanvasLayout(parent, {
        width = 800,
        height = 160,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local options = { marginTop = 7 }
    local group = root:BeginGroup(options)
    options.marginTop = 99
    assert(
        group:GetWidth() == root:GetWidth(),
        "groups must start at full width before any reflow"
    )

    local commits = 0
    local input = group:AddControl("textInput", {
        value = "Saved",
        onCommit = function(text)
            commits = commits + 1
            return text
        end,
    })
    assert(input:GetWidth() == root:GetWidth())
    assert(input.point[5] == -root:GetCursor() - 7)
    local nested = group:BeginGroup({ indent = 1, marginTop = 3 })
    local nestedInput = nested:AddControl("textInput", { value = "Nested" })
    nested:Finish({ marginBottom = 2 })
    local row = group:BeginColumns({ minColumnWidth = 260 })
    local left = row.left:AddControl("textInput", { value = "Left" })
    local rightGroup = row.right:BeginGroup()
    local right = rightGroup:AddControl("textInput", { value = "Right" })
    rightGroup:Finish()
    row:Finish()
    local panel =
        groupEnvironment.CreateFrame("Frame", nil, layout:GetContent())
    panel:SetHeight(40)
    group:AddFrame(panel, { fillWidth = true })
    local finishOptions = { marginBottom = 9 }
    group:Finish(finishOptions)
    finishOptions.marginBottom = 99
    local following = root:AddControl("textInput", { value = "Following" })
    layout:Finalize()
    groupEnvironment.Flush()
    local frames = groupEnvironment.framesCreated
    local followingY = following.point[5]
    assert(
        -followingY == group:GetCursor() + 9,
        "group margins must be copied and applied once"
    )
    assert(
        nestedInput:GetWidth()
            == root:GetWidth() - layout:GetStyleValue("indent")
    )
    assert(nestedInput.point[4] == layout:GetStyleValue("indent"))
    assert(left.point[5] == right.point[5] and right.point[4] > left.point[4])

    input:SetFocus()
    input:SetText("Pending group edit")
    layout:SetSize(520, 160)
    layout:SetSize(400, 160)
    assert(groupEnvironment.QueueSize() == 1)
    groupEnvironment.Flush()
    assert(
        group:GetWidth() == root:GetWidth()
            and input:GetWidth() == root:GetWidth()
    )
    assert(panel:GetWidth() == root:GetWidth())
    assert(left.point[4] == right.point[4] and right.point[5] < left.point[5])
    assert(following.point[5] < followingY)
    assert(
        input:GetText() == "Pending group edit"
            and input:HasFocus()
            and commits == 0
    )
    assert(
        groupEnvironment.framesCreated == frames,
        "group reflows must preserve controls"
    )

    followingY = following.point[5]
    panel:SetHeight(90)
    groupEnvironment.Flush()
    assert(
        following.point[5] == followingY - 50,
        "group height changes must move following rows"
    )
    local height = layout:GetContent():GetHeight()
    followingY = following.point[5]
    layout:RefreshLayout()
    assert(
        layout:GetContent():GetHeight() == height
            and following.point[5] == followingY
    )

    nested:SetShown(false)
    row.right:SetShown(false)
    group:SetShown(false)
    groupEnvironment.Flush()
    assert(
        not input:IsShown()
            and not nestedInput:IsShown()
            and not right:IsShown()
    )
    assert(
        following.point[5] == -layout:GetStyleValue("paddingTop"),
        "hidden groups must remove their contents and both margins"
    )
    group:SetShown(true)
    groupEnvironment.Flush()
    assert(
        input:IsShown()
            and left:IsShown()
            and not nestedInput:IsShown()
            and not right:IsShown()
    )
    assert(
        left:GetWidth() == root:GetWidth(),
        "columns in groups retain their visibility rules"
    )
    nested:SetShown(true)
    row.right:SetShown(true)
    groupEnvironment.Flush()

    root:SetShown(false)
    nested:SetShown(false)
    group:SetShown(false)
    group:SetShown(true)
    rightGroup:SetShown(true)
    local late = rightGroup:BeginGroup()
    local lateInput =
        late:AddControl("textInput", { value = "Added while hidden" })
    late:Finish()
    assert(
        not input:IsShown() and not right:IsShown() and not lateInput:IsShown()
    )
    root:SetShown(true)
    groupEnvironment.Flush()
    assert(
        input:IsShown()
            and right:IsShown()
            and lateInput:IsShown()
            and not nestedInput:IsShown()
    )

    local empty = root:BeginGroup()
    local beforeEmpty = root:GetCursor()
    assert(
        empty:Finish() == beforeEmpty,
        "empty groups must add no implicit spacing"
    )
    groupEnvironment.Flush()
    local appended = root:BeginGroup({ marginTop = 5 })
    appended:AddCustom(100)
    appended:Finish()
    groupEnvironment.Flush()
    assert(
        layout:GetContent():GetHeight() > height,
        "new groups must update finalized canvases"
    )

    parent.visible = false
    layout:SetSize(800, 160)
    group:SetShown(false)
    group:SetShown(true)
    assert(groupEnvironment.QueueSize() == 0)
    parent.visible = true
    parent.scripts.OnShow(parent)
    groupEnvironment.Flush()
    assert(
        input:GetWidth() == root:GetWidth()
            and panel:GetWidth() == root:GetWidth()
    )
    assert(left.point[5] == right.point[5])
    assert(groupEnvironment.QueueSize() == 0)

    local entryCount = #root.entries

    for _, invalid in ipairs({ -1, "1", math.huge, 0 / 0 }) do
        assert(not pcall(root.BeginGroup, root, { marginTop = invalid }))
        assert(not pcall(group.Finish, group, { marginBottom = invalid }))
    end

    assert(
        #root.entries == entryCount and group.finishOptions.marginBottom == 9
    )
    assert(not pcall(root.BeginGroup, root, "invalid"))
    assert(not pcall(group.Finish, group, "invalid"))
    assert(not pcall(root.Finish, root))
    assert(not pcall(row.left.Finish, row.left))
    assert(not pcall(root.BeginColumns, root, { count = 1 }))
    assert(not pcall(legacy.rootFlow.BeginGroup, legacy.rootFlow))
    input:ClearFocus()
end

-- Existing flows acquire the group API through shared prototypes on upgrade.
do
    local upgradeEnvironment = newEnvironment()
    local upgradeLib = loadVersion(upgradeEnvironment, true)
    local layout =
        upgradeLib:CreateCanvasLayout(upgradeEnvironment.CreateFrame("Frame"), {
            width = 500,
            height = 160,
            scrollable = true,
        })
    local root = layout:GetRootFlow()
    local original = root:AddControl("textInput", { value = "Original" })
    layout:Finalize()
    upgradeEnvironment.Flush()
    upgradeLib._canvasFlowPrototype.BeginGroup = nil
    upgradeLib._canvasFlowPrototype.Finish = nil
    assert(root.BeginGroup == nil)
    local frames = upgradeEnvironment.framesCreated
    loadVersion(upgradeEnvironment, false)
    upgradeEnvironment.Flush()
    assert(
        upgradeEnvironment.framesCreated == frames
            and original:GetValue() == "Original"
    )
    local group = root:BeginGroup()
    local added = group:AddControl("textInput", { value = "After upgrade" })
    group:Finish()
    upgradeEnvironment.Flush()
    assert(added:GetWidth() == root:GetWidth())
    local beginGroup = root.BeginGroup
    loadVersion(upgradeEnvironment, true)
    loadVersion(upgradeEnvironment, false)
    assert(
        root.BeginGroup == beginGroup and upgradeEnvironment.QueueSize() == 0
    )
    group:SetShown(false)
    upgradeEnvironment.Flush()
    assert(original:IsShown() and not added:IsShown())
end

-- Tab order follows the current visual rows, including offscreen and stacked fields.
do
    local tabEnvironment = newEnvironment()
    loadVersion(tabEnvironment, true)
    local tabLib = tabEnvironment.LibStub(MAJOR)
    local window = tabEnvironment.CreateFrame("Frame")
    local toolbar = tabEnvironment.CreateFrame("Frame", nil, window)
    toolbar:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    local name = tabLib:CreateTextInput(toolbar, {})
    local parent = tabEnvironment.CreateFrame("Frame", nil, window)
    parent:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -60)
    local layout = tabLib:CreateCanvasLayout(parent, {
        width = 800,
        height = 100,
        scrollable = true,
    })
    local root = layout:GetRootFlow()
    local columns = root:BeginColumns({ minColumnWidth = 260 })
    local first = columns.left:AddControl("textInput", {})
    local third = columns.left:AddControl("textInput", {})
    local second = columns.right:AddControl("textInput", {})
    local fourth = columns.right:AddControl("textInput", {})
    columns:Finish()
    root:AddSpacer(200)
    local lastField = root:AddControl("field", {
        label = "Offscreen value",
        controlType = "textInput",
        controlOptions = {},
    })
    local last = lastField:GetControl()
    layout:Finalize()
    tabEnvironment.Flush()

    local function tab(source, expected, reverse)
        tabEnvironment.IsShiftKeyDown = function()
            return reverse == true
        end

        source.scripts.OnTabPressed(source)
        assert(
            expected:HasFocus(),
            "Tab must follow the current visible layout"
        )
        assert(source == expected or not source:HasFocus())
        tabEnvironment.Flush()
    end

    first:FocusValue()
    tab(first, second)
    tab(second, third)
    tab(third, fourth)
    tab(fourth, last)
    local lastTop = -select(5, lastField:GetPointByName("TOPLEFT"))
    assert(
        layout.scrollBox:GetDerivedScrollOffset()
            == lastTop + lastField:GetHeight() - 100,
        "offscreen focus must reveal the entire labeled field with the nearest scroll"
    )
    tab(last, fourth, true)
    assert(layout.scrollBox:GetDerivedScrollOffset() == -fourth.point[5])
    tab(fourth, third, true)
    tab(third, second, true)
    assert(layout.scrollBox:GetDerivedScrollOffset() == -second.point[5])
    tab(second, first, true)
    tab(first, last, true)
    tab(last, first)
    assert(
        not name:HasFocus(),
        "automatic canvas navigation must stay within its page"
    )

    layout:SetSize(500, 100)
    -- Do not flush first: navigation must settle queued responsive layout work.
    tab(first, third)
    tab(third, second)
    tab(second, fourth)
    tab(fourth, last)
    columns.right:SetShown(false)
    tab(last, third, true)
    tab(third, first, true)
    third:SetControlEnabled(false)
    tab(first, last)
    tab(last, first)
    third:SetControlEnabled(true)

    tabLib:EnableTabNavigation(window)
    tab(first, name, true)
    tab(name, first)
    tab(first, third)
    tab(third, last)
    tab(last, name)
    assert(layout.scrollBox:GetDerivedScrollOffset() > 0)
    tab(name, first)
    assert(
        layout.scrollBox:GetDerivedScrollOffset() == -first.point[5],
        "a scrolled page must stay after the header in the focus order"
    )

    -- Hidden pages must not enter an explicit root that spans several canvases.
    local otherPage = tabEnvironment.CreateFrame("Frame", nil, window)
    local otherLayout =
        tabLib:CreateCanvasLayout(otherPage, { width = 500, height = 100 })
    local other = otherLayout:GetRootFlow():AddControl("textInput", {})
    otherLayout:Finalize()
    otherPage:Hide()
    tabEnvironment.Flush()
    tab(first, name, true)
    tab(name, first)
    assert(not other:HasFocus())

    first:SetText("Pending upgrade")
    loadVersion(tabEnvironment, false)
    tabEnvironment.Flush()
    assert(first:HasFocus() and first:GetText() == "Pending upgrade")
    tab(first, name, true)
    assert(
        first:GetValue() == "Pending upgrade",
        "compatible upgrades must preserve roots and commit once"
    )
    name:CancelAndClearFocus()

    -- A large section is a layout container, not the region that must be revealed.
    local section = root:AddCustom(500)
    local sectionHeader =
        tabLib:CreateExpandableHeader(section, { text = "Large section" })
    sectionHeader:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    local bottomCheckbox =
        tabLib:CreateCheckbox(section, { label = "Offscreen checkbox" })
    bottomCheckbox:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -420)
    layout:RefreshLayout()
    tabEnvironment.Flush()
    last:FocusValue()

    tabEnvironment.IsShiftKeyDown = function()
        return false
    end

    last.scripts.OnTabPressed(last)
    local keyboard = tabLib._navigationKeyboardFrame
    assert(keyboard.control == sectionHeader and sectionHeader.highlightLocked)
    keyboard.scripts.OnKeyDown(keyboard, "TAB")
    assert(
        keyboard.control == bottomCheckbox and bottomCheckbox.highlightLocked
    )
    local sectionTop = -select(5, section:GetPointByName("TOPLEFT"))
    assert(
        layout.scrollBox:GetDerivedScrollOffset()
            == sectionTop + 420 + bottomCheckbox:GetHeight() - 100,
        "focus must reveal a checkbox inside a section taller than the viewport"
    )

    tabEnvironment.IsShiftKeyDown = function()
        return true
    end

    keyboard.scripts.OnKeyDown(keyboard, "TAB")
    assert(
        keyboard.control == sectionHeader
            and layout.scrollBox:GetDerivedScrollOffset() == sectionTop
    )
    tabLib:_ClearNavigationFocus()
end

-- Late native size notifications must not pin a dynamic Field to an old height.
do
    local dynamicEnvironment = newEnvironment()
    local dynamicLib = loadVersion(dynamicEnvironment, false)
    dynamicLib:RegisterControlType("dynamicContent", function(parent, options)
        local control = dynamicEnvironment.CreateFrame("Frame", nil, parent)
        control:SetSize(options.width, 1)
        return control
    end, {
        SetControlEnabled = function(self, enabled)
            self.enabled = enabled
        end,
    })

    local parent = dynamicEnvironment.CreateFrame("Frame")
    local layout =
        dynamicLib:CreateCanvasLayout(parent, { width = 500, height = 200 })
    local root = layout:GetRootFlow()
    local field = root:AddControl("field", {
        label = "Dynamic choices",
        controlType = "dynamicContent",
    })
    local following = root:AddControl("textInput", {})
    local control = field:GetControl()
    layout:Finalize()
    dynamicEnvironment.Flush()

    for _, height in ipairs({ 150, 72, 228 }) do
        parent:Hide()
        local oldWidth, oldHeight = field:GetWidth(), field:GetHeight()
        control:SetHeight(height)
        dynamicEnvironment.Flush()
        local expected = field:GetHeight()
        assert(expected > height)

        field.scripts.OnSizeChanged(field, oldWidth, oldHeight)
        assert(
            field._libModernSettingsExplicitHeight == nil,
            "a stale Field size notification must not become an explicit height"
        )
        assert(field:GetHeight() == expected)

        parent:Show()
        parent.scripts.OnShow(parent)
        dynamicEnvironment.Flush()
        assert(
            -following.point[5] >= -field.point[5] + expected,
            "the next row must reserve the dynamic control's full height"
        )
    end

    local oldWidth, oldHeight = field:GetWidth(), field:GetHeight()
    layout:SetSize(720, 200)
    dynamicEnvironment.Flush()
    field.scripts.OnSizeChanged(field, oldWidth, oldHeight)
    assert(
        root.entries[1].autoWidth,
        "stale dimensions must preserve the canvas's width ownership"
    )
    assert(
        dynamicEnvironment.QueueSize() == 0,
        "stale dimensions must not repeat settled layout work"
    )
end

-- Native search regions and live queries survive either embed load order.
for _, olderFirst in ipairs({ true, false }) do
    local searchEnvironment = newEnvironment()
    loadVersion(searchEnvironment, olderFirst)
    local searchLibrary = searchEnvironment.LibStub(MAJOR)
    local changes = 0
    local search = searchLibrary:CreateSearchBox(UIParent, {
        value = "saved",
        searchIconTexture = "Test\\Search.tga",
        clearIconTexture = "Test\\Close.tga",
        onChanged = function()
            changes = changes + 1
        end,
    })
    search:SetText("draft")
    search:SetFocus()
    local clearButton = search.clearButton
    local textChanged = search.baseScripts.OnTextChanged
    local hookCount = #search.scriptHooks.OnTextChanged
    loadVersion(searchEnvironment, not olderFirst)
    assert(searchEnvironment.LibStub(MAJOR) == searchLibrary)
    assert(search:GetValue() == "draft" and search:HasFocus() and changes == 1)
    assert(
        search.clearButton == clearButton
            and search.baseScripts.OnTextChanged == textChanged
    )
    assert(
        search.searchIcon.texture == "Test\\Search.tga"
            and clearButton.icon.texture == "Test\\Close.tga"
    )
    assert(#search.scriptHooks.OnTextChanged == hookCount)
    clearButton:Click()
    assert(search:GetValue() == "" and changes == 2 and not search:HasFocus())
end

print("LibModernSettings canvas upgrade and responsive layout tests passed")
dofile("tests/scroll_area.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_overflow.lua")(newEnvironment, loadVersion)
dofile("tests/scroll_area_wheel.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_resize.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_scroll_anchor.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_scroll_bookmark.lua")(newEnvironment, loadVersion)

dofile("tests/canvas_nested.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_grid.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_value_list.lua")(newEnvironment, loadVersion)
dofile("tests/canvas_input_alignment.lua")(newEnvironment, loadVersion)
