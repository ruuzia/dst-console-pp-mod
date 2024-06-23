setfenv(1, ConsolePP.env)
local G = GLOBAL
local PopupDialogScreen = require "screens/redux/popupdialog"

local function ConfirmModuleChanges()
    local features_enabled = {}
    local features_disabled = {}
    for _, feature in ipairs(modinfo.FEATURES) do
        if Config:IsFeatureEnabled(feature.name) ~= IsFeatureLoaded(feature.name) then
            table.insert(Config:IsFeatureEnabled(feature.name)
                and features_enabled or features_disabled, feature.name)


        end
    end
    if #features_enabled > 0 or #features_disabled > 0 then
        local str = ""
        if #features_enabled > 0 then
            str = str..("%d module(s) enabled.\n"):format(#features_enabled)
        end
        if #features_disabled > 0 then
            str = str..("%d module(s) disabled.\n"):format(#features_disabled)
        end
        str = str.."Changing which modules are loaded requires a full reload."
        local str =  string.format(str, #features_enabled, #features_disabled)
        TheFrontEnd:PushScreen(
            PopupDialogScreen("[Console++] Reload to enable", str,
                {
                    {
                        text = "Reload Now",
                        cb = function()
                            TheFrontEnd:PopScreen()
                            G.SimReset()
                        end
                    },
                    {
                        text = "Reload Later",
                        cb = function()
                            TheFrontEnd:PopScreen()
                        end
                    }
                }
            )
        )
    end
end

local ModConfigurationScreen = require "screens/redux/modconfigurationscreen"
function ConsolePP.Config()
    local screen = ModConfigurationScreen(modname, true)
    TheFrontEnd:PushScreen(screen)

    Hook(screen, "Apply", function(orig, self, ...)
        local ret = { orig(self, ...) }
        ConfirmModuleChanges()
        return unpack(ret)
    end)
end

-- TODO: deprecate
G.c_config = ConsolePP.Config

return {
    tests = {
        ["test opening config screen"] = function ()
            G.ConsolePP.Config()
            TheFrontEnd:PopScreen()
        end,
    }
}
