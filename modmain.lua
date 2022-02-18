require "debugcommands"
local TextEdit = require "widgets/textedit"

local G = GLOBAL

---[[
require "debugkeys"
G.CHEATS_ENABLED = true
--]]

local TheInput, pcall, loadstring, Ents, nolineprint, Vector3, unpack, setmetatable, rawget =
G.TheInput, G.pcall, G.loadstring, G.Ents, G.nolineprint, G.Vector3, G.unpack, G.setmetatable, G.rawget
--local printwrap    = _G.printwrap
--local global       = _G.global
local setfenv      = G.setfenv

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}


local config_rtoggle = GetModConfigData("remotetoggle")
modassert(config_rtoggle ~= nil, "could not get config data \"remotetoggle\"")
local remote_toggle_keys = {
    [G.KEY_LCTRL] = config_rtoggle == "ctrl",
    [G.KEY_RCTRL] = config_rtoggle == "ctrl",
    [G.KEY_LALT] = config_rtoggle == "alt",
    [G.KEY_RALT] = config_rtoggle == "alt",
}

---@param tbl table
---@param idx string
---@param wrapper fun(old: function, ...): any
local function decorate(tbl, idx, wrapper)
  local origin = tbl[idx]
  tbl[idx] = function(...)
    return wrapper(origin, ...)
  end
end

---@param fn function
---@param overrides table<string, any>
local function modfenv(fn, overrides)
    setfenv(fn, setmetatable(overrides, {__index = G}))
end

local ignores = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}

modfenv(G.OnServerPauseDirty, {
    print = function(...)
        if ignores[(...)] then return end
        print(...)
    end;
})

AddGamePostInit(function()
    TheFrontEnd.consoletext:SetPosition(-100, 100, 0)
end)

---@param str string
---@param ptrn string
---@return number
function string.subcount(str, ptrn)
    local i = 0
    for _ in str:gmatch(ptrn) do i = i + 1 end
    return i
end


local ConsoleScreen = require "screens/consolescreen"

local label_height = 40
--local fontsize = 30
local edit_width = 700
local edit_bg_padding = 50
local baseypos = 50

local function adjust_label_height(console)
    local nlcount = console.console_edit:GetString():subcount('\n')
    console.label_height = label_height + 35 * nlcount
	console.root:SetPosition(console.root:GetPosition().x, baseypos + label_height * nlcount / 2, 0)

    if console.edit_bg:GetSize() then
        console.edit_bg:ScaleToSize( console.edit_width + edit_bg_padding, console.label_height )
        console.console_edit:SetRegionSize( console.edit_width, console.label_height )
    end
end

---@param s string
---@param idx number
---@return number
---@return number
local function str_getlinebounds(s, idx)
    local endi = #s

    if idx > endi or idx < 0 then return end

    local starti = (s:sub(1, idx):rfind_plain('\n') or 0) + 1

    endi = s:find('.\n', idx) or endi

    return starti, endi
end

---@param lua string
local function missing_closing_statement(lua)
    local encoded = lua:gsub("\\.", "")              --remove escapes
                       :gsub("%-%-(%[=*%[)", "%1")   --remove leading `--` in multiline comment
                       :gsub("%[(=*)%[.-%]%1%]", "") --remove multiline strings
                       :gsub("%-%-[^\n]+", "")       --remove single line comments
                       :gsub("(['\"]).-%1", "")      --remove single and double quote strings

                       if encoded:find("%[=*%[") then return true end

    local statements = {["function"] = 0, ["do"] = 0, ["then"] = 0, ["end"] = 0, ["repeat"] = 0, ["until"] = 0}
    for word in encoded:gmatch("%w+") do
        if statements[word] then
            statements[word] = statements[word] + 1
        end
    end

    return statements["function"] + statements["do"] + statements["then"] > statements["end"]
        or statements["repeat"] > statements["until"]
end

