local prj = {}

local utils  = require("premake-bake.core.utils")
local common = require("premake-bake.core.common")
local logger = require("premake-bake.core.logger")

--- @class ProjectConfig : LanguageConfig, CompileOptionsConfig, WarningsConfig
--- @field location?        string|EvaluatePathFn
--- @field kind             string
--- @field group?           string
--- @field srcs?            string[]
--- @field hdrs?            string[]
--- @field includes?        string[]
--- @field configurations?  ConfigurationConfig[]
--- @field platforms?       PlatformConfig[]
--- @field systems?         SystemConfig[]
--- @field toolsets?        ToolsetConfig[]
--- @field dependencies?    string[]

--- Default configuration values
--- @type ProjectConfig
local DEFAULTS = {
    kind = "staticlib",
}

--- @return string, string, boolean # prj_name, prj_base_name, is_third_party
local function parse_project_name(raw_prj_name)
    local is_third_party = raw_prj_name:match("^third_party:") and true or false
    local prj_base_name = is_third_party and raw_prj_name:sub(13) or raw_prj_name
    local prj_name      = is_third_party and ("third_party."..prj_base_name) or raw_prj_name
    return prj_name, prj_base_name, is_third_party
end

--- Declares a project inside the current workspace.
--- @param core         table          -- Core
--- @param raw_prj_name string         -- Project name
--- @param config       ProjectConfig? -- User configuration
function prj.declare(core, raw_prj_name, config)
    config = config or {}
    assert(core._workspace, "Workspace must be defined first.")

    local prj_name, prj_base_name, is_third_party = parse_project_name(raw_prj_name)

    -- Initialise project registry if needed
    core._workspace.projects = core._workspace.projects or {}
    core._workspace.projects.registry = core._workspace.projects.registry or {}
    -- Check for duplicate project names
    assert(not core._workspace.projects.registry[raw_prj_name], "Project with same name is already defined: " .. raw_prj_name)

    logger.verbosef("Setting up project: %s", raw_prj_name)
    logger.indent_push()

    -- Resolve project location
    local paths = core._workspace.paths
    local prj_location = utils.value_or(
        utils.eval(config.location),
        paths:get_project_dir(prj_base_name, is_third_party)
    )
    logger.verbosef("Setting location: %s", prj_location)

    -- Create the project
    project(prj_name)
    location(prj_location)

    -- Apply kind and group
    local prj_kind = utils.value_or(config.kind, DEFAULTS.kind)
    kind(prj_kind)
    logger.verbosef("Setting kind: %s", prj_kind)

    if config.group then
        project().group = config.group
        logger.verbosef("Setting group: %s", config.group)
    end

    local function resolve_files_paths(key)
        local category_files = utils.value_or(config[key], DEFAULTS[key])
        local result = {}
        for _, pat in ipairs(category_files) do
            local full = path.isabsolute(pat) and pat or path.join(prj_location, pat)
            table.insert(result, full)
        end
        return result
    end

    -- Adding source files
    local prj_srcs = resolve_files_paths("srcs")
    if #prj_srcs > 0 then
        files(prj_srcs)
        logger.verbosef("Adding source files:")
        logger.indent_push()
        logger.verbosef(table.concat(prj_srcs,"\n" .. logger.get_indent()))
        logger.indent_pop()
    end

    -- Adding header files
    local prj_hdrs = resolve_files_paths("hdrs")
    if #prj_hdrs > 0 then
        files(prj_hdrs)
        logger.verbosef("Adding header files:")
        logger.indent_push()
        logger.verbosef(table.concat(prj_hdrs,"\n" .. logger.get_indent()))
        logger.indent_pop()
    end

    -- Adding include directories
    local prj_includes = resolve_files_paths("includes")
    local dep_includes = prj_includes
    if #prj_includes > 0 then
        includedirs(prj_includes)
        logger.verbosef("Adding includes:")
        logger.indent_push()
        logger.verbosef(table.concat(prj_includes,"\n" .. logger.get_indent()))
        logger.indent_pop()
    end

    -- Apply language, warnings, compile options
    common.apply_language(config)
    common.apply_warnings(config)
    common.apply_compile_options(config)

    common.apply_named_configs("configurations:",
        config.configurations, DEFAULTS.configurations,
        common.apply_configuration
    )

    -- Per‑platform settings
    common.apply_named_configs("platforms:",
        config.platforms, DEFAULTS.platforms,
        common.apply_platform
    )

    -- Per‑system settings
    common.apply_named_configs("system:",
        config.systems, DEFAULTS.systems,
        common.apply_system
    )

    -- Per‑toolset settings
    common.apply_named_configs("toolset:",
        config.toolsets, DEFAULTS.toolsets,
        common.apply_toolset
    )

    -- Register the project
    core._workspace.projects.registry[raw_prj_name] = {
        raw_prj_name   = raw_prj_name,
        prj_name       = prj_name,
        base_name      = prj_base_name,
        is_third_party = is_third_party,
        kind           = prj_kind,
        dep_includes   = dep_includes,
        config         = config,
    }

    logger.indent_pop()
end

local function apply_dependency(core, prj_name, dep_name)
    logger.indent_push()
    logger.verbosef("Applying dependency '%s' for project '%s':", dep_name, prj_name)
    project(prj_name)

    local prj_entry = core._workspace.projects.registry[prj_name]
    local dep_entry = core._workspace.projects.registry[dep_name]

    if dep_entry.dep_includes and #dep_entry.dep_includes > 0 then
        includedirs(dep_entry.dep_includes)
    end

    links(dep_entry.prj_name)

    if dep_entry.kind == "SharedLib" then
        postbuildcommands ({
            "{MKDIR} " .. path.join(core._workspace.paths:get_bin_dir(), dep_entry.prj_name),
            "{COPYFILE} %{cfg.buildtarget.abspath} " ..
                path.join(core._workspace.paths:get_bin_dir(), dep_entry.prj_name, "%{cfg.buildtarget.name}")
        })
    end

    logger.indent_pop()
end

function prj.resolve(core, raw_prj_name)
    assert(core._workspace, "Workspace must be defined first.")
    core._workspace.projects          = core._workspace.projects or {}
    core._workspace.projects.registry = core._workspace.projects.registry or {}
    core._workspace.projects.stack    = core._workspace.projects.stack or {}

    local entry = core._workspace.projects.registry[raw_prj_name]
    assert(entry, string.format("Project '%s' is not defined.", raw_prj_name))

    if entry.resolved then return end

    table.insert(core._workspace.projects.stack, raw_prj_name)
    if entry.resolving then
        local chain = table.concat(core._workspace.projects.stack, ' -> ')
        error(string.format("Circular dependency detected: %s", chain))
    end

    entry.resolving = true
    logger.indent_push()
    logger.verbosef("Resolving project: %s", raw_prj_name)

    -- Resolve all dependencies first
    local processed = {}
    for _, dep_name in ipairs(entry.config.dependencies or {}) do
        if not processed[dep_name] then
            logger.verbosef("Resolving dependency for project: %s", raw_prj_name)
            prj.resolve(core, dep_name)
            apply_dependency(core, raw_prj_name, dep_name)
        end
    end

    entry.resolved  = true
    entry.resolving = false
    table.remove(core._workspace.projects.stack)

    logger.indent_pop()
end

return prj