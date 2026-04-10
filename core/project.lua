local prj = {}

local utils  = require("premake-bake.core.utils")
local common = require("premake-bake.core.common")

local DEFAULTS = {
    kind           = "staticlib",
    srcs           = { "**.h", "**.hpp", "**.c", "**.cpp" },
    hdrs           = { "**.h", "**.hpp" },
    includes       = { "." },
}

local function parse_project_name(raw_project_name)
    local is_third_party = raw_project_name:match("^third_party:") and true or false
    local base_name = is_third_party and raw_project_name:sub(13) or raw_project_name
    local prj_name  = is_third_party and ("third_party." .. base_name) or raw_project_name
    return base_name, prj_name, is_third_party
end

function prj.declare(main, raw_project_name, config)
    config = config or {}
    local base_name, project_name, is_third_party = parse_project_name(raw_project_name)

    assert(main._workspace, "workspace must be defined first")
    local ws = main._workspace
    ws.projects.registry = ws.projects.registry or {}
    assert(not ws.projects.registry[raw_project_name], "project with same name already defined")

    local paths = main._workspace.paths
    local project_location = utils.value_or(config.location, paths:get_project_dir(base_name, is_third_party))

    project(project_name)
    location(project_location)

    verbosef("Project: '%s'", project_name)
    verbosef("  raw_name: %s", raw_project_name)
    verbosef("  base_name: %s", base_name)
    verbosef("  location: %s", project_location)
    verbosef("  is_third_party: %s", is_third_party)

    -- Basic settings
    local project_kind = utils.value_or(utils.eval(config.kind), DEFAULTS.kind)
    kind(project_kind)

    verbosef("  kind: %s", project_kind)

    local project_group = utils.eval(config.group)
    if project_group then project().group = project_group end

    verbosef("  group: %s", project().group)

    -- Language & dialects
    local project_lang = utils.value_or(config.language, DEFAULTS.language)
    local project_cppdialect = utils.value_or(config.cppdialect, DEFAULTS.cppdialect)
    local project_cdialect = utils.value_or(config.cdialect, DEFAULTS.cdialect)
    if project_lang ~= nil then language(project_lang) end
    if project_cppdialect ~= nil then cppdialect(project_cppdialect) end
    if project_cdialect ~= nil then cdialect(project_cdialect) end

    verbosef("  language: %s", project_lang)
    verbosef("  cdialect: %s", project_cdialect)
    verbosef("  cppdialect: %s", project_cppdialect)

    -- Warnings
    local project_warn_level = utils.eval(config.warning_level)
    local project_warn_error = utils.eval(config.warnings_as_errors)
    if project_warn_level ~= nil then warnings(project_warn_level) end
    if project_warn_error ~= nil then fatalwarnings { "all" } end

    verbosef("  warnings: %s", project_warn_level)
    verbosef("  warnings_as_errors: %s", project_warn_error and "yes" or "no")

    -- Project defines/options
    local project_defines = utils.value_or(utils.eval(config.defines), DEFAULTS.defines)
    local project_build = utils.value_or(utils.eval(config.buildoptions), DEFAULTS.buildoptions)
    local project_link = utils.value_or(utils.eval(config.linkoptions), DEFAULTS.linkoptions)
    if project_defines ~= nil then defines(project_defines) end
    if project_build ~= nil then buildoptions(project_build) end
    if project_link ~= nil then linkoptions(project_link) end

    verbosef("  defines: [%s]", table.concat(project_defines or {}, ", "))
    verbosef("  buildoptions: [%s]", table.concat(project_build or {}, ", "))
    verbosef("  linkoptions: [%s]", table.concat(project_link or {}, ", "))

    -- Files
    local function add_files(category)
        verbosef("  %s:", category)

        local project_category_list = utils.value_or(config[category], DEFAULTS[category])
        for _, pat in ipairs(project_category_list) do
            local full = path.isabsolute(pat) and pat or path.join(project_location, pat)
            files { full }

            verbosef("    - %s", full)
        end
    end
    add_files("srcs")
    add_files("hdrs")

    -- Include directories
    verbosef("  includes:")

    local project_inc_dirs = {}
    local project_includes = utils.value_or(config.includes, DEFAULTS.includes)
    for _, inc in ipairs(project_includes) do
        local full = path.isabsolute(inc) and inc or path.join(project_location, inc)
        table.insert(project_inc_dirs, full)

        verbosef("    - %s", full)
    end

    includedirs(project_inc_dirs)

    -- Apply per-configuration/platform/toolset filters
    common.apply_filtered_settings("configurations", config.configurations, DEFAULTS.configurations)
    common.apply_filtered_settings("platforms", config.platforms, DEFAULTS.platforms)
    common.apply_filtered_settings("toolset", config.toolsets, DEFAULTS.toolsets)

    local entry = {
        raw_project_name = raw_project_name,
        project_name     = project_name,
        project_location = project_location,
        base_name        = base_name,
        includes         = project_inc_dirs,
        is_third_party   = is_third_party,
        dependencies     = utils.eval(config.dependencies) or {},
        config           = config,
        resolved         = false,
        resolving        = false,
    }
    ws.projects.registry[raw_project_name] = entry

    verbosef("Project declaration complete.")
end

local function apply_dependency(paths, parent_project_name, dep_entry)
    project(parent_project_name)
    includedirs(dep_entry.includes)
    links { dep_entry.project_name }

    if dep_entry.kind == "SharedLib" then
        postbuildcommands ({
            "{MKDIR} " .. path.join(paths:get_bin_dir(), dep_entry.project_name),
            "{COPYFILE} %{cfg.buildtarget.abspath} " ..
                path.join(paths:get_bin_dir(), dep_entry.project_name, "%{cfg.buildtarget.name}")
        })
    end
end

function prj.resolve(main, raw_project_name)
    assert(main._workspace, "workspace must be defined first")
    local ws = main._workspace
    local registry = ws.projects.registry
    local stack = ws.projects.stack or {}
    ws.projects.stack = stack

    local entry = registry[raw_project_name]
    assert(entry, string.format("Project '%s' is not defined.", raw_project_name))

    if entry.resolved then return end

    table.insert(stack, raw_project_name)
    if entry.resolving then
        local chain = table.concat(stack, "' -> '")
        error(string.format("Circular dependency detected: '%s'", chain), 0)
    end

    entry.resolving = true
    verbosef("Resolving dependencies for '%s'", raw_project_name)

    -- Resolve all dependencies first
    for _, dep_name in ipairs(entry.dependencies) do
        prj.resolve(main, dep_name)
    end

    -- Now apply them
    project(entry.project_name)
    local processed = {}
    for _, dep_name in ipairs(entry.dependencies) do
        if not processed[dep_name] then
            local dep_entry = registry[dep_name]
            if dep_entry then
                apply_dependency(ws.paths, entry.project_name, dep_entry)
                processed[dep_name] = true
                verbosef("  applied dependency: %s", dep_name)
            end
        end
    end

    entry.resolved  = true
    entry.resolving = false
    table.remove(stack)

    verbosef("Finished resolving %s", raw_project_name)
end

return prj