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

    -- self.islogshown = Config.OPENLOGWITHCONSOLE or TheFrontEnd.consoletext.shown

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
            -- or self.scrollable_log:OnChatControl(...)
            or _OnControl(s, ...)
    end
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
    -- TODO: move to module
    -- self.screen:ToggleRemoteExecute(remote or false)
end

local Menu = require "widgets/menu"
local TEMPLATES = require "widgets/redux/templates"

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

    self.console_edit:AddWordPredictionDictionary {words = words.d_ , delim = "d_" , num_chars = 0}
    self.console_edit:AddWordPredictionDictionary {words = words.The, delim = "The", num_chars = 0}
    --self.console_edit:AddWordPredictionDictionary {words = words.Get, delim = "Get", num_chars = 0}
    --self.console_edit:AddWordPredictionDictionary {words = words.Set, delim = "Set", num_chars = 0}

    -- game does this now!
    --self.console_edit.validrawkeys[G.KEY_V] = true
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
