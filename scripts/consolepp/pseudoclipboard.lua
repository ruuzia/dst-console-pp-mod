-- We can't write to the clipboard, which makes things inconvenient.
-- This module provides a solution to save the contents of the console to a file which can then be retrieved.
-- However, the idea of this module is to make it easy to switch between writing a command from the game
-- console and editing a command from within a real text editor.
-- Now, I've figured out how to make the game let me save files right to the local mods folder,
-- which is a much more convenient location to access.
--
-- Use Ctrl+C to write to pseudoclipboard and Ctrl+Shift+C to replace
-- current console contents with content of pseudoclipboard.

setfenv(1, ConsolePP.env)
local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"

local INFO_TEXT = [[

--------------------------------------
----- Console++ Pseudo-Clipboard -----
--------------------------------------
-- * This file is to make it easier to switch between editing a command within
--   the game and editing it in a real text editor.
-- * From the console, use Ctrl+C to replace the file's content with the current
--   console input.
-- * To send the file content back to the console, use Ctrl+Shift+C.
-- * Lines commented out with "--" will be left.
-- * To completely disable, disable the pseudoclipboard module under advanced in
--   the mod configuration screen and then delete this file.
]]

-- Remove old files --
AddGamePostInit(function() TheSim:ErasePersistentString("../psuedoclipboard.txt") end)
AddGamePostInit(function() TheSim:ErasePersistentString("../pseudoclipboard.txt") end)
------------------------------

local DIRECTORY_PATH = "../mods/"
local DATA_FILE_PATH = DIRECTORY_PATH.."console_clipboard.lua"

-- Make game allow me to open this directory
do
    local found = false
    for _, item in pairs(G.package.assetpath) do
        if item.path == DIRECTORY_PATH then
            found = true
            break
        end
    end
    if not found then
        table.insert(G.package.assetpath, { path = DIRECTORY_PATH })
    end
end

local function GetClipboardFileLines()
    local file, err = G.io.open(DATA_FILE_PATH, "r")
    if not file then
        Log("Error: could not read from %s: %s", DATA_FILE_PATH, err)
        return
    end
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return lines
end

local function ShouldIgnoreLine(line)
    return string.starts(line, "--")
end

local function PushClipboard(contents)
    local file_lines = GetClipboardFileLines() or {}
    local lines = {}
    for line in contents:gmatch("([^\n]+)") do
        table.insert(lines, line)
    end
    for _,line in ipairs(file_lines) do
        if ShouldIgnoreLine(line) then
            table.insert(lines, line)
        end
    end

    local file, err = G.io.open(DATA_FILE_PATH, "w")
    if not file then
        Log("Error: could not write to %s: %s", DATA_FILE_PATH, err)
        return
    end
    file:write(table.concat(lines, "\n"))
    file:close()
    Log("Console contents saved to %s", DATA_FILE_PATH)
end

local function PullClipboard()
    local file_lines = GetClipboardFileLines()
    if file_lines then
        local lines = {}
        for _, line in ipairs(file_lines) do
            if not ShouldIgnoreLine(line) then
                table.insert(lines, line)
            end
        end
        Log("Console contents pulled from %s", DATA_FILE_PATH)
        return table.concat(lines, "\n")
    end
end

Hook(ConsoleScreen, "OnRawKeyHandler", function (orig, screen, key, down, ...)
    if key == KEY_C and down and TheInput:IsKeyDown(KEY_CTRL)
        and not TheInput:IsKeyDown(KEY_ALT) -- In case keyboard layouts that use C
    then
        if TheInput:IsKeyDown(KEY_SHIFT) then
            local content = PullClipboard()
            if content then
                screen.console_edit:SetString(content)
            end
        else
            PushClipboard(screen.console_edit:GetString())
        end
    end
    return orig(screen, key, down, ...)
end)

Hook(ConsoleScreen, "_ctor", function (constructor, screen, ...)
    constructor(screen, ...)
	screen.console_edit.validrawkeys[KEY_C] = true

    -- Initialize file
    if not G.kleifileexists(DATA_FILE_PATH) then
        local f = G.io.open(DATA_FILE_PATH, "w")
        if f then
            Log("Successfully initialized %s", DATA_FILE_PATH)
            f:write(INFO_TEXT)
            f:close()
        else
            Log("Error: failed to open %s", DATA_FILE_PATH)
        end
    end
end)

return {}
