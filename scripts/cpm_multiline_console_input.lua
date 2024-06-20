-- * Multiline console input
--   * Growing and shrinking console with number of lines
--   * Create newline on Shift+Enter
--   * or in an unfinished Lua block
--   * Use up and down error keys to move between lines
setfenv(1, ConsolePP.env)
local G = GLOBAL

local ConsoleScreen = require "screens/consolescreen"

-- UI values
local label_height = 50
local fontsize = 30
local edit_width = 850
local edit_bg_padding = 50
local baseypos = 75

--- Scales the height of the console edit to allow for
--- multiline input.
local function UpdateConsoleSize(screen)
    local _, nlcount = screen.console_edit:GetString():gsub('\n', '')
    screen.label_height = label_height + fontsize * nlcount
	screen.root:SetPosition(screen.root:GetPosition().x, baseypos + (fontsize - 2) * nlcount / 2, 0)
    local wcurr, hcurr = screen.edit_bg:GetSize()
    if wcurr and hcurr and hcurr ~= screen.label_height then
        screen.edit_bg:ScaleToSize( screen.edit_width + edit_bg_padding, screen.label_height )
        screen.console_edit:SetRegionSize( screen.edit_width, screen.label_height )
    end
end

-- Ideally, this is called whenever the console text
-- changes.
local function OnTextUpdate(screen)
    UpdateConsoleSize(screen)
end

local function ShouldAllowNewline(console_edit)
    -- Create newline on Shift+Enter
    -- or in unfinished block
    return TheInput:IsKeyDown(G.KEY_SHIFT)
        or CodeMissingClosingStatement(console_edit:GetString())
        or console_edit.pasting
end

local function BuildFancyConsoleInput(screen)
    screen.edit_bg:SetTexture("images/textbox_long_thinborder.xml", "textbox_long_thinborder.tex" )
	screen.root:SetPosition(0, baseypos, 0)
    screen.label_height = label_height
    screen.edit_width = edit_width
	screen.edit_bg:ScaleToSize(edit_bg_padding + screen.edit_width, label_height )
	screen.edit_bg:SetPosition( 0, 10 )
	screen.console_remote_execute:SetPosition( -screen.edit_width*0.5 -200*0.5 - 35, 0 )
    screen.console_edit:SetRegionSize(screen.edit_width, screen.label_height)
    screen.console_edit:SetVAlign(G.ANCHOR_TOP)
end

-- Screen init post-hook
Hook(ConsoleScreen, "_ctor", function(constructor, self, ...)
    constructor(self, ...)
    BuildFancyConsoleInput(self)

    -- Allow newline (but we add a hook in OnTextInput)
    screen.console_edit:SetAllowNewline(true)

    -- Post hook on console input changes
    local _OnTextInput = self.console_edit.OnTextInput
    self.console_edit.OnTextInput = function(console_edit, text, ...)
        if text == "\n" and not ShouldAllowNewline(console_edit) then
            -- Pass to screen
            console_edit:OnProcess()
            return false
        end
        local ret = _OnTextInput(console_edit, text, ...)
        OnTextUpdate(self)
        return ret
    end
    local _OnSetString = self.console_edit.SetString
    self.console_edit.SetString = function (console_edit, str, ...)
        local ret = { _OnSetString(console_edit, str, ...) }
        OnTextUpdate(self)
        return unpack(ret)
    end

    local _OnRawKey
end)

-- Hijack Enter instead of making the screen close
Hook(ConsoleScreen, "OnTextEntered", function (orig, screen, ...)
    return orig(screen, ...)
end)

return {
}
