local G = GLOBAL

---@param loc table
---@param idx string
---@param wrapper fun(old: function, ...): any
function Hook(loc, idx, wrapper)
    local orig = modassert(loc[idx], "no decorator function")
    assert(type(orig) == "function")
    Impurities:Set(loc, idx)
    loc[idx] = function(...)
        return wrapper(orig, ...)
    end
end

function Require(modname)
    -- Force reload
    Impurities:Package(modname)
    return require(modname)
end

local nextUpvalue = function (fn, i)
    i = i + 1
    local name, value = debug.getupvalue(fn, i)
    if name then
        return i, name, value
    end
end
function Upvalues(fn)
    return nextUpvalue, fn, 0
end

function RecursiveUpvalueHijack(fn, upvalue_name, new_value)
    for i, name, value in Upvalues(fn) do
        if name == upvalue_name then
            debug.setupvalue(fn, i, new_value)
        elseif type(value) == "function" then
            RecursiveUpvalueHijack(value, upvalue_name, new_value)
        end
    end
end

function printf(fmt, ...)
    print(string.format(fmt, ...))
end

---@param t table
---@param name string
---@param expected string
function AssertDefinitionSource(t, name, expected)
    local info = debug.getinfo(t[name], "S")
    if info.source == expected or --[[ support reload ]] info.source:sub(1, #MODROOT) == MODROOT then return end
    printf("[%s] ======== WARNING ===============", modname)
    printf("[%s] %q definition expected in file %q, but found in %q. Running with an incompatible mod?", modname, name, expected, info.source)
    printf("[%s] ================================", modname)
end

local MIN_NO_RECURSE = 100
function PrettyPrint(v)
    if type(v) == "table" then
        -- If it has a tostring method, call it
        if GetMetaField(v, '__tostring') then
            print(v)
        else
            -- table.inspect can really struggle with big tables (at least with PUC-Lua)
            local tbl = v
            local count = 0
            for _ in pairs(tbl) do
                count = count + 1
                if count >= MIN_NO_RECURSE then break end
            end
            print(table.inspect(tbl, count < MIN_NO_RECURSE and 2 or 1))
        end
    else
        print(v)
    end
end

function GetMetaField(t, k)
    local mt = getmetatable(t)
    return mt and mt[k]
end

CallableTable = function (fn)
    local wrapper = { __call = function (_, ...) return fn(...) end }
    Impurities:Set(wrapper, "__call", fn)
    return setmetatable(wrapper, wrapper)
end

-- Alternate disableable and hook function that would work with other mods
-- hooking add their own hook
function Hook2(loc, idx, wrapper)
    local orig = modassert(loc[idx], "no decorator function")
    loc[idx] = CallableTable(orig)
    -- Override call method in metatable
    Impurities:Set(loc[idx], "__call", function(_, ...)
        return wrapper(orig, ...)
    end)
end
