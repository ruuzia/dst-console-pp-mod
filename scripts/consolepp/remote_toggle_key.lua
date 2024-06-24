-- Apply Config.REMOTETOGGLEKEYS setting and keep hotkey shortcuts
-- from triggering remote toggle

setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

local CTRL_KEYS = {
    [KEY_ENTER] = true,
    [KEY_LEFT] = true,
    [KEY_RIGHT] = true,
    [KEY_BACKSPACE] = true,
}

-- Keep CTRL from toggling remote execute if you press enter
Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    local ctrl_down = TheInput:IsKeyDown(KEY_LCTRL) or TheInput:IsKeyDown(KEY_RCTRL)
    if ctrl_down and CTRL_KEYS[key] then
        screen.ctrl_pasting = true

    elseif Config.REMOTETOGGLEKEYS[key] and not down then
        if not screen.ctrl_pasting then
            screen:ToggleRemoteExecute()
            screen.ctrl_pasting = false
            return true
        end
    end

    return orig(screen, key, down, ...)
end)

-- Oh and we need to do this too
Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
    for key in pairs(CTRL_KEYS) do
        screen.console_edit.validrawkeys[key] = true
    end
end)

return {}
