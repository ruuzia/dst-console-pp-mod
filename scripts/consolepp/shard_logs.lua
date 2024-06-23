-- Switch between Client, Master, and Caves logs!
--
setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local TextButton = require "widgets/textbutton"

-- Requires scrollable log
Require "consolepp/scrollable_log"

--- Get the active shard
---@return string|nil name of the current shard
local function ActiveShard()
    if rawget(G, "TheWorld") == nil then
        -- We're not in game!
        return nil
    end
    if not TheNet:GetIsClient() or not TheNet:GetIsServerAdmin() then
        -- We're not running a dedicated server
        return nil
    end

    if G.TheWorld:HasTag "forest" then
        return "Master"
    elseif G.TheWorld:HasTag "cave" then
        return "Caves"
    end

    -- return nil
end

local function SetRemoteLabelColor(screen)
    local shard = ActiveShard()
    if screen.toggle_remote_execute and shard then
        screen.console_remote_execute:SetColour(Config.SHARD_LOG_COLOURS[shard])
    else
        screen.console_remote_execute:SetColour(1,0.7,0.7,1)
    end
end

-- Log buttons to toggle between Client, Server, and Caves
local function LogButton(screen, onactivate, label, color)
    local btn = TextButton(label)
    btn._cpm_activate = onactivate
    btn:SetOnClick(function()
        screen.console_edit:SetEditing(true)
        onactivate()
        TheFrontEnd:ShowConsoleLog()
    end)
    btn:SetText(label)
    btn:SetTextColour(color)
    --btn:SetTextFocusColour(G.UICOLOURS.GOLD)
    btn:SetTextFocusColour(color)
    btn:SetFont(G.NEWFONT_OUTLINE)
    btn.scale = 1.0
    btn:SetOnGainFocus(function()
        btn:SetScale(btn.scale + .10)
    end)
    btn:SetOnLoseFocus(function()
        btn:SetScale(btn.scale)
    end)
    btn:SetScale(btn.scale)
    return btn
end

local MAX_FRONTEND_CONSOLE_LINES = 20

local function ShowLog(screen, logHistory, color)
    if screen._cpm_scrollable_log then
        screen._cpm_scrollable_log.history = logHistory
        screen._cpm_scrollable_log:SetTextColour(unpack(color))
        screen._cpm_scrollable_log:RefreshWidgets(true)
    end

    -- Don't sync with frontend log for now because we don't update
    -- periodically
    --
    -- Hook(TheFrontEnd, "UpdateConsoleOutput", function (orig, self)
    --     orig(self)
    --
    --     local lines = {}
    --     for i = #logHistory - MAX_FRONTEND_CONSOLE_LINES + 1, #logHistory do
    --         table.insert(lines, logHistory[i])
    --     end
    --     self.consoletext:SetString(table.concat(lines, "\n"))
    --     self.consoletext:SetColour(color)
    -- end)
end

-- Add shard butons to console screen UI
Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)

    if not G.TheNet:GetIsClient() and not G.TheNet:GetIsHosting() then return end

    local staticroot = assert(screen._cpm_staticroot)

    local shard_buttons = {}
    screen._cpm_shard_buttons = shard_buttons
    local x = -500
    local y = 210
    do
        local btn = staticroot:AddChild(LogButton(screen, function ()
            ShowLog(screen, Logs.client, G.PORTAL_TEXT_COLOUR)
            return true
        end, "Client", G.PORTAL_TEXT_COLOUR))
        table.insert(shard_buttons, btn)
        shard_buttons["Client"] = btn
        btn:SetPosition(x, y)
    end

    for i, shard in ipairs {"Master", "Caves"} do
        local btn = staticroot:AddChild(LogButton(screen, function ()
            Logs:UpdateClusterLog(shard, function()
                ShowLog(screen, Logs.cluster[shard], Config.SHARD_LOG_COLOURS[shard])
            end)
            return true
        end, shard, Config.SHARD_LOG_COLOURS[shard]))
        btn:SetPosition(x + i * 100, y)
        table.insert(shard_buttons, btn)
        shard_buttons[shard] = btn
    end

    -- Keep from closing console screen when buttons have focus
    screen.console_edit.OnStopForceEdit = function ()
        for _, button in ipairs(screen._cpm_shard_buttons or {}) do
            if button.focus then
                --screen.console_edit:SetEditing(true)
                return
            end
        end
        screen:Close()
    end

end)

-- On Run, automatically switch log to active shard after executing
Hook(ConsoleScreen, "Run", function (orig, screen, ...)
    local shard = screen.toggle_remote_execute and ActiveShard() or "Client"
    local buttons = screen._cpm_shard_buttons
    if shard and buttons and buttons[shard] and modassert(buttons[shard]._cpm_activate) then
        screen.inst:DoTaskInTime(0, function ()
            buttons[shard]._cpm_activate()
        end)
    end

    return orig(screen, ...)
end)


-- Color remote execute based on current shard
Hook(ConsoleScreen, "ToggleRemoteExecute", function (orig, screen, ...)
    local ret = { orig(screen, ...) }

    SetRemoteLabelColor(screen)

    return unpack(ret)
end)

Hook(ConsoleScreen, "OnBecomeActive", function (orig, screen, ...)
    local ret = { orig(screen, ...) }

    -- When console screen is opened, open corresponding log based on current
    -- value of toggle_remote_execute
    local buttons = screen._cpm_shard_buttons
    local shard = screen.toggle_remote_execute and ActiveShard() or "Client"
    if buttons and shard and buttons[shard] and buttons[shard]._cpm_activate then
        buttons[shard]._cpm_activate()
    end

    -- Show and hide buttons along with console log?
    --[[
    Hook(TheFrontEnd, "ShowConsoleLog", function (orig, frontend, ...)
        Log("ShowConsoleLog hook from scripts/cpm_shard_logs.lua")
        for _, button in ipairs(screen._cpm_shard_buttons or {}) do
            button:Show()
        end
        return orig(frontend, ...)
    end)
    Hook(TheFrontEnd, "HideConsoleLog", function (orig, frontend, ...)
        Log("HideConsoleLog hook from scripts/cpm_shard_logs.lua")
        for _, button in ipairs(screen._cpm_shard_buttons or {}) do
            button:Hide()
        end
        return orig(frontend, ...)
    end)
    --]]

    -- Sync with label color
    SetRemoteLabelColor(screen)

    return unpack(ret)
end)

local MAX_LOG_SEND_LENGTH = 1e4

AddModRPCHandler(RPC_NAMESPACE, "RequestClusterLog", function(player, shard)
    --printf("Getting %s server log for %s", shard, tostring(player))
    TheSim:GetPersistentString("../../"..shard.."/server_log.txt", function(succ, contents)
        --printf("Persistent string callback, success: %s, len %d", tostring(succ), #contents)
        if succ then
            SendModRPCToClient(GetClientModRPC(RPC_NAMESPACE, "ClusterLog"), player.userid, shard, contents:sub(-MAX_LOG_SEND_LENGTH))
        end
    end)
end)

AddClientModRPCHandler(RPC_NAMESPACE, "ClusterLog", function(shard, content)
    --printf("%s server log (len: %d) retrieved!", shard, #content)
    Logs:SetClusterLogContents(shard, content)
end)

return {
}
