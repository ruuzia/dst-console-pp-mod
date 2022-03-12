require "debugcommands"

local G = GLOBAL

function G.GetConsolePPEnv() return env end

local TheInput, pcall, loadstring, Ents, Vector3, unpack, setmetatable =
G.TheInput, G.pcall, G.loadstring, G.Ents, G.Vector3, G.unpack, G.setmetatable
--local printwrap    = _G.printwrap
--local global       = _G.global
local setfenv = G.setfenv

local DEBUG = not modname:find("^workshop-")

if DEBUG then
    --require "debugkeys"
    --G.CHEATS_ENABLED = true
end

------------------------------------------
------------------------------------------

--for hot reload - debug mode only?
Impurities = {}

Impurities.locations = setmetatable({}, { __mode = "kv" })
Impurities.names = {}
Impurities.originals = {}

---@param loc table
---@param name string
---@param old any?
---@return any
function Impurities.new(loc, name, old)
    table.insert(Impurities.names, name)
    Impurities.locations[#Impurities.names] = loc
    Impurities.originals[#Impurities.names] = old or loc[name]
    return loc[name]
end

---@param loc table
---@param idx string
---@param wrapper fun(old: function, ...): any
function Decorate(loc, idx, wrapper)
  local origin = modassert(loc[idx], "no decorator function")
  Impurities.new(loc, idx, origin)
  loc[idx] = function(...)
    return wrapper(origin, ...)
  end
end

---@param fn function
---@param overrides table<string, any>
function ModGfenv(fn, overrides)
    return setfenv(fn, setmetatable(overrides, { __index = G }))
end

local nlchar = ('\n'):byte()

---@param s string
---@param idx number
---@return number?
function StrGetLineStart(s, idx)
    for i = idx, 1, -1 do
        if s:byte(i) == nlchar then
            return i + 1 --one char *after* newline
        end
    end
    return 1
end

---@param s string
---@param idx number
---@return number?
function StrGetLineEnd(s, idx)
    for i = idx+1, #s do
        if s:byte(i) == nlchar then
            return i - 1 --one char *before* newline
        end
    end
    return #s
end

---@param s string
---@param idx number
---@return number?
---@return number?
function StrGetLineBounds(s, idx)
    return StrGetLineStart(s, idx), StrGetLineEnd(s, idx)
end

local Text = require "widgets/text"
function TextBoxXPosToCol(textfont, textsize, xpos, line, substring)
    substring = substring or string.utf8sub
    local textbox = Text(textfont, textsize)
    local prevwidth = 0
    local index
    for i = 1, #line do
        textbox:SetString(substring(line, 1, i))
        local width = textbox:GetRegionSize()
        if width > xpos then
            index = width - xpos < xpos - prevwidth and i or i - 1
            break
        end
        prevwidth = width
    end
    textbox:Kill()
    return index or #line
end

function TextBoxStringToPos(font, size, line)
    if line == "" then return 0 end --GetRegionSize would return 2^127
    return( Text(font, size, line):GetRegionSize() )
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

local KnownModIndex = G.KnownModIndex
local ModManager = G.ModManager
G.d_reloadconsolemod = function()
    if TheFrontEnd:GetActiveScreen().name == "ConsoleScreen" then
        TheFrontEnd:PopScreen(TheFrontEnd:GetActiveScreen())
    end
    for i = 1, #Impurities.names do
        if Impurities.locations[i] then
            Impurities.locations[i][Impurities.names[i]] = Impurities.originals[i]
        end
    end
    ModManager:FrontendUnloadMod(modname)

    local prefab_name = "MOD_"..modname
	TheSim:UnloadPrefabs{prefab_name}
    TheSim:UnregisterPrefabs{prefab_name}
	--G.ManifestManager:UnloadModManifest(string.sub(modname, 5))
    KnownModIndex:UpdateSingleModInfo(modname)
    KnownModIndex.savedata.known_mods[modname].modinfo = KnownModIndex:LoadModInfo(modname)
    KnownModIndex:LoadModConfigurationOptions(modname)


    local isworldgen = CHARACTERLIST == nil
    local isfrontend = ReloadFrontEndAssets ~= nil
    local newenv = G.CreateEnvironment(modname, isworldgen, isfrontend)
    newenv.modinfo = KnownModIndex:GetModInfo(modname)

    --SetPostEnv
    newenv.TheFrontEnd = TheFrontEnd
    newenv.TheSim = TheSim
    newenv.Point = Point
    newenv.TheGlobalInstance = TheGlobalInstance

    --flag
    newenv.Reload = true

	if ModManager:InitializeModMain(modname, newenv, "modmain.lua") then
        print "Successfully Initialized ModMain"
        for i,v in ipairs(G.ModManager.mods) do
            if v == env then
                ModManager.mods[i] = newenv
                break
            end
        end

        G.Prefabs[prefab_name].assets = newenv.Assets or {}
    end
	G.RegisterSinglePrefab(G.Prefabs[prefab_name])
	TheSim:LoadPrefabs{prefab_name}
end
------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

Config = {
    rtoggle = GetModConfigData("remotetoggle"),
    tab     = GetModConfigData("tab"),
    automanagelog = GetModConfigData("autoopencloselog"),
    WordSet = GetModConfigData("wordset"),
}

Config.RemoteToggleKeys = {
    [G.KEY_LCTRL] = Config.rtoggle == "ctrl",
    [G.KEY_RCTRL] = Config.rtoggle == "ctrl",
    [G.KEY_LALT]  = Config.rtoggle == "alt",
    [G.KEY_RALT]  = Config.rtoggle == "alt",
}

Config.TabInsert   = Config.tab == "default" or Config.tab == "spaces"
Config.TabComplete = Config.tab == "default" or Config.tab == "complete"
Config.TabNext     = Config.tab == "next"
modassert(Config.TabComplete or Config.TabInsert or Config.TabNext, "unknown tab configuration data")

Config.Ignores = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}

Config.CloseLogOnRun = Config.automanagelog
Config.OpenLogWithConsole = Config.automanagelog

ModGfenv(G.OnServerPauseDirty, {
    print = function(...)
        if Config.Ignores[(...)] then return end
        print(...)
    end;
})

---@param lua string
function CodeMissingClosingStatement(lua)
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

------------------------------------------------------------
------------------------------------------------------------

modimport "consolemodder"
modimport "textedit"

AddGamePostInit(function ()
    modimport "consolelog"
end)
if Reload then
    modimport "consolelog"
end

if G.rawget(G, "GetConsoleLocalRemoteHistory") == nil then
    local remotetogglehistory = {}
    G.global "GetConsoleLocalRemoteHistory"
    G.GetConsoleLocalRemoteHistory = function()
        return remotetogglehistory
    end
end

local ConsoleScreen = require("screens/consolescreen")
local __ctor = Impurities.new(ConsoleScreen, "_ctor")
ConsoleScreen._ctor = function(self, ...)
    __ctor(self, ...)
    ConsoleModder(self, G.GetConsoleHistory(), G.GetConsoleLocalRemoteHistory())
end

