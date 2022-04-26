local G = GLOBAL
local Text = require "widgets/text"
local ChatScrollList = require "widgets/redux/chatscrolllist"
local Widget = require "widgets/widget"
local Deque = require "deque"

local MAX_LOG_HISTORY = 500

local name, print_loggers = G.debug.getupvalue(G.AddPrintLogger, 1) --assuming first and only upvalue
modassert(name == "print_loggers", "unable to find print_loggers table")

local clientlog = Deque()

if ConsolePP.save.clientlog_lines then
    for _, line in ConsolePP.save.clientlog_lines:IPairs() do
        clientlog:PushRight(line)
    end
    local i = 1
    repeat
        if G.debug.getinfo(print_loggers[i], "S").source:find("^"..MODROOT) then
            print("[Console++] removing old print logger")
            table.remove(print_loggers, i)
        else
            i = i + 1
        end
    until i > #print_loggers
end
ConsolePP.save.clientlog_lines = clientlog

local function client_logger(...)
    local args = {...}
    for i = 1, #args do
        args[i] = tostring(args[i])
    end
    local str = table.concat(args)
    for line in str:gmatch "[^\n]+" do
        clientlog:PushRight(line)
    end
    for _ = MAX_LOG_HISTORY, clientlog:Len() do
        clientlog:PopLeft()
    end
end

G.AddPrintLogger(client_logger)

local row_height = 20
local QUEUE_SIZE = 22

local size = row_height
local font = G.BODYTEXTFONT
local scissor_x      = -250

local scissor_y      = -10
local scissor_width  = 800
local scissor_height = 400

local scrolltop = 5

local function can_scroll_fn(target, current)
    return target <= scrolltop and math.abs(target) < clientlog:Len() - QUEUE_SIZE + 5
end

local function update_fn(chatline, index, current_scroll_pos, row_offset)
    chatline:Show()
    local i = clientlog.right + current_scroll_pos - (index - 2)
    chatline:SetString(clientlog.seq[i])
    local x = chatline:GetRegionSize()
    if not x then return end
    chatline:SetPosition(x*0.5, chatline:GetPosition().y)
end

---@class Widget
---@field AddChild fun(Widget): table
---@field _base table
---@field shown boolean

---@class ScrollableConsoleLog : Widget
---@field widgets table
---@field data table
---@field history table
---@field scroll_list table
---@field create_widgets function
---@field print_hook function
ScrollableConsoleLog = Class(Widget, function(self, history)
    Widget._ctor(self, "ScrollableConsoleLog")
    self.widgets = {}

    self.history = history

    function self.create_widgets(parent)
        for i = 1, QUEUE_SIZE do
            self.widgets[i] = parent:AddChild(Text(font, size, clientlog.seq[clientlog.left + QUEUE_SIZE - i + 1]))
            self.widgets[i]:SetHAlign(G.ANCHOR_LEFT)
            local width = self.widgets[i]:GetRegionSize()
            self.widgets[i]:SetPosition(width * 0.5, (i - 1) * row_height)
        end
        return self.widgets, row_height
    end

    function self.print_hook()
        self:RefreshWidgets(true)
    end

    self:MakeLogScrollList()

    G.AddPrintLogger(self.print_hook)

    TheFrontEnd.consoletext.shown = true

end)

function ScrollableConsoleLog:Kill()
    ScrollableConsoleLog._base.Kill(self)

    for i = 1, #print_loggers do
        if print_loggers[i] == self.print_hook then
            table.remove(print_loggers, i)
        end
    end
end

function ScrollableConsoleLog:RefreshWidgets(scroll_to_top)
    if scroll_to_top then
        self.scroll_list.current_scroll_pos = scrolltop
        self.scroll_list.target_scroll_pos = scrolltop
    end
    self.scroll_list:RefreshView()
end

function ScrollableConsoleLog:MakeLogScrollList()
    self.scroll_list = self:AddChild(ChatScrollList(self.create_widgets, update_fn, can_scroll_fn, scissor_x, scissor_y, scissor_width, scissor_height))
    self:RefreshWidgets(true)
    self.scroll_list.scroll_per_click = Config.SCROLLSPEED
end

function ScrollableConsoleLog:OnChatControl(control, down)
    return self.scroll_list:OnChatControl(control, down)
end
