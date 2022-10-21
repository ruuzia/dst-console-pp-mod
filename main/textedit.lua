local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"

function ForceFocusTextEditCursor(self)
    --HACK
    self.inst.TextEditWidget:OnKeyDown(G.KEY_LCTRL, false)
end

local WordPredictionWidget = require "widgets/wordpredictionwidget"

-- Remove old typo file --
AddGamePostInit(function() TheSim:ErasePersistentString("../psuedoclipboard.txt") end)
------------------------------
local PSEUDO_CLIPBOARD_FILE = "../pseudoclipboard.txt"

Hook(WordPredictionWidget, "_ctor", function(orig, self, ...)
    orig(self, ...)
    self.tab_complete = false -- I handle tab complete
    -- either enter_complete or tab_complete must be true for WordPredictionWidget:IsMouseOnly
    self.enter_complete = Config.ENTERCOMPLETE
    function self:IsMouseOnly() return not Config.ENTERCOMPLETE and not Config.TABCOMPLETE end
end)

Hook(TextEdit, "_ctor", function(orig, self, ...)
    -- Windows does funky
    self:SetInvalidCharacterFilter(string.char(3, 12, 25, 26))
    orig(self, ...)
end)

local WINDOWS_FUNKY_INPUTS = {[3] = true, [12] = true, [8] = true, [25] = true, [26] = true}
Hook(TextEdit, "ValidateChar", function(orig, self, ch)
    if TheInput:IsKeyDown(KEY_CTRL) and not self.pasting then return false end

    return orig(self, ch)
end)

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

        elseif (key == KEY_BACKSPACE or key == KEY_W) and ctrl_down then
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

        elseif key == KEY_C and ctrl_down then
            TheSim:SetPersistentString(PSEUDO_CLIPBOARD_FILE, '\n'..self:GetString(), false,
            function (succ)
                if succ then
                    print("Console contents saved to "..PSEUDO_CLIPBOARD_FILE.."!")
                else
                    print("Erorr: Unable to write console contents to "..PSEUDO_CLIPBOARD_FILE"..!")
                end
            end)

        elseif key == G.KEY_TAB then
            if Config.TABCOMPLETE and active_prediction_btn then
                self:ApplyWordPrediction(active_prediction_btn)

            elseif Config.TABNEXT and active_prediction_btn then
                local prediction_btns = self.prediction_widget.prediction_btns
                if active_prediction_btn then
                    if TheInput:IsKeyDown(G.KEY_LCTRL) or TheInput:IsKeyDown(G.KEY_RCTRL) then
                        prediction_btns[active_prediction_btn > 1 and active_prediction_btn - 1 or #prediction_btns]:Select()
                    else
                        prediction_btns[active_prediction_btn < #prediction_btns and active_prediction_btn + 1 or 1]:Select()
                    end
                end

            elseif Config.TABINSERT and self.nextTextEditWidget == nil then
                for _ = 1, Config.TABSPACES do
                    self.inst.TextEditWidget:OnTextInput(' ')
                end
            end
          
        elseif key == KEY_Z and ctrl_down then
            local contents = self:GetString()
            if self.cpm_undo then
                self:SetString(self.cpm_undo)
                self.cpm_undo = nil
                self.cpm_redo = contents

            elseif ontents ~= "" then
                self:SetString("")
                self.cpm_redo = contents
            end
            return true

        elseif key == KEY_Y and ctrl_down then
            if self.cpm_redo then
                self:SetString(self.cpm_redo)
                self.cpm_redo = nil
            end
            return true

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
        end
    end

    return orig(self, key, down)
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

Hook(TextEdit, "OnControl", function (orig, self, control, down)
    -- On mouse down, OnControl is called BEFORE OnMouseDown, and TheInput:IsMouseDown is still false!
    -- so we don't even know if the mouse was down yet!
    -- Wrapping in DoTaskInTime so TheInput:IsMouseDown has been registered
    self.inst:DoTaskInTime(0, function()
        if down and control == G.CONTROL_ACCEPT
            and TheInput:IsMouseDown(G.MOUSEBUTTON_LEFT)
            and TheInput:GetHUDEntityUnderMouse() == self.inst
        then
            self:SetEditing(true)
            onclicked(self, TheFrontEnd.lastx, TheFrontEnd.lasty)
        end
    end)
    -- Don't close after clicking console
    if not down
       and control == G.CONTROL_ACCEPT
       and TheInput:IsMouseDown(G.MOUSEBUTTON_LEFT)
       and TheInput:GetHUDEntityUnderMouse() == self.inst
    then return true end

    return orig(self, control, down)
end)
