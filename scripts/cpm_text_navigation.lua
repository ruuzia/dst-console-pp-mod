setfenv(1, ConsolePP.env)
local G = GLOBAL
local TextEdit = require "widgets/textedit"

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
Hook(TextEdit, "OnRawKey", function(orig, self, key, down)
    local ctrl_down = TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL)
    local active_prediction_btn = self.prediction_widget and self.prediction_widget.active_prediction_btn

    if down then
        if (key == KEY_BACKSPACE or key == KEY_DELETE) and TheInput:IsKeyDown(KEY_LSUPER) then
            local str = self:GetString()
            self.cpm_undo = str
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local i = StrGetLineStart(str, pos)
            self:SetString(str:sub(1, i-1) .. str:sub(pos+1))
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            return true

        elseif key == KEY_BACKSPACE and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            self.cpm_undo = str
            if pos > 0 then
                local ptrn = "["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*$"
                local i = str:sub(1, pos-1):find(ptrn)
                self:SetString(str:sub(1, i-1) .. str:sub(pos + 1))
                self.inst.TextEditWidget:SetEditCursorPos(i - 1)
            end
            return true

        elseif key == G.KEY_TAB then
            if Config.TABCOMPLETE and active_prediction_btn then
                self:ApplyWordPrediction(active_prediction_btn)
                return true

            elseif Config.TABNEXT and active_prediction_btn then
                local prediction_btns = self.prediction_widget.prediction_btns
                if active_prediction_btn then
                    if TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL) then
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
            if pos == 0 then return false end
            local ptrn = "["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*$"
            local i = str:sub(1, pos-1):find(ptrn)
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            ForceFocusTextEditCursor(self)
            return true

        elseif key == KEY_RIGHT and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local ptrn = "^["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*"
            local _, i = str:find(ptrn, pos+1)
            if not i then return false end
            self.inst.TextEditWidget:SetEditCursorPos(i)
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

return {}
