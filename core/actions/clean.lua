local m = {}

local logger = require("premake-bake.core.logger")
local utils  = require("premake-bake.core.utils")

-- Safely remove a file or directory with verbose logging
local function safe_remove(path, is_dir)
    if not path or path == "" then return end
    if is_dir then
        if not os.isdir(path) then
            return
        end

        local ok, err = os.rmdir(path)
        if ok then
            logger.verbosef("  [deleted dir]  %s", path)
        else
            logger.verbosef("  [failed dir]   %s - %s", path, err or "unknown error")
        end
    else
        if not os.isfile(path) then
            return
        end
        local ok, err = os.remove(path)
        if ok then
            logger.verbosef("  [deleted file] %s", path)
        else
            logger.verbosef("  [failed file]  %s - %s", path, err or "unknown error")
        end
    end
end

-- Recursively delete a directory and all its contents (bottom‑up)
local function delete_dir_recursive(dir)
    if not os.isdir(dir) then
        return
    end

    -- Delete files directly inside
    local files = os.matchfiles(path.join(dir, "*"))
    for _, file in ipairs(files) do
        safe_remove(file, false)
    end

    -- Recursively delete subdirectories
    local subdirs = os.matchdirs(path.join(dir, "*"))
    for _, sub in ipairs(subdirs) do
        delete_dir_recursive(sub)
    end

    -- Delete the now‑empty directory
    safe_remove(dir, true)
end

-- Delete directories matching a list of glob patterns (recursively)
local function delete_dirs_matching(patterns)
    for _, pattern in ipairs(patterns) do
        local dirs = os.matchdirs(pattern)
        for _, dir in ipairs(dirs) do
            delete_dir_recursive(dir)
        end
    end
end

-- Delete files matching a list of glob patterns
local function delete_files_matching(patterns)
    for _, pattern in ipairs(patterns) do
        local files = os.matchfiles(pattern)
        for _, file in ipairs(files) do
            safe_remove(file, false)
        end
    end
end

local function collect_clean_patterns(ws)
    local paths = ws.paths
    assert(paths, "Workspace has no paths object")

    local file_patterns = {
        path.join(ws.location, "*.sln"),
    }

    local dir_patterns = {
        path.join(ws.location, ".vs"),
        paths:get_build_dir(),
        paths:get_generated_dir(),
    }

    -- Add project‑specific files (vcxproj, filters, user, Makefiles)
    local registry = ws.projects.registry
    if registry then
        for _, entry in pairs(registry) do
            -- Compute project location (same logic as in project.lua)
            local prj_location = utils.value_or(
                utils.eval(entry.config.location),
                paths:get_project_dir(entry.base_name, entry.is_third_party)
            )
            if prj_location then
                table.insert(file_patterns, path.join(prj_location, "*.vcxproj"))
                table.insert(file_patterns, path.join(prj_location, "*.vcxproj.filters"))
                table.insert(file_patterns, path.join(prj_location, "*.vcxproj.user"))
                table.insert(file_patterns, path.join(prj_location, "*.Makefile"))
                table.insert(file_patterns, path.join(prj_location, "*.make"))
            end
        end
    end

    return file_patterns, dir_patterns
end

function m.setup(core)
    newaction {
        trigger     = "clean",
        description = "Remove all generated files (IDE projects, solution, build directories)",
        onWorkspace = function(wks)
            local ws = core._workspaces[wks.name]
            if not ws then
                error("Workspace not found: " .. tostring(wks.name))
            end

            local file_patterns, dir_patterns = collect_clean_patterns(ws)

            print("Cleaning workspace: " .. wks.name)

            logger.verbosef("Deleting files matching patterns:")
            delete_files_matching(file_patterns)

            logger.verbosef("Deleting directories recursively:")
            delete_dirs_matching(dir_patterns)

            print("Clean completed.")
        end
    }
end

return m