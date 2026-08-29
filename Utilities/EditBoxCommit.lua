local MAJOR, MINOR = "LibModernSettings-1.0", 5
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

lib._pendingEditBoxCommits = lib._pendingEditBoxCommits
    or setmetatable({}, { __mode = "k" })

local commitFrame = lib._editBoxCommitFrame

if not commitFrame then
    commitFrame = CreateFrame("Frame")
    lib._editBoxCommitFrame = commitFrame
end

local function HasPendingCommits()
    return next(lib._pendingEditBoxCommits) ~= nil
end

local function StopCommitFrame()
    commitFrame:UnregisterEvent("GLOBAL_MOUSE_UP")
    commitFrame:SetScript("OnUpdate", nil)
end

local function FlushPendingCommitsOnUpdate(self)
    self:SetScript("OnUpdate", nil)

    if IsMouseButtonDown() then
        self:RegisterEvent("GLOBAL_MOUSE_UP")
        return
    end

    lib:_FlushPendingEditBoxCommits()
end

commitFrame:SetScript("OnEvent", function(self, event)
    if event ~= "GLOBAL_MOUSE_UP" or IsMouseButtonDown() then
        return
    end

    self:UnregisterEvent("GLOBAL_MOUSE_UP")
    self:SetScript("OnUpdate", FlushPendingCommitsOnUpdate)
end)

function lib:_CancelPendingEditBoxCommit(editBox)
    if self._pendingEditBoxCommits[editBox] == nil then
        return false
    end

    self._pendingEditBoxCommits[editBox] = nil

    if not HasPendingCommits() then
        StopCommitFrame()
    end

    return true
end

function lib:_FinalizeEditBoxOnFocusLost(editBox, finalizer)
    self:_CancelPendingEditBoxCommit(editBox)

    if not IsMouseButtonDown() then
        return finalizer(editBox)
    end

    self._pendingEditBoxCommits[editBox] = finalizer
    commitFrame:SetScript("OnUpdate", nil)
    commitFrame:RegisterEvent("GLOBAL_MOUSE_UP")
end

function lib:_FlushPendingEditBoxCommit(editBox)
    local finalizer = self._pendingEditBoxCommits[editBox]

    if not finalizer then
        return false
    end

    self._pendingEditBoxCommits[editBox] = nil

    if not HasPendingCommits() then
        StopCommitFrame()
    end

    if editBox:HasFocus() then
        return true
    end

    return true, finalizer(editBox)
end

function lib:_FlushPendingEditBoxCommits()
    if not HasPendingCommits() then
        return true
    end

    local pending = self._pendingEditBoxCommits
    local editBoxes = {}
    local finalizers = {}

    for editBox, finalizer in pairs(pending) do
        editBoxes[#editBoxes + 1] = editBox
        finalizers[#finalizers + 1] = finalizer
        pending[editBox] = nil
    end

    StopCommitFrame()

    local allCommitted = true

    for index = 1, #editBoxes do
        local editBox = editBoxes[index]

        if not editBox:HasFocus()
            and finalizers[index](editBox) == false then
            allCommitted = false
        end
    end

    return allCommitted
end

if HasPendingCommits() then
    if IsMouseButtonDown() then
        commitFrame:RegisterEvent("GLOBAL_MOUSE_UP")
    else
        commitFrame:SetScript("OnUpdate", FlushPendingCommitsOnUpdate)
    end
else
    StopCommitFrame()
end
