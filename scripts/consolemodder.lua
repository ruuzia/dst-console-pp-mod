--local ConsoleScreen = require "screens/consolescreen"
local G = GLOBAL
local TheInput = G.TheInput
local rawget = G.rawget
local assert = G.assert

local label_height = 50
local fontsize = 30
local edit_width = 850
local edit_bg_padding = 50
local baseypos = 75

local Widget = require "widgets/widget"

---@class ConsoleModder
---@field screen table
---@field console_edit table
---@field arrowkey_set_to_history boolean
---@field history table
---@field remotetogglehistory table
---@field current string
---@field goalxpos number|nil
---@field islogshown boolean
---@param self ConsoleModder
ConsoleModder = Class(function (self, screen, console_history, localremote_history)
    self.screen                  = assert(screen)
    self.console_edit            = assert(screen.console_edit)
    self.arrowkey_set_to_history = false
    self.history                 = assert(console_history)
    self.remotetogglehistory     = assert(localremote_history)
    self.current                 = assert(self.console_edit:GetString())
    self.islogshown              = Config.OPENLOGWITHCONSOLE or TheFrontEnd.consoletext.shown

    --self.screen.CPPmod = self
    --self.console_edit.CPPmod = self
    self:InitiateHookers()
    self:PostInit()
end)

function ConsoleModder:AdjustLabelHeight()
    local _, nlcount = self.console_edit:GetString():gsub('\n', '')
    self.screen.label_height = label_height + fontsize * nlcount
	self.screen.root:SetPosition(self.screen.root:GetPosition().x, baseypos + (fontsize - 2) * nlcount / 2, 0)
    local wcurr, hcurr = self.screen.edit_bg:GetSize()
    if wcurr and hcurr and hcurr ~= self.screen.label_height then
        self.screen.edit_bg:ScaleToSize( self.screen.edit_width + edit_bg_padding, self.screen.label_height )
        self.console_edit:SetRegionSize( self.screen.edit_width, self.screen.label_height )
    end
end

function ConsoleModder:InitiateHookers()
    --I don't like that all these closures are recreated each time the screen is instantiated
    --but I do like that it doesn't modify the global environment so automatically works with hot reload

    local _OnBecomeActive = self.screen.OnBecomeActive
    self.screen.OnBecomeActive = function(s, ...)
        _OnBecomeActive(s, ...)
        self:PostOnBecomeActive()
    end


    local _OnRawKey = self.console_edit.OnRawKey
    self.console_edit.OnRawKey = function(s, ...)
        return self:VerifyEditOnRawKey(...) or _OnRawKey(s, ...)
    end

    local _ValidateChar = self.console_edit.ValidateChar
    self.console_edit.ValidateChar = function(s, ...)
        return self:VerifyValidateChar(...) or _ValidateChar(s, ...)
    end

    AssertDefinitionSource(self.screen, "OnRawKeyHandler", "scripts/screens/consolescreen.lua")
    self.screen.OnRawKeyHandler = function(_, ...)
        return self:ScreenOnRawKeyHandler(...)
    end

    local _OnControl = self.screen.OnControl
    self.screen.OnControl = function(s, ...)
        return self:VerifyOnControl(...)
            or self.scrollable_log:OnChatControl(...)
            or _OnControl(s, ...)
    end

    local _OnTextEntered = self.screen.OnTextEntered
    self.screen.OnTextEntered = function(s, ...)
        return self:VerifyOnTextEntered() or _OnTextEntered(s, ...)
    end
    AssertDefinitionSource(self.screen, "Run", "scripts/screens/consolescreen.lua")

    self.screen.Run = function()
        return self:Run()
    end

    AssertDefinitionSource(self.screen, "Close", "scripts/screens/consolescreen.lua")
    self.screen.Close = function()
        return self:Close()
    end
end

local function DoRun(--[[inst]]_, self)
    self.screen.runtask = nil
    self:Run()
    --self.screen:Close()
end

function ConsoleModder:VerifyOnTextEntered()
    self.console_edit:SetEditing(true)
    if TheInput:IsKeyDown(G.KEY_SHIFT) or CodeMissingClosingStatement(self.console_edit:GetString()) then
        self.console_edit.inst.TextEditWidget:OnTextInput('\n')
        self:AdjustLabelHeight()
        return true
    elseif TheInput:IsKeyDown(G.KEY_CTRL) then
        self:Run()
        return true
    else
        self.console_edit:SetEditing(false)
        return false
    end
