local G = GLOBAL
local History = require "history"
local MAX_LOG_HISTORY = 500

LogHistory = Class(function (self)
    local name
    -- assuming first and only upvalue
    name, self.print_loggers = debug.getupvalue(G.AddPrintLogger, 1)

    modassert(name == "print_loggers", "unable to find print_loggers table")

    self.cluster = {}
    self:InitClientLogs()
    self:SetUpdatingClient(true)
    self:InitClusterLog("Master")
    self:InitClusterLog("Caves")
end)

function LogHistory:InitClientLogs()

    local clientlog = History(MAX_LOG_HISTORY)


    self.client = clientlog
end

function LogHistory:SetUpdatingClient(update)
    if not update then
        for i = 1, #self.print_loggers do
            if self.print_loggers[i] == self.client_logger then
                table.remove(self.print_loggers, i)
            end
        end
        return
    end

    -- @RELOAD ---
    if ConsolePP.save.clientlog_lines then
        for _, line in ipairs(ConsolePP.save.clientlog_lines) do
            self.client:Push(line)
        end
        local i = 1
        repeat
            if debug.getinfo(self.print_loggers[i], "S").source:find("^"..MODROOT) then
                print("[Console++] removing old print logger")
                table.remove(self.print_loggers, i)
            else
                i = i + 1
            end
        until i > #self.print_loggers
    end
    ConsolePP.save.clientlog_lines = self.client
    -------------

     function self.client_logger(...)
        local args = {...}
        -- args can contain holes, so use select
        local n = select("#", ...)
        for i = 1, n do
            args[i] = tostring(args[i])
        end
        local str = table.concat(args)
        for line in str:gmatch "[^\n]+" do
            self.client:Push(line)
        end
    end

    for i, v in ipairs(G.GetConsoleOutputList()) do
        self.client_logger(v)
    end

    self.print_loggers[#self.print_loggers+1] = self.client_logger
end

Hook (require"screens/redux/servercreationscreen", "Create", function (orig, scrn, ...)
    TheSim:SetPersistentString("slot", tostring(scrn.save_slot))
    return orig(scrn, ...)
end)

function LogHistory:UpdateClusterLog(shard, onupdated)
    if modinfo.client_only_mod or TheNet:GetIsServer() then
        local cluster_num
        TheSim:GetPersistentString("slot", function (succ, num)
            if succ then cluster_num = tonumber(num) end
        end)
        if not cluster_num then
            self:SetClusterLogContents(shard, "(No cluster slot)")
            return
        end
        if cluster_num > G.CLOUD_SAVES_SAVE_OFFSET then
            self:SetClusterLogContents(shard, "(Can not read from cloud save)")
            return;
        end
        local path = "../Cluster_"..cluster_num.."/"..shard.."/server_log.txt"
        TheSim:GetPersistentString(path, function (succ, contents)
            if not succ then
                self:SetClusterLogContents(shard, "(Failed to load "..path..")")
                return
            end

            self:SetClusterLogContents(shard, contents)
        end)
        onupdated()
    else
        --printf("Sending %s server log request", shard)
        SendModRPCToServer(GetModRPC(RPC_NAMESPACE, "RequestClusterLog"), shard)
        self._onupdated_callback = onupdated
    end
end

function LogHistory:SetClusterLogContents(shard, contents)
    local log = self.cluster[shard]
    log:Erase()
    local count = 0
    for line in contents:gmatch "[^\n]+" do
        -- Strip "[##:##:##]: " prefix
        local _, nd = line:find("%[%d%d:%d%d:%d%d%]: ")
        if nd then line = line:sub(nd+1) end
        log:Push(line)
        count = count + 1
    end
    if self._onupdated_callback then self._onupdated_callback() end
end

function LogHistory:InitClusterLog(folder)
    self.cluster[folder] = History(MAX_LOG_HISTORY)
end

