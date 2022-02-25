---@diagnostic disable:lowercase-global

name = "Console++"
author = "Friendly Grass"
description = [=[
This clientside mod implements many improvements to the DST command console.
  - Full multiline capability
    - Shift+Enter starts a new line
    - Enter starts a new line if code is missing closing `]]`, `end`, etc
  - More word completions
  - Dynamic word completions (only in local)
  - Remote/Local will not be toggled when using key combinations
  - Disable Server Un/Paused messages (only in local)
  - Print expression results (like Python REPL) (only in local)
  - "=2 + 3" shorthand for "print(2 + 3)" (like Lua REPL)
  - Ctrl+Backspace (all textedits)
  - Tab (all textedits)

TODO:
  - Improvements console log
  - Serverside version of this mod
  - Implement copying text to clipboard (NOT possible in current API)

]=]
version = "1.0.3"
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
    default = ""
},

}







