local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local KnownModIndex = G.KnownModIndex
local ModManager = G.ModManager
local setmetatable = G.setmetatable

--for hot reload - debug mode only?
Impurities = setmetatable({}, {__tostring = function(t) return tostring(t.items) end})

-- location keys are weak
-- If the modified table no longer exists, we can freely forget it
Impurities.items = setmetatable({}, { __mode == "k", __tostring = function(items)
    local xs = {"Impurities:"}
    for k,v in pairs(items) do
        xs[#xs+1] = string.format('location (%s)\n%s', tostring(k), tostring(v))
    end
    return table.concat(xs, '\n')
end})

local item_mt = {__tostring = function(item)
    local xs = {}
    for k,v in pairs(item) do
        xs[#xs+1] = string.format('\t(key = %s, orig = %s)', tostring(k), tostring(v))
    end
    return table.concat(xs, '\n')
end}

---@param loc table
---@param key any index of loc
---@param origin any? the original value (default to current)
---@return any current value of loc[key]
function Impurities:New(loc, key, orig)
    self.items[loc] = self.items[loc] or setmetatable({}, item_mt)
    self.items[loc][key] = orig or loc[key]
    return loc[key]
end

function Impurities:Restore(loc, key)
    local item = self.items[loc]
    if not item then return end          -- Keys (the locations) are weak,
                                         --   Could have been already been GC'd
    loc[key] = item[key]                 -- Restore the value
    item[key] = nil                      -- Discard the impurity
end

function Impurities:Reset()
    for loc, item in pairs(self.items) do
        for k, orig in pairs(item) do
            -- Restore
            loc[k] = orig
        end
    end
    -- Leave behind trash for garbage collector and start anew
    self.items = {}
end

function G.d_cpm_reload(silent)
    -- Update client
    if RUNNING_DEDICATED then
        SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "d_reload"), nil)
    end
    if TheNet:IsDedicated() then
        G.MOD_RPC[RPC_NAMESPACE] = nil
        G.MOD_RPC_HANDLERS[RPC_NAMESPACE] = nil
    end

    local forceprint = print
    if silent then
        env.print = function() end
        G.print = print
    end
    print "============ RELOAD ==============="
    -- Close console if open
    local console_open = false
    if TheNet:GetIsClient() and TheFrontEnd:GetActiveScreen().name == "ConsoleScreen" then
        console_open = true
        TheFrontEnd:PopScreen(TheFrontEnd:GetActiveScreen())
    end
    Impurities:Reset()
    ModManager:FrontendUnloadMod(modname)

    -- Reload modinfos
    KnownModIndex:UpdateSingleModInfo(modname)
    KnownModIndex.savedata.known_mods[modname].modinfo = KnownModIndex:LoadModInfo(modname)
    KnownModIndex:LoadModConfigurationOptions(modname)

    -- These only exist when isworldgen or isfrontend
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

AddClientModRPCHandler(RPC_NAMESPACE, "d_reload", G.d_cpm_reload)
