local CONFIG_DIR = "boxrp/config/"
local CONFIG_SEARCHPATH = "DATA"

local Configs = Configs

local function GetFileNameExt(filename)
    local i = filename:match( ".+()%.%w+$" )
    if i == nil then return filename, nil end

    return string.sub(filename, 1, i-1), string.sub(filename, i+1)
end

local function ParseConfig(fext, content, path)
    if fext == "kv" then
        return util.KeyValuesToTable(content, true, true)
    elseif fext == "json" then
        return util.JSONToTable(content)
    elseif fext == "lua" then
        if SERVER then
            AddCSLuaFile(path)
        end
        return include(path)
    else
        error("'boxRP > Lib Config > File 'garrysmod/data/",filepath,"' has unsupported extension")
    end
end

local function LoadConfigs()
    local files, _ = file.Find(CONFIG_DIR.."*", CONFIG_SEARCHPATH)

    Configs = {}

    for _, filename in ipairs(files) do
        local filepath = CONFIG_DIR..files

        local fname, fext = GetFileNameExt(filename)

        if fext == nil then
            ErrorNoHalt("'boxRP > Lib Config > File 'garrysmod/data/",filepath,"' has no extension -> unable to load as config file")
            continue
        end

        local filecontent = file.Read(filepath, CONFIG_SEARCHPATH)

        local tbl = ParseConfig(fext, filecontent, filepath)

        if tbl ~= nil then
            Configs[fname] = tbl
        else
            ErrorNoHalt("'boxRP > Lib Config > File 'garrysmod/data/",filepath,"' contains invalid syntax")
        end
    end

    hook.Run("BoxRP.ConfigsReloaded")
end

LoadConfigs()
concommand.Add("boxrp_reloadconfigs", LoadConfigs)

function BoxRP.GetConfig(name)
    assert(isstring(name), "'name' is not a string")
    return Configs[name]
end