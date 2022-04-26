---@class Deque
---@field seq table
---@field left number
---@field right number
local Deque = Class(function(self, sequence)
    self.seq = sequence or {}
    self.left = 1
    self.right = #self.seq
end)

function Deque:Len()
    return math.max(self.right - self.left, 0)
end

function Deque:PushRight(push)
    self.right = self.right + 1
    self.seq[self.right] = push
    return push
end

function Deque:PushLeft(push)
    self.left = self.left - 1
    self.seq[self.left] = push
    return push
end

function Deque:PopRight()
    local pop = self.seq[self.right]
    self.seq[self.right] = nil
    self.right = self.right - 1
    return pop
end

function Deque:PopLeft()
    local pop = self.seq[self.left]
    self.seq[self.left] = nil
    self.left = self.left + 1
    return pop
end

function Deque:IPairs()
    return self.Next, self, 0
end

function Deque:Next(i)
    i = i + 1
    if i > self.right then return nil end
    return i, self.seq[i]
end

return Deque
