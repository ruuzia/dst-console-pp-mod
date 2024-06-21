setfenv(1, ConsolePP.env)
local G = GLOBAL

local function RemoveModRPCNamespace(namespace)
    G.MOD_RPC[namespace] = nil
    G.MOD_RPC_HANDLERS[namespace] = nil
    G.CLIENT_MOD_RPC[namespace] = {}
    G.CLIENT_MOD_RPC_HANDLERS[namespace] = {}
    -- todo: undo RPC_QUEUE_RATE_LIMIT increase
end

function ConsolePP.HotReload(silent)
    -- Update client
    if IS_DEDICATED then
        SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "hotreload"), nil)
    end
    RemoveModRPCNamespace(RPC_NAMESPACE)

    local forceprint = print
    if silent then
        -- Temporarily silence print for other functions too
        env.print = function() end
        G.print = print
    end
    local verboseprint = print
    verboseprint "============ RELOAD ==============="
    -- temporarily lose console if open
    local console_open = false
    if not IS_DEDICATED and TheFrontEnd:GetActiveScreen().name == "ConsoleScreen" then
        console_open = true
        TheFrontEnd:GetActiveScreen():Close()
    end
    Impurities:Purge()
    ModManager:FrontendUnloadMod(modname)

    -- Reload modinfos
    -- KnownModIndex:UpdateSingleModInfo(modname)
    -- KnownModIndex.savedata.known_mods[modname].modinfo = KnownModIndex:LoadModInfo(modname)
    -- KnownModIndex:LoadModConfigurationOptions(modname)

    -- (These only exist when isworldgen or isfrontend is set)
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
        verboseprint "Successfully Initialized ModMain"
        -- Change ModManager's reference
        for i,v in ipairs(G.ModManager.mods) do
            if v == env then
                ModManager.mods[i] = newenv
                break
            end
        end

        -- Reload mod prefabs
        local prefab_name = "MOD_"..modname
        G.Prefabs[prefab_name].assets = newenv.Assets or {}
        TheSim:UnloadPrefabs{prefab_name}
        TheSim:UnregisterPrefabs{prefab_name}
        G.RegisterSinglePrefab(G.Prefabs[prefab_name])
        TheSim:LoadPrefabs{prefab_name}

        if console_open then
            verboseprint "Re-opening ConsoleScreen"
            TheFrontEnd:PushScreen(ConsoleScreen())
        end
    else
        if silent then
            forceprint("["..modinfo.name.."] Failed reload!\n"
                 ..KnownModIndex.failedmods[#KnownModIndex.failedmods].error)
        end
        verboseprint("=================================")
        return
    end

    -- Call AddGamePostInits again
    for _, fn in ipairs(newenv.postinitfns.GamePostInit) do
        fn()
    end
    verboseprint "================================="
    if silent then
        env.print = forceprint
        G.print = forceprint
    end
end

AddClientModRPCHandler(RPC_NAMESPACE, "hotreload", function()
    if IS_DEDICATED then return end
    ConsolePP.HotReload()
end)

return {}
