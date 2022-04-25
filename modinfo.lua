---@diagnostic disable:lowercase-global

name = "Console++ "
author = "Friendly Grass"
description = [=[
This clientside mod implements many improvements to the DST command console.

󰀔 View Steam description for details 󰀔
]=]
version = "1.1.2"
dst_compatible = true
forge_compatible = false
gorge_compatible = false
dont_starve_compatible = false
client_only_mod = true
all_clients_require_mod = false
icon_atlas = "modicon.xml"
icon = "modicon.tex"
forumthread = ""
api_version_dst = 10
priority = 0
mod_dependencies = {}

server_filter_tags = {}
configuration_options = {
{
    --GetModConfigData("remotetoggle")
    name = "remotetoggle",
    label = "Remote/Local Toggle Keybind",
    hover = "Keybind for world host to toggle Remote/Local in console - vanilla is Ctrl",
    options = {
        { data = "ctrl", description = "Ctrl" , hover = "left and right control Keys" },
        { data = "alt", description = "Alt" , hover = "left and right alt keys" },

    },
    default = "ctrl"
},
{
    --GetModConfigData("tab")
    name = "tab",
    label = "Tab Behaviour",
    hover = "behaviour of tab key in text inputs",
    options = {
        { data = "default", description = "Complete/Insert", hover = "Complete predictions. If there are none, insert 4 spaces." },
        { data = "spaces", description = "Insert", hover = "Always insert equivalent spaces." },
        { data = "complete", description = "Complete", hover = "Always try to complete prediction" },
        { data = "next", description = "Tab Through", hover = "Tab Through predictions (Ctrl + Tab to go backwards)." },
    },
    default = "default"
},

{
    --GetModConfigData("wordset")
    name = "wordset",
    label = "Word Characters for Ctrl+Backspace",
    options = {
        { data = "%S", description = "All Non-Space Characters" },
        { data = "%w_", description = "Letters, numbers, and underscore" },
    },
    default = "%S"
},

{
    --GetModConfigData("autoopencloselog")
    name = "autoopencloselog",
    label = "Open/Close Log with Console",
    options = {
        { data = true, description = "Yes", hover = "vanilla" },
        { data = false, description = "No" },
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

}