local function indexable(t)
    if type(t) == "table" then return true end
    local mt = G.getmetatable(t)
    if type(mt) ~= "table" then return false end
    return type(mt.__index) == "table"
end

decorate(ConsoleScreen, "DoInit", function(_DoInit, self, ...)
    _DoInit(self, ...)

    local commands = {}
    local debugs = {}
    local thes = {}

    if commands[1] then return end
    for k,_ in pairs(G) do
        if k:find("^c_") then
            table.insert(commands, k:sub(3))
        elseif k:find("^d_") then
            table.insert(debugs, k:sub(3))
        elseif k:find("^The") then
            table.insert(thes, k:sub(4))
        end
    end

    for _,v in ipairs(self.console_edit.prediction_widget.word_predictor.dictionaries) do
        if v.delim == "c_" then
            v.words = commands
            break
        end
    end

    self.edit_bg:SetTexture("images/textbox_long_thinborder.xml", "textbox_long_thinborder.tex" )

    self.console_edit:AddWordPredictionDictionary({words = debugs, delim = "d_", num_chars = 0})
    self.console_edit:AddWordPredictionDictionary({words = thes, delim = "The", num_chars = 0})
    --better implement myself
    --self.console_edit.allow_newline = true

    -- game does this now!
    --self.console_edit.validrawkeys[G.KEY_V] = true
   -- self.console_edit.validrawkeys[G.KEY_DELETE] = true
   -- self.console_edit.validrawkeys[G.KEY_BACKSPACE] = true

	self.root:SetPosition(100, baseypos, 0)
    self.label_height = label_height
    self.edit_width = edit_width
	self.edit_bg:ScaleToSize(edit_bg_padding + self.edit_width, label_height )
    self.console_edit:SetRegionSize(self.edit_width, self.label_height)
	self.console_remote_execute:SetPosition( -self.edit_width*0.5 -200*0.5 - 35, 0 )

    decorate(self.console_edit, "ValidateChar", function(_ValidateChar, textedit, c)
        --G.TheGlobalInstance:DoTaskInTime(0, function() adjust_label_height(self) end)
        if c == '\n' or c == '\t' then
            return true
        end

        return _ValidateChar(textedit, c)
    end)

    local dynamicdelims = {}

    decorate(self.console_edit, "OnRawKey", function (_OnRawKey, textedit, key, down)
        if down then
            adjust_label_height(self)
        end
        if down and (key == G.KEY_PERIOD or (key == G.KEY_SEMICOLON and TheInput:IsKeyDown(G.KEY_SHIFT))) then
            local str = self.console_edit:GetString()
            local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
            local tnames = {}
            local searchpos = pos
            local expressionstart
            repeat
                local wstart, word = str:sub(1, searchpos):match("()([%w_]+)%s*[.:]$")
                if wstart == nil then break end
                expressionstart = wstart
                searchpos = wstart - 1
                table.insert(tnames, word)
            until false

            local t = setmetatable({}, {__index=function(_, k) return rawget(G, k) end})
            if #tnames > 0 then
                for i = #tnames, 1, -1 do
                    t = t[tnames[i]]
                    if not indexable(t) then break end
                end
                if type(t) == "table" then
                    print("AddWordPredictionDictionary")
                    local keys = table.getkeys(t)
                    local delim = str:sub(expressionstart, pos)
                    if dynamicdelims[delim] then
                        for _,v in ipairs(self.console_edit.prediction_widget.word_predictor.dictionaries) do
                            if v.delim == delim then
                                v.words = keys
                                break
                            end
                        end
                    else
                        self.console_edit:AddWordPredictionDictionary {
                            words = keys,
                            delim = delim,
                            num_chars = 0,
                            GetDisplayString = function (word) return word end
                        }
                        dynamicdelims[delim] = true
                    end
                    self.console_edit.prediction_widget:RefreshPredictions()
                end
            end
        end
        if down and not remote_toggle_keys[key] then
            self.ctrl_pasting = true
        end
            
        return _OnRawKey(textedit, key, down)
    end)
end)

