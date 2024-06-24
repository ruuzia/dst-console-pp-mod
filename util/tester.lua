local G = GLOBAL
local xpcall = G.xpcall
local debug = G.debug

function Log(msg, ...)
    print("[Console++] "..msg:format(...))
end

-- like assert
function Assert(test, message)
    if test then return end
    -- assert failed
    local info = debug.getinfo(2)
    -- G.error("Assert failed at "..info.source..":"..info.currentline)
    G.error("[Console++] Assert failed: "..message, 2)
end

local function Describe(value)
    if type(value) == "string" then
        return ("%q"):format(value)
    else
        return tostring(value)
    end
end
function AssertEq(value, expected)
    if value == expected then return end
    local info = debug.getinfo(2)
    G.error(("Assert failed: expected %s but got %s\nNOTE: failed at %s:%s"):format(Describe(expected), Describe(value), info.source, info.currentline), 3)
end

Tester = {}

Tester.FAIL = "fail"
Tester.CONDITIONS_NOT_MET = "conditions_not_met"
Tester.SUCCESS = "success"

local function Run(fn)
    local ok, result = xpcall(fn, function(err)
        Log("FAIL: %s\n%s", tostring(err), G.debugstack(2))
    end)
    if not ok then return Tester.FAIL end
    return result or Tester.SUCCESS
end

local function _RunTestsForModule(_, module)
    Log("Running tests for module %q", module.name)
    for test_name, fn in pairs(module.tests or {}) do
        local result = Run(fn)
        if result == Tester.SUCCESS then
            Log("Test succeeded: "..test_name)
        elseif result == Tester.FAIL then
            Log("Test failed: "..test_name)
        elseif result == Tester.CONDITIONS_NOT_MET then
            Log("Could not run test: conditions not met")
        else
            Log("ERROR: unknown result type %q", result)
        end
    end
end

local function _RunTests()
    local counts = {
        [Tester.SUCCESS] = 0,
        [Tester.FAIL] = 0,
        [Tester.CONDITIONS_NOT_MET] = 0,
    }
    for _, module in ipairs(GetFeatureModules()) do
        if not module.tests then
            Log("WARNING: no tests for module %q", module.name)
        end
        Log("Running tests for module %q", module.name)
        for test_name, fn in pairs(module.tests or {}) do
            local result = Run(fn)
            counts[result] = counts[result] + 1
            if result == Tester.FAIL then
                Log("Test failed: "..test_name)
            end
        end
    end
    print(counts[Tester.SUCCESS].." tests succeeded.")
    print(counts[Tester.FAIL].." tests failed.")
    print(counts[Tester.CONDITIONS_NOT_MET].." test conditions not met.")
end

function RunTestsForModule(name)
    local module
    for _,m in ipairs(GetFeatureModules()) do
        if m.name == name then
            module = m
            break
        end
    end
    Tester.CloseConsole()
    if not module then
        error("Error: could not find module "..tostring(name), 2)
    end
    G.TheGlobalInstance:DoTaskInTime(0.1, _RunTestsForModule, module)
end

function RunTests()
    -- Add delay
    Tester.CloseConsole()
    G.TheGlobalInstance:DoTaskInTime(0.1, _RunTests)
end

function Tester.OpenConsole()
    Tester.CloseConsole()
    local ConsoleScreen = require "screens/consolescreen"
    TheFrontEnd:PushScreen(ConsoleScreen())
    return TheFrontEnd:GetActiveScreen()
end
function Tester.CloseConsole()
    if Tester.IsConsoleOpen() then
        TheFrontEnd:PopScreen(TheFrontEnd:GetActiveScreen())
    end
end
function Tester.IsConsoleOpen()
    return TheFrontEnd:GetActiveScreen().name == "ConsoleScreen"
end
function Tester.SendTextInput(str)
    TheFrontEnd:OnTextInput(str)
end

function Tester.WithKeysDown(modifiers, fn, ...)
    local temp = State()
    temp:Set(TheInput, "IsKeyDown", function (self, key)
        return table.contains(modifiers, key)
    end)
    fn(...)
    temp:Purge()
end

function Tester.SendKey(key)
    TheFrontEnd:OnRawKey(key, true)
    TheFrontEnd:OnRawKey(key, false)
end

function Tester.PressEnter()
    TheFrontEnd:OnRawKey(KEY_ENTER, true)
    TheFrontEnd:OnControl(G.CONTROL_ACCEPT, true)
    TheFrontEnd:OnRawKey(KEY_ENTER, false)
    TheFrontEnd:OnControl(G.CONTROL_ACCEPT, false)
end
