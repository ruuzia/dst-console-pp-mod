-- TODO: proper Lua lexer
-- But for now we have this gobbledygook
--
setfenv(1, ConsolePP.env)
local G = GLOBAL

Lua = {}

local function consume_string_literal(str, i, delim)
    assert(str:sub(i, i) == delim)
    repeat
        i = i + 1
        local c = str:sub(i, i)
        if c == '\\' then
            -- Skip (escape) next character
            i = i + 1
        elseif c == delim then
            return i
        end
    until i > #str
    -- String didn't end
end

local function consume_long_string_literal(str, i, delim)
    local _, _end = str:find("%]"..delim.."%]", i)
    return _end
end

local function long_string_literal(str, i)
    return str:match("%[(=*)%[", i)
end

local function consume_comment(str, i)
    assert(str:sub(i, i+1) == "--")
    i = i + 2
    if longcomment then
        return consume_long_string_literal(str, i, longcomment)
    else
        for i = i, #str do
            if str:sub(i, i) == '\n' then return i end
        end
    end
end

function Lua.IsUnfinishedStringOrComment(str)
    local i = 1
    while i <= #str do
        local c = str:sub(i, i)
        if c == '\'' or c == '\"' then
            i = consume_string_literal(str, i, c)
        elseif c == '-' then
            if str:sub(i+1, i+1) == '-' then
                i = consume_comment(str, i)
            end
        else
            local delim = long_string_literal(str, i)
            if delim then i = consume_long_string_literal(str, i, delim) end
        end
        -- Was the entire string consumed?
        if not i then return true end
        i = i + 1
    end
    return false
end
