local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
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

local Layout = lib._canvasLayoutPrototype
local Flow = lib._canvasFlowPrototype
local Columns = lib._canvasColumnsPrototype

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

local function createContent(layout, options)
    local parent = layout.parent

    if not options.scrollable then
        local content = CreateFrame("Frame", nil, parent)

        content:SetSize(layout.contentWidth, layout.canvasHeight)
        content:SetPoint(
            "TOPLEFT",
            parent,
            "TOPLEFT",
            layout.style.paddingLeft,
            0
        )

        return content
    end

    local viewportMarginTop = options.viewportMarginTop or 0
    local viewportMarginBottom = options.viewportMarginBottom or 0

    assert(
        type(viewportMarginTop) == "number" and viewportMarginTop >= 0,
        "scroll viewport top margin must be non-negative"
    )
    assert(
        type(viewportMarginBottom) == "number"
            and viewportMarginBottom >= 0,
        "scroll viewport bottom margin must be non-negative"
    )
    assert(
        viewportMarginTop + viewportMarginBottom < layout.canvasHeight,
        "scroll viewport margins must leave a positive height"
    )

    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBox")

    scrollBox:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        layout.style.paddingLeft,
        -viewportMarginTop
    )
    scrollBox:SetPoint(
        "BOTTOMRIGHT",
        parent,
        "BOTTOMRIGHT",
        -(layout.style.scrollbarGap + layout.style.scrollbarWidth),
        viewportMarginBottom
    )

    local scrollBar = CreateFrame(
        "EventFrame",
        nil,
        parent,
        "MinimalScrollBar"
    )

    scrollBar:SetWidth(layout.style.scrollbarWidth)
    scrollBar:SetPoint(
        "TOPLEFT",
        scrollBox,
        "TOPRIGHT",
        layout.style.scrollbarGap,
        0
    )
    scrollBar:SetPoint(
        "BOTTOMLEFT",
        scrollBox,
        "BOTTOMRIGHT",
        layout.style.scrollbarGap,
        0
    )

    local content = CreateFrame("Frame", nil, scrollBox)

    content.scrollable = true
    content:SetSize(
        layout.contentWidth,
        options.contentHeight or layout.canvasHeight
    )

    local view = CreateScrollBoxLinearView()

    view:SetPanExtent(options.panExtent or 40)
    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, view)

    layout.scrollBox = scrollBox
    layout.scrollBar = scrollBar
    layout.viewportMarginTop = viewportMarginTop
    layout.viewportMarginBottom = viewportMarginBottom

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

function Layout:GetStyleValue(key)
    return self.style[key]
end

function Layout:GetScrollBox()
    return self.scrollBox
end

function Layout:GetScrollBar()
    return self.scrollBar
end

function Layout:_CreateFlow(x, width, cursor)
    return setmetatable({
        layout = self,
        parent = self.content,
        x = x,
        width = width,
        cursor = cursor,
    }, { __index = Flow })
end

function Layout:AddHeader(title, description, options)
    options = options or {}

    local titleOptions = shallowCopy(options.titleOptions)
    local hasDescription = description and description ~= ""

    titleOptions.fontObject = titleOptions.fontObject or GameFontNormalLarge
    titleOptions.text = title

    local titleText = self.rootFlow:AddText(titleOptions, {
        marginBottom = hasDescription
            and (options.titleMarginBottom or self.style.titleMarginBottom)
            or (options.marginBottom or self.style.headerMarginBottom),
    })
    local descriptionText

    if hasDescription then
        local descriptionOptions = shallowCopy(options.descriptionOptions)

        descriptionOptions.fontObject = descriptionOptions.fontObject
            or GameFontHighlight
        descriptionOptions.text = description
        descriptionText = self.rootFlow:AddText(descriptionOptions, {
            marginBottom = options.marginBottom
                or self.style.headerMarginBottom,
        })
    end

    return titleText, descriptionText
end

function Layout:Finalize(options)
    options = options or {}

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
    else
        self.content:SetHeight(math.max(self.canvasHeight, bottom))
    end

    return bottom
end

function Flow:GetWidth()
    return self.width
end

function Flow:GetCursor()
    return self.cursor
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

function Flow:AddFrame(frame, options)
    assert(frame, "layout frame is required")

    options = options or {}

    local x, width = self:_GetRect(options)
    local marginTop = options.marginTop or 0
    local marginBottom = options.marginBottom

    if marginBottom == nil then
        marginBottom = self.layout.style.rowGap
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

    frame:ClearAllPoints()
    frame:SetPoint(
        "TOPLEFT",
        self.parent,
        "TOPLEFT",
        x,
        -self.cursor
    )

    self.cursor = self.cursor
        + getFrameHeight(frame, options.height)
        + marginBottom

    return frame
end

function Flow:AddText(textOptions, placement)
    local _, width = self:_GetRect(placement)
    local options = shallowCopy(textOptions)

    options.width = options.width or width

    local text = lib:CreateText(self.parent, options)

    return self:AddFrame(text, placement)
end

function Flow:AddSection(text, options)
    options = shallowCopy(options)

    if options.marginTop == nil then
        options.marginTop = self.layout.style.sectionMarginTop
    end
    if options.marginBottom == nil then
        options.marginBottom = self.layout.style.sectionMarginBottom
    end

    return self:AddText({
        fontObject = options.fontObject or GameFontNormal,
        text = text,
    }, options)
end

function Flow:AddControl(controlType, controlOptions, placement)
    local _, width = self:_GetRect(placement)
    local options = shallowCopy(controlOptions)

    options.width = options.width or width

    local control = lib:CreateControl(controlType, self.parent, options)

    return self:AddFrame(control, placement)
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

    self.cursor = self.cursor + height
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

    self.cursor = self.cursor + marginTop

    local columnWidth = (width - ((count - 1) * columnGap)) / count

    assert(columnWidth > 0, "column layout produced a non-positive width")

    local columns = setmetatable({
        parentFlow = self,
        flows = {},
    }, { __index = Columns })

    for index = 1, count do
        local columnX = x
            + ((index - 1) * (columnWidth + columnGap))
        local flow = self.layout:_CreateFlow(
            columnX,
            columnWidth,
            self.cursor
        )

        columns.flows[index] = flow
        columns[index] = flow
    end

    columns.left = columns.flows[1]
    columns.right = columns.flows[2]

    return columns
end

function Columns:Finish(options)
    options = options or {}

    local marginBottom = options.marginBottom or 0

    assert(
        type(marginBottom) == "number" and marginBottom >= 0,
        "column region bottom margin must be non-negative"
    )

    local cursor = self.parentFlow.cursor

    for index = 1, #self.flows do
        cursor = math.max(cursor, self.flows[index].cursor)
    end

    self.parentFlow.cursor = cursor + marginBottom

    return self.parentFlow.cursor
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
    local contentWidth = canvasWidth
        - style.paddingLeft
        - style.scrollbarGap
        - style.scrollbarWidth

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
        type(style.scrollbarWidth) == "number" and style.scrollbarWidth > 0,
        "canvas scrollbar width must be positive"
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

    local layout = setmetatable({
        parent = parent,
        style = style,
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight,
        contentWidth = contentWidth,
    }, { __index = Layout })

    parent:SetSize(canvasWidth, canvasHeight)
    layout.content = createContent(layout, options)
    layout.rootFlow = layout:_CreateFlow(
        0,
        contentWidth,
        style.paddingTop
    )

    return layout
end
