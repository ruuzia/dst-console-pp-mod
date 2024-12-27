setfenv(1, ConsolePP.env)
local G = GLOBAL

local ConsoleScreen = require "screens/consolescreen"

local function ShouldForceRun()
    local ctrl_down = TheInput:IsKeyDown(KEY_CTRL)

    return Config.KEEPCONSOLEOPEN and not ctrl_down
        or not Config.KEEPCONSOLEOPEN and ctrl_down
end

Hook(ConsoleScreen, "OnTextEntered", function (orig, screen, ...)
    if ShouldForceRun() then
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

return {
    tests = {
        -- Test for bug where history idx was off
        ["test history updates properly on force run"] = function ()
            Impurities:Set(Config, "KEEPCONSOLEOPEN", true)
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
