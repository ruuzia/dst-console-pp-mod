-- I think this is kind of out of the scope of this mod.
-- But we'll leave it for now!
--
setfenv(1, ConsolePP.env)
local G = GLOBAL

local revealmap_task

--- A catch-all map reveal command:
--- * asyncronous (doesn't freeze game)
--- * efficient (relatively)
--- * can call from client or server
--- * c_revealmap() -> reveals map
--- * c_revealmap(false) -> unreveals map
---
function G.c_revealmap(reveal)
    if reveal == nil then reveal = true end
    if not G.TheWorld then
        print("c_revealmap called in bad state")
    elseif not G.TheWorld.ismastersim then
        if reveal then
            G.c_remote("c_revealmap()")
        else
            unreveal()
        end
    else
        if not reveal then
            if IS_DEDICATED then SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "UnrevealMap"), nil)
            else unreveal()
            end
        else
            G.TheWorld.minimap.MiniMap:ShowArea(0,0,0,10000)
            local MapExplorer = G.ThePlayer.player_classified.MapExplorer
            local RevealArea = MapExplorer.RevealArea
            local size_x, size_y = G.TheWorld.Map:GetSize()
            size_x = size_x * 2
            size_y = size_y * 2
            revealmap_task = G.TheWorld:DoStaticPeriodicTask(0, coroutine.wrap(function()
                for x = -size_x, size_x, 35 do
                    for y = -size_y, size_y, 35 do
                        RevealArea(MapExplorer, x, 0, y)
                    end
                    coroutine.yield()
                end
                revealmap_task:Cancel()
                revealmap_task = nil
            end))
        end
    end
end

local function unreveal()
    if revealmap_task then
        revealmap_task:Cancel()
        revealmap_task = nil
    end
    G.MapHideAll()
end
AddClientModRPCHandler(RPC_NAMESPACE, "UnrevealMap", unreveal)

return {
}
