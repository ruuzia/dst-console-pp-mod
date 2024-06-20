-- The heart of the Console++ mod.
-- Modifies the ConsoleScreen to implement a bunch of behaviour.
-- * Multiline console input
--   * Growing and shrinking console with number of lines
--   * Create newline on Shift+Enter
--   * or in an unfinished Lua block
--   * Use up and down error keys to move between lines
-- * Force run on Ctrl+Enter without closing console
-- * Multiple shard logs: Client, Master, and Caves
--   * Switch automatically to relevant log
--   * Buttons to toggle between logs
-- * Home goes to beginning of line
-- * End goes to end of line
-- * Fake tab support (tab and backspace keys)
-- * Prevent losing unsaved work when pressing up (to view command history)
--   or when closing the command window (saves it to history)
-- * Dynamic word completion

local G = GLOBAL

local Widget = require "widgets/widget"

local History = require "history"

-- In beta
G.global "ConsoleScreenSettings"

--- The ConsoleModder class wraps around a ConsoleScreen.
ConsoleModder = Class(function(self, screen)
    self.screen = assert(screen)
    self.console_edit = assert(screen.console_edit)
    self.arrowkey_set_to_history = false

    -- See ConsoleModder:ScreenOnRawKeyHandler
    self.unsaved_work = ""

    self.islogshown = Config.OPENLOGWITHCONSOLE or TheFrontEnd.consoletext.shown

    self.buttons = {}

    ConsolePP.tmp.CM = self -- weak reference for in game debugging
    self:InitiateHookers()
    self:PostInit()
end)

--- Initiate hookers.
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

    AssertDefinitionSource(self.screen, "OnRawKeyHandler", "scripts/screens/consolescreen.lua")
    local _OnRawKeyHandler = self.screen.OnRawKeyHandler
    self.screen.OnRawKeyHandler = function(_, ...)
        return self:ScreenOnRawKeyHandler(_OnRawKeyHandler, ...)
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

    -- local _OnTextInput = self.console_edit.OnTextInput
    -- self.console_edit.OnTextInput = function(console_edit, text)
    --     local ret = self:VerifyOnTextInput(text) or _OnTextInput(console_edit, text)
    --     return ret
    -- end

    local _ToggleRemoteExecute = self.screen.ToggleRemoteExecute
    self.screen.ToggleRemoteExecute = function(...)
        _ToggleRemoteExecute(...)
        self:PostToggleRemoteExecute()
    end

    local word_predictor = self.console_edit.prediction_widget.word_predictor

    -- These ones we're completely overriding
    AssertDefinitionSource(self.screen, "Run", "scripts/screens/consolescreen.lua")
    self.screen.Run = function()
        return self:Run()
    end
    AssertDefinitionSource(self.screen, "Close", "scripts/screens/consolescreen.lua")
    self.screen.Close = function()
        return self:Close()
    end
end

--- Called *before* the screen gets the OnTextEntered
--- @return boolean true to fallback to default OnTextEntered call
function ConsoleModder:VerifyOnTextEntered()
    self.console_edit:SetEditing(true)
    -- Force run on CTRL+Enter
    if TheInput:IsKeyDown(G.KEY_CTRL) then
        self:Run()

        if Config.KEEPCONSOLEOPEN then
            self.console_edit:SetEditing(false)
            return false
        else
            return true
        end
    -- KEEPCONSOLEOPEN by default just force runs
    -- And clears the console
    elseif Config.KEEPCONSOLEOPEN then
        self:Run()
        self.redo = self.console_edit:GetString()
        self.console_edit:SetString("")
        return true
    else
        -- Close console!
        self.console_edit:SetEditing(false)
        return false
    end
end

-- --- Before any text input for the console edit
-- --- @return boolean true to fallback to default OnTextInput
-- function ConsoleModder:VerifyOnTextInput(text)
--     if text == '\n' then
--         -- This is only for newline in pasted text
--         -- when pressing enter normally we actually it
--         -- in VerifyOnTextEntered
--         modassert(self.console_edit.pasting)
--         self.console_edit.inst.TextEditWidget:OnTextInput('\n')
--         return true
--     end
--     return false
-- end

-- Replace ConsoleScreen:Close()
function ConsoleModder:Close()
    -- Undo overrides
    Impurities:Restore(TheFrontEnd, "HideConsoleLog")
    Impurities:Restore(TheFrontEnd, "ShowConsoleLog")

	TheInput:EnableDebugToggle(true)
	TheFrontEnd:PopScreen(self.screen)
    if Config.CLOSELOGONRUN or not self.islogshown then
        TheFrontEnd:HideConsoleLog()
    else
        TheFrontEnd:ShowConsoleLog()
    end
