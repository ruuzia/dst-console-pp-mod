setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)

    -- Up and Down arrow is also used to navigate in command history
    -- So if we are on the first line and press UP key, we need to pass
    -- it on to the screen to handle
    -- The added complexity is because we want moving between lines to be
    -- act-on-press, but the history logic is act-on-release, thus the flag
    -- to remember:
    local _moving_between_lines = false

    -- Text is variable-length, so we also need to remember where we're
    -- trying to be: so (UP, UP, UP, DOWN, DOWN, DOWN) puts you back in
    -- the same spot.
    local _goal_x = nil

    local function UpdateGoalXPos()
        if _goal_x then return end
        local pos = screen.console_edit.inst.TextEditWidget:GetEditCursorPos()
        local str = screen.console_edit:GetString()
        local linestart = StrGetLineStart(str, pos)
        _goal_x = TextBoxStringToPos(screen.console_edit.font,
                                     screen.console_edit.size,
                                     str:sub(linestart, pos))
    end

    local function SetToGoalXPos(linestart)
        local str = screen.console_edit:GetString()
        local pos = screen.console_edit.inst.TextEditWidget:GetEditCursorPos()
        linestart = linestart or StrGetLineStart(str, pos)
        local lineend = StrGetLineEnd(str, linestart)
        local col = TextBoxXPosToCol(screen.console_edit.font,
            screen.console_edit.size,
            _goal_x,
            str:sub(linestart, lineend),
            string.sub)

        screen.console_edit.inst.TextEditWidget:SetEditCursorPos(col + linestart - 1)
    end

    Hook(screen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
        local pos = screen.console_edit.inst.TextEditWidget:GetEditCursorPos()
        local str = screen.console_edit:GetString()
        local history = G.ConsoleScreenSettings:GetConsoleHistory()

        if key == KEY_UP and down then
            local linestart = StrGetLineStart(str, pos)
            _moving_between_lines = linestart > 1
            if _moving_between_lines then
                --hello\nthere
                --       ^
                --   linestart
                UpdateGoalXPos()
                SetToGoalXPos(StrGetLineStart(str, linestart - 2))
            end
        elseif key == KEY_DOWN and down then
            local lineend = StrGetLineEnd(str, pos)
            _moving_between_lines = lineend < #str
            if _moving_between_lines then
                UpdateGoalXPos()
                SetToGoalXPos(lineend+2)
            end
        elseif (key == KEY_UP or key == KEY_DOWN)
            and not down
            and _moving_between_lines then
            -- Don't let the screen get this callback!
            _moving_between_lines = false
            return true
        end

        return orig(screen, key, down, ...)
    end)

    Hook(screen.console_edit, "OnRawKey", function(orig, textedit, key, down, ...)
        if key ~= KEY_UP and key ~= KEY_DOWN then
            _goal_x = nil
        end
        return orig(textedit, key, down, ...)
    end)
end)

return {
    tests = {
        ["test arrow keys move between lines"] = function ()
            local screen = Tester.OpenConsole()

            screen.console_edit:SetString("12345\nabc")
            Tester.SendKey(KEY_UP)
            AssertEq(screen.console_edit:GetString(), "12345\nabc")
            AssertEq(screen.console_edit.inst.TextEditWidget:GetEditCursorPos(), 3)
            Tester.SendKey(KEY_DOWN)
            AssertEq(screen.console_edit:GetString(), "12345\nabc")
            AssertEq(screen.console_edit.inst.TextEditWidget:GetEditCursorPos(), 9)
        end,
        ["test history still works"] = function ()
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("-- beefalo")
                screen:Run()
            end
            do
                local screen = Tester.OpenConsole()
                screen.console_edit:SetString("12345\nabc")
                Tester.SendKey(KEY_UP)
                Tester.SendKey(KEY_UP)
                AssertEq(screen.console_edit:GetString(), "-- beefalo")
            end
        end,
    }
}
