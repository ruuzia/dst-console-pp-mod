-- History for scrollable console log(s).
-- We could have also implemented this as a proper queue, which may have
-- been a cleaner implementation, but this is fine too.

local LEEWAY_MULT = 1.5

local History = Class(function (self, max)
    self.size = max
end)

function History:TrimToSize()
    local excess = #self - self.size
    -- Move elements down by excess
    for i = 1, self.size do
        self[i] = self[i + excess]
    end
    -- Clean up excess
    for i = self.size+1, #self do
        self[i] = nil
    end
end

function History:Push(v)
    -- when history reaches 1.5x size, it is trimmed to size
    -- this is much more performant than table.removing elements from the bottom on each insert
    if #self >= self.size * LEEWAY_MULT then
        self:TrimToSize()
    end
    self[#self + 1] = v
end

function History:Erase()
    for i = 1, #self do self[i] = nil end
end

return History
