local floor = math.floor

local History = Class(function (self, max)
    self.size = max
    -- when history reaches size + size_buffer, it is trimmed to size
    self.lee = floor(max * 1.5)
end)

function History:TrimToSize()
    local excess = #self - self.size
    for i = 1, self.size do
        self[i] = self[i + excess]
    end
    for i = self.size+1, #self do
        self[i] = nil
    end
end

function History:Push(v)
    if #self >= self.lee then
        self:TrimToSize()
    end
    self[#self + 1] = v
end

function History:Erase()
    for i = 1, #self do self[i] = nil end
end

return History
