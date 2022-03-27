local MODULES_DIR = "boxrp/modules/"
local MODULE_ROOT = "boxrp/"
local MODULE_DIR_INCLUDEROOT = "module.lua"

local function LoadModuleDir(dir, no_include_root)
    hook.Run("BoxRP.PreLoadModuleDir", dir)

    if not no_include_root then
        BoxRP.IncludeFile(dir..MODULE_DIR_INCLUDEROOT)
    end

    hook.Run("BoxRP.PostLoadModuleDir", dir)
end

local function LoadModuleFile(filepath)
    BoxRP.IncludeFile(filepath)
end

local function LoadModules()
    LoadModuleDir(MODULE_ROOT, true)

    local files, dirs = file.Find(MODULES_DIR.."*", "LUA")
    local moduleList = {}

    for _, filename in ipairs(files) do
        moduleList[MODULES_DIR..filename] = false
    end

    for _, dirname in ipairs(dirs) do
        moduleList[MODULES_DIR..dirname.."/"] = true
    end

    for path, is_dir in SortedPairs(moduleList) do
        if is_dir then
            LoadModuleDir(path)
        else
            LoadModuleFile(path)
        end
    end

end

hook.Add("BoxRP.PreLoadModuleDir", "BoxRP.LibsLoader", function(dir)
    do
        local _, dirs = file.Find(dir.."*", "LUA")
        if not table.HasValue(dirs, "libs") then return end
    end

    BoxRP.IncludeDir(dir.."libs/", true)
end)

hook.Add("OnReloaded", "BoxRP.ReloadModules", LoadModules)
LoadModules()