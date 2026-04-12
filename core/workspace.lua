local m = {}

local utils         = require("premake-bake.core.utils")
local paths_builder = require("premake-bake.core.paths_builder")
local common        = require("premake-bake.core.common")
local logger        = require("premake-bake.core.logger")

--- @class WorkspaceConfig : LanguageConfig, CompileOptionsConfig, WarningsConfig
--- @field location?      string|EvaluatePathFn
--- @field configurations ConfigurationConfig[]
--- @field platforms      PlatformConfig[]
--- @field systems?       SystemConfig[]
--- @field toolsets?      ToolsetConfig[]
--- @field paths?         PathsConfig

--- Default configuration values
--- @type WorkspaceConfig
local DEFAULTS = {
    configurations = {
        debug   = { symbols = "on",  optimize = "off",  runtime = "debug" },
        release = { symbols = "off", optimize = "full", runtime = "release" },
    },
    platforms = {
        x86_64 = { architecture = "x86_64" }
    },
    systems            = {},
    toolsets           = {},
    language           = "c++",
    cdialect           = "c23",
    cppdialect         = "c++23",
    warnings_level     = "default",
    warnings_as_errors = false,
}

--- @param core     table
--- @param ws_name  string           Workspace name
--- @param config   WorkspaceConfig? User configuration
function m.setup(core, ws_name, config)
    config = config or {}

    core._workspaces = core._workspaces or {}
    assert(not core._workspaces[ws_name], string.format("Workspace with same name is already defined: %s", ws_name))

    logger.verbosef("Setting up workspace: %s", ws_name)
    logger.indent_push()
    local paths       = paths_builder.get_paths(config.paths or {})
    local ws_location = utils.value_or(utils.eval(config.location), paths:get_root_dir())
    logger.verbosef("Setting location: %s", ws_location)

    -- Create the workspace.
    workspace(ws_name)
    location(ws_location)

    -- Apply configurations
    local ws_configs      = utils.value_or(config.configurations, DEFAULTS.configurations)
    local ws_config_names = utils.get_keys(ws_configs)
    assert(#ws_config_names > 0, "At least one configuration is required")
    configurations(ws_config_names)

    logger.verbosef("Adding configurations: [%s]", table.concat(ws_config_names, ", "))

    -- Apply platforms
    local ws_platforms      = utils.value_or(config.platforms, DEFAULTS.platforms)
    local ws_platform_names = utils.get_keys(ws_platforms)
    assert(#ws_platform_names > 0, "At least one platform is required")
    platforms(ws_platform_names)

    logger.verbosef("Adding platforms: [%s]", table.concat(ws_platform_names, ", "))

    -- Adding targetdir, objectdir
    local ws_targetdir = path.join(paths:get_bin_pattern(), "%{prj.name}")
    local ws_objdir = path.join(paths:get_obj_pattern(), "%{prj.name}")
    targetdir(ws_targetdir)
    objdir(ws_objdir)
    logger.verbosef("Setting targetdir: %s", ws_targetdir:gsub("%%", "%%%%"))
    logger.verbosef("Setting objdir: %s", ws_objdir:gsub("%%", "%%%%"))

    -- Apply top‑level language and warning.
    common.apply_language(config)
    common.apply_warnings(config)

    -- Apply configurations.
    common.apply_named_configs("configurations:",
        config.configurations, DEFAULTS.configurations,
        common.apply_configuration
    )

    -- Platforms
    common.apply_named_configs("platforms:",
        config.platforms, DEFAULTS.platforms,
        common.apply_platform
    )

    -- Systems
    common.apply_named_configs("system:",
        config.systems, DEFAULTS.systems,
        common.apply_system
    )

    -- Toolsets
    common.apply_named_configs("toolset:",
        config.toolsets, DEFAULTS.toolsets,
        common.apply_toolset
    )

    core._workspaces[ws_name] = {
        name     = ws_name,
        config   = config,
        location = ws_location,
        paths    = paths,
        projects = {
            registry = {},
            stack    = {}
        }
    }

    core._workspace = core._workspaces[ws_name]
    logger.indent_pop()
end

return m