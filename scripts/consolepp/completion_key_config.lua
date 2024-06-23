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


return {
    tests = {
        ["test Config.ENTERCOMPLETE=true"] = function ()
            local temp = State()
            temp:Set(Config, "ENTERCOMPLETE", true)

            local screen = Tester.OpenConsole()
            Tester.SendTextInput("c_boatcollisi")
            Tester.PressEnter()
            AssertEq(screen.console_edit:GetString(), "c_boatcollision")

            temp:Purge()
        end,
        ["test Config.ENTERCOMPLETE=false"] = function ()
            local temp = State()
            temp:Set(Config, "ENTERCOMPLETE", false)
            temp:Set(Config, "KEEPCONSOLEOPEN", true)

            local screen = Tester.OpenConsole()
            Tester.SendTextInput("c_boatcollisi")
            Tester.PressEnter()
            AssertEq(screen.console_edit:GetString(), "")

            temp:Purge()
        end,
        ["test Config.TABCOMPLETE=true"] = function ()
            local temp = State()
            temp:Set(Config, "TABCOMPLETE", true)

            local screen = Tester.OpenConsole()
            Tester.SendTextInput("c_boatcollisi")
            Tester.SendKey(KEY_TAB)
            AssertEq(screen.console_edit:GetString(), "c_boatcollision")

            temp:Purge()
        end,
        ["test Config.TABCOMPLETE=false"] = function ()
            local temp = State()
            temp:Set(Config, "TABCOMPLETE", false)
            temp:Set(Config, "TABINSERT", true)

            local screen = Tester.OpenConsole()
            Tester.SendTextInput("c_boatcollisi")
            Tester.SendKey(KEY_TAB)
            -- Note: we don't want to insert spaces here either,
            -- because who wants tabs in the middle of a line?
            AssertEq(screen.console_edit:GetString(), "c_boatcollisi")

            temp:Purge()
        end,
    }
}
