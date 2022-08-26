local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"

function ForceFocusTextEditCursor(self)
    --HACK
    self.inst.TextEditWidget:OnKeyDown(G.KEY_LCTRL, false)
end

local WordPredictionWidget = require "widgets/wordpredictionwidget"

Hook(WordPredictionWidget, "_ctor", function(__ctor, self, ...)
    __ctor(self, ...)
    self.tab_complete = false -- I handle tab complete
    -- either enter_complete or tab_complete must be true for WordPredictionWidget:IsMouseOnly
    self.enter_complete = true
end)

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
Hook(TextEdit, "OnRawKey", function(_OnRawKey, self, key, down)
    local ctrl_down = TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL)

    if down then
        if (key == G.KEY_BACKSPACE or key == G.KEY_DELETE) and TheInput:IsKeyDown(G.KEY_LSUPER) then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            local i = StrGetLineStart(str, pos)
            self:SetString(str:sub(1, i-1) .. str:sub(pos+1))
            self.inst.TextEditWidget:SetEditCursorPos(i-1)
            return true

        elseif key == G.KEY_TAB then
            if Config.TABCOMPLETE and self.prediction_widget
                                  and self.prediction_widget.active_prediction_btn
            then
                self:ApplyWordPrediction(self.prediction_widget.active_prediction_btn)
            elseif Config.TABINSERT and self.nextTextEditWidget == nil then
                for _ = 1, Config.TABSPACES do
                    self.inst.TextEditWidget:OnTextInput(' ')
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

-- NOT using OnMouseButton because it registers clicks on children too, and OnControl(CONTROL_ACCEPT) is fired right after it which messes things up
--function TextEdit:OnMouseButton(button, down, mouse_x, mouse_y)
local function onclicked(self, mouse_x, mouse_y)
    mouse_x = mouse_x / self:GetScale().x
    mouse_y = mouse_y / self:GetScale().y

    local textposmid_x, textposmid_y = self:GetWorldPosition():Get()
    textposmid_x = textposmid_x / self:GetScale().x
    textposmid_y = textposmid_y / self:GetScale().y
    local size_x, size_y = self:GetRegionSize()
    local x_text_start, y_text_start = textposmid_x - size_x / 2, textposmid_y + size_y / 2
    local target_row = math.ceil((y_text_start - mouse_y) / self.size)

    ---@type string
    local str = self:GetString()
    --local _, rowstart = str:find("^"..("%f[\1-\9\14-\255][\1-\9\14-\255]*."):rep(row))
    local row = 1
    local rowstart = 0
    if target_row > row then
        for nl in str:gmatch("\n()") do
            row = row + 1
            if row == target_row then
                rowstart = nl
                break
            end
        end
    end

    local line = str:sub(rowstart+1, StrGetLineEnd(str, rowstart+1))
    local col = TextBoxXPosToCol(self.font, self.size, mouse_x - x_text_start, line, string.sub)
    self.inst.TextEditWidget:SetEditCursorPos(rowstart + col)
    ForceFocusTextEditCursor(self)

    --test world selection screen textedits and in-game chat input
    return true
end

do
    local _OnControl = Impurities.new(TextEdit, "OnControl")
    function TextEdit:OnControl(control, down)
        local ctrl_down = TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL)
        if down then
            -- TODO: Doesn't work for holding down backspace
            if (control == G.CONTROL_TOGGLE_DEBUGRENDER) and ctrl_down then
                local str = self:GetString()
                local pos = self.inst.TextEditWidget:GetEditCursorPos()
                if pos > 0 then
                    local ptrn = "["..Config.WORDSET.."]*[^"..Config.WORDSET.."]*$"
                    local i = str:sub(1, pos-1):find(ptrn)
                    self:SetString(str:sub(1, i-1) .. str:sub(pos + 1))
                    self.inst.TextEditWidget:SetEditCursorPos(i-1)
                end
                return true

            elseif control == G.CONTROL_FOCUS_LEFT and ctrl_down then
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

            elseif control == G.CONTROL_FOCUS_RIGHT and ctrl_down then
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
            end
        else
            -- This needs to be on mouse up for now because on mouse down, OnControl is called BEFORE OnMouseDown and so we wouldn't even know if the mouse was down yet!
            if control == G.CONTROL_ACCEPT
                and TheInput:IsMouseDown(G.MOUSEBUTTON_LEFT)
                and TheInput:GetHUDEntityUnderMouse() == self.inst
            then
                self:SetEditing(true)
                return onclicked(self, TheFrontEnd.lastx, TheFrontEnd.lasty)
            end
        end
        return _OnControl(self, control, down)
    end
end

