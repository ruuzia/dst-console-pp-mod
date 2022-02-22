require "debugcommands"

local G = GLOBAL


local TheInput, pcall, loadstring, Ents, Vector3, unpack, setmetatable, rawget =
G.TheInput, G.pcall, G.loadstring, G.Ents, G.Vector3, G.unpack, G.setmetatable, G.rawget
--local printwrap    = _G.printwrap
--local global       = _G.global
local setfenv, getfenv, TheSim = G.setfenv, G.getfenv, G.TheSim

local DEBUG = not modname:find("^workshop-")

if DEBUG then
    require "debugkeys"
    G.CHEATS_ENABLED = true
end

------------------------------------------
------------------------------------------

--for hot reload - debug mode only?
---@type {loc: table, name: string, old: function}[]
local impurities = { __mode = "kv" }
function impurities.new(loc, name, old)
    if not DEBUG then return end
    local data = {loc=loc, name=name, old=old}
    table.insert(impurities, data)
    setmetatable(data, impurities)
end

---@param loc table
---@param idx string
---@param wrapper fun(old: function, ...): any
local function decorate(loc, idx, wrapper)
  local origin = modassert(loc[idx], "no decorator function")
  impurities.new(loc, idx, origin)
  loc[idx] = function(...)
    return wrapper(origin, ...)
  end
end

---@param fn function
---@param overrides table<string, any>
local function modGfenv(fn, overrides)
    return setfenv(fn, setmetatable(overrides, { __index = G }))
end

---@param str string
---@param ptrn string
---@return number
local function str_subcount(str, ptrn)
    local i = 0
    for _ in str:gmatch(ptrn) do i = i + 1 end
    return i
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

---@param t table
---@param name string
---@param expected string
local function assert_definition_source(t, name, expected)
    local info = G.debug.getinfo(t[name], "S")
    if info.source == expected or info.source:find("^"..MODROOT) then return end
    print(("[%s] ======== WARNING ==============="):format(modname))
    print(("[%s] %q definition expected in file %q, but found in %q. Running with an incompatible mod?")
          :format(modname, name, expected, info.source))
    print(("[%s] ================================"):format(modname))
end

------------------------------------------
------------------------------------------

---@param reveal boolean
function G.c_revealmap(reveal)
    if G.TheWorld == nil or G.TheWorld.ismastersim == false or G.ThePlayer == nil then
        print("c_revealmap called in bad state")
        return
    end
    if reveal == false then return G.MapHideAll() end

    local MapExplorer = G.ThePlayer.player_classified.MapExplorer
    local size = G.TheWorld.Map:GetSize() * 2
    for x = -size, size, 35 do
        for y = -size, size, 35 do
            MapExplorer:RevealArea(x, 0, y)
        end
    end
end
------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

local TextEdit = require "widgets/textedit"
local ConsoleScreen = require "screens/consolescreen"

local config_rtoggle = GetModConfigData("remotetoggle")
modassert(config_rtoggle ~= nil, "could not get config data \"remotetoggle\"")
local remote_toggle_keys = {
    [G.KEY_LCTRL] = config_rtoggle == "ctrl",
    [G.KEY_RCTRL] = config_rtoggle == "ctrl",
    [G.KEY_LALT] = config_rtoggle == "alt",
    [G.KEY_RALT] = config_rtoggle == "alt",
}

local ignores = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}

local dynamicdelims = {}

modGfenv(G.OnServerPauseDirty, {
    print = function(...)
        if ignores[(...)] then return end
        print(...)
    end;
})

AddGamePostInit(function()
    TheFrontEnd.consoletext:SetPosition(-100, 100, 0)
end)


local label_height = 50
local fontsize = 30
local edit_width = 850
local edit_bg_padding = 50
local baseypos = 75

local function adjust_label_height(console)
    local nlcount = str_subcount(console.console_edit:GetString(), '\n')
    console.label_height = label_height + fontsize * nlcount
	console.root:SetPosition(console.root:GetPosition().x, baseypos + (fontsize - 2) * nlcount / 2, 0)
    local wcurr, hcurr = console.edit_bg:GetSize()
    if wcurr and hcurr and hcurr ~= console.label_height then
        console.edit_bg:ScaleToSize( console.edit_width + edit_bg_padding, console.label_height )
        console.console_edit:SetRegionSize( console.edit_width, console.label_height )
    end
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

local function dynamic_complete(textedit)
    local str = textedit:GetString()
    local pos = textedit.inst.TextEditWidget:GetEditCursorPos()
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
    if #tnames <= 0 then return end

    local t = setmetatable({}, {__index=function(_, k) return rawget(G, k) end})
    local mt
    for i = #tnames, 1, -1 do
        t = t[tnames[i]]
        mt = G.getmetatable(t)
        if type(t) ~= "table" and (mt == nil or type(mt.__index) ~= "table") then return end
    end

    local keys = {}
    local onlyfuncs = str:sub(pos,pos) == ":"
    if type(t) == "table" then
        for k,v in pairs(t) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    if mt and type(mt.__index) == "table" then
        for k,v in pairs(mt.__index) do
            if type(k) == "string" and (not onlyfuncs or type(v) == "function") then
                table.insert(keys, k)
            end
        end
    end
    local delim = str:sub(expressionstart, pos)
    if dynamicdelims[delim] then
        for _,v in ipairs(textedit.prediction_widget.word_predictor.dictionaries) do
            if v.delim == delim then
                v.words = keys
                break
            end
        end
    else
        textedit:AddWordPredictionDictionary {
            words = keys,
            delim = delim,
            num_chars = 0,
            GetDisplayString = function (word) return word end
        }
        dynamicdelims[delim] = true
    end
    textedit.prediction_widget:RefreshPredictions()
