-- * Multiline console input
--   * Growing and shrinking console with number of lines
--   * Create newline on Shift+Enter
--   * or in an unfinished Lua block
--   * Use up and down error keys to move between lines
setfenv(1, ConsolePP.env)
local G = GLOBAL

local ConsoleScreen = require "screens/consolescreen"
local NineSlice = require "widgets/nineslice"
local Widget = require "widgets/widget"

-- UI values
local label_height = 50
local fontsize = 30
local edit_width = 850
local edit_bg_padding = -10
local baseypos = 60
local BACKGROUND_COLOUR = { 142/255, 123/255, 90/255, 0.85 }
-- local BACKGROUND_COLOUR = { 0.2, 0.2, 0.2, 0.85 }
local DECORATION_COLOUR = { 0.1, 0.1, 0.1, 0.95 }

local function IsNewLine(c) return c == "\n" or c == "\r" end

--- Scales the height of the console edit to allow for
--- multiline input.
local function UpdateConsoleSize(screen)
    local _, nlcount = screen.console_edit:GetString():gsub('\n', '')
    screen.label_height = label_height + fontsize * nlcount
	screen._CPM_textbox:SetPosition(0, fontsize * nlcount / 2, 0)
    local wcurr, hcurr = screen.edit_bg:GetSize()
    if wcurr and hcurr and hcurr ~= screen.label_height then
        screen.edit_bg:SetSize( screen.edit_width + edit_bg_padding, screen.label_height )
        screen.console_edit:SetRegionSize( screen.edit_width, screen.label_height )

        local sx, sy = screen.console_edit:GetRegionSize()
        if screen.console_edit.prediction_widget then
            screen.console_edit.prediction_widget:SetPosition(-sx*0.5, sy*0.5)
        end

    end
end

-- Ideally, this is called whenever the console text changes
local function OnTextUpdate(screen)
    UpdateConsoleSize(screen)
end

local function ShouldAllowNewline(console_edit)
    -- Create newline on Shift+Enter
    -- or in unfinished block
    
    return TheInput:IsKeyDown(G.KEY_SHIFT)
        or Lua.CodeMissingClosingStatement(console_edit:GetString())
            and not TheInput:IsKeyDown(G.KEY_CTRL)
        or console_edit.pasting
end

local function ShouldForceNewline(console_edit)
    return TheInput:IsKeyDown(G.KEY_SHIFT)
        or console_edit.pasting
end

local function BuildFancyConsoleInput(screen)
	screen.root:SetPosition(0, baseypos, 0)
    local textbox = screen.root:AddChild(Widget(""))

    screen._CPM_textbox = textbox
    screen.label_height = label_height
    screen.edit_width = edit_width

    if screen.edit_bg then screen.edit_bg:Kill() end
    screen.edit_bg = textbox:AddChild(NineSlice("images/dialogrect_9slice.xml"))
    screen.edit_bg:SetSize(edit_bg_padding + screen.edit_width, label_height)
    screen.edit_bg:SetScale(0.4, 0.4)
	screen.edit_bg:SetPosition( 0, 10 )

    screen.edit_bg:SetTint(unpack(DECORATION_COLOUR))
    screen.edit_bg.mid_center:SetTint(unpack(BACKGROUND_COLOUR))
    screen.edit_bg.elements[4]:SetTint(unpack(BACKGROUND_COLOUR))
    screen.edit_bg.elements[5]:SetTint(unpack(BACKGROUND_COLOUR))

	screen.console_remote_execute:SetPosition( -screen.edit_width*0.5 -200*0.5 - 35, 0 )

    screen.root:RemoveChild(screen.console_edit)
    textbox:AddChild(screen.console_edit)
    screen.console_edit:SetRegionSize(screen.edit_width, screen.label_height)
    screen.console_edit:SetVAlign(G.ANCHOR_TOP)
    screen.console_edit:MoveToFront()
end



