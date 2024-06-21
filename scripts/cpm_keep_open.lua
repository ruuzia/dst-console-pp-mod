setfenv(1, ConsolePP.env)
local G = GLOBAL

local ConsoleScreen = require "screens/consolescreen"

Hook(ConsoleScreen, "OnTextEntered", function (orig, screen, ...)
    local ctrl_down = TheInput:IsKeyDown(KEY_CTRL)

    if Config.KEEPCONSOLEOPEN and not ctrl_down
        or not Config.KEEPCONSOLEOPEN and ctrl_down
    then
        -- Run without closing console
        screen:Run()
        G.ConsoleScreenSettings:Save()
        screen.console_edit:SetString("")
        screen.console_edit:SetEditing(true)
        -- Go to end of history
        screen.history_idx = nil
    else
        return orig(screen, ...)
    end
end)

-- Keep CTRL from toggling remote execute if you press enter
Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    if key == KEY_ENTER and TheInput:IsKeyDown(KEY_CTRL) then
        screen.ctrl_pasting = true
    end
    return orig(screen, key, down, ...)
end)

-- Oh and we need to do this too
Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
	screen.console_edit.validrawkeys[KEY_ENTER] = true
end)

return {
    tests = {
        -- Test for bug where history idx was off
        ["test history updates properly on force run"] = function ()
            Impurities:New(Config, "KEEPCONSOLEOPEN", true)
            local screen = Tester.OpenConsole()
            screen:ToggleRemoteExecute(true)

            Tester.SendTextInput("--foo")
            Tester.PressEnter()

            Tester.SendKey(KEY_UP)
            AssertEq(screen.console_edit:GetString(), "--foo")
            Tester.SendTextInput("bar")
            Tester.PressEnter()

            Tester.SendKey(KEY_UP)
            AssertEq(screen.console_edit:GetString(), "--foobar")
            Tester.SendTextInput("bar")
            Tester.PressEnter()
            AssertEq(screen.console_edit:GetString(), "")
--fooba--foobarr
            Impurities:Restore(Config, "KEEPCONSOLEOPEN")
        end,
    }
}
