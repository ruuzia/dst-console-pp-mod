local G = GLOBAL
local ConsoleScreen = require "screens/consolescreen"
local KnownModIndex = G.KnownModIndex
local ModManager = G.ModManager
local setmetatable = G.setmetatable

Impurities = {}

-- location keys are weak
-- If the modified table no longer exists, we can freely forget it
Impurities.items = setmetatable({}, { __mode = "k" })

Impurities.requires = {}

---@param loc table
---@param key any index of loc
---@param new_value any|nil
---@return any current value of loc[key]
function Impurities:New(loc, key, new_value)
    self.items[loc] = self.items[loc] or {}
    -- Don't add if already added!
    if not self.items[loc][key] then
        -- Boxing the value in a table to support nil values
        self.items[loc][key] = { loc[key] }
    end
    if new_value ~= nil then
        loc[key] = new_value
    end
    return loc[key]
end

function Impurities:Restore(loc, key)
    local item = self.items[loc]
    if not item or not item[key] then return end          -- Keys (the locations) are weak,
                                         --   Could have been already been GC'd
    loc[key] = item[key][1]              -- Restore the value
    item[key] = nil                      -- Discard the impurity
end

function Impurities:Purge()
    for loc, item in pairs(self.items) do
        for k, orig in pairs(item) do
            -- Restore
            loc[k] = orig[1]
        end
    end
    -- Leave behind trash for garbage collector and start anew
    self.items = {}

    -- Unload packages so next require reloads them
    for _,name in ipairs(self.requires) do
        G.package.loaded[name] = nil
    end
end

function Impurities:Package(name)
    table.insert(self.requires, name)
end

