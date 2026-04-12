local core = {}

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
local paths_builder = require("premake-bake.core.paths_builder")
local ws            = require("premake-bake.core.workspace")
local prj           = require("premake-bake.core.project")
local utils         = require("premake-bake.core.utils")
local common        = require("premake-bake.core.common")

local action_clean = require("premake-bake.core.actions.clean")

function core.workspace(name, config)
    ws.setup(core, name, config)
end

function core.project(name, config)
    prj.declare(core, name, config)
end

function core.third_party(name, config)
    prj.declare(core, "third_party:" .. name, config)
end

function core.final()
    action_clean.setup(core)

    for ws_name, ws_entry in pairs(core._workspaces or {}) do
        core._workspace  = ws_entry
        ws_entry.projects = ws_entry.projects or {}
        for prj_name, prj_entry in pairs(ws_entry.projects.registry) do
            if not prj_entry.resolved then
                prj.resolve(core, prj_name)
            end
        end
    end
end

return core