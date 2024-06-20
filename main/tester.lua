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

local function _RunTests()
    local count_succeeded = 0
    local count_failed = 0
    for name, module in pairs(GetFeatureModules()) do
        if not module.tests then
            Log("WARNING: no tests for module %q", name)
        end
        Log("Running tests for module %q", name)
        for test_name, fn in pairs(module.tests) do
            local ok = xpcall(fn, function(err)
                Log("FAIL: %s", tostring(err))
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

function RunTests()
    -- Add delay
    G.TheGlobalInstance:DoTaskInTime(0.1, _RunTests)
end

Tester = {
    OpenConsole = function ()
        local ConsoleScreen = require "screens/consolescreen"
        TheFrontEnd:PushScreen(ConsoleScreen())
        return TheFrontEnd:GetActiveScreen()
    end,
    IsConsoleOpen = function ()
        local ConsoleScreen = require "screens/consolescreen"
        return ConsoleScreen.is_instance(TheFrontEnd:GetActiveScreen())
    end,
    SendTextInput = function (str)
        TheFrontEnd:OnTextInput(str)
    end,
}
