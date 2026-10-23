return function(lib, makeFrame, inputState, key)
    local root = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(root)
    local saved
    local text = lib:CreateTextInput(root, {
        onCommit = function(value)
            saved = value
            return value
        end,
    })
    text:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)

    local function factory(parent)
        local control = makeFrame("Frame", parent)
        control.input = makeFrame("Button", control)
        control.value = 0
        control.releases = 0
        return control
    end

    local methods = {
        Add = function(control, amount)
            control.value = control.value + amount
        end,
    }
    lib:RegisterControlType("navigationExample", factory, methods)
    local first = lib:CreateControl("navigationExample", root)
    first:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -50)
    assert(first._GetTabInput == nil)

    local options = {
        input = function(control)
            return control.input
        end,
        actions = {
            activate = function(control, context)
                assert(saved == "Committed")
                assert(
                    context.source == "keyboard" and context.direction == nil
                )
                assert(
                    context.modifiers.control
                        and context.modifiers.alt
                        and context.modifiers.meta
                )
                control:Add(1)
                return true
            end,
        },
        release = function(control)
            control.releases = control.releases + 1
        end,
        highlight = function(control, focused)
            control.focused = focused
        end,
        hover = function(control, hovered)
            control.hovered = hovered
        end,
    }
    lib:RegisterControlNavigation("navigationExample", options)
    local second = lib:CreateControl("navigationExample", root)
    second:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -100)
    assert(
        first:_GetTabInput() == first.input
            and second:_GetTabInput() == second.input,
        "registration must reach both existing and future instances"
    )

    text:FocusValue()
    text:SetText("Committed")
    text.scripts.OnTabPressed(text)
    local keyboard = lib._navigationKeyboardFrame
    assert(first.focused and first.hovered and keyboard.control == first)
    first.input.scripts.OnLeave(first.input)
    assert(first.hovered)
    inputState.modifiers.control = true
    inputState.modifiers.alt = true
    inputState.modifiers.meta = true
    key("ENTER")
    key("SPACE")
    assert(first.value == 2 and not keyboard.propagateKeyboardInput)
    inputState.modifiers.control = false
    inputState.modifiers.alt = false
    inputState.modifiers.meta = false
    key("UP")
    assert(
        first.value == 2 and keyboard.propagateKeyboardInput,
        "unhandled actions must pass through"
    )
    key("TAB")
    assert(first.releases == 1 and not first.focused and second.focused)
    inputState.modifiers.shift = true
    key("TAB")
    inputState.modifiers.shift = false
    assert(first.focused and not second.focused)

    -- Updating descriptors and prototypes must affect live instances without stacking hooks.
    local hooks = #first.input.scriptHooks.OnHide

    options.actions.activate = function(control)
        control:Add(10)
        return true
    end

    options.highlight = function(control, focused)
        control.focused = focused
        control.updatedHighlight = true
    end

    lib:RegisterControlNavigation("navigationExample", options)
    lib:RegisterControlType("navigationExample", factory, methods)
    assert(
        first.focused and first.updatedHighlight and keyboard.control == first
    )
    assert(#first.input.scriptHooks.OnHide == hooks)
    key("SPACE")
    assert(first.value == 12)

    options.actions.activate = function()
        error("registration must own a copy of the action map")
    end

    key("ENTER")
    assert(first.value == 22)

    for _, case in ipairs({
        { nil, "options must be a table" },
        {
            { mode = "unknown" },
            "mode must be",
        },
        {
            { actions = false },
            "actions must be a table",
        },
        {
            { actions = { activate = true } },
            "actions must map names to functions",
        },
        {
            {
                actions = {
                    [1] = function() end,
                },
            },
            "actions must map names to functions",
        },
    }) do
        local ok, message = pcall(
            lib.RegisterControlNavigation,
            lib,
            "navigationExample",
            case[1]
        )
        assert(not ok and message:find(case[2], 1, true))
    end

    for _, name in ipairs({ "input", "focus", "release", "highlight", "hover" }) do
        local ok = pcall(
            lib.RegisterControlNavigation,
            lib,
            "navigationExample",
            { [name] = true }
        )
        assert(not ok)
    end

    assert(not pcall(lib.RegisterControlNavigation, lib, "notRegistered", {}))
    key("ENTER")
    assert(
        first.value == 32,
        "invalid descriptors must leave the working registration intact"
    )

    local sharedCalls = 0
    local originalHandler =
        lib._navigationControlMethods._HandleNavigationAction

    lib._navigationControlMethods._HandleNavigationAction = function(
        control,
        ...
    )
        sharedCalls = sharedCalls + 1
        return originalHandler(control, ...)
    end

    key("SPACE")
    assert(
        sharedCalls == 1 and first.value == 42,
        "shared method upgrades must reach existing custom types without re-registering them"
    )
    lib._navigationControlMethods._HandleNavigationAction = originalHandler
    local dispatcher = first._GetTabInput
    lib._loadedModules["Utilities/ControlNavigation"] = nil
    dofile("Utilities/ControlNavigation.lua")
    assert(
        first._GetTabInput == dispatcher
            and first.focused
            and keyboard.control == first
    )
    assert(#first.input.scriptHooks.OnHide == hooks)

    first.input:SetEnabled(false)
    assert(not first.focused and not keyboard:IsShown())
    text:FocusValue()
    text.scripts.OnTabPressed(text)
    assert(second.focused, "eligibility must use the declared child input")
    local releases = second.releases
    second:Hide()
    second.input.scripts.OnHide(second.input)
    assert(
        second.releases == releases + 1
            and not second.focused
            and keyboard.control == nil
    )
    second:Show()
    second:_FocusForTab()
    inputState.inCombat = true
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_DISABLED")
    assert(not keyboard:IsShown() and not second.focused)
    inputState.inCombat = false
    keyboard.scripts.OnEvent(keyboard, "PLAYER_REGEN_ENABLED")
    assert(second.focused and keyboard:IsShown())
    key("ESCAPE")
    assert(keyboard.control == nil and not second.focused)

    -- A future native editor gets Tab navigation without losing ordinary text keys.
    local editorRoot = makeFrame("Frame", UIParent)
    lib:EnableTabNavigation(editorRoot)
    local callbackFocuses = 0
    lib:RegisterControlType("navigationEditor", function(parent)
        local control = makeFrame("Frame", parent)
        control.input = makeFrame("EditBox", control)
        control.input:SetScript("OnEditFocusGained", function()
            callbackFocuses = callbackFocuses + 1
        end)
        return control
    end, {})
    local focusCalls, commits = 0, 0
    local editorOptions = {
        mode = "editBox",
        input = options.input,
        focus = function(control)
            focusCalls = focusCalls + 1
            control.input:SetFocus()
        end,
        release = function(control)
            commits = commits + 1
            control.input:ClearFocus()
            return control.accepted ~= false
        end,
    }
    lib:RegisterControlNavigation("navigationEditor", editorOptions)
    local editor = lib:CreateControl("navigationEditor", editorRoot)
    local following = lib:CreateTextInput(editorRoot, {})
    following:SetPoint("TOPLEFT", editorRoot, "TOPLEFT", 0, -50)
    editor.input:SetScript("OnEditFocusGained", function()
        callbackFocuses = callbackFocuses + 1
    end)
    lib:RegisterControlNavigation("navigationEditor", editorOptions)
    second:_FocusForTab()
    editor:_FocusForTab()
    assert(focusCalls == 1 and callbackFocuses == 1 and keyboard.control == nil)
    assert(
        editor.input.scripts.OnKeyDown == nil
            and editor.input.scripts.OnArrowPressed == nil
    )
    assert(
        editor.input.scripts.OnEnterPressed == nil
            and editor.input.scripts.OnEscapePressed == nil
    )
    editor.accepted = false
    editor.input.scripts.OnTabPressed(editor.input)
    assert(
        commits == 1 and not following:HasFocus(),
        "a rejected release must stop traversal"
    )
    editor.accepted = true
    editor:_FocusForTab()
    editor.input.scripts.OnTabPressed(editor.input)
    assert(commits == 2 and following:HasFocus())
    following:CancelAndClearFocus()
end
