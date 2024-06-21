-- Dynamically complete global variables and/or field names.
--
setfenv(1, ConsolePP.env)
local G = GLOBAL

local WordPredictor = require "util/wordpredictor"
local ConsoleScreen = require "screens/consolescreen"

local Handler = Require "cpm_dynamic_completion.handler"

Hook(WordPredictor, "RefreshPredictions", function (orig, self, text, cursor_pos, ...)
    local screen = TheFrontEnd:GetActiveScreen()
    if screen.name == "ConsoleScreen" then
        local dynamic_completions = Handler.TryComplete(self, text, cursor_pos, screen.toggle_remote_execute)
        if dynamic_completions ~= nil then
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

Require "cpm_dynamic_completion.support_completing_in_middle"

return {
    tests = {
        ["test global word prediction"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("ConsoleP")
            local prediction_widget = screen.console_edit.prediction_widget
            Assert(#prediction_widget.prediction_btns > 0)
            AssertEq(screen.console_edit:GetString(), "ConsoleP")
            AssertEq(prediction_widget.prediction_btns[1]:GetText(), "ConsolePP")
            -- Accept completion
            Tester.PressEnter()
            AssertEq(screen.console_edit:GetString(), "ConsolePP")
            AssertEq(#prediction_widget.prediction_btns, 0)
        end,
    }
}
