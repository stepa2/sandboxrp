DeriveGamemode("sandbox")

GM.Name = "Sandbox RP"
GM.Author = "stpM64"
GM.TeamBased = false


BoxRP = BoxRP or {}

function BoxRP.GetRealmFromFilename(filename)
    if string.EndsWith(filename, "_sv.lua") then
        return "sv"
    elseif string.EndsWith(filename, "_cl.lua") then
        return "cl"
    end

    -- xxx_sh.lua goes there
    return "sh"
end

function BoxRP.IncludeFile(filename)
    local realm = BoxRP.GetRealmFromFilename(filename)


    if realm ~= "sv" and SERVER then
        AddCSLuaFile(filename)
    end

    if  (realm == "sv" and SERVER) or
        (realm == "cl" and CLIENT) or
        (realm == "sh")
    then
        hook.Run("BoxRP.PreFileIncluded", filename, realm)
        return include(filename)
    end
end

function BoxRP.IncludeList(files)
    for i, filename in ipairs(files) do
        BoxRP.IncludeFile(filename)
    end
end

function BoxRP.IncludeDir(dir, recursive)
    local files, dirs = file.Find(dir.."*.lua", "LUA")
    assert(files ~= nil, "Error including directory "..dir)

    for _, filename in ipairs(files) do
        BoxRP.IncludeFile(dir..filename)
    end

    if recursive then
        for _, dirname in ipairs(dirs) do
            BoxRP.IncludeDir(dir..dirname.."/", true)
        end
    end
end

local LIBS = {
    "debug_sh.lua",
    "database_sqlite_sh.lua",
    "udata_def_sh.lua",
    "udata_util_sh.lua",
    "udata_sh.lua",
    "udata_db_sv.lua",
    "udata_net_sh.lua",
    "module_loader_sh.lua"
}

local LIB_PREFIX = "boxrp/"

do
    for i, lib in ipairs(LIBS) do
        LIBS[i] = LIB_PREFIX..lib
    end
end

BoxRP.IncludeList(LIBS)