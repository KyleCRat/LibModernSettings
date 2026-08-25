local MAJOR, MINOR = "LibModernSettings-1.0", 3
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

local DEFAULT_PADDING = 8
local DEFAULT_HEADER_HEIGHT = 32
local DEFAULT_ROW_HEIGHT = 36
local DEFAULT_STRIPE_COLOR = { 1, 1, 1, 0.035 }

lib._settingsTablePrototype = lib._settingsTablePrototype or {}
lib._settingsTableRowPrototype = lib._settingsTableRowPrototype or {}

local TableView = lib._settingsTablePrototype
local TableRow = lib._settingsTableRowPrototype

local function shallowCopy(source)
    local copy = {}

    if source then
        for key, value in pairs(source) do
            copy[key] = value
        end
    end

    return copy
end

local function createCells(parent, columns, padding, height)
    local cells = {}
    local x = padding

    for index = 1, #columns do
        local column = columns[index]
        local cell = CreateFrame("Frame", nil, parent)

        cell:SetSize(column.resolvedWidth, height)
        cell:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
        cells[index] = cell
        cells[column.key] = cell
        x = x + column.resolvedWidth
    end

    return cells
end

local function resolveColumns(columns, innerWidth)
    local resolved = {}
    local fixedWidth = 0
    local totalWeight = 0
    local keys = {}

    assert(type(columns) == "table" and #columns > 0, "table columns are required")

    for index = 1, #columns do
        local source = columns[index]

        assert(type(source) == "table", "table columns must be tables")
        assert(
            type(source.key) == "string" and source.key ~= "",
            "table column keys must be non-empty strings"
        )
        assert(not keys[source.key], "table column keys must be unique")
        assert(
            source.width or source.weight,
            "table columns require width or weight"
        )
        assert(
            not (source.width and source.weight),
            "table columns cannot use both width and weight"
        )

        keys[source.key] = true

        local column = shallowCopy(source)

        if column.width then
            assert(column.width > 0, "table column widths must be positive")
            fixedWidth = fixedWidth + column.width
        else
            assert(column.weight > 0, "table column weights must be positive")
            totalWeight = totalWeight + column.weight
        end

        resolved[index] = column
    end

    local remainingWidth = innerWidth - fixedWidth

    assert(remainingWidth >= 0, "fixed table columns exceed the inner width")
    assert(
        totalWeight > 0 or remainingWidth == 0,
        "table columns leave unassigned width"
    )
    assert(
        totalWeight == 0 or remainingWidth > 0,
        "weighted table columns require remaining width"
    )

    for index = 1, #resolved do
        local column = resolved[index]

        column.resolvedWidth = column.width
            or (remainingWidth * column.weight / totalWeight)
    end

    return resolved
end

local function addTextToCell(cell, column, text, options)
    options = shallowCopy(options)
    options.text = text
    options.width = cell:GetWidth()
    options.height = cell:GetHeight()
    options.justifyH = options.justifyH or column.justifyH or "CENTER"
    options.justifyV = options.justifyV or column.justifyV or "MIDDLE"

    local fontString = lib:CreateText(cell, options)

    fontString:SetAllPoints(cell)

    return fontString
end

function TableView:GetFrame()
    return self.frame
end

function TableView:GetHeaderCell(columnKey)
    local cell = self.headerCells[columnKey]

    assert(cell, "unknown table column " .. tostring(columnKey))

    return cell
end

function TableView:GetColumnWidth(columnKey)
    local column = self.columnsByKey[columnKey]

    assert(column, "unknown table column " .. tostring(columnKey))

    return column.resolvedWidth
end

function TableView:AddHeaderText(columnKey, text, options)
    local column = self.columnsByKey[columnKey]

    assert(column, "unknown table column " .. tostring(columnKey))

    options = shallowCopy(options)
    options.fontObject = options.fontObject or GameFontNormalSmall

    return addTextToCell(
        self.headerCells[columnKey],
        column,
        text,
        options
    )
end

function TableView:AddRow(options)
    options = options or {}

    local index = #self.rows + 1
    local rowHeight = options.height or self.rowHeight

    assert(
        type(rowHeight) == "number" and rowHeight > 0,
        "settings table row height must be positive"
    )

    local rowFrame = CreateFrame("Frame", nil, self.frame)

    rowFrame:SetSize(self.width, rowHeight)
    rowFrame:SetPoint(
        "TOPLEFT",
        self.frame,
        "TOPLEFT",
        0,
        -(self.headerHeight + self.rowsHeight)
    )

    if options.striped ~= false and index % 2 == 0 then
        local color = options.stripeColor or self.stripeColor
        local stripe = rowFrame:CreateTexture(nil, "BACKGROUND")

        stripe:SetAllPoints(rowFrame)
        stripe:SetColorTexture(color[1], color[2], color[3], color[4])
        rowFrame.stripe = stripe
    end

    local row = setmetatable({
        tableView = self,
        frame = rowFrame,
        index = index,
        cells = createCells(
            rowFrame,
            self.columns,
            self.padding,
            rowFrame:GetHeight()
        ),
    }, { __index = TableRow })

    self.rows[index] = row
    self.rowsHeight = self.rowsHeight + rowHeight
    self.frame:SetHeight(self.headerHeight + self.rowsHeight)

    return row
end

function TableRow:GetFrame()
    return self.frame
end

function TableRow:GetCell(columnKey)
    local cell = self.cells[columnKey]

    assert(cell, "unknown table column " .. tostring(columnKey))

    return cell
end

function TableRow:AddText(columnKey, text, options)
    local column = self.tableView.columnsByKey[columnKey]

    assert(column, "unknown table column " .. tostring(columnKey))

    options = shallowCopy(options)
    options.fontObject = options.fontObject or GameFontHighlight

    return addTextToCell(self.cells[columnKey], column, text, options)
end

function TableRow:AddControl(columnKey, controlType, controlOptions, placement)
    local cell = self:GetCell(columnKey)
    local options = shallowCopy(controlOptions)
    local control = lib:CreateControl(controlType, cell, options)

    placement = placement or {}

    local point = placement.point or "CENTER"
    local relativePoint = placement.relativePoint or point

    control:SetPoint(
        point,
        cell,
        relativePoint,
        placement.offsetX or 0,
        placement.offsetY or 0
    )

    return control
end

function lib:CreateSettingsTable(parent, options)
    assert(parent, "settings table parent is required")

    options = options or {}
    assert(type(options) == "table", "settings table options must be a table")
    assert(
        type(options.width) == "number" and options.width > 0,
        "settings table width must be positive"
    )

    local padding = options.padding

    if padding == nil then
        padding = DEFAULT_PADDING
    end

    assert(
        type(padding) == "number" and padding >= 0,
        "settings table padding must be non-negative"
    )

    local innerWidth = options.width - (padding * 2)

    assert(innerWidth > 0, "settings table inner width must be positive")

    local columns = resolveColumns(options.columns, innerWidth)
    local frame = CreateFrame("Frame", nil, parent)
    local headerHeight = options.headerHeight or DEFAULT_HEADER_HEIGHT
    local rowHeight = options.rowHeight or DEFAULT_ROW_HEIGHT

    assert(
        type(headerHeight) == "number" and headerHeight > 0,
        "settings table header height must be positive"
    )
    assert(
        type(rowHeight) == "number" and rowHeight > 0,
        "settings table row height must be positive"
    )

    frame:SetSize(options.width, math.max(headerHeight, 1))

    local header = CreateFrame("Frame", nil, frame)

    header:SetSize(options.width, headerHeight)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)

    local tableView = setmetatable({
        frame = frame,
        header = header,
        width = options.width,
        padding = padding,
        headerHeight = headerHeight,
        rowHeight = rowHeight,
        stripeColor = options.stripeColor or DEFAULT_STRIPE_COLOR,
        columns = columns,
        columnsByKey = {},
        rows = {},
        rowsHeight = 0,
    }, { __index = TableView })

    for index = 1, #columns do
        local column = columns[index]

        tableView.columnsByKey[column.key] = column
    end

    tableView.headerCells = createCells(
        header,
        columns,
        padding,
        headerHeight
    )

    return tableView
end