end

function ConsoleModder:BuildStaticRoot()
    -- We need this for some reason
    local staticroot = self.screen:AddChild(Widget(""))
    staticroot:SetScaleMode(G.SCALEMODE_PROPORTIONAL)
    staticroot:SetHAnchor(G.ANCHOR_MIDDLE)
    staticroot:SetVAnchor(G.ANCHOR_MIDDLE)

    staticroot = staticroot:AddChild(Widget(""))
    staticroot:SetPosition(0,100,0)

    self.staticroot = staticroot
end

--- Get the active shard
---@return string|nil name of the current shard
local function GetShard()
    if rawget(G, "TheWorld") == nil then
        -- We're not in game!
        return nil
    end
    if not TheNet:GetIsClient() or not TheNet:GetIsServerAdmin() then
        -- We're not running a dedicated server
        return nil
    end

    if G.TheWorld:HasTag "forest" then
        return "Master"
    elseif G.TheWorld:HasTag "cave" then
        return "Caves"
    end

    -- return nil
end

--- We do out initialization here
function ConsoleModder:PostOnBecomeActive()
    -- Behevior: restore remote/local state of last command
    -- Also: syncs with which shard log is open
    local history = G.ConsoleScreenSettings:GetConsoleHistory()
    local historyline = history and history[#history]
    local remote
    if historyline == nil then
        remote = true
    else
        remote = historyline.remote
    end
    self.screen:ToggleRemoteExecute(remote or false)

    TheFrontEnd.consoletext:Hide()

    Impurities:New(TheFrontEnd, "ShowConsoleLog")
    Impurities:New(TheFrontEnd, "HideConsoleLog")
    TheFrontEnd.ShowConsoleLog = function (frontend)
        self.islogshown = true
        frontend.consoletext.shown = self.islogshown
        self.scrollable_log:Show()
        for _,btn in ipairs(self.buttons) do btn:Show() end
    end
    TheFrontEnd.HideConsoleLog = function (frontend)
        self.islogshown = false
        frontend.consoletext.shown = false
        self.scrollable_log:Hide()
        for _,btn in ipairs(self.buttons) do btn:Hide() end
    end

    if self.islogshown then TheFrontEnd:ShowConsoleLog() else TheFrontEnd:HideConsoleLog() end

    if self.screen.toggle_remote_execute and TheNet:GetIsClient() and TheNet:GetIsServerAdmin() then
        local shard = GetShard()
        if shard and self.buttons[shard] then
            self.buttons[shard].onclick()
        end
    end

end

local Menu = require "widgets/menu"
local TEMPLATES = require "widgets/redux/templates"
local TextButton = require "widgets/textbutton"

-- Log buttons to toggle between Client, Server, and Caves
local function logButton(onclick, label, color)
    local btn = TextButton(label)
    btn:SetOnClick(onclick)
    btn:SetText(label)
    btn:SetTextColour(color)
    --btn:SetTextFocusColour(G.UICOLOURS.GOLD)
    btn:SetTextFocusColour(color)
    btn:SetFont(G.NEWFONT_OUTLINE)
    btn.scale = 1.0
    btn:SetOnGainFocus(function()
        btn:SetScale(btn.scale + .10)
    end)
    btn:SetOnLoseFocus(function()
        btn:SetScale(btn.scale)
    end)
    btn:SetScale(btn.scale)
    return btn
end

local function make_log_switch_buttons(self)
    -- If no dedicated servers, don't make buttons
    if not TheNet:GetIsClient() and not G.TheNet:GetIsHosting() then return end

    local x = -500
    local y = 210
    do
        local btn = self.staticroot:AddChild(logButton(function ()
            self.scrollable_log.history = Logs.client
            self.scrollable_log:RefreshWidgets(true)
            self.scrollable_log:SetTextColour(unpack(G.PORTAL_TEXT_COLOUR))

            self.console_edit:SetEditing(true)
            return true
        end, "Client", G.PORTAL_TEXT_COLOUR))
        table.insert(self.buttons, btn)
        self.buttons["Client"] = btn
        btn:SetPosition(x, y)
    end

    for i, shard in ipairs {"Master", "Caves"} do
        local btn = self.staticroot:AddChild(logButton(function ()
            Logs:UpdateClusterLog(shard, function()
                self.scrollable_log:RefreshWidgets(true)
            end)
            self.scrollable_log.history = Logs.cluster[shard]
            self.scrollable_log:SetTextColour(unpack(Config.SHARD_LOG_COLOURS[shard]))

            self.console_edit:SetEditing(true)
            return true
        end, shard, Config.SHARD_LOG_COLOURS[shard]))
        btn:SetPosition(x + i * 100, y)
        table.insert(self.buttons, btn)
        self.buttons[shard] = btn
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

    -- Someone encountered error here that TheFrontEnd
    -- Should be impossible, it exists on both client and server
    -- perhaps it was another mod doing crazy stuff?
    if TheFrontEnd then TheFrontEnd:HideConsoleLog() end
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

    -- game does this now!
    --self.console_edit.validrawkeys[G.KEY_V] = true

    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLBACK, true)
    self.console_edit:SetPassControlToScreen(G.CONTROL_SCROLLFWD, true)
