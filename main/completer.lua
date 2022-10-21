local G = GLOBAL
local WordPredictor = require "util/wordpredictor"

local indexing_regexp = '()'       --> start index
                     .. '([%w_]+)' --> word
                     .. '%s*'
                     .. '(%(?%)?)' --> optional call --support only for simple calls
                     .. '%s*'
                     .. '([.:])'   --> indexer
                     .. '%s*'
                     .. '$'

local function keymatches_gen(str, pos)
    pos = pos - 1
    -- foo:bar().baz.
    --    ^-----^---^---- pos
    -- Start index of match returned is the control variable!
    -- Becomes end index of next match
    return str:sub(1, pos):match(indexing_regexp)
end

--bypass strict.lua
local rawglobal = G.setmetatable({}, {__index=function(_, k) return rawget(G, k) end})
local simple_get_display_string = function(word) return word end

local function iscallable(v)
    return type(v) == "function" or type(GetMetaField(v, "__call")) == "function"
end

local function isindexable(v)
    return type(v) == "table" or type(GetMetaField(v, "__index")) == "table"
end

local function findtable(str)
    local search_start = str:find("[%w_]*$")
    local indices = {}
    -- Zero index is the one we're completing
    indices[0] = { identifier = str:sub(search_start) }
    local expressionstart
    -- We start at the end and go backwards matching indexing
    for wstart, word, call, indexer in keymatches_gen, str, search_start do
        expressionstart = wstart
        local len = #indices
        indices[len+1] = {
            identifier = word,
            call = call,
            indexer = nil,
        }

        -- Set indexer of previous match
        indices[len].indexer = indexer
    end

    return indices, expressionstart
end

local class_prop__index = Class(nil, nil, {}).__index

local function getpossiblekeys(indices, theplayer)
    -- Temp inject "ThePlayer" into console
    local saved_ThePlayer = G.ThePlayer
    G.ThePlayer = theplayer

    local t = rawglobal
    for i = #indices, 1, -1 do
        local key = indices[i]
        local prevtbl = t
        -- Next layer in table
        t = t[key.identifier]
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

    for k,v in pairs(t) do insertkey(k,v) end

    if type(indexer) == "table" then
        for k,v in pairs(indexer) do
            -- don't want duplicate keys
            if rawget(t, k) == nil then insertkey(k,v) end
        end

    elseif type(indexer) == "function" then
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

local function forcewordprediction(wp, str, exprstart, matches)
    local dic = {
        words = matches,
        delim = str:sub(exprstart),
        num_chars = 0,
        GetDisplayString = simple_get_display_string,
        postfix = "",
    };
    local search_start = str:find("[%w_]*$")
    if search_start and #matches > 0 then
        wp.prediction = {
            start_pos = search_start-1,
            matches = matches,
            dictionary = dic,
        }
    else
        wp:Clear()
    end
end

local function find_word_end(text, cursorpos)
    local _, endw = text:find("^[%w_]*", cursorpos+1)
    return endw or cursorpos
end

AddModRPCHandler(RPC_NAMESPACE, "RequestCompletions", function(player, str)
    local indices, exprstart = findtable(str)
    local matches = getpossiblekeys(indices, player)
    if not matches then return end
    SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "Completions"), player.userid, str, exprstart, table.concat(matches, '\n'))
end)

AddModRPCHandler(RPC_NAMESPACE, "RequestGlobalCompletions", function(player, str)
    local start = os.clock()
    local search_string = str:match("[%w_]+$")
    local matches = getpossiblekeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, player)
    if matches then
        SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "Completions"),
                           player.userid,
                           str,
                           #str - #search_string,
                           table.concat(matches, '\n'))
    end
end)

local _ignore = false

