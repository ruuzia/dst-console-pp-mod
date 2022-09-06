require "debugcommands"

modimport "main/env"

local G = GLOBAL

local pcall, loadstring, Ents, Vector3 = G.pcall, G.loadstring, G.Ents, G.Vector3
local TheInput = G.TheInput

DEBUG = not modname:find("^workshop-")

-- dprint does nothing on workshop release version
env.dprint = DEBUG and print or function() end

G.global "ConsolePP"
ConsolePP = G.ConsolePP or {}

IS_DEDICATED = TheNet:IsDedicated()
local client_only_version_exists = ConsolePP.env and ConsolePP.env.modinfo.client_only_mod
local ismastersim = TheNet:GetIsMasterSimulation()


ConsolePP.save = ConsolePP.save or {}
ConsolePP.tmp = setmetatable({}, {__mode = "v"})
ConsolePP.env = env
G.ConsolePP = ConsolePP

RPC_NAMESPACE = "ConsolePP"

local ConsoleScreen = require("screens/consolescreen")

modimport "main/reload"

modimport "main/util"

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

local ModConfigurationScreen = require "screens/redux/modconfigurationscreen"
function G.c_config()
    TheFrontEnd:PushScreen(ModConfigurationScreen(modname, true))
end

------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

modimport "main/config"

ModFenv(G.OnServerPauseDirty, {
    print = function(...)
        if Config.IGNORES[(...)] then return end
        print(...)
    end;
})


AssertDefinitionSource(G, "ExecuteConsoleCommand", "scripts/mainfunctions.lua")
---@param fnstr string
---@param guid number
---@param x number
---@param z number
function G.ExecuteConsoleCommand(fnstr, guid, x, z)
    local saved_ThePlayer = G.ThePlayer
    G.ThePlayer = guid ~= nil and Ents[guid] or nil
    TheInput.overridepos = x ~= nil and z ~= nil and Vector3(x, 0, z) or nil

    -- lstrip "="
    local equalsstart = fnstr:find("^%=")
    if equalsstart then
        fnstr = fnstr:sub(2)
    end

    -- First try evaluate as expression
    local result = {pcall(loadstring("return "..fnstr))}
    -- If failed
    if not result[1] and not equalsstart then
        result = {pcall(loadstring(fnstr))}
    end
    if #result > 1 then
        for i = 2, #result do
            PrettyPrint(result[i]);
        end
    end

    if guid ~= nil then
        G.ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end

------------------------------------------------------------
------------------------------------------------------------

modimport "main/logs"
Logs = LogHistory()

AddClientModRPCHandler(RPC_NAMESPACE, "ClusterLog", function(shard, content)
    --printf("%s server log (len: %d) retrieved!", shard, #content)
    Logs:SetClusterLogContents(shard, content)
end)

local MAX_LOG_SEND_LENGTH = 1e4

AddModRPCHandler(RPC_NAMESPACE, "RequestClusterLog", function(player, shard)
    --printf("Getting %s server log for %s", shard, tostring(player))
    TheSim:GetPersistentString("../../"..shard.."/server_log.txt", function(succ, contents)
        --printf("Persistent string callback, success: %s, len %d", tostring(succ), #contents)
        if succ then
            SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "ClusterLog"), player.userid, shard, contents:sub(-MAX_LOG_SEND_LENGTH))
        end
    end)
end)

modimport "main/consolemodder"
modimport "main/textedit"
modimport "main/consolelog"
modimport "main/wordpredictionwidget"

local __ctor = Impurities:New(ConsoleScreen, "_ctor")
ConsoleScreen._ctor = function(self, ...)
    Config:Update()
    __ctor(self, ...)
    ConsoleModder(self, G.GetConsoleHistory(), G.GetConsoleLocalRemoteHistory())
end