end

function ConsoleModder:VerifyEditOnRawKey(key, down)
    -- We'll keep this as a back up
    -- self.screen.inst:DoTaskInTime(0, function() self:UpdateConsoleSize() end)

    local ctrl_down = TheInput:IsKeyDown(G.KEY_CTRL)
    local contents = self.console_edit:GetString()
    local cursorpos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()

    if key ~= G.KEY_DOWN and key ~= G.KEY_UP then
        self.goalxpos = nil
    end

    if not down then return false end

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
            for i = 1, math.min(#chars, Config.TABSPACES) do
                self.console_edit.inst.TextEditWidget:OnKeyDown(KEY_BACKSPACE)
                --self.console_edit.inst.TextEditWidget:OnKeyUp(KEY_BACKSPACE)
            end
            return true
        end
   end
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
--
-- The new behavior we're adding:
-- * With multiline text inputs, use up and down arrow keys to
--   move between lines.
-- * Still let up and down arrows move between history
-- * Don't lose unsaved work just by pressing up arrow
function ConsoleModder:ScreenOnRawKeyHandler(_OnRawKeyHandler, key, down)
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()
    local history = G.ConsoleScreenSettings:GetConsoleHistory()

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
        elseif self.arrowkey_set_to_history then
            -- Keep track of "unsaved" code
            if self.screen.history_idx == nil then
                self.unsaved_work = str
            end

            -- Let game handle history.
            -- There was a reason I couldn't do this before,
            -- but haven't figured it out yet so...
            self.arrowkey_set_to_history = false
            _OnRawKeyHandler(self.screen, key, down)
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
        elseif self.arrowkey_set_to_history then
            -- New behavior: we don't want to lose our work.
            -- So when we press down error at end of history,
            -- we return to the "unsaved" text input
            if self.screen.history_idx == #history then
                self.console_edit:SetString(self.unsaved_work)
                self.screen.history_idx = nil
            end

            -- Let game handle history
            _OnRawKeyHandler(self.screen, key, down)
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

function ConsoleModder:PostToggleRemoteExecute()
    -- Now remote toggle is sometimes forced even when there is no remote,
    -- so we add our own guard
    local is_valid_time_to_use_remote = TheNet:GetIsClient() and TheNet:GetIsServerAdmin()
    if not is_valid_time_to_use_remote then return end

    local label = self.screen.console_remote_execute
    if self.screen.toggle_remote_execute then
        local shard = GetShard()
        if shard then label:SetColour(Config.SHARD_LOG_COLOURS[shard]) end
    else
        label:SetColour(1,0.7,0.7,1)
    end
    self.console_edit.prediction_widget:RefreshPredictions()
end

function ConsoleModder:Run()
	local fnstr = self.console_edit:GetString()

    G.SuUsedAdd("console_used")

    local toggle = self.screen.toggle_remote_execute

	if fnstr ~= "" then
		G.ConsoleScreenSettings:AddLastExecutedCommand(fnstr, self.screen.toggle_remote_execute)
	end

    -- Only remote execute if there is actually a remote to execute
	if self.screen.toggle_remote_execute and TheNet:GetIsClient() and TheNet:GetIsServerAdmin() then
        local x, _, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        if fnstr:byte() == string.byte("=") then
            fnstr = string.format("print(table.inspect((%s), 1))", fnstr:sub(2))
        end
		TheNet:SendRemoteExecute(fnstr, x, z)

        self.screen.inst:DoTaskInTime(0, function ()
            local shard = GetShard()
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
