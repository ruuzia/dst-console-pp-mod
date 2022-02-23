require "debugcommands"

local G = GLOBAL


local TheInput, pcall, loadstring, Ents, Vector3, unpack, setmetatable =
G.TheInput, G.pcall, G.loadstring, G.Ents, G.Vector3, G.unpack, G.setmetatable
--local printwrap    = _G.printwrap
--local global       = _G.global
local setfenv = G.setfenv

local DEBUG = not modname:find("^workshop-")

if DEBUG then
    require "debugkeys"
    G.CHEATS_ENABLED = true
end

------------------------------------------
------------------------------------------

--for hot reload - debug mode only?
---@type {loc: table, name: string, old: function}[]
Impurities = { __mode = "kv" }
function Impurities.new(loc, name, old)
    if not DEBUG then return end
    local data = {loc=loc, name=name, old=old}
    table.insert(Impurities, data)
    setmetatable(data, Impurities)
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

---@param s string
---@param idx number
---@return number?
function StrGetLineStart(s, idx)
    if idx > #s or idx < 0 then return nil end

    return (s:sub(1, idx):rfind_plain('\n') or 0) + 1
end

---@param s string
---@param idx number
---@return number?
function StrGetLineEnd(s, idx)
    if idx > #s or idx < 0 then return nil end

    return s:find('.\n', idx) or #s
end

---@param s string
---@param idx number
---@return number?
---@return number?
function StrGetLineBounds(s, idx)
    return StrGetLineStart(s, idx), StrGetLineEnd(s, idx)
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
    local size = G.TheWorld.Map:GetSize() * 2
    for x = -size, size, 35 do
        for y = -size, size, 35 do
            MapExplorer:RevealArea(x, 0, y)
        end
    end
end

G.d_reloadconsolemod = DEBUG and function()
    for _, v in ipairs(Impurities) do
        if v.loc and v.old then
            v.loc[v.name] = v.old
        end
    end
    local isworldgen = CHARACTERLIST == nil
    local isfrontend = ReloadFrontEndAssets ~= nil
    local newenv = G.CreateEnvironment(modname, isworldgen, isfrontend)
    newenv.modinfo = modinfo
    newenv.TheFrontEnd = TheFrontEnd
    newenv.TheSim = TheSim
    newenv.Point = Point
    newenv.TheGlobalInstance = TheGlobalInstance
    for i,v in ipairs(G.ModManager.mods) do
        if v == env then
            G.ModManager.mods[i] = env
        end
    end
	G.ModManager:InitializeModMain(modname, newenv, "modmain.lua")
end or nil
------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

Config = {
    rtoggle = GetModConfigData("remotetoggle"),
}
modassert(Config.rtoggle ~= nil, "could not get config data \"remotetoggle\"")

local ignores = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}


ModGfenv(G.OnServerPauseDirty, {
    print = function(...)
        if ignores[(...)] then return end
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

AssertDefinitionSource(G, "ExecuteConsoleCommand", "mainfunctions.lua")
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

modimport "consolescreen"
modimport "textedit"

AddGamePostInit(function ()
    modimport "consolelog"
end)
if TheFrontEnd then
    modimport "consolelog"
end


