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

local function getpossiblekeys(str, search_start)
    local tnames, calls = {}, {}
    local expressionstart
    local lastindexer = str:sub(search_start-1, search_start-1)
    -- We start at the end and go backwards matching indexing
    for wstart, word, call, indexer in keymatches_gen, str, search_start do
        expressionstart = wstart
        table.insert(tnames, word)

        if call == "()" then
            calls[#tnames] = "func"
        elseif call ~= "" then
            -- Invalid
            return
        end

        if indexer == ":" then
            -- t:func().
            local lastcall = #tnames - 1
            if calls[lastcall] == "func" then calls[lastcall] = "method" end
        end
        lastindexer = indexer
    end
    if #tnames <= 0 then return end

    local t = rawglobal
    for i = #tnames, 1, -1 do
        local prevtbl = t
        -- Next layer in table
        t = t[tnames[i]]
        if calls[i] and iscallable(t) then
            t = t(calls[i] == "method" and prevtbl or nil)
        end
        if not isindexable(t) then return end
    end

    local keys = {}
    local onlyfuncs = str:byte(search_start - 1) == string.byte(':')
    local tbls = {}
    -- For now I don't handle recursive __index chains
    local prevtbl
    for i,tbl in ipairs {t, GetMetaField(t, '__index')} do
        if type(tbl) == "table" then
            for k,v in pairs(tbl) do
                if type(k) == "string" and (not onlyfuncs or iscallable(v)) and (not prevtbl or prevtbl[k] == nil) then
                    -- Key is a string
                    -- If `:`, value must be callable
                    -- Key shouldn't be a duplicate
                    table.insert(keys, k)
                end
            end
            prevtbl = tbl
        end
    end
    if #keys == 0 then return end

    local matches = {}
    local inds = {}
    local search_string = str:sub(search_start)
    if not Config.CASESENSITIVE then search_string = search_string:lower() end
    for _, word in ipairs(keys) do
        inds[word] = (Config.CASESENSITIVE and word or word:lower()):find(search_string, 1, true)
        if inds[word] then table.insert(matches, word) end
    end

    if #matches == 1 and matches[1] == search_string then return end

    -- Sort first by start index and then alphabetically
    table.sort(matches, function(a, b) return inds[a] == inds[b] and a < b or inds[a] < inds[b] end)

    return expressionstart, matches
end

local function getsearchstart(str)
    return str:match("[.:]()[%w_]*$")
end

local function forcewordprediction(wp, str, exprstart, matches)
    local dic = {
        words = matches,
        delim = str:sub(exprstart),
        num_chars = 0,
        GetDisplayString = simple_get_display_string,
        postfix = "",
    };
    local search_start = getsearchstart(str)
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

local function findindexing(text, cursorpos)
    local _, endw = text:find("[%w_]*", cursorpos+1)
    return endw or cursorpos
end

AddModRPCHandler(RPC_NAMESPACE, "RequestCompletions", function(player, str)
    -- Temp inject "ThePlayer" into console
    local saved_ThePlayer = G.ThePlayer
    G.ThePlayer = player

    local exprstart, matches = getpossiblekeys(str, getsearchstart(str))
    if not matches then return end
    SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "Completions"), player.userid, str, exprstart, table.concat(matches, '\n'))

    G.ThePlayer = saved_ThePlayer
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
    local endpos = findindexing(text, #completestr)

    local str = text:sub(1, endpos)
    local wp = scrn.console_edit.prediction_widget.word_predictor
    wp.text = text
    
    forcewordprediction(wp, str, exprstart, matches)

    _ignore = true
    scrn.console_edit.prediction_widget:RefreshPredictions()
end)

local _completionrequest_task
function TryComplete(prediction_widget, text, pos, remote_execute)
    local wp = prediction_widget.word_predictor
    -- only doing this to force refresh the buttons
    if _ignore then _ignore = false return true end

    pos = findindexing(text, pos)
    local str = text:sub(1, pos)
    local search_start = getsearchstart(str)
    if not search_start then return false end

    wp.text = text
    wp.cursor_pos = pos
    --wp.prediction = nil

    if modinfo.client_only_mod or IS_DEDICATED or not remote_execute then
        local exprstart, matches = getpossiblekeys(str, search_start)
        if not matches then
            wp:Clear()
            return true
        end
        forcewordprediction(wp, str, exprstart, matches)
    else
        -- We don't want to be doing multiple of these reqests in a frame
        if _completionrequest_task then
            _completionrequest_task:Cancel()
            _completionrequest_task = nil
        end
        _completionrequest_task = prediction_widget.text_edit.inst:DoTaskInTime(0, function()
            SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestCompletions"), str)
        end)
    end

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
