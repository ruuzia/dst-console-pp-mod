require "debugcommands"

modimport "scripts/env"

local G = GLOBAL

local TheInput, pcall, loadstring, Ents, Vector3, unpack, setmetatable =
G.TheInput, G.pcall, G.loadstring, G.Ents, G.Vector3, G.unpack, G.setmetatable
local setfenv = G.setfenv

--local DEBUG = not modname:find("^workshop-")
local onserver = G.TheNet:GetIsServer()

G.global "ConsolePP"
ConsolePP = G.ConsolePP or {}

local client_only_version_exists = ConsolePP.env and ConsolePP.env.modinfo.client_only_mod
if client_only_version_exists and modinfo.all_clients_require_mod and not onserver then
    return
end

ConsolePP.save = ConsolePP.save or {}
ConsolePP.weak = setmetatable({}, {__mode = "v"})
ConsolePP.env = env
G.ConsolePP = ConsolePP

local ConsoleScreen = require("screens/consolescreen")


------------------------------------------
------------------------------------------

modimport "scripts/reload"

---@param loc table
---@param idx string
---@param wrapper fun(old: function, ...): any
function Hook(loc, idx, wrapper)
  local origin = modassert(loc[idx], "no decorator function")
  Impurities.new(loc, idx, origin)
  loc[idx] = function(...)
    return wrapper(origin, ...)
  end
end

---@param fn function
---@param overrides table<string, any>
function ModFenv(fn, overrides)
    local fenv = G.getfenv(fn)
    -----support hot relod------
    local fenv_mt = G.getmetatable(fenv)
    if fenv_mt and fenv_mt._consolepp then
        setmetatable(overrides, fenv_mt)
    ----------------------------
    else
        setmetatable(overrides, { __index = fenv, _consolepp = true })
    end
    return setfenv(fn, overrides)
end

local nlchar = ('\n'):byte()

---@param s string
---@param idx number
---@return number?
function StrGetLineStart(s, idx, utf8)
    local uidx_dif = 0
    for i = idx, 1, -1 do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i + 1 --one *after* newline
        elseif utf8 and byte >= 128 + 64 then
            uidx_dif = uidx_dif - 1
        end
    end
    return 1
end

---@param s string
---@param idx number
---@return number?
function StrGetLineEnd(s, idx, utf8)
    local uidx_dif = 0
    for i = idx+1, #s do
        local byte = s:byte(i)
        if byte == nlchar then
            return uidx_dif + i - 1 --one *before* newline
        elseif utf8 and byte >= 128 + 64 --[[0b11000000]] then
            uidx_dif = uidx_dif - 1
        end
    end
    return #s + uidx_dif
end

---@param s string
---@param idx number
---@return number?
---@return number?
function StrGetLineBounds(s, idx, utf8)
    return StrGetLineStart(s, idx, utf8), StrGetLineEnd(s, idx, utf8)
end

if not onserver then
    AddGamePostInit(function()
        if ConsolePP.save.HackText then
            print("Removing old hacktext")
            ConsolePP.save.HackText:Kill()
        end
        local hacktext = (require "widgets/widget")()
        ConsolePP.save.HackText = hacktext

        hacktext.inst.entity:AddTextWidget()
        hacktext:Hide()


        function CalcTextRegionSize(str, font, size)
            hacktext.inst.TextWidget:SetSize(size * (G.LOC and G.LOC.GetTextScale() or 1))
            hacktext.inst.TextWidget:SetFont(font)
            hacktext.inst.TextWidget:SetString(str)
            return hacktext.inst.TextWidget:GetRegionSize()
        end
    end)
end

function TextBoxXPosToCol(textfont, textsize, xpos, line, substring)
    substring = substring or string.utf8sub
    local prevwidth = 0
    local index
    for i = 1, #line do
        local width = CalcTextRegionSize(substring(line, 1, i), textfont, textsize)
        if width > xpos then
            index = width - xpos < xpos - prevwidth and i or i - 1
            break
        end
        prevwidth = width
    end
    return index or #line
end

function TextBoxStringToPos(font, size, line)
    if line == "" then return 0 end --GetRegionSize would return 2^127
    return CalcTextRegionSize(line, font, size)
end

---@param t table
---@param name string
---@param expected string
function AssertDefinitionSource(t, name, expected)
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
    local RevealArea = MapExplorer.RevealArea
    local size = G.TheWorld.Map:GetSize() * 2
    for x = -size, size, 35 do
        for y = -size, size, 35 do
            RevealArea(MapExplorer, x, 0, y)
        end
    end
end

------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

modimport "scripts/config"

ModFenv(G.OnServerPauseDirty, {
    print = function(...)
        if Config.IGNORES[(...)] then return end
        print(...)
    end;
})

---@param lua string
function CodeMissingClosingStatement(lua)
    -- lmao why do I do this with regex
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

AssertDefinitionSource(G, "ExecuteConsoleCommand", "scripts/mainfunctions.lua")
---@param fnstr string
---@param guid number
---@param x number
---@param z number
function G.ExecuteConsoleCommand(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
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

------------------------------------------------------------
------------------------------------------------------------

modimport "scripts/logs"
Logs = LogHistory()

modimport "scripts/consolemodder"
modimport "scripts/textedit"
modimport "scripts/consolelog"

local __ctor = Impurities.new(ConsoleScreen, "_ctor")
ConsoleScreen._ctor = function(self, ...)
    __ctor(self, ...)
    ConsoleModder(self, G.GetConsoleHistory(), G.GetConsoleLocalRemoteHistory())
end
