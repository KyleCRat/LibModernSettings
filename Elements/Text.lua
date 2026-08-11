local MAJOR, MINOR = "LibModernSettings-1.0", 2
local lib = LibStub(MAJOR, true)

if not lib or lib._implementationMinor ~= MINOR then
    return
end

function lib:CreateText(parent, options)
    options = options or {}
    assert(type(options) == "table", "text options must be a table")

    local fontString = parent:CreateFontString(nil, "ARTWORK")

    if options.fontObject then
        fontString:SetFontObject(options.fontObject)
    end

    fontString:SetJustifyH(options.justifyH or "LEFT")
    fontString:SetJustifyV(options.justifyV or "TOP")

    if options.width then
        fontString:SetWidth(options.width)
    end

    if options.height then
        fontString:SetHeight(options.height)
    end

    fontString:SetText(options.text or "")

    return fontString
end
