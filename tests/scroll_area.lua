return function(newEnvironment, loadVersion)
    local environment = newEnvironment()
    local lib = loadVersion(environment, true)

    local function frame(width, height)
        local parent = environment.CreateFrame("Frame")
        parent:SetSize(width, height)
        return parent
    end

    local function point(region, name, x, y)
        local _, _, _, actualX, actualY = region:GetPointByName(name)
        assert(actualX == x and actualY == y, name .. " geometry differs")
    end

    -- The two approved changelog layouts, including a separately laid-out header.
    local options = { preset = "inset" }
    local regular = lib:CreateCanvasLayout(frame(656, 536), {
        scrollable = true,
        scrollArea = options,
    })
    local compact = lib:CreateCanvasLayout(frame(230, 540), {
        scrollable = true,
        scrollArea = { preset = "inset", contentSpacing = "compact" },
    })
    local header = lib:CreateCanvasLayout(frame(656, 50), {
        scrollArea = options,
        style = { paddingTop = 4, paddingBottom = 8 },
    })
    assert(regular:GetContentWidth() == 601 and compact:GetContentWidth() == 195)
    local left, right, top, bottom = regular:GetContentInsets()
    assert(left == 16 and right == 39 and top == 16 and bottom == 16)
    local headerLeft, headerRight, headerTop = header:GetContentInsets()
    assert(headerLeft == left and headerRight == right and headerTop == 4)
    assert(header:GetContentWidth() == regular:GetContentWidth() and not header:GetScrollBox())
    point(regular:GetScrollBox(), "TOPLEFT", 16, -6)
    point(regular:GetScrollBox(), "BOTTOMRIGHT", -39, 5)
    point(regular:GetScrollBar(), "TOPRIGHT", -6, -6)
    point(regular:GetScrollBar(), "BOTTOMRIGHT", -6, 5)
    point(compact:GetScrollBox(), "TOPLEFT", 8, -6)
    point(compact:GetScrollBox(), "BOTTOMRIGHT", -27, 5)
    assert(regular:GetScrollBar():GetWidth() == 17)
    local paddingTop, paddingBottom = regular.scrollArea:GetContentPadding()
    assert(paddingTop == 10 and paddingBottom == 11)
    assert(regular:GetStyleValue("paddingTop") == 10 and regular:GetStyleValue("paddingBottom") == 11)
    assert(compact:GetStyleValue("paddingTop") == 2 and compact:GetStyleValue("paddingBottom") == 3)

    local root = regular:GetRootFlow()
    local section = root:AddText({ text = "Retained content" })
    regular:Finalize()
    environment.Flush()
    assert(regular:GetContent():GetHeight() == 525)
    root:AddSpacer(1000)
    regular:RefreshLayout()
    assert(regular:GetContentWidth() == 601, "overflow must not remove or add a scrollbar column")
    regular:SetSize(756, 636)
    environment.Flush()
    assert(regular:GetContentWidth() == 701 and section:GetWidth() == 701)
    assert(regular.scrollArea:GetViewportHeight() == 625)
    assert(regular.scrollArea:GetContentWidth() == regular:GetContentWidth())

    -- Border and content overrides are independent and copied, including zeros.
    local customOptions = {
        preset = "inset",
        borderInsets = { right = 8, top = 20, bottom = 0 },
        contentPadding = { left = 24, bottom = 0 },
        scrollbarGap = 0,
    }
    local custom = lib:CreateCanvasLayout(frame(300, 200), {
        scrollable = true,
        scrollArea = customOptions,
    })
    customOptions.borderInsets.right = 99
    customOptions.contentPadding.left = 99
    local customLeft, customRight, customTop, customBottom = custom:GetContentInsets()
    assert(customLeft == 24 and customRight == 25 and customTop == 20 and customBottom == 0)
    point(custom:GetScrollBar(), "TOPRIGHT", -8, -20)
    assert(custom:GetStyleValue("paddingTop") == 0, "thick borders must not produce negative content padding")

    -- A native list uses the same column without modifying the caller's view.
    local listParent = frame(230, 540)
    local listOptions = { contentSpacing = "compact", borderInsets = { right = 7 } }
    local list = lib:CreateScrollArea(listParent, listOptions)
    local nativeView = { callerPadding = 3 }
    list:Init(nativeView)
    assert(list:GetScrollBox().template == "WowScrollBoxList")
    assert(list:GetScrollBar().template == "MinimalScrollBar")
    assert(list:GetScrollBox().nativeView == nativeView and nativeView.callerPadding == 3)
    assert(listParent:GetWidth() == 230 and listParent.point == nil, "LMS must not size or anchor the outer pane")
    assert(list:GetContentWidth() == 194 and list:GetViewportHeight() == 524)
    local listLeft, listRight, listTop, listBottom = list:GetContentInsets()
    assert(listLeft == 8 and listRight == 28 and listTop == 8 and listBottom == 8)
    paddingTop, paddingBottom = list:GetContentPadding()
    assert(paddingTop == 0 and paddingBottom == 0)
    point(list:GetScrollBox(), "TOPLEFT", 8, -8)
    point(list:GetScrollBox(), "BOTTOMRIGHT", -28, 8)
    point(list:GetScrollBar(), "TOPRIGHT", -7, -6)
    listParent:SetSize(330, 640)
    assert(list:GetContentWidth() == 294 and list:GetViewportHeight() == 624)
    assert(list:GetScrollBox().initCount == 1, "resizing must not reinitialize the view")
    listOptions.borderInsets.right = 90
    assert(not pcall(list.Init, list, nativeView), "a native view must be initialized once")

    local plain = lib:CreateScrollArea(frame(300, 200), {
        preset = "none", kind = "canvas", contentPadding = { left = 0 },
    })
    plain:Init(environment.CreateScrollBoxLinearView())
    point(plain:GetScrollBar(), "TOPRIGHT", 0, 0)
    assert(plain:GetScrollBox().template == "WowScrollBox" and plain:GetContentInsets() == 0)

    -- Simulate a retained canvas created before scroll areas existed.
    local legacy = lib:CreateCanvasLayout(frame(400, 300), {
        scrollable = true,
        viewportMarginTop = 10,
        viewportMarginBottom = 12,
        style = { paddingLeft = 9, scrollbarGap = 5, scrollbarWidth = 18 },
    })
    local oldBox, oldBar = legacy:GetScrollBox(), legacy:GetScrollBar()
    legacy.scrollArea, legacy.geometry = nil, nil
    local framesBeforeUpgrade = environment.framesCreated
    loadVersion(environment, false)
    environment.Flush()
    assert(environment.framesCreated == framesBeforeUpgrade, "upgrades must adopt rather than recreate scroll widgets")
    assert(legacy:GetScrollBox() == oldBox and legacy:GetScrollBar() == oldBar and oldBox.initCount == 1)
    point(oldBox, "TOPLEFT", 9, -10)
    point(oldBox, "BOTTOMRIGHT", -23, 12)
    assert(legacy:GetContentWidth() == 368)
    assert(regular:GetContentWidth() == 701 and custom:GetContentWidth() == 251)
    assert(list:GetContentWidth() == 294 and list:GetScrollBox().nativeView == nativeView)
    point(list:GetScrollBar(), "TOPRIGHT", -7, -6)

    local initCount = list:GetScrollBox().initCount
    loadVersion(environment, false)
    loadVersion(environment, true)
    environment.Flush()
    assert(environment.framesCreated == framesBeforeUpgrade and list:GetScrollBox().initCount == initCount,
        "same-version and late older embeds must not recreate or reconnect scroll areas")

    -- Invalid geometry and competing ownership fail instead of silently drifting.
    for _, bad in ipairs({
        { preset = "missing" }, { contentSpacing = "missing" }, { kind = "missing" },
        { preset = false }, { contentSpacing = false }, { kind = false },
        { borderInsets = { right = -1 } }, { contentPadding = { left = math.huge } },
        { scrollbarWidth = 0 }, { scrollbarGap = 0 / 0 },
    }) do
        assert(not pcall(lib.CreateScrollArea, lib, frame(300, 200), bad))
    end

    assert(not pcall(lib.CreateScrollArea, lib, nil, {}))
    assert(not pcall(lib.CreateScrollArea, lib, frame(300, 200), false))
    assert(not pcall(plain.Init, plain, nil))
    assert(not pcall(lib.CreateCanvasLayout, lib, frame(300, 200), {
        scrollable = true, scrollArea = {}, style = { paddingLeft = 8 },
    }))
    assert(not pcall(lib.CreateCanvasLayout, lib, frame(300, 200), {
        scrollable = true, scrollArea = {}, viewportMarginTop = 4,
    }))
    assert(not pcall(regular.SetSize, regular, 50, 200))
    assert(not pcall(regular.SetSize, regular, 300, 11))

    compact:Finalize({ paddingBottom = 9 })
    local _, _, _, finalBottom = compact:GetContentInsets()
    assert(finalBottom == 14, "reported bottom padding includes the canvas's finalization override")
    environment.Flush()

    print("LibModernSettings scroll area geometry, native list and upgrade tests passed")
end
