local G = GLOBAL

local TheInput = G.TheInput
local TextEdit = require "widgets/textedit"

function ForceFocusTextEditCursor(self)
    --HACK
    self.inst.TextEditWidget:OnKeyDown(G.KEY_LCTRL, false)
end

local WordPredictionWidget = require "widgets/wordpredictionwidget"

Hook(WordPredictionWidget, "_ctor", function(orig, self, ...)
    orig(self, ...)
    self.tab_complete = false -- I handle tab complete
    -- either enter_complete or tab_complete must be true for WordPredictionWidget:IsMouseOnly
    self.enter_complete = Config.ENTERCOMPLETE
    function self:IsMouseOnly() return not Config.ENTERCOMPLETE and not Config.TABCOMPLETE end
end)

-- Hook(TextEdit, "_ctor", function(orig, self, ...)
--     -- Windows does funky
--     self:SetInvalidCharacterFilter(string.char(3, 12, 25, 26))
--     orig(self, ...)
-- end)

-- local WINDOWS_FUNKY_INPUTS = {[3] = true, [12] = true, [8] = true, [25] = true, [26] = true}
-- Hook(TextEdit, "ValidateChar", function(orig, self, ch)
--     if TheInput:IsKeyDown(KEY_CTRL) and not self.pasting then return false end
--
--     return orig(self, ch)
-- end)

