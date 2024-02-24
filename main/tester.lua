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

-- like assert
function Assert(test, message)
    if test then return end
    -- assert failed
    local info = debug.getinfo(2)
    -- G.error("Assert failed at "..info.source..":"..info.currentline)
    G.error("Assert failed.", 2)
end

function AssertEq(value, expected)
    if value == expected then return end
    G.error("Expected "..tostring(expected).." but got "
        ..tostring(value), 2)
end

function RunTests()
    count_succeeded = 0
    count_failed = 0
    for _,module in ipairs(tests) do
        local succeeded = Run(module)
        if succeeded then
            count_succeeded = count_succeeded + 1
        else
            count_failed = count_failed + 1
        end
    end
    print(count_succeeded.." tests succeeded.")
    print(count_failed.." tests failed.")
end
