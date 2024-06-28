local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"

function ForceFocusTextEditCursor(self)
    -- Lil hack
    self.inst.TextEditWidget:OnKeyDown(G.KEY_LCTRL, false)
end

local Widget = require "widgets/widget"
AddGamePostInit(function ()
    --- hot reload ---
    if ConsolePP.save.PsuedoText then
        print("Removing old hacktext")
        ConsolePP.save.PsuedoText:Kill()
    end
    ------------------
    local psuedotext = Widget()
    ConsolePP.save.PsuedoText = psuedotext

    psuedotext.inst.entity:AddTextWidget()
    psuedotext:Hide()

    function CalcTextRegionSize(str, font, size)
        local textwidget = psuedotext.inst.TextWidget
        textwidget:SetSize(size * (G.LOC and G.LOC.GetTextScale() or 1))
        textwidget:SetFont(font)
        textwidget:SetString(str)
        return textwidget:GetRegionSize()
    end
end)

function TextBoxXPosToCol(textfont, textsize, xpos, line, substring)
    substring = substring or string.utf8sub
    local prevwidth = 0
    local index
    for i = 1, #line do
        local width = CalcTextRegionSize(substring(line, 1, i), textfont, textsize)
        if width > xpos then
            index = width - xpos < xpos - prevwidth and i or i - 1
            break
        end
        prevwidth = width
    end
    return index or #line
end

function TextBoxStringToPos(font, size, line)
    if line == "" then return 0 end --GetRegionSize would return 2^127
    return CalcTextRegionSize(line, font, size)
end

local nlchar = ('\n'):byte()

---@param s string
---@param idx number
---@return number?
function StrGetLineStart(s, idx, utf8)
    local uidx_dif = 0
    for i = idx, 1, -1 do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i + 1 --one *after* newline
        elseif utf8 and byte >= 128 + 64 then
            uidx_dif = uidx_dif - 1
        end
    end
    return 1
end

---@param s string
---@param idx number
---@return number?
---@return number?
function StrGetLineBounds(s, idx, utf8)
    return StrGetLineStart(s, idx, utf8), StrGetLineEnd(s, idx, utf8)
end

---@param s string
---@param idx number
---@return number?
function StrGetLineEnd(s, idx, utf8)
    local uidx_dif = 0
    for i = idx+1, #s do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i - 1 --one *before* newline
        elseif utf8 and byte >= 128 + 64 --[[0b11000000]] then
            uidx_dif = uidx_dif - 1
        end
    end
    return #s + uidx_dif
end

