local ws = {}

local utils         = require("premake-bake.core.utils")
local paths_factory = require("premake-bake.core.paths_factory")
local common        = require("premake-bake.core.common")

local DEFAULTS = {
    configurations = {
        debug   = { symbols  = "on",  optimize = "off",  runtime  = "debug" },
        release = { symbols  = "off", optimize = "full", runtime  = "release" }
    },
    platforms = {
        x86_64 = { architecture = "x86_64" }
    },
    toolsets = {
        ["msc*"] = { },
        clang    = { },
        gcc      = { }
    },
    language   = "C++",
    cppdialect = "C++23",
    cdialect   = "C23",
    warnings   = "Extra",
    werror     = true,

    defines      = {},
    buildoptions = {},
    linkoptions  = {},
}

function ws.setup(main, name, config)
    config = config or {}

    main._workspaces = main._workspaces or {}
    assert(not main._workspaces[name], "workspace with same name already defined")

    local paths = paths_factory.get_path(config.paths or {})
    local ws_location = utils.value_or(utils.eval(config.location), paths:get_root_dir())

    workspace(name)
    location(ws_location)

    verbosef("Workspace: '%s'", name)
    verbosef("  location: %s", ws_location)

    -- Configurations
    local ws_configs = utils.value_or(config.configurations, DEFAULTS.configurations)
    local config_names = utils.keys(ws_configs)
    assert(#config_names > 0, "At least one configuration is required")
    configurations(config_names)

    verbosef("  configurations: [%s]", table.concat(config_names, ", "))

    -- Platforms
    local ws_platforms = utils.value_or(config.platforms, DEFAULTS.platforms)
    local platform_names = utils.keys(ws_platforms)
    assert(#platform_names > 0, "At least one platform is required")
    platforms(platform_names)
    defaultplatform(platform_names[1])

    verbosef("  platforms: [%s]", table.concat(platform_names, ", "))
    verbosef("  default_platform: '%s'", platform_names[1])

    -- Language & dialects
    local global_lang = utils.value_or(config.language, DEFAULTS.language)
    local global_cppdialect = utils.value_or(config.cppdialect, DEFAULTS.cppdialect)
    local global_cdialect = utils.value_or(config.cdialect, DEFAULTS.cdialect)
    language(global_lang)
    cppdialect(global_cppdialect)
    cdialect(global_cdialect)

    verbosef("  language: %s", global_lang)
    verbosef("  cdialect: %s", global_cdialect)
    verbosef("  cppdialect: %s", global_cppdialect)

    -- Warnings
    local global_warn_level = utils.value_or(utils.eval(config.warning_level), DEFAULTS.warnings)
    local global_warn_error = utils.value_or(utils.eval(config.warnings_as_errors), DEFAULTS.werror)
    warnings(global_warn_level)
    if global_warn_error then
        fatalwarnings { "all" }
    end

    verbosef("  warnings: %s", global_warn_level)
    verbosef("  warnings_as_errors: %s", global_warn_error and "yes" or "no")

    -- Output directories
    local global_target_dir = path.join(paths:get_bin_pattern(), "%{prj.name}")
    local global_obj_dir = path.join(paths:get_obj_pattern(), "%{prj.name}")
    targetdir(global_target_dir)
    objdir(global_obj_dir)

    verbosef("  targetdir: %s", global_target_dir)
    verbosef("  objdir: %s", global_obj_dir)

    -- Global defines/options
    local global_defines = utils.value_or(utils.eval(config.defines), DEFAULTS.defines)
    local global_build = utils.value_or(utils.eval(config.buildoptions), DEFAULTS.buildoptions)
    local global_link = utils.value_or(utils.eval(config.linkoptions), DEFAULTS.linkoptions)
    defines(global_defines)
    buildoptions(global_build)
    linkoptions(global_link)

    verbosef("  defines: [%s]", table.concat(global_defines, ", "))
    verbosef("  buildoptions: [%s]", table.concat(global_build, ", "))
    verbosef("  linkoptions: [%s]", table.concat(global_link, ", "))

    -- Apply per-configuration settings
    verbosef("  configuration_settings:")

    for _, cfg_name in ipairs(config_names) do
        local settings = common.merge_category(cfg_name, ws_configs, DEFAULTS.configurations)
        if settings then
            filter("configurations:" .. cfg_name)

            if settings.symbols      then symbols(settings.symbols) end
            if settings.optimize     then optimize(settings.optimize) end
            if settings.runtime      then runtime(settings.runtime) end
            if settings.defines      then defines(settings.defines) end
            if settings.buildoptions then buildoptions(settings.buildoptions) end
            if settings.linkoptions  then linkoptions(settings.linkoptions) end

            verbosef("    configuration: '%s'", cfg_name)
            verbosef("      symbols: %s", settings.symbols)
            verbosef("      optimize: %s", settings.optimize)
            verbosef("      runtime: %s", settings.runtime)
            verbosef("      defines: [%s]", table.concat(settings.defines or {}, ", "))
            verbosef("      buildoptions: [%s]", table.concat(settings.buildoptions or {}, ", "))
            verbosef("      linkoptions: [%s]", table.concat(settings.linkoptions or {}, ", "))

            filter({})
        end
    end

    -- Apply per-platform settings
    verbosef("  platform_settings:")

    for _, plat_name in ipairs(platform_names) do
        local settings = common.merge_category(plat_name, ws_platforms, DEFAULTS.platforms)
        if settings then
            filter("platforms:" .. plat_name)

            if settings.architecture  then architecture(settings.architecture) end
            if settings.defines       then defines(settings.defines) end
            if settings.buildoptions  then buildoptions(settings.buildoptions) end
            if settings.linkoptions   then linkoptions(settings.linkoptions) end

            verbosef("    platforms: '%s'", plat_name)
            verbosef("      architecture: %s", settings.architecture)
            verbosef("      defines: [%s]", table.concat(settings.defines or {}, ", "))
            verbosef("      buildoptions: [%s]", table.concat(settings.buildoptions or {}, ", "))
            verbosef("      linkoptions: [%s]", table.concat(settings.linkoptions or {}, ", "))

            filter({})
        end
    end

    -- Apply per-toolset settings
    verbosef("  toolset_settings:")

    local ws_toolsets = utils.value_or(config.toolsets, DEFAULTS.toolsets)
    local toolset_names = utils.keys(ws_toolsets)

    for _, tool_name in ipairs(toolset_names) do
        local settings = common.merge_category(tool_name, ws_toolsets, DEFAULTS.toolsets)
        if settings then
            filter("toolset:" .. tool_name)

            if settings.defines       then defines(settings.defines) end
            if settings.buildoptions  then buildoptions(settings.buildoptions) end
            if settings.linkoptions   then linkoptions(settings.linkoptions) end

            verbosef("    toolset: '%s'", tool_name)
            verbosef("      defines: [%s]", table.concat(settings.defines or {}, ", "))
            verbosef("      buildoptions: [%s]", table.concat(settings.buildoptions or {}, ", "))
            verbosef("      linkoptions: [%s]", table.concat(settings.linkoptions or {}, ", "))

            filter({})
        end
    end

    main._workspace = {
        name     = name,
        config   = config,
        location = ws_location,
        paths    = paths,
        projects = { registry = {}, stack = {} }
    }
    main._workspaces[name] = main._workspace

    verbosef("Workspace setup complete.")
end

return ws