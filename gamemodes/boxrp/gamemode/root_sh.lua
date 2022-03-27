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

    hook.Run("BoxRP.PreFileIncluded", filename, realm)

    if realm ~= "sv" and SERVER then
        AddCSLuaFile(filename)
    end

    if  (realm == "sv" and SERVER) or
        (realm == "cl" and CLIENT) or
        (realm == "sh")
    then
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