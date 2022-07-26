local G = GLOBAL

Config = {}

function Config:SetRemoteToggleKey(key)
    local isctrl, isalt
    if key == "ctrl" then isctrl = true
    elseif key == "alt" then isalt = true
    else
        moderror("Config:SetRemoteToggleKey unknown key: "..key)
    end
    self.REMOTETOGGLEKEYS = {
        [G.KEY_LCTRL] = isctrl,
        [G.KEY_RCTRL] = isctrl,
        [G.KEY_LALT]  = isalt,
        [G.KEY_RALT]  = isalt,
    }
end
function Config:SetTabMode(mode)
    if mode == "default" then
        self.TABINSERT = true
        self.TABCOMPLETE = true
    elseif mode == "spaces" then self.TABINSERT = true
    elseif mode == "complete" then self.TABCOMPLETE = true
    elseif mode == "next" then self.TABNEXT = true
    else
        moderror("Config:SetTabMode unknown mode: "..mode)
    end
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

Config:SetRemoteToggleKey(GetModConfigData("remotetoggle"))
Config:SetTabMode(GetModConfigData("tab"))
Config:SetScrollSpeed(GetModConfigData("scrollspeed"))
Config:SetAutoManageLog(GetModConfigData("autoopencloselog"))
Config:SetWordSet(GetModConfigData("wordset"))

Config.IGNORES = {["Server Unpaused"] = true, ["Server Autopaused"] = true, ["Server Paused"] = false}

