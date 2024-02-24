local History = require "history"

local SIZE = 10
local history = History(SIZE)
history:Push('1')
history:Push('2')
history:Push('3')
history:Push('4')
history:Push('5')
history:Push('6')
history:Push('7')
history:Push('8')
history:Push('9')
history:Push('10')

Assert(#history == 10, "expected history to contain 10 items")

history:Push('11')
history:Push('12')
history:Push('13')
history:Push('14')
history:Push('15')
history:Push('16')
history:Push('17')
history:Push('18')
history:Push('19')
history:Push('20')
history:Push('21')

-- Ensure history has been trimmed to size
Assert(#history >= SIZE, "history is too small")
Assert(#history <= SIZE*2, "history is too big")


AssertEq(history[#history], '21')
