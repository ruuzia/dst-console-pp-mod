local G = GLOBAL
local Text = require "widgets/text"
local ChatScrollList = require "widgets/redux/chatscrolllist"
local Widget = require "widgets/widget"


local row_height = 20
local QUEUE_SIZE = 22

local size = row_height
local font = G.BODYTEXTFONT
local scissor_x      = -250

local scissor_y      = -10
local scissor_width  = 1200
local scissor_height = 400

local scrolltop = 5

local function LineColor(line, default)
    if line:find("Error") or line:find("ERROR") then
        return G.WEBCOLOURS.RED
    elseif line:find("Warning") or line:find("WARNING") then
        return G.WEBCOLOURS.YELLOW
    elseif line:find("Success") or line:find("SUCCESS") then
        return G.WEBCOLOURS.GREEN
    elseif line:find("Note") or line:find("NOTE") then
        return G.UICOLOURS.GOLD
    else
        return default
    end
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
            local line = self.history[QUEUE_SIZE - i + 1]
            self.widgets[i] = parent:AddChild(Text(font, size, line, LineColor(line, self.text_colour)))
            self.widgets[i]:SetHAlign(G.ANCHOR_LEFT)
            local width = self.widgets[i]:GetRegionSize()
            self.widgets[i]:SetPosition(width * 0.5, (i - 1) * row_height)
        end
        return self.widgets, row_height
    end

    function self.can_scroll_fn(target, current)
        return target <= scrolltop and math.abs(target) < #self.history - QUEUE_SIZE + 5
    end

    function self.update_fn(chatline, index, current_scroll_pos, row_offset)
        chatline:Show()
        local i = #self.history + current_scroll_pos - (index - 2)
        local line = self.history[i]
        chatline:SetString(line)
        if line then
            chatline:SetColour(LineColor(line, self.text_colour) or {1,1,1,1})
        end
        local x = chatline:GetRegionSize()
        if x then
            chatline:SetPosition(x*0.5, chatline:GetPosition().y)
        end
    end


    self:MakeLogScrollList()
end)

function ScrollableConsoleLog:SetTextColour(r, g, b, a)
    self.text_colour = {r, g, b, a or 1}
    self:RefreshWidgets(false)
end

function ScrollableConsoleLog:RefreshOnClientPrint()
    self.print_hook = function ()
        self:RefreshWidgets(true)
    end

    G.AddPrintLogger(self.print_hook)
end

function ScrollableConsoleLog:Kill()
    ScrollableConsoleLog._base.Kill(self)

    local print_loggers = Logs.print_loggers
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
    self.scroll_list = self:AddChild(ChatScrollList(self.create_widgets, self.update_fn, self.can_scroll_fn, scissor_x, scissor_y, scissor_width, scissor_height))
    self:RefreshWidgets(true)
    self.scroll_list.scroll_per_click = Config.SCROLLSPEED
end

function ScrollableConsoleLog:OnChatControl(control, down)
    return self.scroll_list:OnChatControl(control, down)
end
