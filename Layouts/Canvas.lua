local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Layouts/Canvas", MINOR) then
    return
end

local DEFAULT_STYLE = {
    canvasWidth = 716,
    canvasHeight = 633,
    paddingLeft = 8,
    scrollbarGap = 8,
    scrollbarWidth = 17,
    columnGap = 15,
    indent = 16,
    nestedColumnGap = 8,
    tablePadding = 8,
    paddingTop = 8,
    paddingBottom = 8,
    rowGap = 4,
    sectionMarginTop = 14,
    sectionMarginBottom = 8,
    titleMarginBottom = 10,
    headerMarginBottom = 24,
}

lib._canvasLayoutPrototype = lib._canvasLayoutPrototype or {}
lib._canvasFlowPrototype = lib._canvasFlowPrototype or {}
lib._canvasColumnsPrototype = lib._canvasColumnsPrototype or {}
lib._canvasGridPrototype = lib._canvasGridPrototype or {}
lib._canvasLayouts = lib._canvasLayouts or setmetatable({}, { __mode = "k" })

local Layout = lib._canvasLayoutPrototype
local Flow = lib._canvasFlowPrototype
local Columns = lib._canvasColumnsPrototype
local Grid = lib._canvasGridPrototype

local function defaultFont(role)
    if role == "title" or role == "titleWithDescription" then
        return GameFontNormalHuge
    elseif role == "section" then
        return GameFontNormalLarge
    elseif role == "description" then
        return GameFontHighlight
    end
end

local function shallowCopy(source)
    local copy = {}

    if source then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end

    return copy
end

local function createStyle(options)
    local style = {}
    local overrides = options.style or {}

    for key, value in pairs(DEFAULT_STYLE) do
        local override = overrides[key]

        if override == nil then
            override = options[key]
        end

        style[key] = override == nil and value or override
    end

    return style
end

local function createGeometry(style, options)
    if options.scrollArea ~= nil then
        assert(options.viewportMarginTop == nil and options.viewportMarginBottom == nil,
            "scrollArea owns viewport margins; use its borderInsets instead")

        local overrides = options.style or {}

        for _, key in ipairs({ "paddingLeft", "scrollbarGap", "scrollbarWidth", "paddingTop", "paddingBottom" }) do
            local headerPadding = not options.scrollable and (key == "paddingTop" or key == "paddingBottom")
            assert(headerPadding or (overrides[key] == nil and options[key] == nil),
                "scrollArea owns " .. key .. "; configure its contentPadding or scrollbar options instead")
        end

        local geometry = lib:_ResolveScrollAreaGeometry(options.scrollArea)
        style.paddingLeft = geometry.left
        style.scrollbarGap = geometry.scrollbarGap
        style.scrollbarWidth = geometry.scrollbarWidth

        if options.scrollable then
            style.paddingTop, style.paddingBottom = geometry.paddingTop, geometry.paddingBottom
        else
            -- Non-scrolling headers can share the horizontal content bounds
            -- without also adopting the scrolling body's vertical padding.
            geometry.top, geometry.bottom = 0, 0
            geometry.paddingTop, geometry.paddingBottom = style.paddingTop, style.paddingBottom
        end

        return geometry
    end

    local top = options.scrollable and (options.viewportMarginTop or 0) or 0
    local bottom = options.scrollable and (options.viewportMarginBottom or 0) or 0
    assert(type(top) == "number" and top >= 0 and top < math.huge,
        "scroll viewport top margin must be finite and non-negative")
    assert(type(bottom) == "number" and bottom >= 0 and bottom < math.huge,
        "scroll viewport bottom margin must be finite and non-negative")

    return {
        left = style.paddingLeft,
        right = style.scrollbarGap + style.scrollbarWidth,
        top = top,
        bottom = bottom,
        paddingTop = style.paddingTop,
        paddingBottom = style.paddingBottom,
        scrollbarRight = 0,
        scrollbarWidth = style.scrollbarWidth,
        scrollbarGap = style.scrollbarGap,
    }
end

local function getMeasuredDimension(frame, methodName)
    if not frame then
        return
    end

    local value = frame[methodName](frame)

    if value and value > 0 then
        return value
    end
end

local function getFrameHeight(frame, explicitHeight)
    if explicitHeight then
        return explicitHeight
    end

    local height = frame:GetHeight()

    if height and height > 0 then
        return height
    end

    if frame.GetStringHeight then
        height = frame:GetStringHeight()
    end

    assert(height and height > 0, "layout frames require a positive height")

    return height
end

