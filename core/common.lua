local common = {}

local utils = require("premake-bake.core.utils")

function common.apply_filtered_settings(category_name, settings_table, defaults)
    settings_table = utils.value_or(settings_table, {})
    for name, settings in pairs(settings_table) do
        local merged = utils.merge(defaults and defaults[name] or {}, settings)
        filter(category_name .. ":" .. name)
        if merged.defines      then defines(merged.defines) end
        if merged.buildoptions then buildoptions(merged.buildoptions) end
        if merged.linkoptions  then linkoptions(merged.linkoptions) end
        filter {}
    end
end

function common.merge_category(category_name, provided, defaults)
    local def = defaults and defaults[category_name]
    local prov = provided and provided[category_name]
    if type(def) == "table" then
        if type(prov) == "table" then
            return utils.merge(def, prov)
        else
            return def
        end
    end
    return prov or def
end

return common