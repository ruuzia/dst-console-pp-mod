local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"
local rawget = G.rawget

function ConsoleEditDynamicComplete(self)
    local str = self:GetString()
    local pos = self.inst.TextEditWidget:GetEditCursorPos()
    local tnames = {}
    local calls = {}
    local indexers = {}
    local searchpos = pos
    local expressionstart
    repeat
        local wstart, word, call, indexer = str:sub(1, searchpos):match("()([%w_]+)%s*(%(?%)?)%s*([.:])$")
        if wstart == nil then break end
        expressionstart = wstart
        searchpos = wstart - 1
        table.insert(tnames, word)
        calls[#tnames] = call
        indexers[#tnames] = indexer
    until false
    if #tnames <= 0 then return end

    local t = G.setmetatable({}, {__index=function(_, k) return rawget(G, k) end})
    local mt
    for i = #tnames, 1, -1 do
        local prevtbl = t
        t = t[tnames[i]]
        if type(t) == "function" and calls[i] == "()" then
            t = t(indexers[i+1] == ":" and prevtbl or nil)
        end
        mt = G.getmetatable(t)
        if type(t) ~= "table" and (mt == nil or type(mt.__index) ~= "table") then return end
    end

    local keys = {}
    local onlyfuncs = str:sub(pos,pos) == ":"
    if type(t) == "table" then
        for k,v in pairs(t) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    if mt and type(mt.__index) == "table" then
        for k,v in pairs(mt.__index) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    local delim = str:sub(expressionstart, pos)
    print(delim, keys, #keys)
    for _,v in ipairs(self.prediction_widget.word_predictor.dictionaries) do
        if v.delim == delim then
            v.words = keys
            return self.prediction_widget:RefreshPredictions()
        end
    end
    self:AddWordPredictionDictionary {
        words = keys,
        delim = delim,
        num_chars = 0,
        GetDisplayString = function (word) return word end
    }
    return self.prediction_widget:RefreshPredictions()
end

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
Decorate(TextEdit, "OnRawKey", function(_OnRawKey, self, key, down)
    if down then
        if (key == G.KEY_BACKSPACE or key == G.KEY_DELETE) and TheInput:IsKeyDown(G.KEY_LCTRL) then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if pos > 0 then
                local i = pos - 1
                while i > 0 and str:find('^%s', i) do
                    i = i - 1
                end
                while i > 0 and str:find('^%S', i) do
                    i = i - 1
                end
                self:SetString(str:sub(1, i) .. str:sub(pos + 1))
                self.inst.TextEditWidget:SetEditCursorPos(i)
            end
            return true

        elseif key == G.KEY_TAB then
            if Config.TabComplete and self.prediction_widget.word_predictor.prediction then
                self:ApplyWordPrediction(self.prediction_widget.active_prediction_btn)
            elseif Config.TabInsert and self.nextTextEditWidget == nil then
                for i = 1, 4 do
                    --\t just inserts a space anyways - handled in self.inst.TextEditWidget engine
                    self:OnTextInput(' ')
                end
            elseif Config.TabNext then
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

local Text = require "widgets/text"
function TextEdit:OnMouseButton(button, down, mouse_x, mouse_y)
    print(button, down, self.editing)
    if not down or button ~= G.MOUSEBUTTON_LEFT then return true end
    mouse_x = mouse_x / self:GetScale().x
    mouse_y = mouse_y / self:GetScale().y

    local textposmid_x, textposmid_y = self:GetWorldPosition():Get()
    textposmid_x = textposmid_x / self:GetScale().x
    textposmid_y = textposmid_y / self:GetScale().y
    local size_x, size_y = self:GetRegionSize()
    local x_text_start, y_text_start = textposmid_x - size_x / 2, textposmid_y + size_y / 2
    local row = math.floor((y_text_start - mouse_y) / self.size)

    ---@type string
    local str = self:GetString()

    local _, a_rowstart = str:find("^"..("[^\n]*\n"):rep(row))
    a_rowstart = a_rowstart or StrGetLineStart(str, #str) - 1
    local u_len = str:utf8len()
    local u_rowstart = str:sub(1, a_rowstart):utf8len()

    local textbox = Text(self.font, self.size)

    for u_idx = u_rowstart+1, u_len do
        local u_char = str:utf8sub(u_idx, u_idx)
        if u_char == "\n" then break end

        textbox:SetString(textbox:GetString()..u_char)
        local width = textbox:GetRegionSize()

        if width > (mouse_x - x_text_start) then break end
    end
    self.inst.TextEditWidget:SetEditCursorPos(a_rowstart + #textbox:GetString())
    textbox:Kill()

    --this should prevent the TextEdit:OnControl(G.CONTROL_ACCEPT, down) thats about to happen from shutting down textedit
    --test world selection screen textedits and in-game chat input
    self.enable_accept_control = not self.editing
    return true
end

Decorate(TextEdit, "OnControl", function (_OnControl, self, control, down)
    return _OnControl(self, control, down)-- or control == G.CONTROL_ACCEPT
end)

