return function(lib, makeFrame, inputState)
    dofile("Utilities/FlashMessages.lua")

    local owner = makeFrame("Frame")
    owner:SetSize(500, 300)
    owner:SetFrameStrata("DIALOG")
    owner:SetFrameLevel(30)
    owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -100)
    local stack =
        lib:CreateFlashMessages(owner, { duration = 2, fadeDuration = 1 })

    local function advance(seconds)
        local update = assert(stack.frame:GetScript("OnUpdate"))
        update(stack.frame, seconds)
    end

    assert(not stack.frame:IsShown() and not stack.frame:GetScript("OnUpdate"))
    assert(not pcall(function()
        lib:CreateFlashMessages(owner, { maxMessages = 1.5 })
    end))
    assert(not pcall(function()
        lib:CreateFlashMessages(owner, { width = 0 })
    end))
    assert(not pcall(function()
        lib:CreateFlashMessages(owner, { duration = 0 / 0 })
    end))
    assert(not pcall(function()
        stack:Show("", "info")
    end))
    assert(not pcall(function()
        stack:Show("Unknown", "other")
    end))

    local height = owner:GetHeight()
    local focused = inputState.keyboardFocus
    local firstID = stack:Show("Choose a color.", "info")
    local secondID = stack:Show("Saved.", "success")
    local thirdID = stack:Show("Enter a valid RGB value.", "error")
    assert(#stack.messages == 3 and owner:GetHeight() == height)
    assert(stack.messages[1].id == firstID and stack.messages[3].id == thirdID)
    assert(stack.messages[2].frame.point[5] < stack.messages[1].frame.point[5])
    assert(
        stack.messages[3].frame.point[5] < stack.messages[2].frame.point[5],
        "messages must stack downward in arrival order"
    )
    assert(
        stack.messages[1].text.text:find("Info:")
            and stack.messages[2].text.text:find("Success:")
            and stack.messages[3].text.text:find("Error:")
    )
    assert(
        stack.messages[1].text.textColor[1]
            ~= stack.messages[3].text.textColor[1]
    )
    assert(
        stack.frame:GetParent() == UIParent,
        "messages must escape a group's scroll clipping"
    )
    assert(
        stack.frame:GetFrameStrata() == "DIALOG"
            and stack.frame:GetFrameLevel() > owner:GetFrameLevel()
    )
    assert(
        stack.frame.point[5] < owner:GetBottom()
            and stack.frame.point[5] - stack.height > 0,
        "stack must fit below the owner"
    )

    stack.messages[2].close:Click()
    assert(#stack.messages == 2 and not stack:Dismiss(secondID))
    assert(
        inputState.keyboardFocus == focused,
        "showing and dismissing messages must not steal input focus"
    )
    advance(2.5)
    assert(stack.messages[1].frame.alpha == 0.5)
    local repeatedID = stack:Show("Choose a color.", "info")
    assert(#stack.messages == 2 and stack.messages[2].id == repeatedID)
    assert(
        stack.messages[2].frame.alpha == 1 and not stack:Dismiss(firstID),
        "repeats must renew their lifetime and move to the end without stale handles"
    )
    advance(0.6)
    assert(#stack.messages == 1 and stack.messages[1].id == repeatedID)
    advance(2.4)
    assert(#stack.messages == 0 and not stack.frame:IsShown())
    assert(
        not stack.frame:GetScript("OnUpdate"),
        "empty stacks must stop updating"
    )

    do
        local previousMouseFoci = inputState.mouseFoci
        stack:Show("Read while hovering")
        local notice = stack.messages[1]
        assert(notice.frame.mouseMotionEnabled)
        stack:Show("Expires independently")
        advance(0.5)

        inputState.mouseFoci = { notice.frame }
        advance(4)
        assert(
            #stack.messages == 1
                and stack.messages[1] == notice
                and notice.age == 0.5,
            "hover must pause only that message while other messages can expire"
        )
        inputState.mouseFoci = { notice.close }
        advance(4)
        assert(
            notice.age == 0.5 and notice.frame.alpha == 1,
            "moving onto the close button must keep the message paused"
        )

        inputState.mouseFoci = {}
        advance(1.75)
        assert(
            notice.age == 2.25 and notice.frame.alpha == 0.75,
            "leaving must resume the remaining lifetime without restarting it"
        )
        inputState.mouseFoci = { notice.frame }
        advance(4)
        assert(
            notice.age == 2.25 and notice.frame.alpha == 0.75,
            "hover must also pause a fade already in progress"
        )
        inputState.mouseFoci = {}
        advance(0.75)
        assert(#stack.messages == 0 and not stack.frame:GetScript("OnUpdate"))

        stack:Show("Dismiss while hovering")
        notice = stack.messages[1]
        inputState.mouseFoci = { notice.close }
        advance(4)
        notice.close:Click()
        assert(
            #stack.messages == 0 and not stack.frame:GetScript("OnUpdate"),
            "paused messages must still allow immediate dismissal"
        )

        stack:Show("Hide owner while hovering")
        inputState.mouseFoci = { stack.messages[1].frame }
        owner:Hide()
        advance(4)
        assert(
            #stack.messages == 0 and not stack.frame:GetScript("OnUpdate"),
            "hover must not prevent cleanup when the owner becomes hidden"
        )
        owner:Show()
        inputState.mouseFoci = previousMouseFoci
        assert(
            inputState.keyboardFocus == focused,
            "hover must not change keyboard focus"
        )
    end

    stack:Show(string.rep("A detailed validation message. ", 5), "error")
    assert(
        stack.messages[1].text:GetStringHeight() > 12
            and owner:GetHeight() == height,
        "wrapped messages must grow independently of their owner"
    )
    assert(
        stack.messages[1].border.LeftEdge:IsShown()
            and stack.messages[1].border.RightEdge:IsShown(),
        "tall messages need their middle border edges"
    )
    local wrappedFrame = stack.messages[1].frame
    stack:Clear()
    stack:Show("Short message")
    assert(stack.messages[1].frame == wrappedFrame)
    assert(
        not stack.messages[1].border.LeftEdge:IsShown()
            and not stack.messages[1].border.RightEdge:IsShown(),
        "reused compact messages must hide edges whose corner anchors overlap"
    )
    stack:Clear()

    for index = 1, 6 do
        stack:Show("Message " .. index)
    end

    assert(#stack.messages == 4 and stack.messages[1].message == "Message 3")
    assert(#stack.pool == 0, "bounded stacks must reuse dismissed frames")
    local framesCreated = #stack.frame.children
    stack:Clear()

    for index = 1, 4 do
        stack:Show("Reused " .. index)
    end

    assert(#stack.frame.children == framesCreated)

    local ownerGap = owner:GetBottom() - stack.frame.point[5]
    owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -680)
    advance(0)
    local fallbackTop = stack.frame.point[5]
    assert(
        fallbackTop - stack.height == owner:GetTop() + ownerGap,
        "insufficient room below must pin the stack's bottom above the owner's top"
    )
    assert(stack.messages[4].frame.point[5] < stack.messages[1].frame.point[5])
    stack:Dismiss(stack.messages[1].id)
    assert(
        stack.frame.point[5] - stack.height == owner:GetTop() + ownerGap,
        "removing messages must preserve the gap above the owner"
    )
    stack:Show("Added above")
    assert(
        stack.frame.point[5] - stack.height == owner:GetTop() + ownerGap,
        "new messages must remain closest to the owner as the stack grows"
    )
    owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -650)
    advance(0)
    assert(
        stack.frame.point[5] - stack.height == owner:GetTop() + ownerGap,
        "fallback placement must follow the owner rather than the screen"
    )
    owner:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -100)
    advance(0)
    assert(
        stack.frame.point[5] < owner:GetBottom(),
        "moving the owner must update the placement"
    )

    UIParent.scale = 0.8

    function owner:GetEffectiveScale()
        return 0.4
    end

    function owner:GetCenter()
        return 3190, 500
    end

    function owner:GetBottom()
        return 10
    end

    function owner:GetTop()
        return self:GetBottom() + self:GetHeight()
    end

    advance(0)
    assert(
        stack.frame.scale == 0.5,
        "messages must match the owner's effective scale"
    )
    local screenWidth = UIParent:GetWidth() / stack.frame.scale
    local screenHeight = UIParent:GetHeight() / stack.frame.scale
    assert(stack.frame.point[4] + stack.frame:GetWidth() < screenWidth)
    assert(
        stack.frame.point[5] - stack.height == owner:GetTop() + ownerGap,
        "scaled owners must keep the same local gap above the frame"
    )
    owner:SetHeight(screenHeight - 20)
    advance(0)
    assert(
        stack.frame.point[5] < screenHeight,
        "when neither side has room, messages must still remain inside the screen"
    )
    owner:SetHeight(height)

    function owner:GetCenter()
        return 0, 500
    end

    advance(0)
    assert(
        stack.frame.point[4] >= 0,
        "left-edge owners must not push messages offscreen"
    )
    local previousWidth = UIParent.width
    UIParent.width = 150
    advance(0)
    assert(
        stack.frame:GetWidth() < UIParent:GetWidth() / stack.frame.scale,
        "screen changes must constrain message width"
    )
    UIParent.width = previousWidth
    UIParent.scale = nil

    local otherOwner = makeFrame("Frame")
    otherOwner:SetSize(400, 100)
    local other = lib:CreateFlashMessages(otherOwner)
    other:Show("Independent")
    owner:Hide()
    owner.scripts.OnHide(owner)
    assert(#stack.messages == 0 and not stack.frame:GetScript("OnUpdate"))
    assert(#other.messages == 1, "owner cleanup must not affect another stack")
    assert(stack:Show("Hidden owner") == nil and #stack.messages == 0)
    owner:Show()
    stack:Show("Shown again")
    local prototype = lib._flashMessagesPrototype
    lib._loadedModules["Utilities/FlashMessages"] = nil
    dofile("Utilities/FlashMessages.lua")
    assert(lib._flashMessagesPrototype == prototype)
    advance(3)
    assert(
        #stack.messages == 0,
        "existing stacks must keep working after a compatible reload"
    )
    local factory = lib.CreateFlashMessages
    dofile("Utilities/FlashMessages.lua")
    assert(
        lib.CreateFlashMessages == factory,
        "duplicate modules must not replace the factory"
    )
    local currentMinor = lib._implementationMinor
    lib._loadedModules["Utilities/FlashMessages"] = nil
    lib._implementationMinor = currentMinor + 1
    dofile("Utilities/FlashMessages.lua")
    assert(
        lib.CreateFlashMessages == factory,
        "older modules must not overwrite a newer library"
    )
    lib._implementationMinor = currentMinor
    lib._loadedModules["Utilities/FlashMessages"] = currentMinor

    otherOwner:Hide()
    other.frame.scripts.OnUpdate(other.frame, 0)
    assert(
        #other.messages == 0 and not other.frame:GetScript("OnUpdate"),
        "visibility loss must clear messages even before the next owner hook"
    )
    print("LibModernSettings flash message tests passed")
end
