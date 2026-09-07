local lib = LibStub("LibModernSettings-1.0")

dofile("Layouts/Table.lua")

local parent = CreateFrame("Frame")
local tableView = lib:CreateSettingsTable(parent, {
    width = 300,
    padding = 8,
    headerHeight = 20,
    rowHeight = 30,
    columns = {
        { key = "name", weight = 1 },
        { key = "value", width = 80 },
    },
})
local firstRow = tableView:AddRow({ striped = false })
local secondRow = tableView:AddRow({ striped = false })
local heightChanges = {}

tableView:SetOnHeightChanged(function(owner, newHeight, oldHeight)
    heightChanges[#heightChanges + 1] = {
        owner = owner,
        newHeight = newHeight,
        oldHeight = oldHeight,
    }
end)

assert(tableView:GetHeight() == 80)
assert(firstRow:GetHeight() == 30)
assert(secondRow:GetFrame().point[5] == -50)

firstRow:SetHeight(60)

assert(firstRow:GetHeight() == 60)
assert(firstRow:GetCell("name"):GetHeight() == 30)
assert(tableView:GetHeight() == 110)
assert(secondRow:GetFrame().point[5] == -80)
assert(#heightChanges == 1)
assert(heightChanges[1].owner == tableView)
assert(heightChanges[1].oldHeight == 80)
assert(heightChanges[1].newHeight == 110)

firstRow:SetHeight(60)
assert(#heightChanges == 1)

secondRow:SetHeight(20)
assert(tableView:GetHeight() == 100)
assert(#heightChanges == 2)
assert(heightChanges[2].oldHeight == 110)
assert(heightChanges[2].newHeight == 100)

local invalidHeightSucceeded = pcall(function()
    firstRow:SetHeight(0)
end)

assert(invalidHeightSucceeded == false)

print("LibModernSettings table layout tests passed")