-- Native linear placement detaches children on every FullUpdate. This view
-- retains one frame with a width owned by Layout:SetSize, while native code
-- still owns extent calculation, scroll offsets and scrollbar handling.
local function layoutScrollContent(view, scrollBox)
    local content = view:GetFrames()[1]
    if content then
        lib:_SetLayoutPoint(content, "TOPLEFT", scrollBox:GetScrollTarget(), "TOPLEFT", 0, 0)
    end
end

local function createContent(layout, options)
    local parent = layout.parent

    if not options.scrollable then
        local content = CreateFrame("Frame", nil, parent)

        content:SetSize(layout.contentWidth, layout.canvasHeight)
        content:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            layout.geometry.left,
            0
        )

        return content
    end

    local area = lib:_CreateScrollArea(parent, layout.geometry, { kind = "canvas" })
    local scrollBox = area:GetScrollBox()

    local content = CreateFrame("Frame", nil, scrollBox)

    content.scrollable = true
    content:SetSize(
        layout.contentWidth,
        options.contentHeight or layout.canvasHeight
    )

    local view = CreateScrollBoxLinearView()

    view.Layout = layoutScrollContent
    view:SetPanExtent(options.panExtent or 40)
    area:Init(view)

    layout.scrollArea = area
    layout.scrollBox = scrollBox
    layout.scrollBar = area:GetScrollBar()
    layout.viewportMarginTop = layout.geometry.top
    layout.viewportMarginBottom = layout.geometry.bottom

    return content
end

function Layout:GetContent()
    return self.content
end

function Layout:GetRootFlow()
    return self.rootFlow
end

function Layout:GetCanvasWidth()
    return self.canvasWidth
end

function Layout:GetCanvasHeight()
    return self.canvasHeight
end

function Layout:GetContentWidth()
    return self.contentWidth
end

function Layout:GetContentInsets()
    local geometry = self.geometry
    local paddingBottom = self.finalizeOptions and self.finalizeOptions.paddingBottom
    if paddingBottom == nil then paddingBottom = self.style.paddingBottom end

    return geometry.left, geometry.right,
        geometry.top + self.style.paddingTop, geometry.bottom + paddingBottom
end

function Layout:GetStyleValue(key)
    return self.style[key]
end

function Layout:GetScrollBox()
    return self.scrollBox
end

function Layout:GetScrollBar()
    return self.scrollBar
end

function Layout:SetSize(width, height)
    assert(type(width) == "number" and width > 0 and width < math.huge,
        "canvas width must be a positive finite number")
    assert(type(height) == "number" and height > 0 and height < math.huge,
        "canvas height must be a positive finite number")

    local contentWidth = width - self.geometry.left - self.geometry.right
    assert(contentWidth > 0, "canvas insets must leave positive content width")
    assert(not self.scrollBox or height > self.viewportMarginTop + self.viewportMarginBottom,
        "scroll viewport margins must leave a positive height")

    local widthChanged = not lib:_LayoutSizeMatches(width, self.canvasWidth)
    local heightChanged = not lib:_LayoutSizeMatches(height, self.canvasHeight)
    if not widthChanged and not heightChanged then
        return
    end

    self.canvasWidth, self.canvasHeight = width, height
    self.contentWidth = contentWidth
    self.rootFlow.width = contentWidth
    -- Do not write an unchanged axis back to a content-sized parent, or feed
    -- resolved geometry back through its own OnSizeChanged notification.
    local resizeWidth = widthChanged and not lib:_LayoutSizeMatches(self.parent:GetWidth(), width)
    local resizeHeight = heightChanged and not lib:_LayoutSizeMatches(self.parent:GetHeight(), height)
    if resizeWidth and resizeHeight then
        self.parent:SetSize(width, height)
    elseif resizeWidth then
        self.parent:SetWidth(width)
    elseif resizeHeight then
        self.parent:SetHeight(height)
    end
    if not lib:_LayoutSizeMatches(self.content:GetWidth(), contentWidth) then
        self.content:SetWidth(contentWidth)
    end
    self:RequestLayout()
end

function Layout:_CreateFlow(x, width, cursor)
    return setmetatable({
        layout = self,
        parent = self.content,
        x = x,
        width = width,
        cursor = cursor,
        entries = {},
    }, { __index = Flow })
end

