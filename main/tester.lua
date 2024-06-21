local G = GLOBAL
local xpcall = G.xpcall
local debug = G.debug

local tests = {
    "test/test_history",
}

local function Run(name)
    print("Running test: "..env.MODROOT..name)
    if string.sub(name, #name-3,#name) ~= ".lua" then
        name = name..".lua"
    end
    local result = G.kleiloadlua(env.MODROOT..name)

    if result == nil then
        print("Error loading test: "..name.." not found!")
        return
    elseif type(result) == "string" then
        print("Error loading test: "..ModInfoname(modname).." importing "..name.."!\n"..result)
        return
    end

    G.setfenv(result, env.env)

    local ok = xpcall(result, function(err)
        print("FAIL", err)
    end)
    if ok then
    else
        print("Test failed: "..name)
    end

    return ok
end

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

function AssertEq(value, expected)
    if value == expected then return end
    G.error("Expected "..tostring(expected).." but got "
        ..tostring(value), 2)
end

Tester = {}

local function _RunTestsForModule(_, module)
    Log("Running tests for module %q", module.name)
    for test_name, fn in pairs(module.tests or {}) do
        local ok = xpcall(fn, function(err)
            Log("FAIL: %s\n%s", tostring(err), debug.traceback(3))
        end)
        if ok then
            Log("Test succeeded: "..test_name)
        else
            Log("Test failed: "..test_name)
        end
    end
end

local function _RunTests()
    local count_succeeded = 0
    local count_failed = 0
    for _, module in ipairs(GetFeatureModules()) do
        if not module.tests then
            Log("WARNING: no tests for module %q", module.name)
        end
        Log("Running tests for module %q", module.name)
        for test_name, fn in pairs(module.tests or {}) do
            local ok = xpcall(fn, function(err)
                Log("FAIL: %s\n%s", tostring(err), debug.traceback(3))
            end)
            if ok then
                count_succeeded = count_succeeded + 1
            else
                Log("Test failed: "..test_name)
                count_failed = count_failed + 1
            end
        end
    end
    print(count_succeeded.." tests succeeded.")
    print(count_failed.." tests failed.")
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
