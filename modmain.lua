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


local FEATURES = {
    "cpm_use_last_remote_toggle",
    "cpm_textedit_click_to_position",
    "cpm_dynamic_completion",
    "cpm_multiline_console_input",
    "cpm_keep_open",
    "cpm_expression_eval",
    "cpm_scrollable_log",
    "cpm_shard_logs",
    "cpm_console_commands",
    "cpm_text_navigation",
    "cpm_pseudoclipboard",
    "cpm_tab_insertion",
    "cpm_arrow_keys_move_between_lines",
    "cpm_completion_key_config",
    "cpm_arrow_keys_move_between_lines",
    "cpm_quiet_server_pause_messages",
    "cpm_config_screen",
    "cpm_hot_reload",
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

Hook(require("screens/consolescreen"), "_ctor", function (constructor, self, ...)
    Config:Update()
    return constructor(self, ...)
end)
