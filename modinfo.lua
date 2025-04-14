CLIENT_VERSION = true

name = CLIENT_VERSION and "Console++ [client version]" or "Console++ [full version]"
author = "Friendly Grass"
description = [=[
This mod implements many improvements to the DST command console.

󰀔 Please view the Steam description for details 󰀔
]=]
version = "1.5.2"
dst_compatible = true
forge_compatible = false
gorge_compatible = false
dont_starve_compatible = false
client_only_mod = CLIENT_VERSION
all_clients_require_mod = not CLIENT_VERSION
icon_atlas = "modicon.xml"
icon = "modicon.tex"
forumthread = ""
api_version_dst = 10
-- Other mods first for my incompatibility detection
priority = -20
-- Client version should start after server
if CLIENT_VERSION then priority = priority - 1 end
mod_dependencies = {}

local function Header(data)
    data.options = { { description = "", data = false}} -- A list of one item - boolean option without a description
    data.default = false
    return data
end

FEATURES = {
    {
        name = "use_last_remote_toggle",
        desc = "When opening the console, default remote execute toggle to last executed commmand"
    },
    {
        name = "textedit_click_to_position",
        desc = "Click on text in the console or other textedit to position cursor!"
    },
    {
        name = "dynamic_completion",
        desc = "Dynamic Lua word completions",
        add_config = "Word Completion",
    },
    {
        name = "multiline_console_input",
        desc = "A full multiline console input",
        add_config = "Multiline Console",
    },
    {
        name = "keep_open",
        desc = "Support Enter+Ctrl behaviour",
    },
    {
        name = "expression_eval",
        desc = "Try evaluating commands as expression and pretty-printing output",
        add_config = "Evaluate as Expression",
    },
    {
        name = "scrollable_log",
        desc = "Provide a scrollable log within the console screen",
    },
    {
        name = "shard_logs",
        desc = "Switch between Client, Forest, Caves logs in the console screen",
        dependencies = {"scrollable_log"},
        add_config = "Shard Logs",
    },
    {
        name = "console_commands",
        desc = "Might remove: provides a c_revealmap() command"
    },
    {
        name = "text_navigation",
        desc = "Text navigation features: home, end, ctrl+left, ctrl+right, ctrl+backspace, etc",
    },
    {
        name = "pseudoclipboard",
        desc = "Ctrl+C writes current console contents to \"pseudoclipboard\" file and Ctrl+Shift+C replaces console input with content of psuedoclipboard",
        default = false,
        add_config = "Pseudoclipboard",
    },
    {
        name = "tab_insertion",
        desc = "Supports using tab to insert and delete spaces",
    },
    {
        name = "arrow_keys_move_between_lines",
        desc = "Using UP and DOWN to move between lines",
    },
    {
        name = "completion_key_config",
        desc = "Applying tab complete and enter complete configuration",
    },
    {
        name = "remote_toggle_key",
        desc = "Customize remote toggle key and keep shortcuts from triggering remote toggle",
    },
    {
        name = "quiet_server_pause_messages",
        desc = "Disables annoying Server Pause and Server Unpaused messages",
        add_config = "Quiet Server Pause Messages",
    },
    {
        name = "config_screen",
        desc = "Use ConsolePP.Config() to open mod settings from anywhere without reloading",
    },
    {
        name = "support_completing_in_middle",
        desc = "Game's built-in word prediction always tries to complete from end of input rather than at cursor.",
    },
    {
        name = "hot_reload",
        desc = "[dev] use ConsolePP.HotReload() to hot reload entire mod",
        default = false,
    },
}

