local m = {}

--- Returns the first non‑nil value, or the default if the value is nil.
function m.value_or(value, default)
    return (value ~= nil) and value or default
end

--- Evaluates a value if it's a function, otherwise returns the value unchanged.
function m.eval(value, ...)
    return (type(value) == "function") and value(...) or value
end

--- Returns a list (array) of all keys present in a table.
function m.get_keys(t)
    local res = {}
    for k, _ in pairs(t) do
        table.insert(res, k)
    end
    return res
end

function m.merge(base, overrides, recursive)
    local result = {}
    for k, v in pairs(base or {}) do result[k] = v end
    for k, v in pairs(overrides or {}) do
        if recursive and type(v) == "table" and type(base[k]) == "table" then
            result[k] = m.merge(base[k], v)
        else
            result[k] = v
        end
    end
    return result
end

return m