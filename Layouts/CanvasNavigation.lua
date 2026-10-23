local MAJOR, MINOR = "LibModernSettings-1.0", 11
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("Layouts/CanvasNavigation", MINOR)
then
    return
end

lib._canvasLayoutPrototype = lib._canvasLayoutPrototype or {}
local Layout = lib._canvasLayoutPrototype

local function isFinite(value)
    return type(value) == "number"
        and value == value
        and math.abs(value) < math.huge
end

local function isSectionKey(key)
    return type(key) == "string" and key ~= ""
end

local function belongsToContent(layout, frame, requireShown)
    local ancestor = frame

    while ancestor and ancestor ~= layout.content do
        if requireShown and not ancestor:IsShown() then return false end

        ancestor = ancestor:GetParent()
    end

    return ancestor == layout.content
end

local function validateFrame(layout, frame)
    assert(
        type(frame) == "table"
            and type(frame.GetParent) == "function"
            and type(frame.GetTop) == "function",
        "scroll anchor must be a canvas frame"
    )
    assert(
        belongsToContent(layout, frame),
        "scroll anchor must belong to this canvas content"
    )
end

local function getBounds(layout, frame)
    local contentTop, frameTop = layout.content:GetTop(), frame:GetTop()

    if not contentTop or not frameTop then return end

    local scale = frame:GetEffectiveScale() / layout.content:GetEffectiveScale()
    return contentTop - frameTop * scale, frame:GetHeight() * scale
end

function Layout:GetScrollAnchor()
    return self.scrollAnchorFrame, self.scrollAnchorOffset
end

function Layout:_OnAnchorScroll()
    -- Wheel interpolation can notify before its offset changes. Only scroll
    -- notifications from our own reflow belong to the retained anchor.
    if self.scrollAnchorFrame and not self.refreshing then
        self:SetScrollAnchor(nil)
    end
end

-- The offset is measured down from the frame's top to the viewport's top.
-- Keep the request through nested, deferred reflows; user scrolling releases it.
function Layout:SetScrollAnchor(frame, offset)
    assert(self.scrollBox, "scroll anchors require a scrollable canvas")

    if frame == nil then
        assert(
            offset == nil,
            "clearing a scroll anchor does not accept an offset"
        )
        self.scrollAnchorFrame = nil
        self.scrollAnchorOffset = nil
        return
    end

    validateFrame(self, frame)

    if offset == nil then offset = 0 end

    assert(isFinite(offset), "scroll anchor offset must be finite")

    if not self.scrollAnchorObserved then
        self.scrollBox:RegisterCallback(BaseScrollBoxEvents.OnScroll, function()
            self:_OnAnchorScroll()
        end, self)
        self.scrollAnchorObserved = true
    end

    self.scrollAnchorOffset = offset
    self.scrollAnchorFrame = frame
    self:RequestLayout()
end

function Layout:_RestoreScrollAnchor()
    local frame = self.scrollAnchorFrame

    if not frame then return end

    if not belongsToContent(self, frame) then
        self:SetScrollAnchor(nil)
        return
    end

    if not frame:IsVisible() then return end

    local top, height = getBounds(self, frame)

    if not top then return end

    local offset = self.scrollAnchorOffset

    if offset >= height then
        -- A collapsed section must reveal its heading instead of scrolling past it.
        offset = 0
    end

    self.scrollBox:ScrollToOffset(
        top + offset,
        ScrollBoxConstants.NoScrollInterpolation
    )
end

