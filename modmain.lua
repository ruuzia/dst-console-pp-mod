local G = GLOBAL

G.global "ConsolePP"
if G.ConsolePP and G.ConsolePP.env.modinfo.all_clients_require_mod and modinfo.client_only_mod then
    -- Server+all_clients version already exists
    -- Don't run client-only mod
    -- TODO: support client-only configuration with active all clients mod
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

ConsolePP.save = ConsolePP.save or {}
ConsolePP.tmp = setmetatable({}, {__mode = "v"})
ConsolePP.env = env
G.ConsolePP = ConsolePP

RPC_NAMESPACE = "ConsolePP"

modimport "main/reload"
modimport "main/util"


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

local ConsoleScreen = require("screens/consolescreen")
local __ctor = Impurities:New(ConsoleScreen, "_ctor")
ConsoleScreen._ctor = function(self, ...)
    Config:Update()
    __ctor(self, ...)
    ConsoleModder(self)
end

modimport "main/textedit"
modimport "main/consolelog"
modimport "main/wordpredictionwidget"
modimport "main/tester"

local FEATURES = {
    "cpm_textedit_click_to_position",
    "cpm_dynamic_completion",
    "cpm_multiline_console_input",
    "cpm_keep_open",
    "cpm_expression_eval",
    "cpm_shard_logs",
    "cpm_console_commands",
}

local modules = {}

for _, module in ipairs(FEATURES) do
    Log("Loading feature module %q", module)
    local ok, result = pcall(Require, module)
    if not ok then
        Log("Failed to load module: %q", module)
        moderror(result)
    else
        result = result or {}
        result.name = module
        table.insert(modules, result)
    end
end

function GetFeatureModules()
    return modules
end