function Layout:AddHeader(title, description, options)
    options = options or {}

    local titleOptions = shallowCopy(options.titleOptions)
    local hasDescription = description and description ~= ""

    titleOptions.text = title

    local titleMarginBottom = options.marginBottom
    if hasDescription then
        titleMarginBottom = options.titleMarginBottom
    end
    local titleText = self.rootFlow:_AddText(titleOptions, {
        marginBottom = titleMarginBottom,
    }, hasDescription and "titleWithDescription" or "title")
    local descriptionText

    if hasDescription then
        local descriptionOptions = shallowCopy(options.descriptionOptions)

        descriptionOptions.text = description
        descriptionText = self.rootFlow:_AddText(descriptionOptions, {
            marginBottom = options.marginBottom,
        }, "description")
    end

    return titleText, descriptionText
end

function Layout:Finalize(options)
    options = options or {}
    self.finalizeOptions = shallowCopy(options)
    self.finalized = true
    return self:RefreshLayout()
end

-- Replays geometry only: controls, values, handlers and focus stay intact.
function Layout:RefreshLayout()
    if self.refreshing or not self.finalized then
        return
    end

    self.refreshing = true
    self.dirty = nil
    if self.rootFlow.entries then
        self.rootFlow:_RefreshLayout(self.style.paddingTop)
    end
    local options = self.finalizeOptions

    local paddingBottom = options.paddingBottom
        or self.style.paddingBottom

    assert(
        type(paddingBottom) == "number" and paddingBottom >= 0,
        "layout bottom padding must be non-negative"
    )

    local bottom = self.rootFlow.cursor
        + paddingBottom

    if options.contentHeight then
        bottom = math.max(bottom, options.contentHeight)
    end

    if self.scrollBox then
        local viewportHeight = self.canvasHeight
            - self.viewportMarginTop
            - self.viewportMarginBottom
        local contentHeight = math.max(viewportHeight, bottom)

        self.content:SetHeight(contentHeight)
        self.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
        self:_RestoreScrollAnchor()
    else
        self.content:SetHeight(math.max(self.canvasHeight, bottom))
    end

    self.refreshing = nil
    return bottom
end

function Layout:RequestLayout()
    if self.refreshing or not self.rootFlow.entries then
        return
    end
    self.dirty = true
    if not self.finalized or self.refreshPending or not self.parent:IsVisible() then
        return
    end

    self.refreshPending = true
    C_Timer.After(0, function()
        self.refreshPending = nil
        if self.dirty and self.parent:IsVisible() then
            self:RefreshLayout()
        end
    end)
end

function Layout:_ScrollControlIntoView(control)
    if not self.scrollBox then
        return
    end

    local extent = self.scrollBox:GetVisibleExtent()
    local frame = control
    local ancestor = control:GetParent()
    while ancestor and ancestor ~= self.content do
        if ancestor._libModernSettingsControlType == "field" then
            local height = ancestor:GetHeight() * ancestor:GetEffectiveScale() / self.content:GetEffectiveScale()
            -- Keep the label visible when it fits, but reveal the focused child
            -- when a wrapping composite field is taller than the viewport.
            if height <= extent then
                frame = ancestor
            end
        end
        ancestor = ancestor:GetParent()
    end
    if not ancestor then
        return
    end

    self:SetScrollAnchor(nil)
    local contentTop = self.content:GetTop()
    local frameTop = frame:GetTop()
    if not contentTop or not frameTop then
        return
    end

    local scale = frame:GetEffectiveScale() / self.content:GetEffectiveScale()
    local top = contentTop - frameTop * scale
    local height = frame:GetHeight() * scale
    local bottom = top + height
    local offset = self.scrollBox:GetDerivedScrollOffset()
    if top < offset or height > extent then
        self.scrollBox:ScrollToOffset(top, ScrollBoxConstants.NoScrollInterpolation)
    elseif bottom > offset + extent then
        self.scrollBox:ScrollToOffset(bottom - extent, ScrollBoxConstants.NoScrollInterpolation)
    end
end

function Flow:GetWidth()
    return self.width
end

function Flow:GetCursor()
    return self.cursor
end

local function isFlowShown(flow)
    return flow.shown ~= false and (not flow.parentFlow or isFlowShown(flow.parentFlow))
end

local function setFlowFramesShown(flow, shown)
    shown = shown and flow.shown ~= false

    for _, entry in ipairs(flow.entries) do
        if entry.columns or entry.grid then
            for _, child in ipairs((entry.columns or entry.grid).flows) do
                setFlowFramesShown(child, shown)
            end
        elseif entry.group then
            setFlowFramesShown(entry.group, shown)
        elseif entry.frame then
            entry.frame:SetShown(shown)
        end
    end
end

function Flow:SetShown(shown)
    assert(type(shown) == "boolean", "flow visibility must be boolean")
    assert(self.entries, "flow visibility requires a tracked canvas")

    if (self.shown ~= false) == shown then
        return
    end

    self.shown = shown
    setFlowFramesShown(self, isFlowShown(self))
    self.layout:RequestLayout()
