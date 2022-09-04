local G = GLOBAL

Config = {}

function Config:SetRemoteToggleKey(key)
    local isctrl, isalt
    if key == "ctrl" then isctrl = true
    elseif key == "alt" then isalt = true
    else moderror("Config:SetRemoteToggleKey unknown key: "..key)
    end
    self.REMOTETOGGLEKEYS = {
        [G.KEY_LCTRL] = isctrl,
        [G.KEY_RCTRL] = isctrl,
        [G.KEY_LALT]  = isalt,
        [G.KEY_RALT]  = isalt,
    }
end
function Config:SetTabSpaces(numSpaces)
    self.TABSPACES = numSpaces
    self.TABINSERT = numSpaces > 0
end
function Config:SetTabMode(mode)
    self.TABCOMPLETE = mode == "complete"
    self.TABNEXT = mode == "next"
    modassert(self.TABCOMPLETE or self.TABNEXT, "Config:SetTabMode unknown mode: "..mode)
end
function Config:SetScrollSpeed(numlines)
    self.SCROLLSPEED = numlines
end
function Config:SetAutoManageLog(flag)
    self.CLOSELOGONRUN = flag
    self.OPENLOGWITHCONSOLE = flag
end
function Config:SetWordSet(regexset)
    self.WORDSET = regexset
end
function Config:SetKeepOpenWithoutCtrl(keep_open)
    self.KEEPCONSOLEOPEN = keep_open
end
function Config:SetCaseSensitive(iscasesensitive)
    self.CASESENSITIVE = iscasesensitive
end
function Config:SetConsoleLogTheme(theme)
    if theme == "default" then
        Config.SHARD_LOG_COLOURS = {
            Master = G.PLAYERCOLOURS.TEAL,
            Caves = G.PLAYERCOLOURS.ORANGE,
        }
    elseif theme == "alternative" then
        Config.SHARD_LOG_COLOURS = {
            Master = {0.50, 0.2, 0.40, 1.0},
            Caves = G.PLAYERCOLOURS.DARKPLUM,
        }
    end
end

function Config:Update()
    Config:SetKeepOpenWithoutCtrl (GetModConfigData "keepopen")
    Config:SetRemoteToggleKey     (GetModConfigData "remotetoggle")
    Config:SetTabSpaces           (GetModConfigData "tabwidth")
    Config:SetTabMode             (GetModConfigData "tab")
    Config:SetScrollSpeed         (GetModConfigData "scrollspeed")
    Config:SetAutoManageLog       (GetModConfigData "autoopencloselog")
    Config:SetWordSet             (GetModConfigData "wordset")
    Config:SetCaseSensitive       (GetModConfigData "casesensitive")
    Config:SetConsoleLogTheme     (GetModConfigData "logtheme")

    Config.IGNORES = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}
end

Config:Update()

