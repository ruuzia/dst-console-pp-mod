setfenv(1, ConsolePP.env)
local G = GLOBAL
local Handler = {}

local Predictor = Require 'cpm_dynamic_completion.prediction'

local SimpleGetDisplayString = function(word) return word end
local function ForceWordPrediction(wp, str, exprstart, matches)
    local dic = {
        words = matches,
        delim = str:sub(exprstart),
        num_chars = 0,
        GetDisplayString = SimpleGetDisplayString,
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

local function FindWordEnd(text, cursorpos)
    local _, endw = text:find("^[%w_]*", cursorpos+1)
    return endw or cursorpos
end

AddModRPCHandler(RPC_NAMESPACE, "RequestCompletions", function(player, str)
    local indices, exprstart = Predictor.FindTable(str)
    if not indices then return end
    local matches = Predictor.GetPossibleKeys(indices, player)
    if not matches then return end
    SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "Completions"), player.userid, str, exprstart, table.concat(matches, '\n'))
end)

AddModRPCHandler(RPC_NAMESPACE, "RequestGlobalCompletions", function(player, str)
    local search_string = str:match("[%w_]+$")
    local matches = Predictor.GetPossibleKeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, player)
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
    local scrn = Predictor.TheFrontEnd:GetActiveScreen()
    if scrn.name ~= "ConsoleScreen" then return end
    -- Check text still starts the same
    local text = scrn.console_edit:GetString()
    if not text:sub(1, #completestr) == completestr then return end

    matches = matches:split('\n')
    local endpos = FindWordEnd(text, #completestr)

    local str = text:sub(1, endpos)
    local wp = scrn.console_edit.prediction_widget.word_predictor
    wp.text = text

    ForceWordPrediction(wp, str, exprstart, matches)

    _ignore = true
    scrn.console_edit.prediction_widget:RefreshPredictions()
end)

-- We don't want to be doing multiple server reqests in a frame
local SetCompletionRequestTask
do
    local _task
    SetCompletionRequestTask = function (callback)
        local screen = TheFrontEnd:GetActiveScreen()
        if screen.name == "ConsoleScreen" then
            if _task then _task:Cancel() end
            _task = screen.inst:DoTaskInTime(0, callback)
        end
    end
end

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

local function is_in_string_or_comment(str)
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

local ignored_searches = {
    ["do"] = true,
    ["then"] = true,
    ["end"] = true,
}
function Handler.TryComplete(wp, text, cursor_pos, remote_execute)
    -- only being called to force refresh the buttons
    if _ignore then _ignore = false return true end

    local pos = FindWordEnd(text, cursor_pos)
    local str = text:sub(1, pos)
    local search_start = str:find("[%w_]*$")
    local running_in_client = modinfo.client_only_mod or IS_DEDICATED or not remote_execute
    local indexer = str:sub(search_start-1, search_start-1)

    if indexer == '.' or indexer == ':' then
        -- Chain index completion (e.g: tree.apple.components.juiceable:Squeez)
        if running_in_client then
            local indices, exprstart = Predictor.FindTable(str)
            if indices then
                local matches = Predictor.GetPossibleKeys(indices, G.ThePlayer)
                if not matches then
                    wp:Clear()
                    return true
                end
                ForceWordPrediction(wp, str, exprstart, matches)
            end
        else
            SetCompletionRequestTask(function()
                SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestCompletions"), str)
            end)
        end

    elseif search_start <= pos then
        -- Global completions
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
                local matches = Predictor.GetPossibleKeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, G.ThePlayer)
                if not matches then
                    wp:Clear()
                    return true
                end
                ForceWordPrediction(wp, str, search_start, matches)
            end
        elseif Config.AUTOCOMPLETING then
            -- We don't want to be doing multiple of these reqests in a frame
            -- So each one overwrites the previous
            SetCompletionRequestTask(function()
                SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestGlobalCompletions"), str)
            end)
        else return end
    else return end

    wp.text = text
    wp.cursor_pos = pos
    --wp.prediction = nil

    return true
end

return Handler