end

function Flow:_GetRect(options)
    options = options or {}

    local indent = options.indent or 0

    assert(type(indent) == "number" and indent >= 0, "indent must be non-negative")

    local indentWidth = indent * self.layout.style.indent
    local x = self.x + indentWidth
    local width = self.width - indentWidth
    local splitCount = options.splitCount

    if splitCount then
        local splitIndex = options.splitIndex or 1
        local columnGap = options.columnGap
            or self.layout.style.nestedColumnGap

        assert(
            type(splitCount) == "number"
                and splitCount >= 1
                and splitCount % 1 == 0,
            "splitCount must be a positive integer"
        )
        assert(
            type(splitIndex) == "number"
                and splitIndex >= 1
                and splitIndex <= splitCount,
            "splitIndex must be within splitCount"
        )
        assert(splitIndex % 1 == 0, "splitIndex must be an integer")
        assert(
            type(columnGap) == "number" and columnGap >= 0,
            "split column gap must be non-negative"
        )

        width = (width - ((splitCount - 1) * columnGap)) / splitCount
        x = x + ((splitIndex - 1) * (width + columnGap))
    end

    assert(width > 0, "layout placement produced a non-positive width")

    return x, width
end

function Flow:_PlaceFrame(frame, options, role)
    assert(frame, "layout frame is required")

    options = options or {}
    assert(options.onLayout == nil or type(options.onLayout) == "function",
        "frame onLayout must be a function")

    local x, width = self:_GetRect(options)
    local marginTop = options.marginTop
    local marginBottom = options.marginBottom

    if marginTop == nil then
        marginTop = role == "section" and self.layout.style.sectionMarginTop or 0
    end
    if marginBottom == nil then
        if role == "section" then
            marginBottom = self.layout.style.sectionMarginBottom
        elseif role == "titleWithDescription" then
            marginBottom = self.layout.style.titleMarginBottom
        elseif role == "title" or role == "description" then
            marginBottom = self.layout.style.headerMarginBottom
        else
            marginBottom = self.layout.style.rowGap
        end
    end

    assert(
        type(marginTop) == "number" and marginTop >= 0,
        "layout top margin must be non-negative"
    )
    assert(
        type(marginBottom) == "number" and marginBottom >= 0,
        "layout bottom margin must be non-negative"
    )

    self.cursor = self.cursor + marginTop

    if options.fillWidth then
        frame:SetWidth(width)
    end

    lib:_SetLayoutPoint(frame,
        "TOPLEFT",
        self.parent,
        "TOPLEFT",
        x,
        -self.cursor
    )

    if options.onLayout and self.layout.refreshing then
        -- Resolve nested content after assigning its width and before measuring
        -- its height. Native size notifications may arrive after this pass.
        options.onLayout(frame)
    end

    self.cursor = self.cursor
        + getFrameHeight(frame, options.height)
        + marginBottom

    return frame
end

local function watchEntrySize(entry, layout)
    local frame = entry.frame
    if not frame:HasScript("OnSizeChanged") then
        return -- FontStrings are measured during layout and visible OnShow.
    end
    frame:HookScript("OnSizeChanged", function()
        local width, height = frame:GetWidth(), frame:GetHeight()
        if entry.autoWidth and not lib:_LayoutSizeMatches(width, entry.allocatedWidth)
            and not layout.refreshing
            and not frame._libModernSettingsUpdatingLayout
            and not frame._libModernSettingsRefreshingAppearance then
            entry.autoWidth = nil
        end
        if not lib:_LayoutSizeMatches(width, entry.width)
            or not lib:_LayoutSizeMatches(height, entry.height) then
            entry.width, entry.height = width, height
            layout:RequestLayout()
        end
    end)
end

