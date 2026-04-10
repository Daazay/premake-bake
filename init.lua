local main = {}

local function add_parent_to_path()
    local source    = debug.getinfo(1, "S").source
    local file_path = source:match("@?(.*/)")
    if file_path then
        local parent_dir = file_path:match("^(.*)/[^/]+/$") or file_path:match("^(.*)/[^/]+$")
        if parent_dir then
            package.path = package.path .. ";" .. parent_dir .. "/?.lua" .. ";" .. parent_dir .. "/?/init.lua"
        end
    end
end
add_parent_to_path()

-- Preload modules
local paths_factory = require("premake-bake.core.paths_factory")
local workspace_mod = require("premake-bake.core.workspace")
local project_mod   = require("premake-bake.core.project")
local utils         = require("premake-bake.core.utils")
local common        = require("premake-bake.core.common")
local actions       = require("premake-bake.core.actions")

--

function main.workspace(name, config)
    workspace_mod.setup(main, name, config)
end

function main.project(name, config)
    assert(main._workspace, "workspace must be defined first")
    project_mod.declare(main, name, config)
end

function main.third_party(name, config)
    assert(main._workspace, "workspace must be defined first")
    local full_name = "third_party:" .. name
    project_mod.declare(main, full_name, config)
end

function main.finalize()
    actions.setup(main)

    for ws_name, ws_entry in pairs(main._workspaces) do
        ws_entry.projects          = ws_entry.projects or {}
        ws_entry.projects.registry = ws_entry.projects.registry or {}
        for prj_name, prj_entry in pairs(ws_entry.projects.registry) do
            if not prj_entry.resolved then
                project_mod.resolve(main, prj_name)
            end
        end
    end
end

return main