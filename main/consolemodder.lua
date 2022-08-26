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
local ConsoleHistoryWidget = G.package.loaded["widgets/consolehistorywidget"]

-- In beta
G.global "ConsoleScreenSettings"

ConsoleModder = Class(function (self, screen, console_history, localremote_history)
    self.screen                  = assert(screen)
    self.console_edit            = assert(screen.console_edit)
    self.arrowkey_set_to_history = false
    self.history                 = assert(console_history)
    self.remotetogglehistory     = assert(localremote_history)
    self.current                 = assert(self.console_edit:GetString())
    self.islogshown              = Config.OPENLOGWITHCONSOLE or TheFrontEnd.consoletext.shown

    self.buttons = {}

    ConsolePP.tmp.CM = self -- weak reference for in game debugging
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
    --doesn't modify the global environment so automatically works with hot reload

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
        local continue, valid = self:VerifyValidateChar(...)
        if continue then return _ValidateChar(s, ...)
        else return valid end
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

function ConsoleModder:VerifyOnTextEntered()
    self.console_edit:SetEditing(true)
    -- Force run on CTRL+Enter
    if TheInput:IsKeyDown(G.KEY_CTRL) then
        self:Run()

        return true
    -- Create newline on Shift+Enter or in unfinished block
    elseif TheInput:IsKeyDown(G.KEY_SHIFT) or CodeMissingClosingStatement(self.console_edit:GetString()) then
        self.console_edit.inst.TextEditWidget:OnTextInput('\n')
        self:AdjustLabelHeight()
        return true
    else
        -- Close console!
        self.console_edit:SetEditing(false)
        return false
    end
end

function ConsoleModder:Close()
    -- use Class methods instead of overrides (assumes definitions are in FrontEnd class!)
    TheFrontEnd.HideConsoleLog = nil
    TheFrontEnd.ShowConsoleLog = nil

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

    self.staticroot = staticroot
end

local History = require "history"

local function getshard()
    if G.TheWorld:HasTag "forest" then
        return "Master"
    elseif G.TheWorld:HasTag "cave" then
        return "Caves"
    end
end

---[[
function ConsoleModder:PostOnBecomeActive()
    local remote = self.remotetogglehistory[#self.history]
    if remote ~= nil then
        self.screen:ToggleRemoteExecute(remote)
    end
    TheFrontEnd.consoletext:Hide()
    function TheFrontEnd.ShowConsoleLog(frontend)
        self.islogshown = true
        frontend.consoletext.shown = self.islogshown
        self.scrollable_log:Show()
        for _,btn in ipairs(self.buttons) do btn:Show() end
    end
    function TheFrontEnd.HideConsoleLog(frontend)
        self.islogshown = false
        frontend.consoletext.shown = false
        self.scrollable_log:Hide()
        for _,btn in ipairs(self.buttons) do btn:Hide() end
    end

    if self.islogshown then TheFrontEnd:ShowConsoleLog() else TheFrontEnd:HideConsoleLog() end

    if self.screen.toggle_remote_execute then
        local shard = getshard()
        if shard then
            self.buttons[shard].onclick()
        end
    end

end

--]]

local Menu = require "widgets/menu"
local TEMPLATES = require "widgets/redux/templates"

local function make_log_switch_buttons(self)
    -- If no dedicated servers, don't make buttons
    if not G.TheNet:GetIsClient() and not G.TheNet:GetIsHosting() then return end

    local x = -490
    local y = 210
    local sz = {100, 50}
    do
        local btn = self.staticroot:AddChild(TEMPLATES.StandardButton(function ()
            self.scrollable_log.history = Logs.client
            self.scrollable_log:RefreshWidgets(true)
            self.scrollable_log:SetTextColour(1, 1, 1, 1)

            self.console_edit:SetEditing(true)
            return true
        end, "Client", sz))
        table.insert(self.buttons, btn)
        self.buttons["Client"] = btn
        btn:SetPosition(x, y)
    end

    local colours = {G.WEBCOLOURS.TEAL, G.WEBCOLOURS.ORANGE}
    for i, shard in ipairs {"Master", "Caves"} do
        local btn = self.staticroot:AddChild(TEMPLATES.StandardButton(function ()
            Logs:UpdateClusterLog(shard)
            self.scrollable_log.history = Logs.cluster[shard]
            self.scrollable_log:SetTextColour(unpack(colours[i]))
            self.scrollable_log:RefreshWidgets(true)

            self.console_edit:SetEditing(true)
            return true
        end, shard, sz))
        btn:SetPosition(x + i * 100, y)
        table.insert(self.buttons, btn)
        self.buttons[shard] = btn
        btn:SetTextColour(colours[i])
        btn:SetTextFocusColour(colours[i])
    end
end

function ConsoleModder:PostInit()
    local words = {
        c_ = {},
        d_ = {},
        The = {},
        --disable because these currently interfere with dynamic completions
        --Get = {},
        --Set = {},
    }

    for key in pairs(G) do
        for delim in pairs(words) do
            if key:starts(delim) then
                table.insert(words[delim], key:sub(#delim+1))
            end
        end
    end

    local prediction_widget = self.console_edit.prediction_widget

    if prediction_widget then
        for _,v in ipairs(prediction_widget.word_predictor.dictionaries) do
            if v.delim == "c_" then
                v.words = words["c_"]
                break
            end
        end
    end


    TheFrontEnd:HideConsoleLog()
    --TheFrontEnd:ShowConsoleLog()
    self:BuildStaticRoot()

    self.scrollable_log = self.staticroot:AddChild(ScrollableConsoleLog(Logs.client))
    --self.scrollable_log:SetVAnchor(G.ANCHOR_BOTTOM)
    self.scrollable_log:SetPosition(-550, -200)
    self.scrollable_log:RefreshOnClientPrint()

    make_log_switch_buttons(self)

    self.console_edit.OnStopForceEdit = function ()
        for i = 1, #self.buttons do
            if self.buttons[i].focus then
                --self.console_edit:SetEditing(true)
                return
            end
        end
        self:Close()
    end

    self.scrollable_log:SetPosition(-550, -200)

    self.console_edit:AddWordPredictionDictionary {words = words.d_ , delim = "d_" , num_chars = 0}
    self.console_edit:AddWordPredictionDictionary {words = words.The, delim = "The", num_chars = 0}
    --self.console_edit:AddWordPredictionDictionary {words = words.Get, delim = "Get", num_chars = 0}
    --self.console_edit:AddWordPredictionDictionary {words = words.Set, delim = "Set", num_chars = 0}

    --better implement myself
    --self.console_edit.allow_newline = true

    -- game does this now!
    --self.console_edit.validrawkeys[G.KEY_V] = true

    self.screen.edit_bg:SetTexture("images/textbox_long_thinborder.xml", "textbox_long_thinborder.tex" )
	self.screen.root:SetPosition(0, baseypos, 0)
    self.screen.label_height = label_height
    self.screen.edit_width = edit_width
	self.screen.edit_bg:ScaleToSize(edit_bg_padding + self.screen.edit_width, label_height )
	self.screen.edit_bg:SetPosition( 0, 10 )
	self.screen.console_remote_execute:SetPosition( -self.screen.edit_width*0.5 -200*0.5 - 35, 0 )
    self.console_edit:SetRegionSize(self.screen.edit_width, self.screen.label_height)

    self.console_edit:SetVAlign(G.ANCHOR_TOP)

    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLBACK, true)
    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLFWD, true)
end

-- Produce bad input on some keybinds
WINDOWS_FUNKY_INPUTS = {[3] = true, [12] = true}

function ConsoleModder:VerifyValidateChar(c)
    local continue = false
    local valid = true
    -- If Ctrl+Enter, then we don't want to input a newline!
    -- But we still want a new line when pasting
    if WINDOWS_FUNKY_INPUTS[c:byte()] then
        valid = false
    elseif c == '\n' and (not TheInput:IsKeyDown(G.KEY_CTRL) or self.console_edit.pasting) then
        valid = true
    else
        continue = true
    end

    return continue, valid
end

function ConsoleModder:VerifyEditOnRawKey(key, down)
    local ctrl_down = TheInput:IsKeyDown(G.KEY_CTRL)
    local contents = self.console_edit:GetString()
    local cursorpos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()

    if key ~= G.KEY_DOWN and key ~= G.KEY_UP then
        self.goalxpos = nil
    end
    self.screen.inst:DoTaskInTime(0, function() self:AdjustLabelHeight() end)
    if not down then return false end

    if key == G.KEY_PERIOD or (key == G.KEY_SEMICOLON and TheInput:IsKeyDown(G.KEY_SHIFT)) then
        self:DynamicComplete()
    end

    if not Config.REMOTETOGGLEKEYS[key] and ctrl_down then
        self.screen.ctrl_pasting = true
    end

    if key == G.KEY_HOME then
        self.console_edit.inst.TextEditWidget:SetEditCursorPos(StrGetLineStart(contents, cursorpos) - 1)
        ForceFocusTextEditCursor(self.console_edit)
        return true

    elseif key == G.KEY_END then
        self.console_edit.inst.TextEditWidget:SetEditCursorPos(StrGetLineEnd(contents, cursorpos))
        ForceFocusTextEditCursor(self.console_edit)
        return true

    elseif key == KEY_BACKSPACE then
        local linestart = StrGetLineStart(contents, cursorpos)
        local chars = contents:sub(linestart, cursorpos)
        if chars:find "^%s+$" then
            for i = 1, math.min(#chars, 4) do
                self.console_edit.inst.TextEditWidget:OnKeyDown(KEY_BACKSPACE)
                --self.console_edit.inst.TextEditWidget:OnKeyUp(KEY_BACKSPACE)
            end
            return true
        end
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
            do
                local idx = self.screen.history_idx
                self.screen.history_idx = idx and idx > 1 and idx - 1 or #self.history
            end
            -- self:UpdateGoalXPos()
            self.console_edit:SetString( self.history[ self.screen.history_idx ] )
            -- self:SetToGoalXPos(StrGetLineStart(self.console_edit:GetString(), #self.console_edit:GetString()))

            if self.remotetogglehistory[self.screen.history_idx] ~= nil then
                self.screen:ToggleRemoteExecute(self.remotetogglehistory[self.screen.history_idx])
            end
            --[[
            self.screen.console_history:Show(self.history, self.history_idx)
            --]]
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
                -- self:UpdateGoalXPos()
                self.console_edit:SetString(self.current)
                -- self:SetToGoalXPos(1)
                self.screen.history_idx = nil
            else
                self.screen.history_idx = math.min(#self.history, self.screen.history_idx + 1)
                -- self:UpdateGoalXPos()
                self.console_edit:SetString(self.history[self.screen.history_idx])
                -- self:SetToGoalXPos(1)

                if self.remotetogglehistory[self.screen.history_idx] ~= nil then
                    self.screen:ToggleRemoteExecute(self.remotetogglehistory[self.screen.history_idx])
                end
                --[[
                self.screen.console_history:Show(self.history, self.history_idx)
                --]]
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

	if fnstr ~= "" and fnstr ~= self.history[#self.history] then
		table.insert(self.history, fnstr)
        local toggle = self.screen.toggle_remote_execute
        self.remotetogglehistory[#self.history] = toggle
        if G.ConsoleScreenSettings then
            G.ConsoleScreenSettings:AddLastExecutedCommand(fnstr, toggle)
            G.ConsoleScreenSettings:Save()
        end
	end

	if self.screen.toggle_remote_execute then
        local x, _, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        if fnstr:byte() == string.byte("=") then
            fnstr = ("print(%s)"):format(fnstr:sub(2))
        end
		G.TheNet:SendRemoteExecute(fnstr, x, z)

        self.screen.inst:DoTaskInTime(0, function ()
            local shard = getshard()
            if shard and self.buttons[shard] then
                self.buttons[shard].onclick()
            end
            --self.scrollable_log:RefreshWidgets(true)
        end)
	else
		G.ExecuteConsoleCommand(fnstr)
        --self.scrollable_log:RefreshWidgets()
        local btn = self.buttons["Client"]
        if btn then btn:onclick() end
	end
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
    if not self.console_edit.prediction_widget then return end
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

