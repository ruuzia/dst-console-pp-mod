setfenv(1, ConsolePP.env)
local G = GLOBAL

local WordPredictionWidget = require "widgets/wordpredictionwidget"

Hook(WordPredictionWidget, "_ctor", function(orig, self, ...)
    orig(self, ...)
    self.tab_complete = false -- I handle tab complete
    -- either enter_complete or tab_complete must be true for WordPredictionWidget:IsMouseOnly
    self.enter_complete = Config.ENTERCOMPLETE
    function self:IsMouseOnly() return not Config.ENTERCOMPLETE and not Config.TABCOMPLETE end
end)


return {}
