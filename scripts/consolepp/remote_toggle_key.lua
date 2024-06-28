-- Apply Config.REMOTETOGGLEKEYS setting and keep hotkey shortcuts
-- from triggering remote toggle

setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

local CTRL_KEYBINDS = {
    [KEY_ENTER] = true,
    [KEY_LEFT] = true,
    [KEY_RIGHT] = true,
    [KEY_BACKSPACE] = true,
    [KEY_TAB] = true,
    [KEY_V] = true,
}

-- Keep CTRL from toggling remote execute if you press enter
Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    local ctrl_down = TheInput:IsKeyDown(KEY_LCTRL) or TheInput:IsKeyDown(KEY_RCTRL)

    if ctrl_down and CTRL_KEYBINDS[key] then
        -- Prevent remote toggle
        screen.ctrl_pasting = true
    end

    if Config.REMOTETOGGLEKEYS[key] and not down then
        if not screen.ctrl_pasting then
            screen:ToggleRemoteExecute()
        end
        -- Stop preventing toggle
        screen.ctrl_pasting = false
        return true
    end

    if ctrl_down and not CTRL_KEYBINDS[key] then
        -- Stop preventing toggle
        screen.ctrl_pasting = false
    end

    if (key == KEY_LCTRL or key == KEY_RCTRL) and not down then
        -- Prevent remote toggle
        screen.ctrl_pasting = false
        return true
    end

    local ret = orig(screen, key, down, ...)

    return ret
end)

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
    for key in pairs(CTRL_KEYBINDS) do
        screen.console_edit.validrawkeys[key] = true
    end
    for key in pairs(Config.REMOTETOGGLEKEYS) do
        screen.console_edit.validrawkeys[key] = true
    end
end)

return {
    tests = {
        ["test ctrl keybinds not triggering remote toggle"] = function ()
            local temp = State()
            temp:Set(Config, "REMOTETOGGLEKEYS", {
                [KEY_LCTRL] = true,
                [KEY_RCTRL] = true,
                [KEY_LALT] = false,
                [KEY_RALT] = false,
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
            temp:Purge()
        end,

        ["test Alt remote toggle"] = function ()
            local temp = State()
            temp:Set(Config, "REMOTETOGGLEKEYS", {
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
            AssertEq(screen.toggle_remote_execute, true)
            Tester.SendKey(KEY_LCTRL)
            Assert(screen.toggle_remote_execute, "Ctrl shouldn't toggle remote execute here")
            Tester.SendKey(KEY_LALT)
            Assert(not screen.toggle_remote_execute, "Alt should toggle remote execute here")
            temp:Purge()
        end,

        ["test Ctrl remote toggle"] = function ()
            local temp = State()
            temp:Set(Config, "REMOTETOGGLEKEYS", {
                [KEY_LCTRL] = true,
                [KEY_RCTRL] = true,
                [KEY_LALT] = false,
                [KEY_RALT] = false,
            })
            local screen = Tester.OpenConsole()
            AssertEq(Config.REMOTETOGGLEKEYS[KEY_LCTRL], true)
            if not screen.console_remote_execute.shown then
                return Tester.CONDITIONS_NOT_MET
            end
            screen:ToggleRemoteExecute(true)
            AssertEq(screen.toggle_remote_execute, true)
            Tester.SendKey(KEY_LALT)
            Assert(screen.toggle_remote_execute, "Alt shouldn't toggle remote execute here")
            Tester.SendKey(KEY_LCTRL)
            Assert(not screen.toggle_remote_execute, "Ctrl should toggle remote execute here")
            temp:Purge()
        end,
    }
}
