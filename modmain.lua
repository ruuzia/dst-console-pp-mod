local G = GLOBAL

G.global "ConsolePP"
if G.ConsolePP and G.ConsolePP.env.modinfo.all_clients_require_mod and modinfo.client_only_mod then
    -- Server+all_clients version already exists
    -- Don't run client-only mod
    return
end

require "debugcommands"

modimport "main/env"

local pcall, loadstring, Ents, Vector3 = G.pcall, G.loadstring, G.Ents, G.Vector3
local TheInput = G.TheInput

DEBUG = not modname:find("^workshop-")

-- dprint does nothing on workshop release version
env.dprint = DEBUG and print or function() end

ConsolePP = G.ConsolePP or {}

IS_DEDICATED = TheNet:IsDedicated()

local ismastersim = TheNet:GetIsMasterSimulation()


ConsolePP.save = ConsolePP.save or {}
ConsolePP.tmp = setmetatable({}, {__mode = "v"})
ConsolePP.env = env
G.ConsolePP = ConsolePP

RPC_NAMESPACE = "ConsolePP"

local ConsoleScreen = require("screens/consolescreen")

modimport "main/reload"

modimport "main/util"

local revealmap_task
local function unreveal()
    if revealmap_task then
        revealmap_task:Cancel()
        revealmap_task = nil
    end
    G.MapHideAll()
end
AddClientModRPCHandler(RPC_NAMESPACE, "UnrevealMap", unreveal)

function G.c_revealmap(reveal)
    if reveal == nil then reveal = true end
    if not G.TheWorld then
        print("c_revealmap called in bad state")
    elseif not G.TheWorld.ismastersim then
        if reveal then
            G.c_remote("c_revealmap()")
        else
            unreveal()
        end
    else
        if not reveal then
            if IS_DEDICATED then SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "UnrevealMap"), nil)
            else unreveal()
            end
        else
            G.TheWorld.minimap.MiniMap:ShowArea(0,0,0,10000)
            local MapExplorer = G.ThePlayer.player_classified.MapExplorer
            local RevealArea = MapExplorer.RevealArea
            local size_x, size_y = G.TheWorld.Map:GetSize()
            size_x = size_x * 2
            size_y = size_y * 2
            revealmap_task = G.TheWorld:DoStaticPeriodicTask(0, coroutine.wrap(function()
                for x = -size_x, size_x, 35 do
                    for y = -size_y, size_y, 35 do
                        RevealArea(MapExplorer, x, 0, y)
                    end
                    coroutine.yield()
                end
                revealmap_task:Cancel()
                revealmap_task = nil
            end))
        end
    end
end
--]]

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

    if guid then G.ThePlayer = Ents[guid] end
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

    G.ThePlayer = saved_ThePlayer
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

modimport "main/completer"
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
