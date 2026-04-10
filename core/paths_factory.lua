local paths_factory = {}

local utils = require("premake-bake.core.utils")

local methods = {}
methods.__index = methods

function methods:__eval_and_cache(key, base_getter, default_subdir)
    if self._cache[key] == nil then
        local base   = type(base_getter) == "function" and base_getter(self) or base_getter
        local subdir = utils.value_or(self._config[key], default_subdir)
        local full   = path.isabsolute(subdir) and subdir or path.join(base, subdir)
        self._cache[key] = full
    end
    return self._cache[key]
end

function methods:get_root_dir()        return self:__eval_and_cache("root_dir", "./", "./") end
function methods:get_projects_dir()    return self:__eval_and_cache("projects_dir", self.get_root_dir, "projects") end
function methods:get_third_party_dir() return self:__eval_and_cache("third_party_dir", self.get_root_dir, "third_party") end
function methods:get_generated_dir()   return self:__eval_and_cache("generated_dir", self.get_root_dir, "generated") end

function methods:get_build_dir() return self:__eval_and_cache("build_dir", self.get_root_dir, "build") end
function methods:get_bin_dir()   return self:__eval_and_cache("bin_dir", self.get_build_dir, "bin") end
function methods:get_obj_dir()   return self:__eval_and_cache("obj_dir", self.get_build_dir, "obj") end

function methods:get_bin_pattern() return self:__eval_and_cache("bin_pattern", self.get_bin_dir, "%{cfg.buildcfg}-%{cfg.platform}") end
function methods:get_obj_pattern() return self:__eval_and_cache("obj_pattern", self.get_obj_dir, "%{cfg.buildcfg}-%{cfg.platform}") end

function methods:get_project_dir(project_name, is_third_party)
    local base = is_third_party and self:get_third_party_dir() or self:get_projects_dir()
    return path.join(base, project_name)
end

function methods:get_generated_include_dir(project_name)
    return path.join(self:get_generated_dir(), project_name, "include")
end

function paths_factory.get_path(config)
    local instance = {
        _config = config or {},
        _cache  = {}
    }

    return setmetatable(instance, methods)
end

return paths_factory