local m = {}

local utils  = require("premake-bake.core.utils")
local logger = require("premake-bake.core.logger")

--- @class CompileOptionsConfig
--- @field defines?      string[]
--- @field buildoptions? string[]
--- @field linkoptions?  string[]

--- @class WarningsConfig
--- @field warnings_level?     string
--- @field warnings_as_errors? boolean

--- @class WarningsConfigEx : WarningsConfig
--- @field enablewarnings?  string[]
--- @field disablewarnings? string[]

--- @class ConfigurationConfig : CompileOptionsConfig, WarningsConfig
--- @field runtime?  string
--- @field symbols?  string
--- @field optimize? string

--- @class PlatformConfig : CompileOptionsConfig
--- @field arch string

--- @class SystemConfig : CompileOptionsConfig

--- @class ToolsetConfig : CompileOptionsConfig, WarningsConfigEx

--- @class LanguageConfig
--- @field language?   string
--- @field cdialect?   string
--- @field cppdialect? string

function m.apply_compile_options(config)
    if not config then return end
    if config.defines and #config.defines > 0 then
        defines(config.defines)
        logger.verbosef("Adding defines: [%s]", table.concat(config.defines, ','))
    end
    if config.buildoptions and #config.buildoptions > 0 then
        buildoptions(config.buildoptions)
        logger.verbosef("Adding buildoptions: [%s]", table.concat(config.buildoptions, ','))
    end
    if config.linkoptions and #config.linkoptions > 0 then
        linkoptions(config.linkoptions)
        logger.verbosef("Adding linkoptions: [%s]", table.concat(config.linkoptions, ','))
    end
end

function m.apply_warnings(config)
    if not config then return end
    if config.warnings_level then
        warnings(config.warnings_level)
        logger.verbosef("Setting warning level: %s", config.warnings_level)
    end
    if config.warnings_as_errors == true then
        fatalwarnings({ "all" })
        logger.verbosef("Treating warnings as errors")
    end
end

function m.apply_warnings_ex(config)
    if not config then return end
    m.apply_warnings(config)
    if config.enablewarnings and #config.enablewarnings > 0 then
        enablewarnings(config.enablewarnings)
        logger.verbosef("Enabling warnings: [%s]", table.concat(config.enablewarnings, ','))
    end
    if config.disablewarnings and #config.disablewarnings > 0 then
        disablewarnings(config.disablewarnings)
        logger.verbosef("Disabling warnings: [%s]", table.concat(config.disablewarnings, ','))
    end
end

function m.apply_configuration(config)
    if not config then return end
    m.apply_compile_options(config)
    m.apply_warnings(config)
    if config.runtime then
        runtime(config.runtime)
        logger.verbosef("Setting runtime: %s", config.runtime)
    end
    if config.symbols then
        symbols(config.symbols)
        logger.verbosef("Setting symbols: %s", config.symbols)
    end
    if config.optimize then
        optimize(config.optimize)
        logger.verbosef("Setting optimize: %s", config.optimize)
    end
end

function m.apply_platform(config)
    if not config then return end
    if config.arch then
        architecture(config.arch)
        logger.verbosef("Setting architecture: %s", config.arch)
    end
    m.apply_compile_options(config)
end

function m.apply_system(config)
    if not config then return end
    m.apply_compile_options(config)
end

function m.apply_toolset(config)
    if not config then return end
    m.apply_compile_options(config)
    m.apply_warnings_ex(config)
end

function m.apply_language(config)
    if not config then return end
    if config.language then
        language(config.language)
        logger.verbosef("Setting language: %s", config.language)
    end
    if config.cdialect then
        cdialect(config.cdialect)
        logger.verbosef("Setting cdialect: %s", config.cdialect)
    end
    if config.cppdialect then
        cppdialect(config.cppdialect)
        logger.verbosef("Setting cppdialect: %s", config.cppdialect)
    end
end

function m.apply_named_configs(filter_pattern, user_configs, default_configs, apply_fn)
    user_configs    = user_configs or {}
    default_configs = default_configs or {}

    local names = utils.get_keys(user_configs)
    if #names == 0 then
        names = utils.get_keys(default_configs)
    end
    for _, name in ipairs(names) do
        local user_cfg    = user_configs[name]
        local default_cfg = default_configs[name]
        local merged      = default_cfg and utils.merge(default_cfg, user_cfg) or user_cfg

        logger.verbosef("Applying filter: %s", filter_pattern .. name)
        filter(filter_pattern .. name)
        logger.indent_push()
        apply_fn(merged)
        logger.indent_pop()
        logger.verbosef("Resettting filter")
        filter("")
    end
end

return m