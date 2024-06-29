local G = GLOBAL

G.global "ConsolePP"
if G.ConsolePP and G.ConsolePP.env.modinfo.all_clients_require_mod and modinfo.client_only_mod then
    -- Server+all_clients version already exists
    -- Don't run client-only mod
    -- TODO: support client-only configuration with active all clients mod
    return
end

require "debugcommands"

modimport "util/env"

DEBUG = not modname:find("^workshop-")
IS_DEDICATED = TheNet:IsDedicated()

ConsolePP = G.ConsolePP or {}
ConsolePP.save = ConsolePP.save or {}
ConsolePP.tmp = setmetatable({}, {__mode = "v"})
ConsolePP.env = env
G.ConsolePP = ConsolePP

RPC_NAMESPACE = "ConsolePP"

modimport "util/state"
modimport "util/modding"
modimport "util/config"
modimport "util/history"
modimport "util/logs"
modimport "util/text"
modimport "util/consolelog"
modimport "util/tester"
modimport "util/lua"
modimport "util/prediction"

------------------------------------------
------------------------------------------

Assets = {
}

------------------------------------------------------------
------------------------------------------------------------

local FEATURE_PATH = "consolepp/"

local modules = {}

function LoadModule(name)
    Log("Loading feature module %q", name)
    local ok, result = pcall(Require, FEATURE_PATH..name)
    if not ok then
        Log("Failed to load module: %q", name)
        moderror(result)
    else
        result = result or {}
        result.name = name
        table.insert(modules, result)
    end
end

for _, feature in ipairs(modinfo.FEATURES) do
    if Config:IsFeatureEnabled(feature.name) then
        LoadModule(feature.name)
    end
end

function IsFeatureLoaded(name)
    return G.package.loaded[FEATURE_PATH..name] ~= nil
end

function GetFeatureModules()
    return modules
end