function Layout:RegisterScrollSection(key, frame, options)
    assert(self.scrollBox, "scroll sections require a scrollable canvas")
    assert(isSectionKey(key), "scroll section key must be a non-empty string")
    validateFrame(self, frame)
    assert(
        frame ~= self.content,
        "scroll sections must be children of the canvas content"
    )
    assert(
        options == nil or type(options) == "table",
        "scroll section options must be a table"
    )
    options = options or {}
    assert(
        options.isExpanded == nil or type(options.isExpanded) == "function",
        "scroll section isExpanded must be a function"
    )

    self.scrollSections = self.scrollSections or {}
    self.scrollSectionOrder = self.scrollSectionOrder or {}

    for registeredKey, section in pairs(self.scrollSections) do
        assert(
            registeredKey == key or section.frame ~= frame,
            "a scroll section frame can only have one key per canvas"
        )
    end

    local previous = self.scrollSections[key]

    if not previous then
        self.scrollSectionOrder[#self.scrollSectionOrder + 1] = key
    end

    self.scrollSections[key] = {
        frame = frame,
        isExpanded = options.isExpanded,
    }

    if previous and previous.frame == self.scrollAnchorFrame then
        self:SetScrollAnchor(frame, self.scrollAnchorOffset)
    end
end

function Layout:UnregisterScrollSection(key)
    assert(self.scrollBox, "scroll sections require a scrollable canvas")
    assert(isSectionKey(key), "scroll section key must be a non-empty string")
    local section = self.scrollSections and self.scrollSections[key]

    if not section then return false end

    if section.frame == self.scrollAnchorFrame then
        self:SetScrollAnchor(nil)
    end

    self.scrollSections[key] = nil

    for index, registeredKey in ipairs(self.scrollSectionOrder) do
        if registeredKey == key then
            table.remove(self.scrollSectionOrder, index)
            break
        end
    end

    return true
end

local function visibleSections(layout)
    local sections = {}

    for index, key in ipairs(layout.scrollSectionOrder or {}) do
        local section = layout.scrollSections[key]

        if belongsToContent(layout, section.frame, true) then
            local top, height = getBounds(layout, section.frame)
            sections[#sections + 1] = {
                key = key,
                section = section,
                order = index,
                top = top,
                height = height,
            }
        end
    end

    -- Consumers may reorder retained frames without registering them again.
    -- Registration order only breaks ties, including not-yet-measured frames.
    table.sort(sections, function(left, right)
        local leftTop, rightTop = left.top or math.huge, right.top or math.huge

        if leftTop == rightTop then return left.order < right.order end

        return leftTop < rightTop
    end)
    return sections
end

function Layout:CaptureScrollBookmark()
    assert(self.scrollBox, "scroll bookmarks require a scrollable canvas")

    if not self.content:IsVisible() then return end

    local scrollOffset = self.scrollBox:GetDerivedScrollOffset()
    local anchor, anchorOffset = self:GetScrollAnchor()

    if
        (anchor == self.content and anchorOffset == 0)
        or (not anchor and scrollOffset < 1)
    then
        return { version = 1, kind = "top" }
    end

    local sections = visibleSections(self)
    local extent = self.scrollBox:GetVisibleExtent()
    local bestIndex, bestOffset
    local bestScore = 0

    for index, entry in ipairs(sections) do
        local section = entry.section

        if section.frame == anchor then
            -- A new selection can arrive before the previous reflow completes.
            bestIndex = index
            bestOffset = anchorOffset
            break
        end

        if entry.top then
            local overlap = math.min(
                entry.top + entry.height,
                scrollOffset + extent
            ) - math.max(entry.top, scrollOffset)

            if overlap > 0 then
                local expanded = true

                if section.isExpanded then
                    expanded = section.isExpanded()
                    assert(
                        type(expanded) == "boolean",
                        "scroll section isExpanded must return a boolean"
                    )
                end

                local score = overlap + (expanded and extent or 0)

                if score > bestScore then
                    bestIndex = index
                    bestOffset = scrollOffset - entry.top
                    bestScore = score
                end
            end
        end
    end

    if not bestIndex then return end

    local fallbacks = {}

    for distance = 1, #sections do
        local following = sections[bestIndex + distance]
        local preceding = sections[bestIndex - distance]

        if following then fallbacks[#fallbacks + 1] = following.key end

        if preceding then fallbacks[#fallbacks + 1] = preceding.key end
    end

    return {
        version = 1,
        kind = "section",
        key = sections[bestIndex].key,
        offset = bestOffset,
        fallbacks = fallbacks,
    }
end

local function validateBookmark(bookmark)
    assert(
        type(bookmark) == "table" and bookmark.version == 1,
        "scroll bookmark must come from CaptureScrollBookmark"
    )
    assert(
        bookmark.kind == "top" or bookmark.kind == "section",
        "invalid scroll bookmark kind"
    )

    if bookmark.kind == "section" then
        assert(
            isSectionKey(bookmark.key)
                and isFinite(bookmark.offset)
                and type(bookmark.fallbacks) == "table",
            "invalid scroll section bookmark"
        )
        local count = 0

        for index, key in pairs(bookmark.fallbacks) do
            assert(
                type(index) == "number"
                    and index >= 1
                    and index == math.floor(index)
                    and index <= #bookmark.fallbacks
                    and isSectionKey(key),
                "invalid scroll bookmark fallback"
            )
            count = count + 1
        end

        assert(
            count == #bookmark.fallbacks,
            "scroll bookmark fallbacks must be an array"
        )
    end
end

local function findShownSection(layout, key)
    local section = layout.scrollSections and layout.scrollSections[key]

    if section and belongsToContent(layout, section.frame, true) then
        return section
    end
end

function Layout:RestoreScrollBookmark(bookmark)
    assert(self.scrollBox, "scroll bookmarks require a scrollable canvas")

    if bookmark == nil then
        self:SetScrollAnchor(nil)
        return
    end

    validateBookmark(bookmark)

    if bookmark.kind == "top" then
        self:SetScrollAnchor(self.content, 0)
        return
    end

    local section = findShownSection(self, bookmark.key)
    local offset = bookmark.offset

    if not section then
        for _, key in ipairs(bookmark.fallbacks) do
            section = findShownSection(self, key)

            if section then
                offset = 0
                break
            end
        end
    end

    if section then
        self:SetScrollAnchor(section.frame, offset)
    else
        self:SetScrollAnchor(self.content, 0)
    end
end