-- Screen init post-hook
Hook(ConsoleScreen, "_ctor", function(constructor, screen, ...)
    constructor(screen, ...)
    BuildFancyConsoleInput(screen)

    -- Allow newline (but we add a hook in OnTextInput)
    screen.console_edit:SetAllowNewline(true)

    -- Post hook on console input changes
    local _OnTextInput = screen.console_edit.OnTextInput
    screen.console_edit.OnTextInput = function(console_edit, char, ...)
        if IsNewLine(char) and not ShouldAllowNewline(console_edit) then
	    if DEBUG then print("OnTextInput", G.json.encode(char), "executing command") end
            -- Executing the command... but actually
            -- we have to wait for OnControl and up
            -- otherwise, upon closing the console, it will also register
            -- a click for whatever happens to be beneath the mouse
            -- console_edit:OnProcess()
	    
	    -- Just want to ensure the flag does not somehow get stuck on true
            console_edit._CPM_inserting_newline = false
            return false
        elseif IsNewLine(char) then
	    if DEBUG then print("OnTextInput", G.json.encode(char), "inserting newline") end
            -- Inserting newline
            -- Must make sure that the CONTROL_ACCEPT up trigger doesn't
            -- try and now complete word predictions with the changed text
            console_edit._CPM_inserting_newline = true

            -- The text engine seems to have a weird bug with inserting a newline
            -- when the current line is empty. This has bothered me enough I'm 
            -- going to have it put it in a space to make it work in these cases.
            local pos = console_edit.inst.TextEditWidget:GetEditCursorPos()
            if pos == 0 then
                console_edit.inst.TextEditWidget:OnTextInput(' ')
            end
        end
        local ret = _OnTextInput(console_edit, char, ...)
        OnTextUpdate(screen)
        return ret
    end
    local _OnSetString = screen.console_edit.SetString
    screen.console_edit.SetString = function (console_edit, str, ...)
        local ret = { _OnSetString(console_edit, str, ...) }
        OnTextUpdate(screen)
        return unpack(ret)
    end

    local _OnControl = screen.console_edit.OnControl
    screen.console_edit.OnControl = function (console_edit, control, down, ...)
	if control ~= G.CONTROL_ACCEPT or down then
	    -- not interested
	    return _OnControl(console_edit, control, down, ...)
	end
	if DEBUG then print("OnControl accept down", console_edit._CPM_inserting_newline) end

        if console_edit._CPM_inserting_newline then
            console_edit._CPM_inserting_newline = false
            -- Don't want to complete any word predictions after inserting a newline
	    return true
        end

	if TheInput:IsKeyDown(KEY_CTRL) then
	    -- Force run
	    console_edit:OnProcess()
	    return true
	end

        -- Now check if anyone else (prediction widget) needs to do something with the accept
        if _OnControl(console_edit, control, down, ...) then
	    if DEBUG then print("Control accept consumed by other") end
            return true
        end

        -- Finally, run the console command
        console_edit:OnProcess()
        return true
    end

    Hook(screen.console_edit, "OnRawKey", function (orig, console_edit, key, down, ...)
        -- Keep prediction_widget from claiming that Shift+Enter!
        if key == KEY_ENTER and down and ShouldForceNewline(console_edit) then
            console_edit:OnTextInput("\n")
            return true
        end

        local ret = orig(console_edit, key, down, ...)
        -- Make backspace on line update immediately
        UpdateConsoleSize(screen)
        return ret
    end)
end)

return {
    tests = {
        ["Test allows multiple lines"] = function ()
            local screen = Tester.OpenConsole()
            Tester.SendTextInput("-- A line")
            Tester.WithKeysDown({ KEY_SHIFT }, Tester.PressEnter)
            -- Tester.SendTextInput("if true")
            -- AssertEq(screen.console_edit:GetString(), "-- A line\nif true")
            -- Tester.SendKey(KEY_ENTER)
            -- AssertEq(screen.console_edit:GetString(), "-- A line\nif true\n")
        end,
        ["shift+enter newline takes precedence"] = function ()
            local temp = State()
            temp:Set(Config, "ENTERCOMPLETE", true)
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("ConsoleP")
                -- Even though there is a word completion available, ignore it!
                Tester.WithKeysDown({ KEY_SHIFT }, Tester.PressEnter)
                AssertEq(screen.console_edit:GetString(), "ConsoleP\n")
            end
            temp:Purge()
        end,
        ["test new line in middle of word"] = function ()
            local temp = State()
            temp:Set(Config, "ENTERCOMPLETE", true)
            do
                local screen = Tester.OpenConsole()
                Tester.SendTextInput("do abc_")
                Tester.SendKey(KEY_LEFT)
                Tester.SendKey(KEY_LEFT)
                Tester.PressEnter()
                AssertEq(screen.console_edit:GetString(), "do ab\nc_")
                AssertEq(screen.console_edit.inst.TextEditWidget:GetEditCursorPos(), 6)
            end
            temp:Purge()
        end,
    }
}
