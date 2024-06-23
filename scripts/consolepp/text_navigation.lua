setfenv(1, ConsolePP.env)
local G = GLOBAL
local TextEdit = require "widgets/textedit"

local function IsWordCharacter(c)
    local ptrn = "["..Config.WORDSET.."]"
    return c:find(ptrn) ~= nil
end

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
Hook(TextEdit, "OnRawKey", function(orig, self, key, down)
    local ctrl_down = TheInput:IsKeyDown(KEY_LCTRL) or TheInput:IsKeyDown(KEY_RCTRL) or TheInput:IsKeyDown(KEY_CTRL)
    local active_prediction_btn = self.prediction_widget and self.prediction_widget.active_prediction_btn

    if down then
        if (key == KEY_BACKSPACE or key == KEY_DELETE) and TheInput:IsKeyDown(KEY_LSUPER) then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local i = StrGetLineStart(str, pos)
            self:SetString(str:sub(1, i-1) .. str:sub(pos+1))
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            return true

        elseif key == KEY_BACKSPACE and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local i = pos
            if IsWordCharacter(str:sub(i, i)) then
                -- move to start of word
                while i > 0 and IsWordCharacter(str:sub(i, i)) do
                    i = i - 1
                end
            else
                -- move to end of previous word
                while i > 0 and not IsWordCharacter(str:sub(i, i)) do
                    i = i - 1
                end
            end

            self:SetString(str:sub(1, i) .. str:sub(pos + 1))
            self.inst.TextEditWidget:SetEditCursorPos(i)
            return true

        elseif key == G.KEY_TAB then
            if Config.TABCOMPLETE and active_prediction_btn then
                self:ApplyWordPrediction(active_prediction_btn)
                return true

            elseif Config.TABNEXT and active_prediction_btn then
                local prediction_btns = self.prediction_widget.prediction_btns
                if active_prediction_btn then
                    if ctrl_down then
                        prediction_btns[active_prediction_btn > 1 and active_prediction_btn - 1 or #prediction_btns]:Select()
                    else
                        prediction_btns[active_prediction_btn < #prediction_btns and active_prediction_btn + 1 or 1]:Select()
                    end
                end
                return true

            end

        elseif key == KEY_LEFT and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if IsWordCharacter(str:sub(pos, pos)) then
                -- move to start of word
                while pos > 0 and IsWordCharacter(str:sub(pos, pos)) do
                    pos = pos - 1
                end
            else
                -- move to end of previous word
                while pos > 0 and not IsWordCharacter(str:sub(pos, pos)) do
                    pos = pos - 1
                end
            end
            self.inst.TextEditWidget:SetEditCursorPos(pos)
            ForceFocusTextEditCursor(self)
            return true

        elseif key == KEY_RIGHT and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if pos <  #str and IsWordCharacter(str:sub(pos+1, pos+1)) then
                -- move to end of word
                while IsWordCharacter(str:sub(pos+1, pos+1)) do
                    pos = pos + 1
                end
            else
                -- move to start of next word
                while pos < #str and not IsWordCharacter(str:sub(pos+1, pos+1)) do
                    pos = pos + 1
                end
            end
            self.inst.TextEditWidget:SetEditCursorPos(pos)
            ForceFocusTextEditCursor(self)
            return true

        elseif key == KEY_HOME then
            local contents = self:GetString()
            local cursor = self.inst.TextEditWidget:GetEditCursorPos()
            self.inst.TextEditWidget:SetEditCursorPos(StrGetLineStart(contents, cursor) - 1)
            ForceFocusTextEditCursor(self)
            return true

        elseif key == KEY_END then
            local contents = self:GetString()
            local cursor = self.inst.TextEditWidget:GetEditCursorPos()
            self.inst.TextEditWidget:SetEditCursorPos(StrGetLineEnd(contents, cursor))
            ForceFocusTextEditCursor(self)
            return true
        end
    end

    return orig(self, key, down)
end)

return {
    tests = {
        ["test command-backspace delete line"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("hello\nhow are you today")
            Tester.WithKeysDown({ KEY_LSUPER }, Tester.SendKey, KEY_BACKSPACE)
            AssertEq(screen.console_edit:GetString(), "hello\n")
        end,

        ["test ctrl-backspace delete word"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("the quick brown box")
            Tester.WithKeysDown({ KEY_LCTRL }, Tester.SendKey, KEY_BACKSPACE)
            Tester.SendTextInput("fox")
            AssertEq(screen.console_edit:GetString(), "the quick brown fox")
        end,

        ["test tab with Config.TABNEXT"] = function ()
            local temp = State()
            temp:Set(Config, "TABNEXT", true)
            temp:Set(Config, "TABCOMPLETE", false)
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("c_sel")
                Tester.SendKey(KEY_TAB)
                Tester.SendKey(KEY_TAB)
                Tester.SendKey(KEY_TAB)
                Tester.WithKeysDown({ KEY_LCTRL }, Tester.SendKey, KEY_TAB)
            end
            temp:Purge()
        end,

        ["test word movements"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("foo().components.bar!@#!@$baz = 42")
            Tester.WithKeysDown({ KEY_CTRL }, function ()
                Tester.SendKey(KEY_LEFT)
                Tester.SendKey(KEY_LEFT)
                Tester.SendKey(KEY_LEFT)
                Tester.SendKey(KEY_BACKSPACE)
            end)
            Tester.SendTextInput(".")
            Tester.WithKeysDown({ KEY_CTRL }, function ()
                Tester.SendKey(KEY_RIGHT)
                Tester.SendKey(KEY_RIGHT)
                Tester.SendKey(KEY_RIGHT)
            end)
            AssertEq(screen.console_edit:GetString(), "foo().components.bar.baz = 42")
            AssertEq(screen.console_edit.inst.TextEditWidget:GetEditCursorPos(), #"foo().components.bar.baz = 42")
        end,

        ["test home and end keys"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("the quick brown\njumps over")
            Tester.SendKey(KEY_HOME)
            Tester.SendKey(KEY_BACKSPACE)
            Tester.SendTextInput(" fox ")
            Tester.SendKey(KEY_END)
            Tester.SendTextInput(" the lazy dog")
            AssertEq(screen.console_edit:GetString(), "the quick brown fox jumps over the lazy dog")
        end,
    }
}
