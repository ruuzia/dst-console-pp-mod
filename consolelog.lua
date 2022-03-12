local G = GLOBAL

TheFrontEnd.consoletext:SetPosition(-100, 100, 0)
--TheFrontEnd.consoletext.closeonrun = Config.CloseLogOnRun

--@TODO: Implement scrolling console log
---might just do it from scratch

--[===[---- CONSOLE -----------
self.consoletext = Text(BODYTEXTFONT, 20, "CONSOLE TEXT")
self.consoletext:SetVAlign(ANCHOR_BOTTOM)
self.consoletext:SetHAlign(ANCHOR_LEFT)
self.consoletext:SetVAnchor(ANCHOR_MIDDLE)
self.consoletext:SetHAnchor(ANCHOR_MIDDLE)
self.consoletext:SetScaleMode(SCALEMODE_PROPORTIONAL)

self.consoletext:SetRegionSize(900, 406)
self.consoletext:SetPosition(0,0,0)
self.consoletext:Hide()
-----------------

local ChatScrollList = require "widgets/redux/chatscrolllist"
local ChatLine = require "widgets/redux/chatline"
local MAX_CONSOLE_LINES = 20
local font = TheFrontEnd.consoletext.font
local size = TheFrontEnd.consoletext.size
local width, height = TheFrontEnd.consoletext:GetRegionSize()
local row_height = size + 2
local line_offset = 0

local widget_rows = {}

local function CreateOutputWidgets(parent)
    for i = 1, MAX_CONSOLE_LINES do
        local chatline = parent:AddChild(ChatLine(font, width, --[[user_max_chars]]nil, width, --[[message_max_chars]]nil))
        chatline:SetPosition(-35, line_offset + (i - 1) * row_height)
        widget_rows[i] = chatline
    end

    return widget_rows, row_height
end

local function UpdateLogLine(line, index, current_row, row_offset, data)
    if index == MAX_CONSOLE_LINES then
        if row_offset == 0 then
            line:Hide()
        else
            line:Show()
        end
    end
end

local function CanScroll(goal_pos, current_pos)
    return true
end

TheFrontEnd.consoletext = ChatScrollList(CreateOutputWidgets, UpdateLogLine, CanScroll, 20, 600, 400, 600)

--TheFrontEnd.consoletext:SetVAlign(G.ANCHOR_BOTTOM)
--TheFrontEnd.consoletext:SetHAlign(G.ANCHOR_LEFT)
--TheFrontEnd.consoletext:SetHAnchor(G.ANCHOR_MIDDLE)
--TheFrontEnd.consoletext:SetVAnchor(G.ANCHOR_MIDDLE)
--TheFrontEnd.consoletext:SetScaleMode(G.SCALEMODE_PROPORTIONAL)

AssertDefinitionSource(TheFrontEnd, "UpdateConsoleOutput", "scripts/frontend.lua")
function TheFrontEnd:UpdateConsoleOutput()
    local output = G.GetConsoleOutputList()
end
--]===]
