local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local KnownModIndex = G.KnownModIndex
local ModManager = G.ModManager
local setmetatable = G.setmetatable

--for hot reload - debug mode only?
Impurities = {}

Impurities.locations = setmetatable({}, { __mode = "kv" })
Impurities.names = {}
Impurities.originals = {}

---@param loc table
---@param name string
---@param old any?
---@return any
function Impurities.new(loc, name, old)
    table.insert(Impurities.names, name)
    Impurities.locations[#Impurities.names] = loc
    Impurities.originals[#Impurities.names] = old or loc[name]
    return loc[name]
end

function G.d_cpm_reload(silent)
    local forceprint = print
    if silent then
        print = function() end
        G.print = print
    end
    print "============ RELOAD ==============="
    local console_open = false
    if TheFrontEnd:GetActiveScreen().name == "ConsoleScreen" then
        console_open = true
        TheFrontEnd:PopScreen(TheFrontEnd:GetActiveScreen())
    end
    for i = 1, #Impurities.names do
        if Impurities.locations[i] then
            Impurities.locations[i][Impurities.names[i]] = Impurities.originals[i]
        end
    end
    ModManager:FrontendUnloadMod(modname)

	--G.ManifestManager:UnloadModManifest(string.sub(modname, 5))
    KnownModIndex:UpdateSingleModInfo(modname)
    KnownModIndex.savedata.known_mods[modname].modinfo = KnownModIndex:LoadModInfo(modname)
    KnownModIndex:LoadModConfigurationOptions(modname)


    local isworldgen = CHARACTERLIST == nil
    local isfrontend = ReloadFrontEndAssets ~= nil
    local newenv = G.CreateEnvironment(modname, isworldgen, isfrontend)
    newenv.modinfo = KnownModIndex:GetModInfo(modname)

    --SetPostEnv
    newenv.TheFrontEnd = TheFrontEnd
    newenv.TheSim = TheSim
    newenv.Point = Point
    newenv.TheGlobalInstance = TheGlobalInstance
	if ModManager:InitializeModMain(modname, newenv, "modmain.lua", true) then
        print "Successfully Initialized ModMain"
        for i,v in ipairs(G.ModManager.mods) do
            if v == env then
                ModManager.mods[i] = newenv
                break
            end
        end

        local prefab_name = "MOD_"..modname
        G.Prefabs[prefab_name].assets = newenv.Assets or {}
        TheSim:UnloadPrefabs{prefab_name}
        TheSim:UnregisterPrefabs{prefab_name}
        G.RegisterSinglePrefab(G.Prefabs[prefab_name])
        TheSim:LoadPrefabs{prefab_name}

        if console_open then
            print "Re-opening ConsoleScreen"
            TheFrontEnd:PushScreen(ConsoleScreen())
        end
    else
        if silent then
            forceprint("["..modinfo.name.."] Failed reload!\n"
                 ..KnownModIndex.failedmods[#KnownModIndex.failedmods].error)
        end
        print("=================================")
        return
    end

    for _, fn in ipairs(newenv.postinitfns.GamePostInit) do
        fn()
    end
    print "================================="
    if silent then
        print = forceprint
        G.print = forceprint
    end
end
