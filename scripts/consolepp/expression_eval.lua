-- This module adds behaviour similar to what can be found in the Lua
-- REPL. If you prefix your input with an equal sign "=", it will be
-- evaluated as an expression rather than a block. Additionally, 
-- it will first try to parse the command as an expression and then
-- as a block if it fails. Finally, the results of commands
-- evaluated as an expression will be pretty printed nicely.
--
-- SUPPORT:
-- -------
-- Client-only version running local: FULL
-- Client-only version running remote: PARTIAL (must use "=" to evaluate as expression)
-- All-clients version running local: FULL
-- All-clients version running remote: FULL
--

setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

-- Overriding ConsoleScreen:Run!
AssertDefinitionSource(ConsoleScreen, "Run", "scripts/screens/consolescreen.lua")
function ConsoleScreen:Run()
	local fnstr = self.console_edit:GetString()

    G.SuUsedAdd("console_used")

	if fnstr ~= "" then
		G.ConsoleScreenSettings:AddLastExecutedCommand(fnstr, self.toggle_remote_execute)
	end

	if self.toggle_remote_execute and TheNet:GetIsClient() and (TheNet:GetIsServerAdmin() or IsConsole()) then
        local x, y, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
        --- [NEW] ---
        if fnstr:byte() == string.byte("=") then
            fnstr = string.format("print(table.inspect((%s), 1))", fnstr:sub(2))
        end
        -------------
		TheNet:SendRemoteExecute(fnstr, x, z)
	else
		G.ExecuteConsoleCommand(fnstr)
	end
end

-- Overriding ExecuteConsoleCommand@
AssertDefinitionSource(G, "ExecuteConsoleCommand", "scripts/mainfunctions.lua")
function G.ExecuteConsoleCommand(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
        saved_ThePlayer = G.ThePlayer
        G.ThePlayer = guid ~= nil and G.Ents[guid] or nil
    end
    G.TheInput.overridepos = x ~= nil and z ~= nil and G.Vector3(x, 0, z) or nil

    -------- [OLD] ---------
    -- local status, r = pcall(loadstring(fnstr))
    -- if not status then
    --     nolineprint(r)
    -- end
    ------------------------
    ------- [NEW] ----------
    -- lstrip "="
    local equalsstart = fnstr:find("^%=")
    if equalsstart then
        fnstr = fnstr:sub(2)
    end

    -- First try to parse as expression
    local command, err = G.loadstring("return "..fnstr)
    if not command and not equalsstart then
        -- Try again as block
        command, err = G.loadstring(fnstr)
    end

    if command then
        local result = { pcall(command) }
        -- If failed
        if result[1] then
            for i = 2, #result do
                PrettyPrint(result[i]);
            end
        else
            -- Runtime error
            print(tostring(result[2]))
        end
    else
        -- Parsing error
        print(tostring(err))
    end
    ------------------------

    if guid ~= nil then
        G.ThePlayer = saved_ThePlayer
    end
    G.TheInput.overridepos = nil
end

return {
}