end

function ConsoleModder:Close()
    TheFrontEnd.HideConsoleLog = G.getmetatable(TheFrontEnd).HideConsoleLog
    TheFrontEnd.ShowConsoleLog = G.getmetatable(TheFrontEnd).ShowConsoleLog

	TheInput:EnableDebugToggle(true)
	TheFrontEnd:PopScreen(self.screen)
    if Config.CLOSELOGONRUN or not self.islogshown then
        TheFrontEnd:HideConsoleLog()
    else
        TheFrontEnd:ShowConsoleLog()
    end
end

function ConsoleModder:BuildStaticRoot()
    local staticroot = self.screen:AddChild(Widget(""))
    staticroot:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
    staticroot:SetHAnchor(G.ANCHOR_MIDDLE)
    staticroot:SetVAnchor(G.ANCHOR_MIDDLE)

    staticroot = staticroot:AddChild(Widget(""))
    staticroot:SetPosition(0,100,0)

    self.screen.staticroot = staticroot
end

---[[
function ConsoleModder:PostOnBecomeActive()
    local remote = self.remotetogglehistory[#self.history]
    if remote ~= nil then
        self.screen:ToggleRemoteExecute(remote)
    end
    TheFrontEnd:HideConsoleLog()
    --TheFrontEnd:ShowConsoleLog()
    self:BuildStaticRoot()

    self.scrollable_log = self.screen.staticroot:AddChild(ScrollableConsoleLog(self.history))
    --self.scrollable_log:SetVAnchor(G.ANCHOR_BOTTOM)
    self.scrollable_log:SetPosition(-550, -200)

    function TheFrontEnd.ShowConsoleLog(frontend)
        self.islogshown = true
        frontend.consoletext.shown = self.islogshown
        self.scrollable_log:Show()
    end
    function TheFrontEnd.HideConsoleLog(frontend)
        self.islogshown = false
        frontend.consoletext.shown = false
        self.scrollable_log:Hide()
    end

    if self.islogshown then TheFrontEnd:ShowConsoleLog() else TheFrontEnd:HideConsoleLog() end
end
--]]

function ConsoleModder:PostInit()
    local words = {
        c_ = {},
        d_ = {},
        The = {},
        Get = {},
        Set = {},
    }

    for key in pairs(G) do
        for delim in pairs(words) do
            if key:starts(delim) then
                table.insert(words[delim], key:sub(#delim+1))
            end
        end
    end

    for _,v in ipairs(self.console_edit.prediction_widget.word_predictor.dictionaries) do
        if v.delim == "c_" then
            v.words = words["c_"]
            break
        end
    end


    self.console_edit:AddWordPredictionDictionary {words = words.d_ , delim = "d_" , num_chars = 0}
    self.console_edit:AddWordPredictionDictionary {words = words.The, delim = "The", num_chars = 0}
    self.console_edit:AddWordPredictionDictionary {words = words.Get, delim = "Get", num_chars = 0}
    self.console_edit:AddWordPredictionDictionary {words = words.Set, delim = "Set", num_chars = 0}

    --better implement myself
    --self.console_edit.allow_newline = true

    -- game does this now!
    --self.console_edit.validrawkeys[G.KEY_V] = true

    self.screen.edit_bg:SetTexture("images/textbox_long_thinborder.xml", "textbox_long_thinborder.tex" )
	self.screen.root:SetPosition(100, baseypos, 0)
    self.screen.label_height = label_height
    self.screen.edit_width = edit_width
	self.screen.edit_bg:ScaleToSize(edit_bg_padding + self.screen.edit_width, label_height )
	self.screen.edit_bg:SetPosition( 0, 10 )
	self.screen.console_remote_execute:SetPosition( -self.screen.edit_width*0.5 -200*0.5 - 35, 0 )
    self.console_edit:SetRegionSize(self.screen.edit_width, self.screen.label_height)

    self.console_edit:SetVAlign(G.ANCHOR_TOP)

    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLBACK, true)
    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLFWD, true)

    --self.console_edit:EnableWordWrap(true)
    --self.console_edit:EnableWhitespaceWrap(true)
    --self.console_edit:EnableScrollEditWindow(true)

end

function ConsoleModder:VerifyValidateChar(c)
    return c == '\t'
end

function ConsoleModder:VerifyEditOnRawKey(key, down)
    if key ~= G.KEY_DOWN and key ~= G.KEY_UP then
        self.goalxpos = nil
    end
    self.screen.inst:DoTaskInTime(0, function() self:AdjustLabelHeight() end)
    if not down then return false end

    if key == G.KEY_PERIOD or (key == G.KEY_SEMICOLON and TheInput:IsKeyDown(G.KEY_SHIFT)) then
        self:DynamicComplete()
    end

    if not Config.REMOTETOGGLEKEYS[key] and TheInput:IsKeyDown(G.KEY_CTRL) then
        self.screen.ctrl_pasting = true
    end

    if key == G.KEY_HOME then
        self.console_edit.inst.TextEditWidget:SetEditCursorPos(
            StrGetLineStart(self.console_edit:GetString(),
            self.console_edit.inst.TextEditWidget:GetEditCursorPos()) - 1)
        ForceFocusTextEditCursor(self.console_edit)
        return true

    elseif key == G.KEY_END then
        self.console_edit.inst.TextEditWidget:SetEditCursorPos(
            StrGetLineEnd(self.console_edit:GetString(),
            self.console_edit.inst.TextEditWidget:GetEditCursorPos()))
        ForceFocusTextEditCursor(self.console_edit)
        return true
    end

    self.screen.inst:DoTaskInTime(0, function() self:AdjustLabelHeight() end)
end

function ConsoleModder:UpdateGoalXPos()
    if self.goalxpos then return end
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()
    local linestart = StrGetLineStart(str, pos)
    self.goalxpos = TextBoxStringToPos(self.console_edit.font, self.console_edit.size, str:sub(linestart, pos))
end

function ConsoleModder:SetToGoalXPos(linestart)
    local str = self.console_edit:GetString()
    linestart = linestart or StrGetLineStart(str, self.console_edit.inst.TextEditWidget:GetEditCursorPos())
    local lineend = StrGetLineEnd(str, linestart)
    local col = TextBoxXPosToCol(self.console_edit.font,
                                 self.console_edit.size,
                                 self.goalxpos,
                                 str:sub(linestart, lineend),
                                 string.sub)

    self.console_edit.inst.TextEditWidget:SetEditCursorPos(col + linestart - 1)
end

-- runs after TextEdit:OnRawKey if it didnt return false
-- so only for some special non-input keys
-- completely overriding because im changing basically everything
function ConsoleModder:ScreenOnRawKeyHandler(key, down)
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()

    if key == G.KEY_UP then
        if down then
            local linestart = StrGetLineStart(str, pos)
            if linestart == 1 then
                self.arrowkey_set_to_history = true
            else
                --hello\nthere
                --       ^
                --   linestart
                self.arrowkey_set_to_history = false
                self:UpdateGoalXPos()
                self:SetToGoalXPos(StrGetLineStart(str, linestart - 2))
                return true
            end
        elseif #self.history > 0 and self.arrowkey_set_to_history then
            self.arrowkey_set_to_history = false
            self.screen.history_idx = self.screen.history_idx and self.history[self.screen.history_idx] == str
                                  and self.screen.history_idx or nil
            if self.screen.history_idx == nil then
                self.current = str
            end
            self.screen.history_idx = self.screen.history_idx
                                  and math.max(1, self.screen.history_idx - 1)
                                   or #self.history
            self:UpdateGoalXPos()
            self.console_edit:SetString( self.history[ self.screen.history_idx ] )
            self:SetToGoalXPos(StrGetLineStart(self.console_edit:GetString(), #self.console_edit:GetString()))

            if self.remotetogglehistory[self.screen.history_idx] ~= nil then
                self.screen:ToggleRemoteExecute(self.remotetogglehistory[self.screen.history_idx])
            end
        end

    elseif key == G.KEY_DOWN then
        if down then
            local lineend = StrGetLineEnd(str, pos)
            if lineend == #str then
                self.arrowkey_set_to_history = true
            else
                self.arrowkey_set_to_history = false
                self:UpdateGoalXPos()
                self:SetToGoalXPos(lineend+2)
                return true
            end
        elseif #self.history > 0 and self.screen.history_idx and self.arrowkey_set_to_history then
            if self.screen.history_idx == #self.history then
                self:UpdateGoalXPos()
                self.console_edit:SetString(self.current)
                self:SetToGoalXPos(1)
                self.screen.history_idx = nil
            else
                self.screen.history_idx = math.min(#self.history, self.screen.history_idx + 1)
                self:UpdateGoalXPos()
                self.console_edit:SetString(self.history[self.screen.history_idx])
                self:SetToGoalXPos(1)

                if self.remotetogglehistory[self.screen.history_idx] ~= nil then
                    self.screen:ToggleRemoteExecute(self.remotetogglehistory[self.screen.history_idx])
                end
            end
        end

    elseif not down and Config.REMOTETOGGLEKEYS[key] then
        if not self.screen.ctrl_pasting then
            self.screen:ToggleRemoteExecute()
        end
        self.screen.ctrl_pasting = false
    else
        self.arrowkey_set_to_history = false
    end
end

function ConsoleModder:VerifyOnControl(control, down)
    if not down and control == G.CONTROL_OPEN_DEBUG_CONSOLE and TheInput:IsKeyDown(G.KEY_SHIFT) then
        return true
    end
end

function ConsoleModder:Run()

	local fnstr = self.console_edit:GetString()

    G.SuUsedAdd("console_used")

	if fnstr ~= "" --[=[and fnstr ~= self.history[#self.history]]=] then
		table.insert(self.history, fnstr)
        self.remotetogglehistory[#self.history] = self.screen.toggle_remote_execute
	end

	if self.screen.toggle_remote_execute then
        local x, _, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        if fnstr:byte() == string.byte("=") then
            fnstr = ("print(%s)"):format(fnstr:sub(2))
        end
		G.TheNet:SendRemoteExecute(fnstr, x, z)
	else
		G.ExecuteConsoleCommand(fnstr)
	end
    self.scrollable_log:RefreshWidgets()
end

local indexing_regexp = '()'       --> start index
                     .. '([%w_]+)' --> word
                     .. '%s*'
                     .. '(%(?%)?)' --> optional call --support only for simple calls
                     .. '%s*'
                     .. '([.:])'   --> indexer
                     .. '$'
--bypass strict.lua
local rawglobal = G.setmetatable({}, {__index=function(_, k) return rawget(G, k) end})
local simple_get_display_string = function(word) return word end

function ConsoleModder:DynamicComplete()
    local str = self.console_edit:GetString()
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local tnames = {}
    local calls = {}
    local indexers = {}
    local searchpos = pos
    local expressionstart
    repeat
        local wstart, word, call, indexer = str:sub(1, searchpos):match(indexing_regexp)
    if not wstart then break end
        expressionstart = wstart
        searchpos = wstart - 1
        table.insert(tnames, word)
        calls[#tnames] = call
        indexers[#tnames] = indexer
    until false
    if #tnames <= 0 then return end

    local t = rawglobal
    local mt
    for i = #tnames, 1, -1 do
        local prevtbl = t
        t = t[tnames[i]]
        if type(t) == "function" and calls[i] == "()" then
            t = t(indexers[i+1] == ":" and prevtbl or nil)
        end
        mt = G.getmetatable(t)
        if type(t) ~= "table" and (not mt or type(mt.__index) ~= "table") then return end
    end

    local keys = {}
    local onlyfuncs = str:byte(pos) == string.byte(":")
    if type(t) == "table" then
        for k,v in pairs(t) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    --supports metatable __index but not a whole chain of them
    if mt and type(mt.__index) == "table" then
        for k,v in pairs(mt.__index) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    if not keys[1] then return end
    local delim = str:sub(expressionstart, pos)
    for _,v in ipairs(self.console_edit.prediction_widget.word_predictor.dictionaries) do
        if v.delim == delim then
            v.words = keys
            return self.console_edit.prediction_widget:RefreshPredictions()
        end
    end
    self.console_edit:AddWordPredictionDictionary {
        words = keys,
        delim = delim,
        num_chars = 0,
        GetDisplayString = simple_get_display_string,
    }
    local dicts = self.console_edit.prediction_widget.word_predictor.dictionaries
    --bring new dictionary to front
    dicts[1], dicts[#dicts] = dicts[#dicts], dicts[1]
    self.console_edit.prediction_widget:RefreshPredictions()
end

