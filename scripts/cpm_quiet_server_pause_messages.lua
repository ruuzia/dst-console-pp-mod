setfenv(1, ConsolePP.env)
local G = GLOBAL

local function SorryICantHearYou(...)
    if Config.IGNORES[(...)] then return end
    print(...)
end

Hook(G, "OnServerPauseDirty", function (orig, ...)
    Impurities:New(G, "print", SorryICantHearYou)
    local ret = { orig(...) }
    Impurities:Restore(G, "print")
    return unpack(ret)
end)

return {}
