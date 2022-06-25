local check_ty = BoxRP.CheckType

BoxRP.UData = BoxRP.UData or {}

BoxRP.UData.ObjectDefs = BoxRP.UData.ObjectDefs or {}
local recipent_fns = recipent_fns or {}
local recipent_fns_global = recipent_fns_global or {}

BoxRP.UData.OBJECT_ID_BITS = 31
BoxRP.UData.OBJECT_ID_MAX = bit.rshift(1, 31) - 1

BoxRP.RegisterType("BoxRP.UData.ObjectId", {
    IsInstance = function(val)
        if not isnumber(val) then return false end
        if bit.tobit(val) ~= val then return false end

        return val > 0 and val < BoxRP.UData.OBJECT_ID_MAX
    end
})

local FIELDTYPE_NOPARAM = {
    ["bool"] = true,
    ["number"] = true,
    ["string"] = true,
    ["vector"] = true,
    ["angle"] = true,
    ["matrix"] = true,
    ["entity"] = true
}

local FIELDTYPE_1PARAM = {
    ["object"] = true,
    ["object_lazy"] = true
}

BoxRP.RegisterType("BoxRP.UData.FieldType", {
    IsInstance = function(val)
        if isstring(val) then return FIELDTYPE_NOPARAM[val] or false end
        if istable(val) then
            if FIELDTYPE_1PARAM[val[1]] ~= true then return false end
            return val[2] == nil or isstring(val[2])
        end
        return false
    end
})

local function ObjectFieldChecker(val, param)
    if not BoxRP.IsType(val, "BoxRP.UData.Object") then return false end
    return param == nil or val.Table == param
end

local FIELDTYPE_CHECKER = {
    bool = isbool,
    number = isnumber,
    string = isstring,
    vector = isvector,
    angle = isangle,
    matrix = ismatrix,
    entity = IsEntity,
    object = ObjectFieldChecker,
    object_lazy = ObjectFieldChecker
}

function BoxRP.UData.CheckFieldValue(value, type)
    if value == nil then return true end

    if istable(type) then
        return FIELDTYPE_CHECKER[type[1]](value, type[2])
    else
        return FIELDTYPE_CHECKER[type](value)
    end
end


local function GetInitObjDef(objty)
    assert(objty ~= "", "'objty' is empty string")

    local def = BoxRP.UData.ObjectDefs[objty] or {}
    BoxRP.UData.ObjectDefs[objty] = def

    return def
end

local function ProcessNetMode(inp)
    if inp == nil then return nil end

    if table.HasValue(inp, "everyone") then
        return "everyone"
    else
        return inp
    end
end

local function ProcessObject(config)
    return {
        SaveSv = check_ty(config.Save, "config.Save", "bool"),
        NetMode = ProcessNetMode(check_ty(config.NetMode, "config.NetMode", "table"))
    }
end

function BoxRP.UData.RegObject(objty, config)
    check_ty(objty, "objty", "string")
    check_ty(config, "config", "table")

    local objdef = GetInitObjDef(objty)
    objdef.Obj = ProcessObject(config)
end

local function ProcessField(config)
    return {
        SaveSv = check_ty(config.SaveOverride, "config.SaveOverride", {"bool","nil"}),
        NetMode = ProcessNetMode(check_ty(config.NetModeOverride, "config.NetModeOverride", {"table","nil"})),
        Type = check_ty(config.Type, "config.Type","BoxRP.UData.FieldType"),
        Checker = check_ty(config.Checker, "config.Checker",{"function","nil"})
    }
end

function BoxRP.UData.RegField(objty, key, config)
    check_ty(objty, "objty", "string")
    check_ty(objty, "key", "string")
    check_ty(config, "config", "table")

    local objdef = GetInitObjDef(objty)
    objdef.EveryField = nil
    objdef.Fields = objdef.Fields or {}
    objdef.Fields[key] = ProcessField(config)

    if SERVER then
        BoxRP.UData.DB_RegisterField(objty, key, objdef.Fields[key])
    end

    if not isstring(config.AutoGetter) and not isstring(config.AutoSetter) then return end
    local meta = BoxRP.UData.GetMetatable(objty)

    if isstring(config.AutoGetter) then
        meta[config.AutoGetter] = function(self)
            return self:Raw_Get(key)
        end
    end

    if isstring(config.AutoSetter) then
        meta[config.AutoSetter] = function(self, value, unchecked)
            self:Raw_Set(key, value, unchecked)
        end
    end
end

function BoxRP.UData.RegTableField(objty, key, config)
    check_ty(objty, "objty", "string")
    check_ty(objty, "key", "string")
    check_ty(config, "config", "table")

    local childobj_name = objty.."$array!"..key

    local parentobjdef = GetInitObjDef(objty)
    local childobjdef = GetInitObjDef(childobj_name)

    childobjdef.Obj = ProcessObject(config)
    childobjdef.Fields = nil
    childobjdef.EveryField = ProcessField(config)

    parentobjdef.Fields = parentobjdef.Fields or {}
    parentobjdef.Fields[key] = {
        SaveSv = check_ty(config.Save, "config.Save", "bool"),
        NetMode = ProcessNetMode(check_ty(config.NetMode, "config.NetMode", "table")),
        Type = {"object", childobj_name},
    }

    if check_ty(config.AutoCreate, "config.AutoCreate", "bool") then
        parentobjdef.Fields[key].Checker = function(obj, k, v)
            return v ~= nil
        end

        BoxRP.UData.RegHookLoaded(objty, "BoxRP.UData.RegTableField$"..key, function(obj)
            if obj:Raw_Get(key) == nil then
                assert(not CLIENT)

                obj:Raw_Set(key, BoxRP.UData.Create(childobj_name))
            end
        end)
    end

end

function BoxRP.UData.RegNetMode(objty, name, recipents)
    check_ty(objty, "objty", {"string", "nil"})
    check_ty(name, "name", "string")
    check_ty(recipents, "recipents", "function")

    if objty == nil then
        recipent_fns_global[name] = recipents
    else
        recipent_fns[objty] = recipent_fns[objty] or {}
        recipent_fns[objty][name] = recipents
    end
end

function BoxRP.UData.GetMetatable(objty)
    check_ty(objty, "objty", "string")

    local def = GetInitObjDef(objty)
    def.Metatable = def.Metatable or {}

    return def.Metatable
end

function BoxRP.UData.GetFieldDef(objdef, key)
    -- Internal, no type checks
    if isstring(objdef) then
        objdef = BoxRP.UData.ObjectDefs[objdef]
    end

    if objdef.EveryField ~= nil then return objdef.EveryField end

    return objdef.Fields[key]
end

if SERVER then
    function BoxRP.UData.GetRecipents(obj, netmodes)
        -- Internal, no type checks

        local recip = RecipientFilter()

        if netmodes == "everyone" then
            recip:AddAllPlayers()
            return recip
        end

        local recipent_fns_specific = recipent_fns[obj.Type] or {}

        for _, netmode in ipairs(netmodes) do
            local fn = recipent_fns_specific[netmode] or recipent_fns[netmode]

            if fn ~= nil then
                fn(obj, recip)
            end
        end

        return recip
    end
end