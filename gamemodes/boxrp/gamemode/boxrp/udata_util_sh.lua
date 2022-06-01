BoxRP.UData = BoxRP.UData or {}

local function ParseNNumbers(input, numcount)
    input = tostring(input)

    local parts = string.Split(input, "|")
    if #parts ~= numcount then return nil end

    local result = {}


    for i, part in ipairs(parts) do
        local num = tonumber(part)
        if num == nil then return nil end
        result[i] = num
    end

    return result
end

local function PackNumbers(args)
    for i, val in ipairs(args) do
        args[i] = tostring(i)
    end

    return table.concat(args, "|")
end

function BoxRP.UData.Util_SqlToMem(value, type)
    if value == nil then return nil end

    if type == "bool" then
        return tobool(value)
    elseif type == "number" then
        return tonumber(value)
    elseif type == "string" then
        return tostring(value)
    elseif type == "vector" then
        local parts = ParseNNumbers(value, 3)
        if parts == nil then return nil end
        return Vector(unpack(parts))
    elseif type == "angle" then
        local parts = ParseNNumbers(value, 3)
        if parts == nil then return nil end
        return Angle(unpack(parts))
    elseif type == "matrix" then
        local parts = ParseNNumbers(value, 16)
        if parts == nil then return nil end

        local matrix = Matrix()
        matrix:SetUnpacked(unpack(parts))
        return matrix
    end

    assert(istable(type))
    local type_1 = type[1]
    assert(type_1 == "object" or type_1 == "object_id")

    local oid = tonumber(value)

    if type_1 == "object_id" then
        return oid
    end

    local object = BoxRP.UData.Objects[oid]

    if type[2] ~= nil and type[2] ~= object.Type then
        return nil
    end

    return object
end

function BoxRP.UData.Util_MemToSql(value, type)
    if value == nil then return nil end

    if type == "bool" then
        return Either(value, 1, 0), false
    elseif type == "number" then
        return value, false
    elseif type == "string" then
        return value, false
    elseif type == "vector" or type == "angle" or type == "matrix" then
        return PackNumbers(value:Unpack())
    elseif istable(type) and (type[1] == "object" or type[1] == "object_raw") then
        if isnumber(value) then
            return value, true
        else
            return value.Id, true
        end
    end

    BoxRP.Error("Unsupported field type: ",type)
end