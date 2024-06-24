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
    [KEY_LCTRL] = true,
    [KEY_RCTRL] = true,
    [KEY_TAB] = true,
}

-- Keep CTRL from toggling remote execute if you press enter
Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    Log("OnRawKeyHandler %d %s", key, tostring(down))
    local mod_down = TheInput:IsKeyDown(KEY_LCTRL) or TheInput:IsKeyDown(KEY_RCTRL)
                  or TheInput:IsKeyDown(KEY_LALT) or TheInput:IsKeyDown(KEY_RALT)
    if mod_down and CTRL_KEYS[key] then
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

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
    for key in pairs(CTRL_KEYS) do
        screen.console_edit.validrawkeys[key] = true
    end
    for key in pairs(Config.REMOTETOGGLEKEYS) do
        screen.console_edit.validrawkeys[key] = true
    end
end)

return {
    ["test ctrl keybinds not triggering remote toggle"] = function ()
        local temp = State(Config, "REMOTETOGGLEKEYS", {
            [KEY_LCTRL] = true,
            [KEY_RCTRL] = true,
        })
        local screen = Tester.OpenConsole()
        if not screen.console_remote_execute.shown then
            return Tester.CONDITIONS_NOT_MET
        end
        screen:ToggleRemoteExecute(true)
        Tester.WithKeysDown({ KEY_LCTRL }, Tester.PressEnter)
        Assert(screen.toggle_remote_execute, "Ctrl+Enter shouldn't toggle remote execute")
        Tester.WithKeysDown({ KEY_RCTRL }, Tester.SendKey, KEY_LEFT)
        Assert(screen.toggle_remote_execute, "Ctrl+left/right shouldn't toggle remote execute")
        Tester.WithKeysDown({ KEY_LCTRL }, Tester.SendKey, KEY_BACKSPACE)
        Assert(screen.toggle_remote_execute, "Ctrl+backspace shouldn't toggle remote execute")
        Tester.SendKey(KEY_LCTRL)
        Assert(not screen.toggle_remote_execute, "Ctrl should toggle remote execute")
        temp:Purge()
    end,

    ["test Config.REMOTETOGGLEKEYS alt"] = function ()
        local temp = State(Config, "REMOTETOGGLEKEYS", {
            [KEY_LCTRL] = false,
            [KEY_RCTRL] = false,
            [KEY_LALT] = true,
            [KEY_RALT] = true,
        })
        local screen = Tester.OpenConsole()
        if not screen.console_remote_execute.shown then
            return Tester.CONDITIONS_NOT_MET
        end
        screen:ToggleRemoteExecute(true)
        Tester.SendKey(KEY_CTRL)
        Assert(screen.console_edit.toggle_remote_execute, "Ctrl shouldn't toggle remote execute here")
        Tester.SendKey(KEY_ALT)
        Assert(not screen.console_edit.toggle_remote_execute, "Alt should toggle remote execute here")
        temp:Purge()
    end,
}