-- Changes for ALL textedits - not just console edit
-- First OnRawKey to run
decorate(TextEdit, "OnRawKey", function(_OnRawKey, self, key, down)
    if down then
        if key == G.KEY_BACKSPACE and TheInput:IsKeyDown(G.KEY_LCTRL) then
            local str = self:GetString()
            local pos = self.inst.TextEditWidget:GetEditCursorPos()
            if pos > 0 then
                local i = pos - 1
                while i > 0 and str:find('^%s', i) do
                    i = i - 1
                end
                while i > 0 and str:find('^%S', i) do
                    i = i - 1
                end
                self:SetString(str:sub(1, i) .. str:sub(pos + 1))
                self.inst.TextEditWidget:SetEditCursorPos(i)
            end
            return true

        elseif key == G.KEY_TAB and not self.nextTextEditWidget then
            for _= 1, 4 do
                self:OnTextInput(' ')
            end
            return true
        end
    end

    return _OnRawKey(self, key, down)
end)

-- runs after TextEdit:OnRawKey if it didnt return false
-- so only for some special non-input keys
-- completely overriding because im changing basically everything
function ConsoleScreen:OnRawKeyHandler(key, down)
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()
    local CONSOLE_HISTORY = G.GetConsoleHistory()

    if down and key == G.KEY_UP then
        local linestart = str_getlinebounds(str, pos)
        local plstart, plend = str_getlinebounds(str, linestart-2)

        if plstart then
            self.console_edit.inst.TextEditWidget:SetEditCursorPos(math.min(pos - linestart + plstart, plend))
            return true
        elseif #CONSOLE_HISTORY > 0 then
            self.history_idx = self.history_idx and math.max(1, self.history_idx - 1) or #CONSOLE_HISTORY
            self.console_edit:SetString( CONSOLE_HISTORY[ self.history_idx ] )
        end

    elseif down and key == G.KEY_DOWN then
        local linestart, lineend = str_getlinebounds(str, pos)
        local nlstart, nlend = str_getlinebounds(str, lineend + 1)

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

    elseif not down and remote_toggle_keys[key] then
        print("debug", self.ctrl_pasting)
        if not self.ctrl_pasting then
            self:ToggleRemoteExecute()
        end
        self.ctrl_pasting = false
    end
end


decorate(ConsoleScreen, "OnTextEntered", function(_OnTextEntered, self)
    if TheInput:IsKeyDown(G.KEY_SHIFT) or missing_closing_statement(self.console_edit:GetString()) then
        self.console_edit:SetEditing(true)
        self.console_edit:OnTextInput('\n')
        return
    end
    _OnTextEntered(self)
end)


--ConsoleScreen:Close()
decorate(ConsoleScreen, "OnControl", function(_OnControl, self, control, down)
    if not down and control == G.CONTROL_OPEN_DEBUG_CONSOLE and TheInput:IsKeyDown(G.KEY_SHIFT) then
        return true
    end
    return _OnControl(self, control, down)
end)



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

---@param fnstr string
---@param guid number
---@param x number
---@param z number
function G.ExecuteConsoleCommand(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
        saved_ThePlayer = ThePlayer
        ThePlayer = guid ~= nil and Ents[guid] or nil
    end
    TheInput.overridepos = x ~= nil and z ~= nil and Vector3(x, 0, z) or nil

    local equalsstart = fnstr:find("^%=")
    if equalsstart then
        fnstr = fnstr:sub(2)
    end

    local result = {pcall(loadstring("return "..fnstr))}
    if not result[1] and not equalsstart then
        result = {pcall(loadstring(fnstr))}
    end
    if #result > 1 then
        for i = 2, #result do
            result[i] = tostring(result[i])
        end

        nolineprint(unpack(result, 2))
    end

    if guid ~= nil then
        ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end

