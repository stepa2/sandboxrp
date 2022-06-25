local ModuleList
local MODULE_LIST_FILE = "boxrp/module_list.txt"

local function LoadModuleList()
    local mlist_file = file.Read(MODULE_LIST_FILE, "DATA")

    if mlist_file == nil then
        ErrorNoHalt("BoxRP > Module Loader > Missing module list 'data/",MODULE_LIST_FILE,"'.\n")
        ErrorNoHalt("All modules will be loaded! Beware!\n")
        ModuleList = nil
        return
    end

    local mlist_kvs = util.KeyValuesToTable(mlist_file, true, false)
    assert(mlist_kvs)

    ModuleList = {}

    for key, value in pairs(mlist_kvs) do
        if value == "load" then
            ModuleList[key] = true
        elseif value == "skip" then
            ModuleList[key] = false
        else
            ErrorNoHalt("BoxRP > Module Loader > Module list file contains invalid entry for '",key,"' - should be 'load' or 'skip'\n")
        end
    end
end


local MODULE_ROOT_DIR = "boxrp/modules/"
local MODULE_INCLUDE_FILE = "module_sh.lua"

local AllModules = {}
local LoadedModules = {}
local ModuleFiles = {}

local function PrepareModule(name, file)
    AllModules[name] = true

    if ModuleList ~= nil and ModuleList[name] == false then return end

    if ModuleList ~= nil and ModuleList[name] == nil then
        ErrorNoHalt("BoxRP > ModuleLoader > Module '",name,"' missing from module list file. Will load anyway\n")
    end

    LoadedModules[name] = true
    table.insert(ModuleFiles, file)
end

local function LoadModules()
    LoadModuleList()

    local files, folders = file.Find(MODULE_ROOT_DIR.."*", "LUA")
    if files == nil then
        MsgN("BoxRP > Module Loader > folder '",MODULE_ROOT_DIR,"' not exists, skipping module-loading")
        return
    end

    AllModules = {}
    LoadedModules = {}
    ModuleFiles = {}

    for _, filename in ipairs(files) do
        PrepareModule(string.StripExtension(filename), MODULE_ROOT_DIR..filename)
    end

    for _, foldername in ipairs(folders) do
        PrepareModule(foldername, MODULE_ROOT_DIR..foldername.."/"..MODULE_INCLUDE_FILE)
    end

    table.sort(ModuleFiles)

    BoxRP.IncludeList(ModuleFiles)
end

function BoxRP.RequireModules(module_list)
    local missing_modules = {}

    for _, module in ipairs(module_list) do
        if not LoadedModules[module] then
            table.insert(missing_modules, module)
        end
    end

    if #missing_modules ~= 0 then
        BoxRP.Error("Missing modules: ", table.concat(missing_modules, ", "))
    end
end

LoadModules()
hook.Add("OnReloaded", "BoxRP.ModuleLoader", LoadModules)