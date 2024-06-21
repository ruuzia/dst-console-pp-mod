local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local KnownModIndex = G.KnownModIndex
local ModManager = G.ModManager
local setmetatable = G.setmetatable

Impurities = {}

-- location keys are weak
-- If the modified table no longer exists, we can freely forget it
Impurities.items = setmetatable({}, { __mode = "k" })

Impurities.requires = {}

---@param loc table
---@param key any index of loc
---@param new_value any|nil
---@return any current value of loc[key]
function Impurities:New(loc, key, new_value)
    self.items[loc] = self.items[loc] or {}
    -- Don't add if already added!
    if not self.items[loc][key] then
        -- Boxing the value in a table to support nil values
        self.items[loc][key] = { loc[key] }
    end
    if new_value ~= nil then
        loc[key] = new_value
    end
    return loc[key]
end

function Impurities:Restore(loc, key)
    local item = self.items[loc]
    if not item or not item[key] then return end          -- Keys (the locations) are weak,
                                         --   Could have been already been GC'd
    loc[key] = item[key][1]              -- Restore the value
    item[key] = nil                      -- Discard the impurity
end

function Impurities:Purge()
    for loc, item in pairs(self.items) do
        for k, orig in pairs(item) do
            -- Restore
            loc[k] = orig[1]
        end
    end
    -- Leave behind trash for garbage collector and start anew
    self.items = {}

    -- Unload packages so next require reloads them
    for _,name in ipairs(self.requires) do
        G.package.loaded[name] = nil
    end
end

function Impurities:Package(name)
    table.insert(self.requires, name)
end

local function remove_mod_rpc_namespace(namespace)
    G.MOD_RPC[namespace] = nil
    G.MOD_RPC_HANDLERS[namespace] = nil
    G.CLIENT_MOD_RPC[namespace] = {}
    G.CLIENT_MOD_RPC_HANDLERS[namespace] = {}
    -- todo: undo RPC_QUEUE_RATE_LIMIT increase
end

function G.d_cpm_reload(silent)
    -- Update client
    if IS_DEDICATED then
        SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "d_reload"), nil)
    end
    remove_mod_rpc_namespace(RPC_NAMESPACE)

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
        TheFrontEnd:PopScreen(TheFrontEnd:GetActiveScreen())
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

AddClientModRPCHandler(RPC_NAMESPACE, "d_reload", function()
    if IS_DEDICATED then return end
    G.d_cpm_reload()
end)