end

local function console_edit_ValidateChar(_ValidateChar, textedit, c)
    if c == '\n' or c == '\t' then
        return true
    end

    return _ValidateChar(textedit, c)
end


decorate(ConsoleScreen, "DoInit", function(_DoInit, self, ...)
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

    decorate(self.console_edit, "ValidateChar", console_edit_ValidateChar)

    dynamicdelims = {}

    decorate(self.console_edit, "OnRawKey", function (_OnRawKey, textedit, key, down)
        if down and (key == G.KEY_PERIOD or (key == G.KEY_SEMICOLON and TheInput:IsKeyDown(G.KEY_SHIFT))) then
            dynamic_complete(textedit)
        end
        if down and not remote_toggle_keys[key] then
            self.ctrl_pasting = true
        end
        local res = _OnRawKey(textedit, key, down)

        adjust_label_height(self)

        return res
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

decorate(ConsoleScreen, "OnControl", function (_OnControl, self, control, down)
    if not down and control == G.CONTROL_ACCEPT and self.console_edit._mouse_set_cursor then
        self.console_edit._mouse_set_cursor = nil
        return true
    elseif not down and control == G.CONTROL_OPEN_DEBUG_CONSOLE and TheInput:IsKeyDown(G.KEY_SHIFT) then
        return true
    else
        return _OnControl(self, control, down)
    end
end)

local FONTDATA = require "fontdata"

function TextEdit:OnMouseButton(button, down, x, y)
    if not down or button ~= G.MOUSEBUTTON_LEFT then return false end
    x = x / self:GetScale().x
    y = y / self:GetScale().y

    local textposmid_x, textposmid_y = self:GetWorldPosition():Get()
    textposmid_x = textposmid_x / self:GetScale().x
    textposmid_y = textposmid_y / self:GetScale().y
    local size_x, size_y = self:GetRegionSize()
    local x_text_start, y_text_start = textposmid_x - size_x / 2, textposmid_y + size_y / 2
    local row = math.floor((y_text_start - y) / self.size)

    ---@type string
    local str = self:GetString()

    local _, rowstartidx = str:find("^"..("[^\n]*\n"):rep(row))
    if rowstartidx == nil then
        _, rowstartidx = str_getlinebounds(str, #str)
    end
    local len = str:utf8len()
    local utf8rowstart = str:sub(1, rowstartidx):utf8len()
    local index = rowstartidx
    local width = x - x_text_start
    for i = utf8rowstart+1, len do
        local c = str:utf8sub(i, i)
        if c == "\n" then break end
        local fontwidth = self.size * FONTDATA[G.DEFAULTFONT][c]
        width = width - fontwidth
        if width < 0 then break end
        index = index + #c
    end
    self.inst.TextEditWidget:SetEditCursorPos(index)
    self._mouse_set_cursor = true
    return true
end

-- runs after TextEdit:OnRawKey if it didnt return false
-- so only for some special non-input keys
-- completely overriding because im changing basically everything
assert_definition_source(ConsoleScreen, "OnRawKeyHandler", "scripts/screens/consolescreen.lua")
function ConsoleScreen:OnRawKeyHandler(key, down)
    local pos = self.console_edit.inst.TextEditWidget:GetEditCursorPos()
    local str = self.console_edit:GetString()
    local CONSOLE_HISTORY = G.GetConsoleHistory()

    if down and key == G.KEY_UP then
        local linestart = str_getlinebounds(str, pos)
        local plstart, plend = str_getlinebounds(str, (linestart or 0)-2)

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
        if not self.ctrl_pasting then
            self:ToggleRemoteExecute()
        end
        self.ctrl_pasting = false
    end
end

decorate(ConsoleScreen, "OnTextEntered", function(_OnTextEntered, self)
    self.console_edit:SetEditing(true)
    if TheInput:IsKeyDown(G.KEY_SHIFT) or missing_closing_statement(self.console_edit:GetString()) then
        self.console_edit:OnTextInput('\n')
    elseif TheInput:IsKeyDown(G.KEY_LCTRL) then
        self:Run()
    else
        self.console_edit:SetEditing(false)
        _OnTextEntered(self)
    end
end)

assert_definition_source(ConsoleScreen, "Run", "scripts/screens/consolescreen.lua")
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

assert_definition_source(G, "ExecuteConsoleCommand", "scripts/mainfunctions.lua")
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

        print(unpack(result, 2))
    end

    if guid ~= nil then
        ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end

G.d_reloadconsolemod = DEBUG and function()
    for _, v in ipairs(impurities) do
        if v.loc then
            v.loc[v.name] = v.old
        end
    end
    local isworldgen = CHARACTERLIST == nil
    local isfrontend = ReloadFrontEndAssets ~= nil
    local newenv = G.CreateEnvironment(modname, isworldgen, isfrontend)
    newenv.modinfo = modinfo
    for i,v in ipairs(G.ModManager.mods) do
        if v == env then
            G.ModManager.mods[i] = env
        end
    end
	G.ModManager:InitializeModMain(modname, newenv, "modmain.lua")
end or nil

