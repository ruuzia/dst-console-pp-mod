-- We can't write to the clipboard, and this isn't a particularly
-- convenient solution. But it's a temporary fix so there's at least
-- *some* way to save the contents of console log.
--
-- Use Ctrl+C to write to psuedoclipboard and Ctrl+Shift+C to replace
-- current console contents with content of psuedoclipboard.

setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

-- Remove old typo file --
AddGamePostInit(function() TheSim:ErasePersistentString("../psuedoclipboard.txt") end)
------------------------------
local PSEUDO_CLIPBOARD_FILE = "../pseudoclipboard.txt"

-- Keep CTRL from toggling remote execute if you press enter
Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    if key == KEY_C and down and TheInput:IsKeyDown(KEY_CTRL)
        and not TheInput:IsKeyDown(KEY_ALT) -- In case keyboard layouts that use C
    then
        if TheInput:IsKeyDown(KEY_SHIFT) then
            TheSim:GetPersistentString(PSEUDO_CLIPBOARD_FILE, function (succ, content)
                if succ then
                    screen.console_edit:SetString(content)
                    Log("Console contents pulled from "..PSEUDO_CLIPBOARD_FILE.."!")
                else
                    Log("Erorr: Unable to pull console contents from "..PSEUDO_CLIPBOARD_FILE"..!")
                end
            end)
        else
            TheSim:SetPersistentString(PSEUDO_CLIPBOARD_FILE, screen.console_edit:GetString(), false, function (succ)
                if succ then
                    Log("Console contents saved to "..PSEUDO_CLIPBOARD_FILE.."!")
                else
                    Log("Erorr: Unable to write console contents to "..PSEUDO_CLIPBOARD_FILE"..!")
                end
            end)
        end
    end
    return orig(screen, key, down, ...)
end)

-- Oh and we need to do this too
Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
	screen.console_edit.validrawkeys[KEY_C] = true
end)

return {}
