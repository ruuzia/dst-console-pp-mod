
name = "Console++"
author = "Friendly Grass"
description = [[

]]
version = "1.0.1"
dst_compatible = true
forge_compatible = false
gorge_compatible = false
dont_starve_compatible = false
client_only_mod = true
all_clients_require_mod = false
--icon_atlas = "modicon.xml"
--icon = "modicon.tex"
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

}







