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
            clientlog:Push(line)
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
    ConsolePP.save.clientlog_lines = clientlog
    -------------

    local clientlog  = self.client
     function self.client_logger(...)
        local args = {...}
        for i = 1, #args do
            args[i] = tostring(args[i])
        end
        local str = table.concat(args)
        for line in str:gmatch "[^\n]+" do
            clientlog:Push(line)
        end
    end

    self.print_loggers[#self.print_loggers+1] = self.client_logger
end

Hook (require"screens/redux/servercreationscreen", "Create", function (Create, scrn, ...)
    TheSim:SetPersistentString("slot", tostring(scrn.save_slot))
    return Create(scrn, ...)
end)

function LogHistory:UpdateClusterLog(shard)
    local cluster_num
    local log = self.cluster[shard]
    log:Erase()

    TheSim:GetPersistentString("slot", function (succ, num)
        if succ then cluster_num = tonumber(num) end
    end)
    if not cluster_num then
        log:Push("(No cluster slot)")
        return
    end
    if cluster_num > G.CLOUD_SAVES_SAVE_OFFSET then
        log:Push("(Can not read from cloud save)")
    end
    local path = "../Cluster_"..cluster_num.."/"..shard.."/server_log.txt"
    TheSim:GetPersistentString(path, function (succ, contents)
        if not succ then
            log:Push("(Failed to load "..path..")")
            return
        end
        for line in contents:gmatch "[^\n]+" do
            log:Push(line)
        end
    end)
end

function LogHistory:InitClusterLog(folder)
    self.cluster[folder] = History(MAX_LOG_HISTORY)
end