server_filter_tags = {}
configuration_options = {
    Header {
        label = " 	󰀮 Keys",
        hover = "What Tab, Ctrl, Enter, etc do",
        name = "titleKeyBehaviour",
    },

    {
        name = "tab",
        label = "Tab Behaviour",
        hover = "Behaviour of tab key in text inputs (see Tab Spaces)",
        options = {
            --{ data = "default", description = "Complete/Insert", hover = "Complete predictions. If there are none, insert 4 spaces." },
            --{ data = "spaces", description = "Insert", hover = "Always insert equivalent spaces." },
            { data = "complete", description = "Complete", hover = "Complete prediction" },
            { data = "next", description = "Tab Through", hover = "Tab Through predictions (Ctrl + Tab to go backwards)." },
        },
        default = "complete"
    },

    {
        name = "tabwidth",
        label = "Tab Spaces",
        hover = "Spaces to insert on a tab (No support for real tabs)",
        options = {
            { data = 0, description = "NONE" },
            { data = 1, description = "One" },
            { data = 2, description = "Two" },
            { data = 3, description = "Three" },
            { data = 4, description = "Four" },
            { data = 6, description = "Six" },
            { data = 8, description = "Eight" },
        },
        default = 4
    },

    {
        name = "remotetoggle",
        label = "Remote Toggle with",
        hover = "Keybind for world host to toggle Remote/Local in console - vanilla is Ctrl",
        options = {
            { data = "ctrl", description = "Ctrl" , hover = "left and right control Keys" },
            { data = "alt", description = "Alt" , hover = "left and right alt keys" },

        },
        default = "ctrl"
    },

    {
        name = "keepopen",
        label = "Use Ctrl+Enter to",
        hover = "Should console close on run or stay open",
        options = {
            { data = false, description = "Run & Stay Open", hover = "console closes by default (vanilla)" },
            { data = true, description = "Run & Close", hover = "console stays open by default" },
        },
        default = false
    },

    {
        name = "entercomplete",
        label = "Complete with Enter",
        hover = "Accept completion with Enter",
        options = {
            { data = true, description = "Yes" },
            { data = false, description = "No" },
        },
        default = false,
    },

    Header {
        label = "󰀏 Other behaviours",
        name = "titleOtherOptions", -- you wont access it in the scripts, so any unique name will do
    },

    -- Is this really a needed config option?
    -- Disabling for now. I think if I do it like this
    -- it will be backwards compatible.
    {
        --GetModConfigData("wordset")
        name = "wordset",
        label = "Word Characters for Ctrl+Backspace",
        --options = {
        --    { data = "%S", description = "All Non-Space Characters" },
        --    { data = "%w_", description = "Letters, numbers, and underscore" },
        --},
        default = "%w_"
    },

    {
        --GetModConfigData("autoopencloselog")
        name = "autoopencloselog",
        label = "Open/Close Log with console",
        options = {
            { data = true, description = "Yes", hover = "vanilla" },
            { data = false, description = "No" , hover = "Only Ctrl+L opens and closes log"},
        },
        default = true
    },

    {
        --GetModConfigData("scrollspeed")
        name = "scrollspeed",
        label = "Console Log Scroll Speed",
        options = {
            { data = 1, description = "1", hover = "1 line per mouse wheel" },
            { data = 2, description = "2", hover = "2 lines per mouse wheel" },
            { data = 3, description = "3", hover = "3 lines per mouse wheel" },
            { data = 4, description = "4", hover = "4 lines per mouse wheel" },
            { data = 5, description = "5", hover = "5 lines per mouse wheel" },
            { data = 6, description = "6", hover = "6 lines per mouse wheel" },
        },
        default = 2
    },

    {
        name = "logtheme",
        label = "Shard Log Colours",
        hover = "Colours of Master and Caves logs",
        options = {
            { data = "default", description = "Default", hover = "Teal and orange" },
            { data = "alternative", description = "Minimal", hover = "Less extreme colours requested" },
        },
        default = "default",
    },
    {
        name = "autocomplete",
        label = "Autocomplete Globals",
        hover = "Provide words completions for global variables",
        options = {
            { data = true, description = "Enabled" },
            { data = false, description = "Disabled" },
        },
        default = true,
    },
    {
        name = "autocompletefields",
        label = "Autocomplete Fields",
        hover = "Provide word completions after \".\" and \":\" chains",
        options = {
            { data = true, description = "Enabled" },
            { data = false, description = "Disabled" },
        },
        default = true,
    },
}

configuration_options[#configuration_options+1] = Header {
    label = "󰀖 Disable modules",
    name = "titleDisableFeatures",
}
for i = 1, #FEATURES do
    local module = FEATURES[i]
    if module.add_config then
        configuration_options[#configuration_options+1] = {
            name = "module:"..module.name,
            label = module.add_config,
            hover = module.desc,
            options = {
                { data = true, description = "Enabled" },
                { data = false, description = "Disabled" },
            },
            default = true,
        }
    end
end

configuration_options[#configuration_options+1] = Header {
    label = "=== Advanced ===",
    name = "titleAdvancedWarning",
}

configuration_options[#configuration_options+1] = Header {
    label = "󰀀  All modules",
    name = "titleModuleToggling",
}

for i = 1, #FEATURES do
    local module = FEATURES[i]
    if not module.add_config then
        configuration_options[#configuration_options+1] = {
            name = "module:"..module.name,
            label = module.name,
            hover = module.desc,
            options = {
                { data = true, description = "Enabled" },
                { data = false, description = "Disabled" },
            },
            default = module.default == nil and true or module.default,
        }
    end
end
