-- When opening the console, default remote execute toggle to
-- the last executed command.
--
setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

-- We must run after the game's OnBecomeActive but before
-- the shard log's hook
Hook(ConsoleScreen, "OnBecomeActive", function (orig, self, ...)
    local ret = { orig(self, ...) }

    local history = G.ConsoleScreenSettings:GetConsoleHistory()
    local historyline = history and history[#history]
    if historyline == nil then
        Log "defaulting to true"
        -- Default to true
        self:ToggleRemoteExecute(true)
    else
        self:ToggleRemoteExecute(historyline.remote or false)
    end

    return unpack(ret)
end)

return {
    tests = {
        ["test saving last remote"] = function ()
            Impurities:Set(Config, "KEEPCONSOLEOPEN", false)
            if not TheNet:GetIsClient() then
                Log("Must be client in server to run this test")
                return
            end
            local screen = Tester.OpenConsole()
            screen:ToggleRemoteExecute(false)
            Tester.SendTextInput("-- testing non-remote toggle")
            Tester.PressEnter()
            screen = Tester.OpenConsole()
            AssertEq(screen.toggle_remote_execute, false)
            Impurities:Restore(Config, "KEEPCONSOLEOPEN")
        end,
    }
}
