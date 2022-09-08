CLIENT_VERSION = true
---@diagnostic disable:lowercase-global

name = "Console++"
author = "Friendly Grass"
description = [=[
This clientside mod implements many improvements to the DST command console.

󰀔 View Steam description for details 󰀔
]=]
version = "1.3.10"
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
-- Client version should start before server
if CLIENT_VERSION then priority = priority - 1 end
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
    name = "tabwidth",
    label = "Tab Spaces",
    hover = "Spaces to insert on a tab (No support for real tabs)",
    options = {
        { data = 0, description = "NONE" },
        { data = 2, description = "Two" },
        { data = 3, description = "Three" },
        { data = 4, description = "Four" },
        { data = 8, description = "Eight" },
    },
    default = 4
},
{
    --GetModConfigData("tab")
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
    --GetModConfigData("wordset")
    name = "wordset",
    label = "Word Characters for Ctrl+Backspace",
    options = {
        { data = "%S", description = "All Non-Space Characters" },
        { data = "%w_", description = "Letters, numbers, and underscore" },
    },
    default = "%w_"
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

{
    name = "keepopen",
    label = "Close with Ctrl",
    hover = "Enter runs console by default and Ctrl+Enter closes (instead of reverse)",
    options = {
        { data = false, description = "Close by default" },
        { data = true, description = "Run by default" },
    },
    default = false
},

{
    name = "casesensitive",
    label = "Case Sensitive Completions",
    hover = "Case sensitivity of dynamic autocompletions when indexing with '.' or ':'",
    options = {
        { data = true, description = "Case Sensitive" },
        { data = false, description = "Case Insensitive" },
    },
    default = true,
},

{
    name = "logtheme",
    label = "Shard Log Colours",
    hover = "Colours of Master and Caves logs",
    options = {
        { data = "default", description = "Default", hover = "Teal and orange" },
        { data = "alternative", description = "Alternative", hover = "Less extreme maybe? Shades of purple." },
    },
    default = "default",
},

}
