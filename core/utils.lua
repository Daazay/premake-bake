local utils = {}

function utils.value_or(value, default)
    return (value ~= nil) and value or default
end

function utils.eval(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

function utils.keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

function utils.merge(base, overrides)
    local result = {}
    for k, v in pairs(base) do result[k] = v end
    for k, v in pairs(overrides) do
        if type(v) == "table" and type(base[k]) == "table" then
            result[k] = utils.merge(base[k], v)
        else
            result[k] = v
        end
    end
    return result
end

return utils