local MODULE_ROOT_DIR = "boxrp/modules/"
local MODULE_INCLUDE_FILE = "module_sh.lua"

local function LoadModules()
    local files, folders = file.Find(MODULE_ROOT_DIR.."*", "LUA")
    if files == nil then
        MsgN("BoxRP > Module Loader > folder '",MODULE_ROOT_DIR,"' not exists, skipping module-loading")
        return
    end

    local module_paths = {}

    for _, filename in ipairs(files) do
        table.insert(module_paths, MODULE_ROOT_DIR..filename)
    end

    for _, foldername in ipairs(folders) do
        table.insert(module_paths, MODULE_ROOT_DIR..foldername.."/"..MODULE_INCLUDE_FILE)
    end

    table.sort(module_paths)

    BoxRP.IncludeList(module_paths)
end

LoadModules()
hook.Add("OnReloaded", "BoxRP.ModuleLoader", LoadModules)