function Flow:_AddFrame(frame, options, role)
    if not self.entries then
        return self:_PlaceFrame(frame, options, role)
    end
    local entry = { frame = frame, placement = shallowCopy(options), role = role }
    self.entries[#self.entries + 1] = entry
    self:_PlaceFrame(frame, entry.placement, role)
    entry.width, entry.height = frame:GetWidth(), frame:GetHeight()
    entry.allocatedWidth = entry.width
    watchEntrySize(entry, self.layout)

    if not isFlowShown(self) then
        frame:Hide()
    end

    return frame
end

function Flow:AddFrame(frame, options)
    return self:_AddFrame(frame, options)
end

function Flow:_AddText(textOptions, placement, role)
    local _, width = self:_GetRect(placement)
    local options = shallowCopy(textOptions)

    options.width = options.width or width
    options.fontObject = options.fontObject or defaultFont(role)

    local text = lib:CreateText(self.parent, options)

    self:_AddFrame(text, placement, role)
    if self.entries then
        self.entries[#self.entries].autoWidth = not (textOptions and textOptions.width)
    end
    if self.entries and role and not (textOptions and textOptions.fontObject) then
        local entry = self.entries[#self.entries]
        entry.defaultFont = true
        lib:_ApplyDefaultFont(text, defaultFont(role))
    end
    return text
end

function Flow:AddText(textOptions, placement)
    return self:_AddText(textOptions, placement)
end

function Flow:AddSection(text, options)
    options = shallowCopy(options)

    return self:_AddText({
        fontObject = options.fontObject,
        text = text,
    }, options, "section")
end

function Flow:AddControl(controlType, controlOptions, placement)
    local _, width = self:_GetRect(placement)
    local options = shallowCopy(controlOptions)

    options.width = options.width or width

    local control = lib:CreateControl(controlType, self.parent, options)

    self:AddFrame(control, placement)
    if self.entries then
        self.entries[#self.entries].autoWidth = not (controlOptions and controlOptions.width)
    end
    return control
end

function Flow:AddCustom(height, options)
    assert(type(height) == "number" and height > 0, "height must be positive")

    local _, width = self:_GetRect(options)
    local frame = CreateFrame("Frame", nil, self.parent)

    frame:SetSize(width, height)

    local placement = shallowCopy(options)

    placement.height = height

    return self:AddFrame(frame, placement)
end

function Flow:AddSpacer(height)
    assert(
        type(height) == "number" and height >= 0,
        "spacer height must be non-negative"
    )

    if self.entries then
        self.entries[#self.entries + 1] = { spacer = height }
    end
    self.cursor = self.cursor + height
end

function Flow:BeginGroup(options)
    options = options or {}
    assert(type(options) == "table", "group options must be a table")
    assert(self.entries, "groups require a tracked canvas")

    local x, width = self:_GetRect(options)
    local marginTop = options.marginTop or 0
    assert(type(marginTop) == "number" and marginTop >= 0 and marginTop < math.huge,
        "group top margin must be a non-negative finite number")

    local group = self.layout:_CreateFlow(x, width, self.cursor + marginTop)
    group.parentFlow = self
    group.groupOptions = shallowCopy(options)
    self.entries[#self.entries + 1] = { group = group }
    return group
end

function Flow:Finish(options)
    assert(self.groupOptions, "Finish requires a group flow")
    options = options or {}
    assert(type(options) == "table", "group finish options must be a table")

    local marginBottom = options.marginBottom or 0
    assert(type(marginBottom) == "number" and marginBottom >= 0 and marginBottom < math.huge,
        "group bottom margin must be a non-negative finite number")
    self.finishOptions = shallowCopy(options)

    if self.shown ~= false then
        self.parentFlow.cursor = self.cursor + marginBottom
    end

    self.layout:RequestLayout()
    return self.parentFlow.cursor
end

function Flow:_RefreshGroup()
    if self.shown == false then
        return
    end

    local parentFlow = self.parentFlow
    self.x, self.width = parentFlow:_GetRect(self.groupOptions)
    self:_RefreshLayout(parentFlow.cursor + (self.groupOptions.marginTop or 0))

    if self.finishOptions then
        self:Finish(self.finishOptions)
    end
end

function Flow:BeginColumns(options)
    options = options or {}

    local x, width = self:_GetRect(options)
    local count = options.count or 2
    local columnGap = options.columnGap or self.layout.style.columnGap
    local marginTop = options.marginTop or 0

    assert(
        type(count) == "number" and count >= 2 and count % 1 == 0,
        "column count must be an integer of at least two"
    )
    assert(
        type(columnGap) == "number" and columnGap >= 0,
        "column gap must be non-negative"
    )
    assert(
        type(marginTop) == "number" and marginTop >= 0,
        "column region top margin must be non-negative"
    )
    assert(options.minColumnWidth == nil
        or (type(options.minColumnWidth) == "number"
            and options.minColumnWidth > 0 and options.minColumnWidth < math.huge),
        "minimum column width must be a positive finite number or nil")
    assert(options.verticalAlign == nil or options.verticalAlign == "top"
        or options.verticalAlign == "center" or options.verticalAlign == "bottom",
        "column vertical alignment must be 'top', 'center', or 'bottom'")

    self.cursor = self.cursor + marginTop

    local columnWidth = (width - ((count - 1) * columnGap)) / count

    assert(columnWidth > 0, "column layout produced a non-positive width")

    local columns = setmetatable({
        parentFlow = self,
        flows = {},
        options = shallowCopy(options),
    }, { __index = Columns })
    if self.entries then
        self.entries[#self.entries + 1] = { columns = columns }
    end

    for index = 1, count do
        local columnX = x
            + ((index - 1) * (columnWidth + columnGap))
        local flow = self.layout:_CreateFlow(
            columnX,
            columnWidth,
            self.cursor
        )
        flow.parentFlow = self

        columns.flows[index] = flow
        columns[index] = flow
    end

    columns.left = columns.flows[1]
    columns.right = columns.flows[2]

    return columns
end

function Columns:Finish(options)
    options = options or {}
    self.finishOptions = shallowCopy(options)

    local marginBottom = options.marginBottom or 0

    assert(
        type(marginBottom) == "number" and marginBottom >= 0,
        "column region bottom margin must be non-negative"
    )

    local cursor = self.parentFlow.cursor

    for index = 1, #self.flows do
        if self.flows[index].shown ~= false then
            cursor = math.max(cursor, self.flows[index].cursor)
        end
    end

    self.parentFlow.cursor = cursor + marginBottom

    return self.parentFlow.cursor
end

function Columns:_RefreshLayout()
    local options = self.options
    local parentFlow = self.parentFlow
    local x, width = parentFlow:_GetRect(options)
    local gap = options.columnGap or parentFlow.layout.style.columnGap
    local count = 0

    for _, flow in ipairs(self.flows) do
        flow.parentFlow = parentFlow

        if flow.shown ~= false then
            count = count + 1
        end
    end

    if count == 0 then
        return
    end

    local columnWidth = (width - (count - 1) * gap) / count
    local stacked = options.minColumnWidth and columnWidth < options.minColumnWidth
    parentFlow.cursor = parentFlow.cursor + (options.marginTop or 0)
    local cursor = parentFlow.cursor
    local visibleIndex = 0
    local bottom = cursor

    for _, flow in ipairs(self.flows) do
        if flow.shown ~= false then
            flow.x = stacked and x or x + visibleIndex * (columnWidth + gap)
            flow.width = stacked and width or columnWidth
            flow:_RefreshLayout(cursor)
            bottom = math.max(bottom, flow.cursor)
            visibleIndex = visibleIndex + 1

            if stacked then
                cursor = flow.cursor
            end
        end
    end

    -- Measure at the final column widths first, then align shorter columns.
    -- Stacked flows keep their normal sequential placement.
    if not stacked and options.verticalAlign and options.verticalAlign ~= "top" then
        for _, flow in ipairs(self.flows) do
            if flow.shown ~= false then
                local offset = bottom - flow.cursor

                if options.verticalAlign == "center" then
                    offset = offset / 2
                end

                if offset > 0 then
                    flow:_RefreshLayout(cursor + offset)
                end
            end
        end
    end

    if self.finishOptions then
        self:Finish(self.finishOptions)
    end
end

-- Unlike independent column flows, grid cells wrap in declaration order.
-- Controls remain in their original flows as the available column count changes.
function Flow:BeginGrid(options)
    options = options or {}
    assert(type(options) == "table", "grid options must be a table")
    assert(self.entries, "grids require a tracked canvas")
    assert(type(options.minColumnWidth) == "number"
        and options.minColumnWidth > 0 and options.minColumnWidth < math.huge,
        "grid minimum column width must be a positive finite number")
    assert(options.maxColumns == nil or (type(options.maxColumns) == "number"
        and options.maxColumns >= 1 and options.maxColumns < math.huge and options.maxColumns % 1 == 0),
        "grid maximum columns must be a positive integer or nil")
    for _, key in ipairs({ "columnGap", "rowGap", "marginTop" }) do
        assert(options[key] == nil or (type(options[key]) == "number"
            and options[key] >= 0 and options[key] < math.huge),
            "grid " .. key .. " must be a non-negative finite number or nil")
    end
    self:_GetRect(options)
    local grid = setmetatable({
        parentFlow = self,
        flows = {},
        options = shallowCopy(options),
    }, { __index = Grid })
    self.entries[#self.entries + 1] = { grid = grid }
    return grid
end

function Grid:AddCell()
    local parent = self.parentFlow
    local x, width = parent:_GetRect(self.options)
    local flow = parent.layout:_CreateFlow(x, width, parent.cursor)
    flow.parentFlow = parent
    self.flows[#self.flows + 1] = flow
    parent.layout:RequestLayout()
    return flow
end

function Grid:Finish(options)
    options = options or {}
    assert(type(options) == "table", "grid finish options must be a table")
    local marginBottom = options.marginBottom or 0
    assert(type(marginBottom) == "number" and marginBottom >= 0 and marginBottom < math.huge,
        "grid bottom margin must be a non-negative finite number")
    self.finishOptions = shallowCopy(options)
    self.parentFlow.layout:RequestLayout()
end

function Grid:_RefreshLayout()
    local options = self.options
    local parent = self.parentFlow
    local x, width = parent:_GetRect(options)
    local gap = options.columnGap or parent.layout.style.columnGap
    local count = 0
    for _, flow in ipairs(self.flows) do
        if flow.shown ~= false then
            count = count + 1
        end
    end
    if count == 0 then
        return
    end

    local columns = math.max(1, math.floor((width + gap) / (options.minColumnWidth + gap)))
    columns = math.min(columns, count, options.maxColumns or columns)
    local cellWidth = (width - (columns - 1) * gap) / columns
    local rowStart = parent.cursor + (options.marginTop or 0)
    local rowBottom = rowStart
    local column = 0
    for _, flow in ipairs(self.flows) do
        if flow.shown ~= false then
            if column == columns then
                rowStart = rowBottom + (options.rowGap or 0)
                column = 0
            end
            flow.x, flow.width = x + column * (cellWidth + gap), cellWidth
            flow:_RefreshLayout(rowStart)
            rowBottom = math.max(rowBottom, flow.cursor)
            column = column + 1
        end
    end
    parent.cursor = rowBottom + (self.finishOptions and self.finishOptions.marginBottom or 0)
end

function Flow:_RefreshLayout(cursor)
    self.cursor = cursor

    if not isFlowShown(self) then
        return
    end

    for _, entry in ipairs(self.entries) do
        if entry.columns then
            entry.columns:_RefreshLayout()
        elseif entry.grid then
            entry.grid:_RefreshLayout()
        elseif entry.group then
            entry.group:_RefreshGroup()
        elseif entry.spacer then
            self.cursor = self.cursor + entry.spacer
        else
            local frame = entry.frame
            if entry.autoWidth and not frame:HasScript("OnSizeChanged")
                and not lib:_LayoutSizeMatches(frame:GetWidth(), entry.width) then
                entry.autoWidth = nil
            end
            if entry.defaultFont then
                lib:_ApplyDefaultFont(frame, defaultFont(entry.role))
            end
            if entry.autoWidth then
                local _, width = self:_GetRect(entry.placement)
                if frame.SetControlWidth then
                    frame:SetControlWidth(width)
                elseif frame._libModernSettingsAppearanceOptions then
                    local options = frame._libModernSettingsAppearanceOptions
                    if not lib:_LayoutSizeMatches(width, options.width) then
                        options.width = width
                        lib:_RefreshControlAppearance(frame)
                    end
                elseif not frame._libModernSettingsControlType then
                    frame:SetWidth(width)
                end
            end
            if frame._libModernSettingsControlType and frame.RefreshLayout then
                frame:RefreshLayout()
            end
            self:_PlaceFrame(frame, entry.placement, entry.role)
            entry.width, entry.height = frame:GetWidth(), frame:GetHeight()
            entry.allocatedWidth = entry.width
        end
    end
end

function lib:CreateCanvasLayout(parent, options)
    assert(parent, "canvas layout parent is required")

    options = options or {}
    assert(type(options) == "table", "canvas layout options must be a table")
    assert(
        options.style == nil or type(options.style) == "table",
        "canvas layout style must be a table"
    )

    local style = createStyle(options)
    local measurementFrame = options.measurementFrame
    local canvasWidth = options.width
        or getMeasuredDimension(measurementFrame, "GetWidth")
        or getMeasuredDimension(parent, "GetWidth")
        or style.canvasWidth
    local canvasHeight = options.height
        or getMeasuredDimension(measurementFrame, "GetHeight")
        or getMeasuredDimension(parent, "GetHeight")
        or style.canvasHeight
    local geometry = createGeometry(style, options)
    local contentWidth = canvasWidth - geometry.left - geometry.right

    assert(
        type(canvasWidth) == "number" and canvasWidth > 0,
        "canvas layout width must be positive"
    )
    assert(
        type(canvasHeight) == "number" and canvasHeight > 0,
        "canvas layout height must be positive"
    )
    assert(
        type(style.paddingLeft) == "number" and style.paddingLeft >= 0,
        "canvas left padding must be non-negative"
    )
    assert(
        type(style.scrollbarGap) == "number" and style.scrollbarGap >= 0,
        "canvas scrollbar gap must be non-negative"
    )
    assert(
        type(style.scrollbarWidth) == "number" and style.scrollbarWidth >= 0
            and (not options.scrollable or style.scrollbarWidth > 0),
        "canvas scrollbar width must be non-negative, and positive for scrolling layouts"
    )
    assert(
        type(style.columnGap) == "number" and style.columnGap >= 0,
        "canvas column gap must be non-negative"
    )
    assert(
        type(style.indent) == "number" and style.indent >= 0,
        "canvas indent must be non-negative"
    )
    assert(
        type(style.nestedColumnGap) == "number"
            and style.nestedColumnGap >= 0,
        "canvas nested column gap must be non-negative"
    )
    assert(
        type(style.tablePadding) == "number" and style.tablePadding >= 0,
        "canvas table padding must be non-negative"
    )
    assert(
        type(style.paddingTop) == "number" and style.paddingTop >= 0,
        "canvas top padding must be non-negative"
    )
    assert(
        type(style.paddingBottom) == "number" and style.paddingBottom >= 0,
        "canvas bottom padding must be non-negative"
    )
    assert(
        type(style.rowGap) == "number" and style.rowGap >= 0,
        "canvas row gap must be non-negative"
    )
    assert(
        type(style.sectionMarginTop) == "number"
            and style.sectionMarginTop >= 0,
        "canvas section top margin must be non-negative"
    )
    assert(
        type(style.sectionMarginBottom) == "number"
            and style.sectionMarginBottom >= 0,
        "canvas section bottom margin must be non-negative"
    )
    assert(
        type(style.titleMarginBottom) == "number"
            and style.titleMarginBottom >= 0,
        "canvas title bottom margin must be non-negative"
    )
    assert(
        type(style.headerMarginBottom) == "number"
            and style.headerMarginBottom >= 0,
        "canvas header bottom margin must be non-negative"
    )
    assert(contentWidth > 0, "canvas layout content width must be positive")
    assert(canvasHeight > geometry.top + geometry.bottom,
        "scroll viewport margins must leave a positive height")

    local layout = setmetatable({
        parent = parent,
        style = style,
        geometry = geometry,
        scrollAreaOptions = options.scrollArea and lib:_CopyScrollAreaOptions(options.scrollArea),
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight,
        contentWidth = contentWidth,
        styleOverrides = {},
    }, { __index = Layout })

    for key in pairs(DEFAULT_STYLE) do
        local value = options.style and options.style[key]
        if value == nil then
            value = options[key]
        end
        layout.styleOverrides[key] = value
    end

    parent:SetSize(canvasWidth, canvasHeight)
    layout.content = createContent(layout, options)
    layout.content._libModernSettingsCanvasLayout = layout
    layout.rootFlow = layout:_CreateFlow(
        0,
        contentWidth,
        style.paddingTop
    )

    lib._canvasLayouts[layout] = true
    parent:HookScript("OnShow", function()
        -- Font metrics can settle only after the canvas is visible.
        layout:RequestLayout()
    end)

    return layout
end

-- Tracked canvases keep their original option intent and placement records.
-- Older, untracked canvases cannot be reconstructed safely from screen pixels.
for layout in pairs(lib._canvasLayouts) do
    layout.content._libModernSettingsCanvasLayout = layout
    local options = {
        style = layout.styleOverrides,
        scrollable = layout.scrollBox ~= nil,
        scrollArea = layout.scrollAreaOptions,
    }

    if not options.scrollArea then
        options.viewportMarginTop = layout.viewportMarginTop
        options.viewportMarginBottom = layout.viewportMarginBottom
    end

    layout.style = createStyle(options)
    layout.geometry = createGeometry(layout.style, options)
    layout.contentWidth = layout.canvasWidth - layout.geometry.left - layout.geometry.right
    layout.content:SetWidth(layout.contentWidth)
    layout.rootFlow.width = layout.contentWidth

    if layout.scrollBox then
        layout.viewportMarginTop = layout.geometry.top
        layout.viewportMarginBottom = layout.geometry.bottom
        layout.scrollBox:GetView().Layout = layoutScrollContent

        if layout.scrollArea then
            layout.scrollArea:_ApplyGeometry(layout.geometry)
        else
            layout.scrollArea = lib:_CreateScrollArea(layout.parent, layout.geometry, {
                kind = "canvas",
                scrollBox = layout.scrollBox,
                scrollBar = layout.scrollBar,
            })
        end
    else
        layout.content:ClearAllPoints()
        layout.content:SetPoint("TOPLEFT", layout.parent, "TOPLEFT", layout.geometry.left, 0)
    end

    layout:RequestLayout()
end
