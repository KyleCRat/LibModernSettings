return function(lib)
    dofile("IconPicker/NameData.lua")
    dofile("IconPicker/Names.lua")
    local realIndex = lib._iconNameIndex
    local clientLookup = C_Texture.GetFilenameFromFileDataID
    local calls = 0
    C_Texture.GetFilenameFromFileDataID = function(id)
        calls = calls + 1
        return id == 40 and "Interface\\Icons\\New_Client_Name" or "FileData ID " .. id
    end
    local firstBlock = { 10, 12, "10;First\n12;Second\n" }
    local secondBlock = { 20, 20, "20;Third\n" }
    lib._iconNameIndex = { blocks = { firstBlock, secondBlock } }
    assert(lib:_GetIconFilename(20) == "Interface\\Icons\\Third")
    assert(not firstBlock.names and secondBlock.names and not secondBlock[3],
        "lookups must decode only the requested block and release its packed text")
    assert(lib:_GetIconFilename(10) == "Interface\\Icons\\First")
    assert(lib:_GetIconFilename(12) == "Interface\\Icons\\Second" and calls == 0)
    for _, id in ipairs({ 1, 11, 15, 21 }) do
        assert(lib:_GetIconFilename(id) == nil, "unknown IDs must not become filename labels")
    end
    assert(lib:_GetIconFilename(40) == "Interface\\Icons\\New_Client_Name")
    assert(calls == 5)
    lib._iconNameIndex = realIndex

    local count, previous = 0, 0
    for _, block in ipairs(realIndex.blocks) do
        local packed = block[3]
        local size, first, last = 0, nil, nil
        for id, name in packed:gmatch("(%d+);([^\n]+)") do
            id = tonumber(id)
            assert(id > previous, "the generated index must be unique and sorted")
            assert(lib:_GetIconFilename(id) == "Interface\\Icons\\" .. name)
            previous, last = id, id
            first = first or id
            size = size + 1
        end
        assert(size > 0 and size <= 128)
        assert(block[1] == first and block[2] == last)
        count = count + size
    end
    assert(count == realIndex.count and count > 30000)
    assert(calls == 5, "all generated IDs must resolve without client/session metadata")

    local catalogue = lib:CreateIconCatalogue({
        getFilename = function(id)
            return lib:_GetIconFilename(id)
        end,
        icons = { { texture = 6997112 }, { texture = 8531288 }, { texture = 1 } },
    })
    local search = catalogue:BeginSearch("manaforge")
    assert(search:Step(10) and #search.results == 1 and search.results[1].texture == 6997112)
    search = catalogue:BeginSearch("stegodon")
    assert(search:Step(10) and #search.results == 1 and search.results[1].texture == 8531288)
    search = catalogue:BeginSearch("filedata")
    assert(search:Step(10) and #search.results == 0)
    C_Texture.GetFilenameFromFileDataID = clientLookup
    print("LibModernSettings generated icon-name tests passed")
end
