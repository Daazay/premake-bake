local actions = {}
local utils = require("premake-bake.core.utils")  -- reuse existing utils if available

-- Helper: safe delete with verbose logging
local function safe_remove(path, is_dir)
    if not path or path == "" then return end
    if is_dir then
        if not os.isdir(path) then return end
        local ok, err = os.rmdir(path)
        if ok then
            verbosef("  [deleted dir]  %s", path)
        else
            verbosef("  [failed dir]   %s - %s", path, err or "unknown error")
        end
    else
        if not os.isfile(path) then return end
        local ok, err = os.remove(path)
        if ok then
            verbosef("  [deleted file] %s", path)
        else
            verbosef("  [failed file]  %s - %s", path, err or "unknown error")
        end
    end
end

-- Recursively delete a directory and all its contents (bottom-up)
local function delete_dir_recursive(dir)
    if not os.isdir(dir) then return end

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

    -- Delete the now-empty directory
    safe_remove(dir, true)
end

-- Delete directories matching glob patterns (recursively)
local function delete_dirs_matching(patterns)
    for _, pattern in ipairs(patterns) do
        for _, dir in ipairs(os.matchdirs(pattern)) do
            delete_dir_recursive(dir)
        end
    end
end

-- Delete files matching glob patterns
local function delete_files_matching(patterns)
    for _, pattern in ipairs(patterns) do
        local matches = os.matchfiles(pattern)
        for _, file in ipairs(matches) do
            safe_remove(file, false)
        end
    end
end

-- Collect all generated/project files to delete
local function collect_clean_patterns(ws)
    local paths = ws.paths
    assert(paths, "workspace has no paths object")

    local file_patterns = {
        path.join(ws.location, "*.sln"),
    }
    local dir_patterns = {
        path.join(ws.location, ".vs"),
        paths:get_build_dir(),   -- main build directory
        paths:get_generated_dir(), -- often generated includes, etc.
    }

    -- Add project‑specific files
    local registry = ws.projects.registry
    if registry then
        for _, entry in pairs(registry) do
            if entry.project_location then
                table.insert(file_patterns, path.join(entry.project_location, "*.vcxproj*"))
                table.insert(file_patterns, path.join(entry.project_location, "*.Makefile"))
                table.insert(file_patterns, path.join(entry.project_location, "*.make"))
            end
        end
    end

    return file_patterns, dir_patterns
end

local function setup_clean_action(main)
    main._workspaces = main._workspaces or {}

    newaction {
        trigger     = "clean",
        description = "Remove generated files, build directories, and IDE artifacts",
        onWorkspace = function(wks)
            local ws = main._workspaces[wks.name]
            assert(ws, "workspace not found: " .. tostring(wks.name))

            local file_patterns, dir_patterns = collect_clean_patterns(ws)

            print("Cleaning workspace: " .. wks.name)

            verbosef("Deleting files matching patterns:")
            delete_files_matching(file_patterns)

            verbosef("Deleting directories recursively:")
            delete_dirs_matching(dir_patterns)

            print("Clean completed.")
        end
    }
end

function actions.setup(main)
    setup_clean_action(main)
end

return actions