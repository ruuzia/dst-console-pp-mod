setfenv(1, ConsolePP.env)
local G = GLOBAL
local _M = {}

-- TODO: proper Lua lexer
-- for now we have this gobbledygook
--
local indexing_regexp = '()'       --> start index
                     .. '([%w_]+)' --> word
                     .. '%s*'
                     .. '(%(?%)?)' --> optional call --support only for simple calls
                     .. '%s*'
                     .. '([.:])'   --> indexer
                     .. '%s*'
                     .. '$'

local class_prop__index = Class(nil, nil, {}).__index


local function IndexKeyWalker(str, pos)
    pos = pos - 1
    -- foo:bar().baz.
    --    ^-----^---^---- pos
    -- Start index of match returned is the control variable!
    -- Becomes end index of next match
    return str:sub(1, pos):match(indexing_regexp)
end

local function get(t, k) return t[k] end
-- Currently we call __index metamethods, should we?
local function safeget(t, k)
    local ok, v = pcall(get, t, k)
    if not ok then return nil end
    return v
end

local function iscallable(v)
    return type(v) == "function" or type(GetMetaField(v, "__call")) == "function"
end

local function isindexable(v)
    return type(v) == "table" or type(GetMetaField(v, "__index")) == "table"
end

local function ValidateIdentifer(word)
    return word:find("^[%w_][%a_]*$") ~= nil
end

function _M.FindTable(str)
    local search_start = str:find("[%w_]*$")
    local indices = {}
    -- Zero index is the one we're completing
    local incomplete_word = str:sub(search_start)
    if incomplete_word ~= "" and not ValidateIdentifer(incomplete_word) then return end
    indices[0] = { identifier = incomplete_word }
    local expressionstart
    -- We start at the end and go backwards matching indexing
    for wstart, word, call, indexer in IndexKeyWalker, str, search_start do
        expressionstart = wstart
        local len = #indices
        if not ValidateIdentifer(word) then return end
        indices[len+1] = {
            identifier = word,
            call = call,
            indexer = nil,
        }

        -- Set indexer of previous match
        indices[len].indexer = indexer
    end

    if not expressionstart then return end

    return indices, expressionstart
end

function _M.GetPossibleKeys(indices, theplayer)
    -- Temp inject "ThePlayer" into console
    local saved_ThePlayer = G.ThePlayer
    G.ThePlayer = theplayer

    local t = GLOBAL
    for i = #indices, 1, -1 do
        local key = indices[i]
        local prevtbl = t
        -- Next layer in table
        t = safeget(t, key.identifier)
        if key.call == "()" and iscallable(t) then
            t = t(key.indexer == ":" and prevtbl or nil)
        end
        if not isindexable(t) then return end
    end

    local keys = {}
    local onlyfuncs = indices[0].indexer == ":"

    local insertkey = function(k,v)
        if type(k) == "string"
            and (not onlyfuncs or iscallable(v))    -- If `:`, value must be callable
            and k ~= "_"
        then
            table.insert(keys, k)
        end
    end

    local indexer = GetMetaField(t, '__index')

    local is_table = type(t) == "table"
    if is_table then
        for k,v in pairs(t) do insertkey(k,v) end
    end

    if type(indexer) == "table" then
        for k,v in pairs(indexer) do
            -- don't want duplicate keys
            if not is_table or rawget(t, k) == nil then insertkey(k,v) end
        end
    elseif type(indexer) == "function" then
        -- special handling for class instances
        if indexer == class_prop__index then
            for k,v in pairs(rawget(t, "_")) do insertkey(k,v) end
            for k,v in pairs(getmetatable(t)) do insertkey(k,v) end
        end
    end

    -- Restore
    G.ThePlayer = saved_ThePlayer

    if #keys == 0 then return end

    local matches = {}
    local inds = {}
    local search_string = indices[0].identifier
    --if not Config.CASESENSITIVE then search_string = search_string:lower() end
    for _, word in ipairs(keys) do
        local cased_find = word:find(search_string, 1, true)
        local insensitive_find = word:lower():find(search_string:lower(), 1, true)
        -- Different casing works too, but it exact case match has higher precedence
        inds[word] = cased_find or (insensitive_find and insensitive_find + 0.5) or nil
        if inds[word] then table.insert(matches, word) end
    end

    if #matches == 1 and matches[1] == search_string then return end

    -- Sort first by start index and then alphabetically
    table.sort(matches, function(a, b) return inds[a] == inds[b] and a < b or inds[a] < inds[b] end)

    return matches
end

return _M
