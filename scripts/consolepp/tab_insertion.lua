-- Game doesn't support real tabs, fortunately real software engineers
-- actually insert and delete 4 spaces anyways ;)
--
setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    if key == KEY_TAB and down and Config.TABINSERT then
        for _ = 1, Config.TABSPACES do
            screen.console_edit.inst.TextEditWidget:OnTextInput(' ')
        end
    elseif key == KEY_BACKSPACE and down then
        local contents = screen.console_edit:GetString()
        local cursor = screen.console_edit.inst.TextEditWidget:GetEditCursorPos()

        local linestart = StrGetLineStart(contents, cursor)
        local chars = contents:sub(linestart, cursor)
        if chars:find "^%s+$" then
            for i = 1, math.min(#chars, Config.TABSPACES) do
                screen.console_edit.inst.TextEditWidget:OnKeyDown(KEY_BACKSPACE)
            end
            return true
        end
   end

    return orig(screen, key, down, ...)
end)

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
	screen.console_edit.validrawkeys[KEY_TAB] = true
	screen.console_edit.validrawkeys[KEY_BACKSPACE] = true
end)

return {
    tests = {
        ["test inserting deleting tabs"] = function ()
            local temp = State()
            temp:Set(Config, "TABSPACES", 7)
            temp:Set(Config, "TABINSERT", true)

            local screen = Tester.OpenConsole()
            Tester.SendKey(KEY_TAB)
            AssertEq(screen.console_edit:GetString(), "       ")
            Tester.SendKey(KEY_BACKSPACE)
            AssertEq(screen.console_edit:GetString(), "")

            temp:Purge()
        end,
        ["test config for disabling tabs"] = function ()
            local temp = State()
            temp:Set(Config, "TABINSERT", false)

            local screen = Tester.OpenConsole()
            Tester.SendKey(KEY_TAB)
            AssertEq(screen.console_edit:GetString(), "")
            Tester.SendKey(KEY_BACKSPACE)
            AssertEq(screen.console_edit:GetString(), "")

            temp:Purge()
        end
    }
}
