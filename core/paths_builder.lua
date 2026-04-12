local m = {}

local utils = require("premake-bake.core.utils")

--- @alias EvaluatePathFn fun(paths: Paths): string

--- @class PathsConfig
--- @field root_dir?        string|EvaluatePathFn -- Project root (default ".")
--- @field projects_dir?    string|EvaluatePathFn -- Where project files lives
--- @field third_party_dir? string|EvaluatePathFn -- Third-party dependencies
--- @field generated_dir?   string|EvaluatePathFn -- Generated source files
--- @field build_dir?       string|EvaluatePathFn -- Main build output directory
--- @field bin_dir?         string|EvaluatePathFn -- Binaries (executables/libs)
--- @field obj_dir?         string|EvaluatePathFn -- Object files
--- @field bin_pattern?     string|EvaluatePathFn -- Pattern for binary output paths
--- @field obj_pattern?     string|EvaluatePathFn -- Pattern for object file paths

--- @class Paths
--- @field _config PathsConfig          -- User-provided or extended configuration
--- @field _cache table<string, string> -- Resolved absolute paths by key
local Paths = {}
Paths.__index = Paths

-- Default values for built-in paths.
-- Functions are evaluated lazily and cached.
Paths._defaults = {
    root_dir        = ".",
    projects_dir    = "projects",
    third_party_dir = "third_party",
    build_dir       = "build",
     -- `generated_dir` is relative to build_dir by default
    generated_dir   = "generated",
    bin_dir         = "bin",
    obj_dir         = "obj",
    bin_pattern     = "%{cfg.buildcfg}-%{cfg.platform}",
    obj_pattern     = "%{cfg.buildcfg}-%{cfg.platform}",
}

--- Resolves a path key: evaluates, resolves relative to a base, and caches.
--- @param self     Paths instance
--- @param key      string – configuration key (e.g., "root_dir", "my_custom")
--- @param base_val string|EvaluatePathFn – base directory (or function returning it)
--- @return         string – absolute resolved path
local function resolve(self, key, base_val)
    if self._cache[key] == nil then
        -- 1. Get raw value: from user config, fallback to defaults (if any).
        local raw = self._config[key]
        if raw == nil and Paths._defaults[key] ~= nil then
            raw = Paths._defaults[key]
        end
        if raw == nil then
            error("There are no config for path key: " .. tostring(key), 2)
        end

        -- 2. Evaluate if it's a function (passing self).
        local evalualed = utils.eval(raw, self)

        -- 3. Make absolute: if already absolute, keep; else join with base.
        if path.isabsolute(evalualed) then
            self._cache[key] = evalualed
        else
            local base  = utils.eval(base_val, self)
            self._cache[key] = path.join(base, evalualed)
        end
    end
    return self._cache[key]
end

-- Convenience getters for built-in paths.
-- Each delegates to `resolve` with the appropriate base directory.
function Paths:get_root_dir()        return resolve(self, "root_dir",       ".") end
function Paths:get_projects_dir()    return resolve(self, "projects_dir",    self.get_root_dir) end
function Paths:get_third_party_dir() return resolve(self, "third_party_dir", self.get_root_dir) end
function Paths:get_generated_dir()   return resolve(self, "generated_dir",   self.get_build_dir) end
function Paths:get_build_dir()       return resolve(self, "build_dir",       self.get_root_dir) end
function Paths:get_bin_dir()         return resolve(self, "bin_dir",         self.get_build_dir) end
function Paths:get_obj_dir()         return resolve(self, "obj_dir",         self.get_build_dir) end
function Paths:get_bin_pattern()     return resolve(self, "bin_pattern",     self.get_bin_dir) end
function Paths:get_obj_pattern()     return resolve(self, "obj_pattern",     self.get_obj_dir) end

--- Generic getter for any path key (built‑in or custom).
--- For custom keys, it resolves relative to `root_dir` unless overridden.
--- @param key string|nil – if given, only that key is cleared; otherwise all.
function Paths:get(key)
    local method = self["get_" .. key]
    if method then return method(self) end
    return resolve(self, key, self.get_root_dir)
end

--- Invalidates cached path(s).
--- @param key string|nil
--- @return Paths
function Paths:invalidate(key)
    if key then
        self._cache[key] = nil
    else
        self._cache = {}
    end
    return self
end

--- Factory: creates a new Paths instance.
--- @param config? PathsConfig
--- @return Paths
function m.get_paths(config)
    local instance = {
        _config = config or {},
        _cache  = {},
    }
    return setmetatable(instance, Paths)
end

--- Creates a new Paths instance by extending the current configuration.
--- @param overrides PathsConfig
--- @return Paths
function Paths:extend(overrides)
    local new_config = utils.merge(self._config, overrides or {})
    return m.get_paths(new_config)
end

function Paths:get_project_dir(prj_name, is_third_party)
    local base = is_third_party and self:get_third_party_dir() or self:get_projects_dir()
    return path.join(base, prj_name)
end

return m