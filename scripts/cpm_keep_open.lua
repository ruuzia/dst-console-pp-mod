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
    else
        return orig(screen, ...)
    end
end)

return {
    tests = {
    }
}
