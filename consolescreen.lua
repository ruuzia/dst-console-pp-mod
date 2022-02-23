local ConsoleScreen = require "screens/consolescreen"
local G = GLOBAL
local TheInput = G.TheInput

Config.RemoteToggleKeys = {
    [G.KEY_LCTRL] = Config.rtoggle == "ctrl",
    [G.KEY_RCTRL] = Config.rtoggle == "ctrl",
    [G.KEY_LALT] = Config.rtoggle == "alt",
    [G.KEY_RALT] = Config.rtoggle == "alt",
}

local label_height = 50
local fontsize = 30
local edit_width = 850
local edit_bg_padding = 50
local baseypos = 75


local function adjust_label_height(console)
    local _, nlcount = console.console_edit:GetString():gsub('\n', '')
    console.label_height = label_height + fontsize * nlcount
	console.root:SetPosition(console.root:GetPosition().x, baseypos + (fontsize - 2) * nlcount / 2, 0)
    local wcurr, hcurr = console.edit_bg:GetSize()
    if wcurr and hcurr and hcurr ~= console.label_height then
        console.edit_bg:ScaleToSize( console.edit_width + edit_bg_padding, console.label_height )
        console.console_edit:SetRegionSize( console.edit_width, console.label_height )
    end
end

local function console_edit_ValidateChar(_ValidateChar, textedit, c)
    if c == '\n' or c == '\t' then
        return true
    end

    return _ValidateChar(textedit, c)
end

Decorate(ConsoleScreen, "DoInit", function(_DoInit, self, ...)
    _DoInit(self, ...)

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

    self.edit_bg:SetTexture("images/textbox_long_thinborder.xml", "textbox_long_thinborder.tex" )
	self.root:SetPosition(100, baseypos, 0)
    self.label_height = label_height
    self.edit_width = edit_width
	self.edit_bg:ScaleToSize(edit_bg_padding + self.edit_width, label_height )
    self.console_edit:SetRegionSize(self.edit_width, self.label_height)
	self.console_remote_execute:SetPosition( -self.edit_width*0.5 -200*0.5 - 35, 0 )

    self.console_edit:EnableWordWrap(true)
    self.console_edit:EnableWhitespaceWrap(true)

    Decorate(self.console_edit, "ValidateChar", console_edit_ValidateChar)

    Decorate(self.console_edit, "OnRawKey", function (_OnRawKey, textedit, key, down)
        if down and (key == G.KEY_PERIOD or (key == G.KEY_SEMICOLON and TheInput:IsKeyDown(G.KEY_SHIFT))) then
            ConsoleEditDynamicComplete(textedit)
        end
        if down and not Config.RemoteToggleKeys[key] then
            self.ctrl_pasting = true
        end
        local res = _OnRawKey(textedit, key, down)

        adjust_label_height(self)

        return res
    end)
end)


Decorate(ConsoleScreen, "OnControl", function (_OnControl, self, control, down)
    --[[if not down and control == G.CONTROL_ACCEPT and self.console_edit._mouse_set_cursor then
        self.console_edit._mouse_set_cursor = nil
        return true
    else]]if not down and control == G.CONTROL_OPEN_DEBUG_CONSOLE and TheInput:IsKeyDown(G.KEY_SHIFT) then
        print("OnControl - down")
        return true
    else
        return _OnControl(self, control, down)
    end
end)

-- runs after TextEdit:OnRawKey if it didnt return false
-- so only for some special non-input keys
-- completely overriding because im changing basically everything
AssertDefinitionSource(ConsoleScreen, "OnRawKeyHandler", "scripts/screens/consolescreen.lua")
function ConsoleScreen:OnRawKeyHandler(key, down)
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()
    local CONSOLE_HISTORY = G.GetConsoleHistory()

    if down and key == G.KEY_UP then
        local linestart = StrGetLineStart(str, pos)
        local plstart, plend = StrGetLineBounds(str, (linestart or 0)-2)

        if plstart then
            self.console_edit.inst.TextEditWidget:SetEditCursorPos(math.min(pos - linestart + plstart, plend))
            return true
        elseif #CONSOLE_HISTORY > 0 then
            self.history_idx = self.history_idx and math.max(1, self.history_idx - 1) or #CONSOLE_HISTORY
            self.console_edit:SetString( CONSOLE_HISTORY[ self.history_idx ] )
        end

    elseif down and key == G.KEY_DOWN then
        local linestart, lineend = StrGetLineBounds(str, pos)
        local nlstart, nlend = StrGetLineBounds(str, lineend + 1)

        if nlstart then
            self.console_edit.inst.TextEditWidget:SetEditCursorPos(math.min(pos - linestart + nlstart, nlend))
            return true
        elseif #CONSOLE_HISTORY > 0 and self.history_idx then
            if self.history_idx == #CONSOLE_HISTORY then
                self.console_edit:SetString("")
            else
                self.history_idx = math.min(#CONSOLE_HISTORY, self.history_idx + 1)
                self.console_edit:SetString(CONSOLE_HISTORY[self.history_idx])
            end
        end

    elseif not down and Config.RemoteToggleKeys[key] then
        if not self.ctrl_pasting then
            self:ToggleRemoteExecute()
        end
        self.ctrl_pasting = false
    end
end

Decorate(ConsoleScreen, "OnTextEntered", function(_OnTextEntered, self)
    self.console_edit:SetEditing(true)
    if TheInput:IsKeyDown(G.KEY_SHIFT) or CodeMissingClosingStatement(self.console_edit:GetString()) then
        self.console_edit:OnTextInput('\n')
    elseif TheInput:IsKeyDown(G.KEY_LCTRL) then
        self:Run()
    else
        self.console_edit:SetEditing(false)
        _OnTextEntered(self)
    end
end)

AssertDefinitionSource(ConsoleScreen, "Run", "scripts/screens/consolescreen.lua")
function ConsoleScreen:Run()
    local CONSOLE_HISTORY = G.GetConsoleHistory()
	local fnstr = self.console_edit:GetString()

    G.SuUsedAdd("console_used")

	if fnstr ~= "" and fnstr ~= CONSOLE_HISTORY[#CONSOLE_HISTORY] then
		table.insert( CONSOLE_HISTORY, fnstr )
	end

	if self.toggle_remote_execute then
        local x, _, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        if fnstr:find("^=") then
            fnstr = ("print(%s)"):format(fnstr:sub(2))
        end
		G.TheNet:SendRemoteExecute(fnstr, x, z)
	else
		G.ExecuteConsoleCommand(fnstr)
	end
end
