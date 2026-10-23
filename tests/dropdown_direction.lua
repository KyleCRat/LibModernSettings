return function(lib, buildMenu, createMenuFrame)
    for _, multiSelect in ipairs({ false, true }) do
        local control = lib:CreateDropdown(nil, {
            menuDirection = "up",
            multiSelect = multiSelect,
            value = multiSelect and {} or 1,
            choices = {
                { value = 1, label = "First" },
                { value = 2, label = "Second" },
            },
        })

        local function CheckAnchor()
            local anchor = control.dropdown.menuAnchor
            assert(
                anchor.point == "BOTTOMLEFT"
                    and anchor.relativePoint == "TOPLEFT"
            )
            assert(
                anchor.relativeTo == control.dropdown
                    and anchor.x == 0
                    and anchor.y == 0
            )
        end

        CheckAnchor()
        control:SetValue(multiSelect and { [2] = true } or 2)
        control:SetChoices({ { value = 2, label = "Second" } })
        control:SetControlWidth(350)
        lib:_RefreshControlAppearance(control)
        CheckAnchor()

        local menu = buildMenu(control)
        assert(
            menu.maxScrollExtent == math.floor(UIParent:GetHeight() * 0.75),
            "upward menus must retain the full height allowance, regardless of space above the input"
        )
        assert(#menu.menuAcquiredCallbacks == 1)

        local short = createMenuFrame(false)
        menu.menuAcquiredCallbacks[1](short)
        short.scripts.OnShow(short)
        assert(
            not short.clearedPoints and short.point == nil,
            "short menus must keep the requested native anchor"
        )

        local scrolling = createMenuFrame(true)
        menu.menuAcquiredCallbacks[1](scrolling)
        scrolling.scripts.OnShow(scrolling)
        assert(scrolling.clearedPoints and scrolling.point[1] == "LEFT")
        assert(
            scrolling.point[2] == UIParent
                and scrolling.point[3] == "BOTTOMLEFT"
        )
        assert(
            scrolling.point[5] == UIParent:GetHeight() / 2,
            "long upward menus must still center instead of shrinking to the space above"
        )

        lib._loadedModules["Controls/Dropdown"] = nil
        dofile("Controls/Dropdown.lua")
        CheckAnchor()
        assert(
            multiSelect and control:GetValue()[2] or control:GetValue() == 2,
            "compatible module reloads must preserve the direction and selection"
        )
    end

    local down = lib:CreateDropdown(nil, { menuDirection = "down" })
    assert(
        down.dropdown.menuAnchor.point == "TOPLEFT"
            and down.dropdown.menuAnchor.relativePoint == "BOTTOMLEFT"
    )

    local default = lib:CreateDropdown(nil, {})
    local nativeAnchor = {}
    default.dropdown:SetMenuAnchor(nativeAnchor)
    lib:_RefreshControlAppearance(default)
    assert(
        default.dropdown.menuAnchor == nativeAnchor,
        "omitting menuDirection must preserve existing native or consumer anchors"
    )

    for _, direction in ipairs({
        "left",
        "",
        true,
        1,
        {},
    }) do
        assert(
            not pcall(
                lib.CreateDropdown,
                lib,
                nil,
                { menuDirection = direction }
            ),
            "invalid menuDirection values must be rejected"
        )
    end

    print("LibModernSettings dropdown direction tests passed")
end
