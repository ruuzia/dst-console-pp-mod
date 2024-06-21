setfenv(1, ConsolePP.env)

local ModConfigurationScreen = require "screens/redux/modconfigurationscreen"
function ConsolePP.Config()
    TheFrontEnd:PushScreen(ModConfigurationScreen(modname, true))
end

-- TODO: deprecate
G.c_config = CosolePP.Config

return {}
