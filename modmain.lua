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

modimport "util/reload"
modimport "util/util"
modimport "util/config"
modimport "util/history"
modimport "util/logs"
modimport "util/textedit"
modimport "util/consolelog"
modimport "util/tester"

------------------------------------------
------------------------------------------

Assets = {
    Asset("IMAGE", "images/textbox_long_thinborder.tex"),
    Asset("ATLAS", "images/textbox_long_thinborder.xml"),
}

------------------------------------------------------------
------------------------------------------------------------

local FEATURE_PATH = "consolepp/"
local FEATURES = {
    "use_last_remote_toggle",
    "textedit_click_to_position",
    "dynamic_completion",
    "multiline_console_input",
    "keep_open",
    "expression_eval",
    "scrollable_log",
    "shard_logs",
    "console_commands",
    "text_navigation",
    "pseudoclipboard",
    "tab_insertion",
    "arrow_keys_move_between_lines",
    "completion_key_config",
    "arrow_keys_move_between_lines",
    "quiet_server_pause_messages",
    "config_screen",
    "hot_reload",
}

local modules = {}

for _, module in ipairs(FEATURES) do
    Log("Loading feature module %q", module)
    local ok, result = pcall(Require, FEATURE_PATH..module)
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

Hook(require("screens/consolescreen"), "_ctor", function (constructor, self, ...)
    Config:Update()
    return constructor(self, ...)
end)
