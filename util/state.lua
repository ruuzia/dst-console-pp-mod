local G = GLOBAL

State = Class(function (self)
    -- location keys are weak
    -- If the modified table no longer exists, we can freely forget it
    self.locations = setmetatable({}, { __mode = "k" })

    self.requires = {}

end)

---@param loc table
---@param key any index of loc
---@param new_value any|nil
---@return any current value of loc[key]
function State:Set(loc, key, new_value)
    self.locations[loc] = self.locations[loc] or {}
    -- Don't add if already added!
    if not self.locations[loc][key] then
        -- Boxing the value in a table to support nil values
        self.locations[loc][key] = { loc[key] }
    end
    if new_value ~= nil then
        loc[key] = new_value
    end
    return loc[key]
end

function State:Restore(loc, key)
    local item = self.locations[loc]
    if not item or not item[key] then return end          -- Keys (the locations) are weak,
                                         --   Could have been already been GC'd
    loc[key] = item[key][1]              -- Restore the value
    item[key] = nil                      -- Discard the impurity
end

function State:Purge()
    for loc, item in pairs(self.locations) do
        for k, orig in pairs(item) do
            -- Restore
            loc[k] = orig[1]
            -- Log("Restoring %s", k)
        end
    end
    -- Leave behind trash for garbage collector and start anew
    self.locations = {}

    -- Unload packages so next require reloads them
    for _,name in ipairs(self.requires) do
        G.package.loaded[name] = nil
    end
end

function State:Package(name)
    table.insert(self.requires, name)
end

Impurities = State()