AddClientModRPCHandler(RPC_NAMESPACE, "Completions", function(completestr, exprstart, matches)
    -- Check console screen is still open
    local scrn = TheFrontEnd:GetActiveScreen()
    if scrn.name ~= "ConsoleScreen" then return end
    -- Check text still starts the same
    local text = scrn.console_edit:GetString()
    if not text:sub(1, #completestr) == completestr then return end

    matches = matches:split('\n')
    local endpos = find_word_end(text, #completestr)

    local str = text:sub(1, endpos)
    local wp = scrn.console_edit.prediction_widget.word_predictor
    wp.text = text
    
    forcewordprediction(wp, str, exprstart, matches)

    _ignore = true
    scrn.console_edit.prediction_widget:RefreshPredictions()
end)

-- We don't want to be doing multiple server reqests in a frame
local set_completion_request_task
do
    local _task
    set_completion_request_task = function (callback)
        local screen = TheFrontEnd:GetActiveScreen()
        if screen.name == "ConsoleScreen" then
            if _task then _task:Cancel() end
            _task = screen.inst:DoTaskInTime(0, callback)
        end
    end
end

local function match_string_literal(str, i, delim)
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

local function match_long_string_literal(str, i, delim)
    local _, _end = str:find("%]"..delim.."%]", i)
    return _end
end

local function long_literal_delim(str, i)
    return str:match("%[(=*)%[", i)
end

local function match_comment(str, i)
    assert(str:sub(i, i+1) == "--")
    i = i + 2
    if longcomment then
        return match_long_string_literal(str, i, longcomment)
    else
        for i = i, #str do
            if str:sub(i, i) == '\n' then return i end
        end
    end
end

local function is_in_string_or_comment(str)
    local i = 1
    repeat
        local c = str:sub(i, i)
        if c == '\'' or c == '\"' then
            i = match_string_literal(str, i, c)
        elseif c == '-' then
            if str:sub(i+1, i+1) == '-' then
                i = match_comment(str, i)
            end
        else
            local long = long_literal_delim(str, i)
            if long then i = match_long_string_literal(str, i, long) end
        end
        if not i then return true end
        i = i + 1
    until i > #str
    return false
end

local ignored_searches = {
    ["do"] = true,
    ["then"] = true,
    ["end"] = true,
}
function TryComplete(prediction_widget, text, cursor_pos, remote_execute)
    local wp = prediction_widget.word_predictor
    -- only being called to force refresh the buttons
    if _ignore then _ignore = false return true end

    local pos = find_word_end(text, cursor_pos)
    local str = text:sub(1, pos)
    local search_start = str:find("[%w_]*$")
    local running_in_client = modinfo.client_only_mod or IS_DEDICATED or not remote_execute
    local indexer = str:sub(search_start-1, search_start-1)
    if indexer == '.' or indexer == ':' then
        if running_in_client then
            local indices, exprstart = findtable(str)
            local matches = getpossiblekeys(indices, G.ThePlayer)
            if not matches then
                wp:Clear()
                return true
            end
            forcewordprediction(wp, str, exprstart, matches)
        else
            set_completion_request_task(function()
                SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestCompletions"), str)
            end)
        end

    elseif search_start <= pos then
        local search_string = str:sub(search_start)

        if tonumber(search_string:sub(1, 1)) or ignored_searches[search_string] then
            wp:Clear()
            return true
        elseif is_in_string_or_comment(str) then
            -- Match prefab names
            return false
        end

        if running_in_client then
            if Config.AUTOCOMPLETING then
                local matches = getpossiblekeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, G.ThePlayer)
                if not matches then
                    wp:Clear()
                    return true
                end
                forcewordprediction(wp, str, search_start, matches)
            end
        elseif Config.AUTOCOMPLETING then
            -- We don't want to be doing multiple of these reqests in a frame
            -- So each one overwrites the previous
            set_completion_request_task(function()
                SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestGlobalCompletions"), str)
            end)
        else return end
    else return end

    wp.text = text
    wp.cursor_pos = pos
    --wp.prediction = nil

    return true
end

-- Modified to support completing in the middle
AssertDefinitionSource(WordPredictor, "Apply", "scripts/util/wordpredictor.lua")
function WordPredictor:Apply(prediction_index)
    -- COPY PASTED
	local new_text = nil
	local new_cursor_pos = nil
	if self.prediction ~= nil then
		local new_word = self.prediction.matches[math.clamp(prediction_index or 1, 1, #self.prediction.matches)]

		new_text = self.text:sub(1, self.prediction.start_pos) .. new_word .. self.prediction.dictionary.postfix
		new_cursor_pos = #new_text

        --[[OLD]]--local endpos = FindEndCursorPos(self.text, self.cursor_pos)
		--[[NEW]]local endpos = self.prediction.start_pos + (delim and #delim or 0)
		local remainder_text = self.text:sub(endpos+1) or ""
		local remainder_strip_pos = remainder_text:find("[^a-zA-Z0-9_]") or (#remainder_text + 1)
		if self.prediction.dictionary.postfix ~= "" and remainder_text:sub(remainder_strip_pos, remainder_strip_pos + (#self.prediction.dictionary.postfix-1)) == self.prediction.dictionary.postfix then
			remainder_strip_pos = remainder_strip_pos + #self.prediction.dictionary.postfix
		end

		new_text = new_text .. remainder_text:sub(remainder_strip_pos)
	end

	self:Clear()
	return new_text, new_cursor_pos
end
