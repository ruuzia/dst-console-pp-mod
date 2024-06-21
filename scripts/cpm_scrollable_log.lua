setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local Widget = require "widgets/widget"

local function BuildStaticRoot(screen)
    -- We need this for some reason
    local staticroot = screen:AddChild(Widget(""))
    staticroot:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
    staticroot:SetHAnchor(G.ANCHOR_MIDDLE)
    staticroot:SetVAnchor(G.ANCHOR_MIDDLE)

    staticroot = staticroot:AddChild(Widget(""))
    staticroot:SetPosition(0,100,0)

    screen._cpm_staticroot = staticroot
end

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)

    BuildStaticRoot(screen)
    local scrollable_log = screen._cpm_staticroot:AddChild(ScrollableConsoleLog(Logs.client))
    --screen.scrollable_log:SetVAnchor(G.ANCHOR_BOTTOM)
    scrollable_log:SetPosition(-550, -200)
    scrollable_log:RefreshOnClientPrint()
    -- Make accessible from screen
    screen._cpm_scrollable_log = scrollable_log

    -- Allow scrolling controls
    screen.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLBACK, true)
    screen.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLFWD, true)

    -- Temporarily override ShowConsoleLog and HideConsoleLog
    Impurities:New(TheFrontEnd, "ShowConsoleLog", function (frontend)
        print "called ShowConsoleLog()"
        -- Pretend vanilla consoletext is shown
        frontend.consoletext.shown = true
        screen._cpm_scrollable_log:Show()
    end)
    Impurities:New(TheFrontEnd, "HideConsoleLog", function (frontend)
        print "called HideConsoleLog()"
        frontend.consoletext.shown = false
        screen._cpm_scrollable_log:Hide()
    end)
end)


-- Vanilla currently force shows the log
Hook(ConsoleScreen, "OnBecomeActive", function (orig, screen, ...)
    local should_show_log = Config.OPENLOGWITHCONSOLE or TheFrontEnd.consoletext.shown

    local ret = { orig(screen, ...) }

    if should_show_log then
        TheFrontEnd.consoletext:Hide()
        TheFrontEnd:ShowConsoleLog()
    else
        TheFrontEnd:HideConsoleLog()
    end

    return unpack(ret)
end)

Hook(ConsoleScreen, "OnControl", function (orig, screen, ...)
    if screen._cpm_scrollable_log:OnChatControl(...) then
        return true
    end
    return orig(screen, ...)
end)

-- Vanilla currently always closes the log
Hook(ConsoleScreen, "Close", function (orig, screen, ...)
    local should_hide_log = Config.CLOSELOGONRUN or not screen._cpm_scrollable_log.shown

    local ret = { orig(screen, ...) }

    -- Undo overrides
    Impurities:Restore(TheFrontEnd, "HideConsoleLog")
    Impurities:Restore(TheFrontEnd, "ShowConsoleLog")

    if should_hide_log then
        TheFrontEnd:HideConsoleLog()
    else
        TheFrontEnd:ShowConsoleLog()
    end

    return unpack(ret)
end)

return {}
