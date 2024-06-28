-- The game's WordPredictor utility class generally
-- works well for our purposes, except that it typically
-- tries to complete from the end of the text rather than
-- from the current word. We have to override a small local
-- helper function to fix this.

setfenv(1, ConsolePP.env)
local G = GLOBAL

local WordPredictor = require "util/wordpredictor"

local function FindEndCursorPos(text, cursor_pos)
	return cursor_pos
end

for _, fn in pairs(WordPredictor) do
    if type(fn) == "function" then
        RecursiveUpvalueHijack(fn, "FindEndCursorPos", FindEndCursorPos)
    end
end

return {
    tests = {
        ["test completing in middle"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput(" c_spawn('abigail')")
            Tester.SendKey(KEY_HOME)
            Tester.SendTextInput("c_give('abiga")
            Assert(#screen.console_edit.prediction_widget.prediction_btns > 0)
        end
    }
}
