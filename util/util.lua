local G = GLOBAL

---@param loc table
---@param idx string
---@param wrapper fun(old: function, ...): any
function Hook(loc, idx, wrapper)
    local orig = modassert(loc[idx], "no decorator function")
    assert(type(orig) == "function")
    Impurities:Set(loc, idx)
    loc[idx] = function(...)
        return wrapper(orig, ...)
    end
end

function Require(modname)
    -- Force reload
    Impurities:Package(modname)
    return require(modname)
end

local nlchar = ('\n'):byte()

function printf(fmt, ...)
    print(string.format(fmt, ...))
end

---@param s string
---@param idx number
---@return number?
function StrGetLineStart(s, idx, utf8)
    local uidx_dif = 0
    for i = idx, 1, -1 do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i + 1 --one *after* newline
        elseif utf8 and byte >= 128 + 64 then
            uidx_dif = uidx_dif - 1
        end
    end
    return 1
end

---@param s string
---@param idx number
---@return number?
---@return number?
function StrGetLineBounds(s, idx, utf8)
    return StrGetLineStart(s, idx, utf8), StrGetLineEnd(s, idx, utf8)
end

---@param s string
---@param idx number
---@return number?
function StrGetLineEnd(s, idx, utf8)
    local uidx_dif = 0
    for i = idx+1, #s do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i - 1 --one *before* newline
        elseif utf8 and byte >= 128 + 64 --[[0b11000000]] then
            uidx_dif = uidx_dif - 1
        end
    end
    return #s + uidx_dif
end

local Widget = require "widgets/widget"
AddGamePostInit(function ()
    --- hot reload ---
    if ConsolePP.save.PsuedoText then
        print("Removing old hacktext")
        ConsolePP.save.PsuedoText:Kill()
    end
    ------------------
    local psuedotext = Widget()
    ConsolePP.save.PsuedoText = psuedotext

    psuedotext.inst.entity:AddTextWidget()
    psuedotext:Hide()

    function CalcTextRegionSize(str, font, size)
        local textwidget = psuedotext.inst.TextWidget
        textwidget:SetSize(size * (G.LOC and G.LOC.GetTextScale() or 1))
        textwidget:SetFont(font)
        textwidget:SetString(str)
        return textwidget:GetRegionSize()
    end
end)

function TextBoxXPosToCol(textfont, textsize, xpos, line, substring)
    substring = substring or string.utf8sub
    local prevwidth = 0
    local index
    for i = 1, #line do
        local width = CalcTextRegionSize(substring(line, 1, i), textfont, textsize)
        if width > xpos then
            index = width - xpos < xpos - prevwidth and i or i - 1
            break
        end
        prevwidth = width
    end
    return index or #line
end

function TextBoxStringToPos(font, size, line)
    if line == "" then return 0 end --GetRegionSize would return 2^127
    return CalcTextRegionSize(line, font, size)
end

---@param t table
---@param name string
---@param expected string
function AssertDefinitionSource(t, name, expected)
    local info = debug.getinfo(t[name], "S")
    if info.source == expected or --[[ support reload ]] info.source:sub(1, #MODROOT) == MODROOT then return end
    printf("[%s] ======== WARNING ===============", modname)
    printf("[%s] %q definition expected in file %q, but found in %q. Running with an incompatible mod?", modname, name, expected, info.source)
    printf("[%s] ================================", modname)
end

local MIN_NO_RECURSE = 100
function PrettyPrint(v)
    if type(v) == "table" then
        -- If it has a tostring method, call it
        if GetMetaField(v, '__tostring') then
            print(v)
        else
            -- table.inspect can really struggle with big tables (at least with PUC-Lua)
            local tbl = v
            local count = 0
            for _ in pairs(tbl) do
                count = count + 1
                if count >= MIN_NO_RECURSE then break end
            end
            print(table.inspect(tbl, count < MIN_NO_RECURSE and 2 or 1))
        end
    else
        print(v)
    end
end

---@param lua string
function CodeMissingClosingStatement(lua)
    -- lmao why do I do this with regex
    local encoded = lua:gsub("\\.", "")              --remove escapes
                       :gsub("%-%-(%[=*%[)", "%1")   --remove leading `--` in multiline comment
                       :gsub("%[(=*)%[.-%]%1%]", "") --remove multiline strings
                       :gsub("%-%-[^\n]+", "")       --remove single line comments
                       :gsub("(['\"]).-%1", "")      --remove single and double quote strings

    if encoded:find("%[=*%[") then return true end

    local stat = {
        ["function"] = 0, ["do"] = 0, ["if"] = 0,
        ["end"] = 0, ["repeat"] = 0, ["until"] = 0,
        ["for"] = 0, ["while"] = 0, ["then"] = 0,
        ["elseif"] = 0
    }

    for word in encoded:gmatch("[%w_]+") do
        if stat[word] then
            stat[word] = stat[word] + 1
        end
    end

    return stat["function"] + stat["do"] + stat["if"] > stat["end"]
        or stat["repeat"]                             > stat["until"]
        or stat["if"]       + stat["elseif"]          > stat["then"]
        or stat["for"]      + stat["while"]           > stat["do"]
end

function GetMetaField(t, k)
    local mt = getmetatable(t)
    return mt and mt[k]
end
