local MAJOR, MINOR = "LibModernSettings-1.0", 12
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Utilities/TabNavigation", MINOR)
then
    return
end

lib._tabNavigationRoots = lib._tabNavigationRoots
    or setmetatable({}, { __mode = "k" })

local function findRoot(control)
    local canvasRoot
    local frame = control

    while frame do
        local layout = frame._libModernSettingsCanvasLayout

        if layout and not canvasRoot then canvasRoot = layout.parent end

        if lib._tabNavigationRoots[frame] then return frame, canvasRoot end

        frame = frame:GetParent()
    end

    return canvasRoot, canvasRoot
end

local function refreshLayouts(root)
    lib:_RefreshPendingFields(root)

    for layout in pairs(lib._canvasLayouts or {}) do
        if
            layout.dirty
            and layout.parent:IsVisible()
            and DoesAncestryInclude(root, layout.parent)
        then
            layout:RefreshLayout()
        end
    end
end

local function compareBranches(left, right)
    if left.top ~= right.top then return left.top > right.top end

    if left.left ~= right.left then return left.left < right.left end

    return left.index < right.index
end

local function collectInputs(frame, inputs, root)
    if
        not frame:IsVisible()
        or (frame ~= root and lib._tabNavigationRoots[frame])
    then
        return
    end

    if frame._GetTabInput then
        local input = frame:_GetTabInput()

        if input and input:IsVisible() and input:IsEnabled() then
            inputs[#inputs + 1] = frame
        end
    end

    local branches = {}

    for index, child in ipairs({ frame:GetChildren() }) do
        local childInputs = {}
        collectInputs(child, childInputs, root)

        if #childInputs > 0 then
            local scale = child:GetEffectiveScale()
            branches[#branches + 1] = {
                inputs = childInputs,
                top = math.floor((child:GetTop() or 0) * scale + 0.5),
                left = math.floor((child:GetLeft() or 0) * scale + 0.5),
                index = index,
            }
        end
    end
    -- Keep containers together: scrolling a page must not move its offscreen
    -- fields ahead of a toolbar outside that page.
    table.sort(branches, compareBranches)

    for _, branch in ipairs(branches) do
        for _, control in ipairs(branch.inputs) do
            inputs[#inputs + 1] = control
        end
    end
end

local function scrollIntoView(control, root)
    local frame = control

    while frame do
        local layout = frame._libModernSettingsCanvasLayout

        if layout then
            -- A nested canvas can resize its section and dirty the outer canvas.
            if layout.dirty then layout:RefreshLayout() end

            layout:_ScrollControlIntoView(control)
        end

        if frame == root then break end

        frame = frame:GetParent()
    end
end

function lib:EnableTabNavigation(parent)
    assert(parent, "tab navigation parent is required")
    self._tabNavigationRoots[parent] = true
end

local function revealPendingControl()
    local control = lib._pendingControlReveal
    lib._pendingControlReveal = nil
    lib._controlRevealQueued = nil

    if
        not control
        or GetCurrentKeyBoardFocus() ~= control
        or not control:IsVisible()
    then
        return
    end

    local root = findRoot(control)

    if root and root:IsVisible() then
        refreshLayouts(root)
        scrollIntoView(control, root)
    end
end

function lib:_RequestControlReveal(control)
    local root, canvasRoot = findRoot(control)

    if not canvasRoot or not root:IsVisible() then return end

    self._pendingControlReveal = control

    if self._controlRevealQueued then return end
    -- Appending a row can resize several nested sections. Let native size
    -- notifications reach their owners before measuring the focused input.
    self._controlRevealQueued = true
    C_Timer.After(0, revealPendingControl)
end

function lib:_NavigateTab(control, context)
    local root = findRoot(control)

    if not root or not root:IsVisible() then return false end

    local direction = context.modifiers.shift and -1 or 1

    if control:_ReleaseTabFocus() == false then return true end
    -- Committing can hide the page, rebuild fields, or focus an error dialog.
    -- Re-read the candidates only after the consumer has finished its callback.
    if
        GetCurrentKeyBoardFocus()
        or not root:IsVisible()
        or findRoot(control) ~= root
    then
        return true
    end

    refreshLayouts(root)
    local inputs = {}
    collectInputs(root, inputs, root)

    for index, input in ipairs(inputs) do
        if input == control then
            local target = inputs[(index - 1 + direction) % #inputs + 1]
            scrollIntoView(target, root)
            target:_FocusForTab()
            break
        end
    end

    return true
end
