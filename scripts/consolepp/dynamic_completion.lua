-- Dynamically complete global variables and/or field names.
--
setfenv(1, ConsolePP.env)
local G = GLOBAL

local WordPredictor = require "util/wordpredictor"
local ConsoleScreen = require "screens/consolescreen"

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
    local indices, exprstart = Prediction.FindTable(str)
    if not indices then return end
    local matches = Prediction.GetPossibleKeys(indices, player)
    if not matches then return end
    SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "Completions"), player.userid, str, exprstart, table.concat(matches, '\n'))
end)

AddModRPCHandler(RPC_NAMESPACE, "RequestGlobalCompletions", function(player, str)
    local search_string = str:match("[%w_]+$")
    local matches = Prediction.GetPossibleKeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, player)
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

local ignored_searches = {
    ["do"] = true,
    ["then"] = true,
    ["end"] = true,
}

local function TryComplete(wp, text, cursor_pos, remote_execute)
    -- only being called to force refresh the buttons
    if _ignore then _ignore = false return true end

    local pos = FindWordEnd(text, cursor_pos)
    local str = text:sub(1, pos)
    local search_start = str:find("[%w_]*$")
    local running_in_client = modinfo.client_only_mod or IS_DEDICATED or not remote_execute
    local indexer = str:sub(search_start-1, search_start-1)

    if Lua.IsUnfinishedStringOrComment(str) then
        return false
    end

    if indexer == '.' or indexer == ':' then
        -- Chain index completion (e.g: tree.apple.components.juiceable:Squeez)
        if running_in_client and Config.COMPLETINGFIELDS then
            local indices, exprstart = Prediction.FindTable(str)
            if indices then
                local matches = Prediction.GetPossibleKeys(indices, G.ThePlayer)
                if not matches then
                    wp:Clear()
                    return true
                end
                ForceWordPrediction(wp, str, exprstart, matches)
            end
        elseif Config.COMPLETINGFIELDS then
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
        end

        if running_in_client then
            if Config.AUTOCOMPLETING then
                local matches = Prediction.GetPossibleKeys({ [0] = { identifier = search_string }, { identifier = "_G" } }, G.ThePlayer)
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

Hook(WordPredictor, "RefreshPredictions", function (orig, self, text, cursor_pos, ...)
    local screen = TheFrontEnd:GetActiveScreen()
    if screen and screen.name == "ConsoleScreen" then
        local dynamic_completions = TryComplete(self, text, cursor_pos, screen.toggle_remote_execute)
        if dynamic_completions then
            return dynamic_completions
        end
    end
    return orig(self, text, cursor_pos, ...)
end)

-- Refresh completions after ToggleRemoteExecute
Hook(ConsoleScreen, "ToggleRemoteExecute", function (orig, self, ...)
    local ret = { orig(self, ...) }

    self.console_edit.prediction_widget:RefreshPredictions()

    return unpack(ret)
end)

return {
    tests = {
        ["test global word prediction"] = function ()
            local temp = State()
            temp:Set(Config, "ENTERCOMPLETE", true)
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("ConsoleP")
                local prediction_widget = screen.console_edit.prediction_widget
                Assert(#prediction_widget.prediction_btns > 0)
                AssertEq(screen.console_edit:GetString(), "ConsoleP")
                AssertEq(prediction_widget.prediction_btns[1]:GetText(), "ConsolePP")
                Tester.PressEnter()
                AssertEq(screen.console_edit:GetString(), "ConsolePP")
                AssertEq(#prediction_widget.prediction_btns, 0)
            end
            temp:Purge()
        end,
        ["test table word prediction"] = function ()
            G.global "_CPM_foo"
            local temp = State()
            temp:Set(G, "_CPM_foo", {
                bar = { baz = { bat = { Bar = function() end } } }
            })
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("_CPM_foo.bar.baz.bat:")
                local prediction_widget = screen.console_edit.prediction_widget
                AssertEq(#prediction_widget.prediction_btns, 1)
                AssertEq(prediction_widget.prediction_btns[1]:GetText(), "Bar")
            end
            temp:Purge()
        end,

        ["test prefab name completion still works"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("c_spawn(\"beef_b")
            local prediction_widget = screen.console_edit.prediction_widget
            Assert(#prediction_widget.prediction_btns > 0, "should have prefab name predictions")
            AssertEq(prediction_widget.prediction_btns[1]:GetText(), "\"beef_bell\"")
        end,
    },
}
