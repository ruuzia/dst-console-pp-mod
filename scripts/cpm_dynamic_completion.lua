-- Dynamically complete variable and field names.
--
setfenv(1, ConsolePP.env)

local WordPredictor = require "util/wordpredictor"

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


Require "cpm_dynamic_completion.support_completing_in_middle"
