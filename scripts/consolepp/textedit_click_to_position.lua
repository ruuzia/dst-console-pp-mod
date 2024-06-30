-- Enable mouse to position cursor on textedits!
-- Set for all textedits, not just console edit.
-- Somewhat hacky!
-- TODO: prevent misclicks on edge of console edit from closing console screen

setfenv(1, ConsolePP.env)
local G = GLOBAL
local TextEdit = require "widgets/textedit"
local TheInput = G.TheInput

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
    local rowstart = 1
    if target_row > row then
        for nl in str:gmatch("\n()") do
            row = row + 1
            if row == target_row then
                rowstart = nl
                break
            end
        end
    end

    local line = str:sub(rowstart, StrGetLineEnd(str, rowstart))
    local col = TextBoxXPosToCol(self.font, self.size, mouse_x - x_text_start, line, string.sub)
    self.inst.TextEditWidget:SetEditCursorPos(rowstart + col - 1)
    ForceFocusTextEditCursor(self)

    --test world selection screen textedits and in-game chat input
    return true
end

-- And Why do we need this crazyness again?

-- OnControl is triggered right after OnMouseButton
-- We need a flag to differentiate mouse up from any other (ControlAccept, false)
local mouse_button_just_triggered_mouse_up
Hook(TextEdit, "OnMouseButton", function (orig, self, button, down, mouse_x, mouse_y)
    --print("OnMouseButton", button, down, mouse_x, mouse_y)
    if button == G.MOUSEBUTTON_LEFT and TheInput:GetHUDEntityUnderMouse() == self.inst and not down then
        mouse_button_just_triggered_mouse_up = true
    end
    return orig(button, down, mouse_x, mouse_y)
end)

Hook(TextEdit, "OnControl", function (orig, self, control, down)
    if control == G.CONTROL_ACCEPT
        and TheInput:GetHUDEntityUnderMouse() == self.inst
        and down
        and TheInput:IsMouseDown(G.MOUSEBUTTON_LEFT)
    then
        self:SetEditing(true)
        if TheFrontEnd.lastx and TheFrontEnd.lasty then
            onclicked(self, TheFrontEnd.lastx, TheFrontEnd.lasty)
        end
        return true
    end
    if mouse_button_just_triggered_mouse_up then
        mouse_button_just_triggered_mouse_up = false
        return true
    end

    return orig(self, control, down)
end)

-- Console: make sure clicking on text edit never triggers run or cancel.
-- Harder than it should be.

Hook(require "screens/consolescreen", "_ctor", function (constructor, self, ...)
    constructor(self, ...)

    Hook(self.console_edit, "OnStopForceEdit", function (orig, console_edit, ...)
        if not self.edit_bg.focus then
            return orig(self, ...)
        end
    end)
end)
Hook(require "screens/consolescreen", "OnControl", function (orig, self, control, down, ...)
    if control == G.CONTROL_ACCEPT and not down and (self.edit_bg.focus or TheInput:GetHUDEntityUnderMouse() == self.console_edit.inst) then
        self.console_edit:SetEditing(true)
        return true
    end
    return orig(self, control, down, ...)
end)

return {
    tests = {
        ["click to position console edit"] = function ()
            local text = "Hello, World!"
            local x, y = 360, 130

            local console = Tester.OpenConsole()
            Tester.SendTextInput(text)
            onclicked(console.console_edit, x, y)

            Assert(Tester.IsConsoleOpen(), "Clicking on console edit shouldn't close it!")
            Assert(console.console_edit:GetString(), text)
            local cursor_pos = console.console_edit.inst.TextEditWidget:GetEditCursorPos()
            AssertEq(cursor_pos, 2)
        end
    },
}
