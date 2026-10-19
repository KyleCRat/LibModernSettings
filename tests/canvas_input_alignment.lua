return function(newEnvironment, loadVersion)
    -- Resolve actual anchors, including LEFT and label-relative BOTTOMLEFT. The
    -- generic frame mock's GetTop only models TOPLEFT canvas positioning.
    local function anchorOffset(point, height)
        if point:find("TOP") then
            return height / 2
        elseif point:find("BOTTOM") then
            return -height / 2
        end
        return 0
    end

    local function centerY(frame, origin)
        if frame == origin then
            return 0
        end
        local point, relative, relativePoint, _, y = frame:GetPoint()
        assert(point, "inputs and labels must retain their anchors")
        return centerY(relative, origin) + anchorOffset(relativePoint, relative:GetHeight())
            + y - anchorOffset(point, frame:GetHeight())
    end

    local function assertAligned(first, second, origin)
        assert(math.abs(centerY(first, origin) - centerY(second, origin)) < 0.001,
            "interactive rows must align independently of their labels/descriptions")
    end

    for _, startWithOld in ipairs({ false, true }) do
        local environment = newEnvironment()
        local lib = loadVersion(environment, startWithOld)
        local parent = environment.CreateFrame("Frame")
        local layout = lib:CreateCanvasLayout(parent, { width = 900, height = 200, scrollable = true })
        local root = layout:GetRootFlow()
        local columns = root:BeginColumns({ count = 3, minColumnWidth = 180, verticalAlign = "input" })
        local checkbox = columns[1]:AddControl("checkbox", { label = "Enabled", value = true })
        local group = columns[2]:BeginGroup()
        local field = group:AddControl("field", {
            label = "Name",
            description = string.rep("A longer description. ", 12),
            controlType = "textInput",
            controlOptions = { value = "Saved" },
        })
        group:Finish()
        local color = columns[3]:AddControl("color", { label = "Tint", value = { r = 0.5, g = 1, b = 0 } })
        columns:Finish()
        local commits = 0
        local following = root:AddControl("textInput", {
            value = "Original",
            onCommit = function(text)
                commits = commits + 1
                return text
            end,
        })
        root:AddSpacer(500)
        layout:Finalize()
        environment.Flush(10)
        local frameCount = environment.framesCreated
        following:SetFocus()
        following:SetText("Pending edit")

        local function checkWide()
            assertAligned(checkbox, field:GetControl(), layout:GetContent())
            assertAligned(checkbox, color.buttons.custom, layout:GetContent())
            assert(-following.point[5] >= -field.point[5] + field:GetHeight(),
                "descriptions must still reserve their full height below aligned inputs")
        end
        checkWide()

        loadVersion(environment, not startWithOld)
        environment.Flush(10)
        checkWide()
        for _, description in ipairs({ "", "Short", string.rep("Wrapped description. ", 20) }) do
            local checkboxY = checkbox.point[5]
            field:SetDescription(description)
            environment.Flush(10)
            checkWide()
            assert(checkbox.point[5] == checkboxY, "description height must not move the aligned checkbox")
        end

        field.label.stringHeight = 36
        field:RefreshLayout()
        environment.Flush(10)
        checkWide()
        field.label.stringHeight = nil
        field:RefreshLayout()
        environment.Flush(10)
        checkWide()

        local left, right = layout:GetContentInsets()
        local gap = layout:GetStyleValue("columnGap")
        local rowGap = layout:GetStyleValue("rowGap")
        local start = layout:GetStyleValue("paddingTop")
        local threshold = 3 * 180 + 2 * gap
        for _, width in ipairs({ threshold, threshold - 1, 900, 400, threshold }) do
            layout:SetSize(width + left + right, 200)
            environment.Flush(10)
            if width < threshold then
                assert(checkbox.point[5] == -start, "stacked controls must discard alignment padding")
                assert(field.point[5] == checkbox.point[5] - checkbox:GetHeight() - rowGap)
                assert(color.point[5] == field.point[5] - field:GetHeight() - rowGap)
            else
                checkWide()
            end
            assert(environment.framesCreated == frameCount, "alignment must retain existing controls")
            assert(following:HasFocus() and following:GetText() == "Pending edit" and commits == 0)
            assert(checkbox:GetValue() and color:GetValue().r == 0.5)
        end

        columns[2]:SetShown(false)
        environment.Flush(10)
        assert(checkbox.point[5] == -start and color.point[5] == -start,
            "without a titled neighbor, compact controls must return to the row top")
        columns[1]:SetShown(false)
        environment.Flush(10)
        assert(color.point[5] == -start, "a single remaining control must reserve no alignment gap")
        columns[3]:SetShown(false)
        environment.Flush(10)
        assert(following.point[5] == -start, "an entirely hidden row must occupy no space")

        following:CancelAndClearFocus()
        parent:Hide()
        columns[1]:SetShown(true)
        columns[2]:SetShown(true)
        columns[3]:SetShown(true)
        layout:SetSize(900, 200)
        parent:Show()
        parent.scripts.OnShow(parent)
        environment.Flush(10)
        checkWide()
        local checkboxY, followingY = checkbox.point[5], following.point[5]
        for _ = 1, 3 do
            layout:RefreshLayout()
            environment.Flush(10)
            assert(checkbox.point[5] == checkboxY and following.point[5] == followingY,
                "alignment must not accumulate offsets on repeated reflows")
        end
    end

    local environment = newEnvironment()
    local lib = loadVersion(environment, false)
    local parent = environment.CreateFrame("Frame")
    local layout = lib:CreateCanvasLayout(parent, { width = 800, height = 200 })
    local root = layout:GetRootFlow()
    local examples = {}
    local function addExample(kind, options, input)
        local columns = root:BeginColumns({ minColumnWidth = 200, verticalAlign = "input" })
        local control = columns.left:AddControl(kind, options)
        local checkbox = columns.right:AddControl("checkbox", { label = "Enabled" })
        columns:Finish()
        examples[#examples + 1] = { control = control, checkbox = checkbox, input = input }
        return control
    end

    for _, kind in ipairs({ "dropdown", "slider" }) do
        local function getInput(control)
            return control.dropdown or control.inputRow
        end
        for _, label in ipairs({ "Choice", "" }) do
            addExample(kind, { label = label, minValue = 0, maxValue = 100, step = 1, value = 50 }, getInput)
        end
        for _, position in ipairs({ "top", "left" }) do
            addExample("field", {
                label = "Choice",
                labelPosition = position,
                description = "Help below the input",
                controlType = kind,
                controlOptions = { minValue = 0, maxValue = 100, step = 1, value = 50 },
            }, function(field)
                return getInput(field:GetControl())
            end)
        end
    end
    local values = addExample("field", {
        label = "Values",
        controlType = "valueList",
        controlOptions = { value = { "1", "2", "3", "4", "5", "6" } },
    }, function(field)
        return field:GetControl().entries[1]
    end)
    layout:Finalize()
    environment.Flush(10)
    for _, example in ipairs(examples) do
        assertAligned(example.checkbox, example.input(example.control), layout:GetContent())
    end
    assert(values:GetControl():GetHeight() > 34, "the value-list example must exercise multiple rows")
    values:GetControl():SetValue({ "1" })
    environment.Flush(10)
    assertAligned(examples[#examples].checkbox, values:GetControl().entries[1], layout:GetContent())

    -- Custom frames opt in explicitly; titles and decorative frames do not.
    local columns = root:BeginColumns({ verticalAlign = "input" })
    local decoration = columns.left:AddCustom(80)
    local checkbox = columns.right:AddControl("checkbox", { label = "Custom alignment" })
    columns:Finish()
    layout:Finalize()
    environment.Flush(10)
    assert(checkbox.point[5] == decoration.point[5])
    function decoration:GetInputAlignmentOffset()
        return 60
    end
    layout:RefreshLayout()
    assert(checkbox.point[5] == decoration.point[5] - 60 + checkbox:GetHeight() / 2)
    for _, offset in ipairs({ -1, math.huge, 0 / 0, "invalid" }) do
        decoration.GetInputAlignmentOffset = function()
            return offset
        end
        assert(not pcall(lib._GetInputAlignmentOffset, lib, decoration))
    end
    decoration.GetInputAlignmentOffset = function() end
    assert(not pcall(lib._GetInputAlignmentOffset, lib, decoration))
    print("LibModernSettings input-aligned column tests passed")
end
