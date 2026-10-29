local MAJOR, MINOR = "LibModernSettings-1.0", 13
local lib = LibStub(MAJOR, true)

if
    not lib
    or lib._implementationMinor ~= MINOR
    or not lib:_BeginModule("TexturePicker/Browser", MINOR)
then
    return
end

lib._texturePickerUI = lib._texturePickerUI or {}
local UI = lib._texturePickerUI
local Values = lib._iconUtils
local CELL_WIDTH, CELL_HEIGHT, GAP = 256, 176, 8

local function label(parent, text)
    local region = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    region:SetText(text)
    return region
end

function UI.Draw(region, value, maxWidth, maxHeight, entry)
    if region.boundValue ~= value then
        region.boundValue = value
        local info = not (entry and entry.file)
            and type(value) == "string"
            and C_Texture.GetAtlasInfo(value)
        region.artWidth = entry and entry.width or 128
        region.artHeight = entry and entry.height or 128

        if info then
            region:SetAtlas(value, false)
            region.artWidth, region.artHeight = info.width, info.height
        else
            region:SetTexture(
                value,
                "CLAMPTOBLACKADDITIVE",
                "CLAMPTOBLACKADDITIVE"
            )
            region:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- Atlases and bundled files supply dimensions. Unknown files keep their
    -- complete UVs in a square preview because no public dimension API exists.
    local width = math.max(1, region.artWidth or 128)
    local height = math.max(1, region.artHeight or 128)
    local scale = math.min(1, maxWidth / width, maxHeight / height)
    region:SetSize(width * scale, height * scale)
end

function UI.Bind(picker, wrapper, index)
    local button = wrapper.button

    if not button then
        button = CreateFrame("Button", nil, wrapper)
        wrapper.button = button
        button:SetAllPoints()
        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()
        button.background:SetColorTexture(0.08, 0.08, 0.08, 0.7)
        button.artwork = button:CreateTexture(nil, "ARTWORK")
        button.artwork:SetPoint("CENTER", button, "TOP", 0, -72)
        button.label = label(button, "")
        button.label:SetPoint("BOTTOMLEFT", 8, 6)
        button.label:SetPoint("BOTTOMRIGHT", -8, 6)
        button.label:SetHeight(28)
        button.label:SetMaxLines(2)
        local hover = button:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0.08)
        button:SetHighlightTexture(hover)
        button:SetScript("OnClick", function()
            if not picker:Validate() then return end

            picker.input:CancelAndClearFocus()
            picker:SetValue(button.entry.texture)
        end)
    end

    local entry = picker.entries[index]

    if button.entry ~= entry then
        lib:HideOwnedTooltip(button)
        button.entry = entry
        button.label:SetText(entry.name)
        lib:SetTooltip(
            button,
            { title = entry.name, text = tostring(entry.texture) }
        )
    end

    UI.Draw(button.artwork, entry.texture, CELL_WIDTH - 16, 132, entry)
    local selected = Values.Key(entry.texture) == Values.Key(picker.value)

    if selected then
        button.background:SetColorTexture(0.5, 0.38, 0.05, 0.7)
    else
        button.background:SetColorTexture(0.08, 0.08, 0.08, 0.7)
    end

    button:Show()
end

function UI.Paint(picker)
    local value = picker.value or picker.session.defaultTexture
    UI.Draw(
        picker.preview,
        value,
        236,
        128,
        picker.catalogue.byValue[Values.Key(value)]
    )
    picker.scrollBox:ForEachFrame(function(wrapper)
        local entry = wrapper.button and wrapper.button.entry

        if entry then
            local selected = Values.Key(entry.texture)
                == Values.Key(picker.value)
            wrapper.button.background:SetColorTexture(
                selected and 0.5 or 0.08,
                selected and 0.38 or 0.08,
                selected and 0.05 or 0.08,
                0.7
            )
        end
    end)
end

function UI.AddTabs(picker, frame, selected)
    local textures = lib:CreateSideTab(frame, {
        iconAtlas = "ChallengeMode-Runes-CircleGlow",
        tooltip = "Textures",
        selected = selected == "textures",
        onClick = function()
            picker:SetBrowser("textures")
        end,
    })
    textures:SetPoint("TOPLEFT", frame, "TOPRIGHT", -1, -48)
    local icons = lib:CreateSideTab(frame, {
        iconTexture = 134400,
        tooltip = "Icons",
        selected = selected == "icons",
        onClick = function()
            picker:SetBrowser("icons")
        end,
    })
    icons:SetPoint("TOPLEFT", textures, "BOTTOMLEFT", 0, -8)
end

local function createInputs(picker)
    local frame = picker.frame
    picker.preview = frame:CreateTexture(nil, "ARTWORK")
    picker.preview:SetPoint("CENTER", frame, "TOPLEFT", 140, -108)
    local caption = label(frame, "Texture path, file ID or atlas")
    caption:SetPoint("TOPLEFT", 280, -56)
    caption:SetJustifyH("LEFT")
    picker.input = lib:CreateTextInput(frame, {
        maxLetters = 260,
        onCommit = function(text)
            local value, message = Values.Normalize(text)

            if message then return nil, message end
            if not picker:SetValue(value, true) then return nil end

            return value and tostring(value) or ""
        end,
        onError = function(message)
            picker.inputError = true
            picker:Error(message)
        end,
    })
    picker.input:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -8)
    picker.input:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    picker.input:HookScript("OnEscapePressed", function()
        picker:Close()
    end)
