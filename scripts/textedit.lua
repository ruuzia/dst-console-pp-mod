local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"

function ForceFocusTextEditCursor(self)
    ---HACK
    self.inst.TextEditWidget:OnKeyDown(G.KEY_LCTRL, false)
end

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
Hook(TextEdit, "OnRawKey", function(_OnRawKey, self, key, down)
    local ctrl_down = TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL)
    if down then
        if (key == G.KEY_BACKSPACE or key == G.KEY_DELETE) and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if pos > 0 then
                local ptrn = "["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*$"
                local i = str:sub(1, pos-1):find(ptrn)
                self:SetString(str:sub(1, i-1) .. str:sub(pos + 1))
                self.inst.TextEditWidget:SetEditCursorPos(i-1)
            end
            return true

        elseif (key == G.KEY_BACKSPACE or key == G.KEY_DELETE) and TheInput:IsKeyDown(G.KEY_LSUPER) then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local i = StrGetLineStart(str, pos)
            self:SetString(str:sub(1, i-1) .. str:sub(pos+1))
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            return true

        elseif key == G.KEY_LEFT and ctrl_down then
            ---[[
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if pos == 0 then return false end
            local ptrn = "["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*$"
            local i = str:sub(1, pos-1):find(ptrn)
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            ForceFocusTextEditCursor(self)
            return true
            --]]

        elseif key == G.KEY_RIGHT and ctrl_down then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            --if pos == #str then return false end
            ---[[
            local ptrn = "^[^"..Config.WORDSET.."]*["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*"
            local _, i = str:find(ptrn, pos+1)
            if not i then return false end
            --]]
            self.inst.TextEditWidget:SetEditCursorPos(i)
            ForceFocusTextEditCursor(self)
            return true

        elseif key == G.KEY_TAB then
            if Config.TABCOMPLETE and self.prediction_widget
                                  and self.prediction_widget.word_predictor.prediction then
                print("TABCOMPLETE")
                self:ApplyWordPrediction(self.prediction_widget.active_prediction_btn)
            elseif Config.TABINSERT and self.nextTextEditWidget == nil then
                for _ = 1, 4 do
                    --\t just inserts a space anyways
                    print("TABINSERT")
                    self:OnTextInput(' ')
                end
            elseif Config.TABNEXT and self.prediction_widget then
                local active_btn_id = self.prediction_widget.active_prediction_btn
                local prediction_btns = self.prediction_widget.prediction_btns
                if active_btn_id then
                    if TheInput:IsKeyDown(G.KEY_LCTRL) then
                        prediction_btns[active_btn_id > 1 and active_btn_id - 1 or #prediction_btns]:Select()
                    else
                        prediction_btns[active_btn_id < #prediction_btns and active_btn_id + 1 or 1]:Select()
                    end
                end
            end
        end
    end

    return _OnRawKey(self, key, down)
end)

local on_control = Impurities.new(TextEdit, "OnControl")
local function mod_on_control(self, control, down)
    local ret = on_control(self, control, down)
    if not down and control == G.CONTROL_ACCEPT then
        self.enable_accept_control = true
        TextEdit.OnControl = on_control
    end
    return ret
end


local nlchar = string.byte('\n')
function TextEdit:OnMouseButton(button, down, mouse_x, mouse_y)
    if not down or button ~= G.MOUSEBUTTON_LEFT then return true end
    mouse_x = mouse_x / self:GetScale().x
    mouse_y = mouse_y / self:GetScale().y

    local textposmid_x, textposmid_y = self:GetWorldPosition():Get()
    textposmid_x = textposmid_x / self:GetScale().x
    textposmid_y = textposmid_y / self:GetScale().y
    local size_x, size_y = self:GetRegionSize()
    local x_text_start, y_text_start = textposmid_x - size_x / 2, textposmid_y + size_y / 2
    local row = math.floor((y_text_start - mouse_y) / self.size + 0.5)

    ---@type string
    local str = self:GetString()
    --local _, rowstart = str:find("^"..("%f[\1-\9\14-\255][\1-\9\14-\255]*."):rep(row))
    local rowstart = 0
    for i = 1, #str do
        if str:byte(i) == nlchar then
            row = row - 1
            if row == 1 then
                rowstart = i
                break
            end
        end
    end

    local line = str:sub(rowstart+1, StrGetLineEnd(str, rowstart+1))
    local col = TextBoxXPosToCol(self.font, self.size, mouse_x - x_text_start, line, string.sub)
    self.inst.TextEditWidget:SetEditCursorPos(rowstart + col)
    ForceFocusTextEditCursor(self)

    --this should prevent the TextEdit:OnControl(G.CONTROL_ACCEPT, down) thats about to happen from shutting down textedit
    --test world selection screen textedits and in-game chat input
    self.enable_accept_control = not self.editing
    self.OnControl = mod_on_control
    return true
end