end

local function createGrid(picker)
    local inset = picker.frame.Inset
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 12, -216)
    inset:SetPoint("BOTTOMRIGHT", -12, 50)
    picker.area = lib:CreateScrollArea(inset, { contentSpacing = "compact" })
    picker.scrollBox = picker.area:GetScrollBox()
    local view = CreateScrollBoxListGridView(2, 0, 0, 0, 0, GAP, GAP)
    picker.view = view
    view:SetElementSize(CELL_WIDTH, CELL_HEIGHT)
    view:SetElementInitializer("Frame", function(wrapper, index)
        UI.Bind(picker, wrapper, index)
    end)
    view:SetElementResetter(function(wrapper)
        lib:HideOwnedTooltip(wrapper.button)
        wrapper.button.entry = nil
        wrapper.button:Hide()
    end)
    picker.area:Init(view)
end

function UI.SelectCategory(picker, category)
    for index, tab in ipairs(picker.categoryTabs) do
        tab:SetSelected(index == category.index)
    end
end

local function createCategories(picker)
    local tabs = CreateFrame("Frame", nil, picker.frame)
    picker.categoryTabs = {}
    tabs:SetPoint("BOTTOMLEFT", picker.frame.Inset, "TOPLEFT", 8, 0)
    tabs:SetSize(#picker.catalogue.categories * 86, 32)

    for index, category in ipairs(picker.catalogue.categories) do
        local button = lib:CreateTab(tabs, {
            text = category.name,
            width = 86,
            height = 32,
            tooltip = category.tooltip,
            onClick = function()
                picker:SetCategory(category.id)
            end,
        })
        picker.categoryTabs[index] = button
        button:SetPoint("BOTTOMLEFT", (index - 1) * 86, 0)

        if picker.styleCategoryTab then
            picker.styleCategoryTab(button, picker.frame)
        end
    end
end

local function createActions(picker)
    local cancel = lib:CreateButton(picker.frame, {
        text = "Cancel",
        onClick = function()
            picker:Close()
        end,
    })
    cancel:SetPoint("BOTTOMRIGHT", -24, 10)
    local reset = lib:CreateButton(picker.frame, {
        text = "Reset",
        tooltip = "Preview the default texture. Apply saves it; Cancel keeps the previous texture.",
        onClick = function()
            picker:Reset()
        end,
    })
    reset:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    local apply = lib:CreateButton(picker.frame, {
        text = "Apply",
        onClick = function()
            picker:Apply()
        end,
    })
    apply:SetPoint("RIGHT", reset, "LEFT", -8, 0)
end

local function createResize(picker)
    local frame = picker.frame
    frame:SetResizable(true)
    frame:SetResizeBounds(580, 450)
    frame:SetScript("OnSizeChanged", function(_, width)
        local left, right = picker.area:GetContentInsets()
        local available = width - 24 - left - right
        local columns =
            math.max(2, math.floor((available + GAP) / (CELL_WIDTH + GAP)))

        if picker.columns == columns then return end

        picker.columns = columns
        picker.view:SetStride(columns)

        if picker.session and picker.browser == "textures" then
            picker.scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
        end
    end)
    picker.columns = 2
    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(20, 20)
    resize:SetPoint("BOTTOMRIGHT", -2, 2)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture(
        "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight"
    )
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
    end)
end

function UI.Create(picker, parent)
    local frame = CreateFrame("Frame", nil, parent, "ButtonFrameTemplate")
    picker.frame = frame
    frame:Hide()
    frame:SetSize(620, 660)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetClampRectInsets(0, -48, 0, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function() end)
    ButtonFrameTemplate_HidePortrait(frame)
    frame.TopTileStreaks:Hide()
    frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -1)
    frame.CloseButton:SetFrameLevel(frame.TitleContainer:GetFrameLevel() + 1)
    frame.TitleContainer:EnableMouse(true)
    frame.TitleContainer:RegisterForDrag("LeftButton")
    frame.TitleContainer:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame.TitleContainer:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.CloseButton:SetScript("OnClick", function()
        picker:Close()
    end)
    frame:SetScript("OnHide", function()
        if picker.session and not picker.switching then picker:Close() end
    end)
    frame:SetScript("OnEvent", function()
        picker:Close()
    end)
    frame:EnableKeyboard(true)
    frame:SetPropagateKeyboardInput(true)
    frame:SetScript("OnKeyDown", function(_, key)
        frame:SetPropagateKeyboardInput(key ~= "ESCAPE")

        if key == "ESCAPE" then picker:Close() end
    end)
    picker.messages = lib:CreateFlashMessages(frame)
    createInputs(picker)
    createGrid(picker)
    createCategories(picker)
    createActions(picker)
    createResize(picker)
    UI.AddTabs(picker, frame, "textures")
    lib:EnableTabNavigation(frame)
end
