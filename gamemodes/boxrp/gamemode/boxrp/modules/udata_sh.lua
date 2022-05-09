local check_ty = BoxRP.CheckType
local SQL = BoxRP.SQLite.Query
local SQLSingle = BoxRP.SQLite.QuerySingle
local SQLEscape = sql.SQLStr

---------------

SQL([[
    CREATE TABLE IF NOT EXISTS boxrp_objects (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
    ) STRICT;

    CREATE TABLE IF NOT EXISTS boxrp_object_vars (
        id INTEGER NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,

        FOREIGN KEY (id) REFERENCES boxrp_objects(id)
            ON UPDATE CASCADE ON DELETE CASCADE
    ) STRICT;

    CREATE TABLE IF NOT EXISTS boxrp_object_xrefs (
        id_owner INTEGER NOT NULL,
        key TEXT NOT NULL,
        id_value INTEGER NOT NULL,

        FOREIGN KEY (id_owner, id_value) REFERENCES boxrp_objects(id, id)
            ON UPDATE CASCADE ON DELETE CASCADE
    ) STRICT;
]])

---------------

BoxRP.UData = {}
local objdescs = objdescs or {}
BoxRP.UData.Objects = BoxRP.UData.Objects or {}

local OBJECT = OBJECT or {}
OBJECT.__index = OBJECT

BoxRP.RegisterType("BoxRP.UData.Object", {
    IsInstance = function(val)
        return val ~= nil and debug.getmetatable(val) == OBJECT
    end
})

BoxRP.UData.OBJECT_ID_BITS = 31
BoxRP.UData.OBJECT_ID_MAX = bit.lshift(1, BoxRP.UData.OBJECT_ID_BITS) - 1

BoxRP.RegisterType("BoxRP.UData.ObjectId", {
    IsInstance = function(val)
        if not isnumber(val) then return false end
        if bit.tobit(val) ~= val then return false end

        return val > 0 and val <= BoxRP.UData.OBJECT_ID_MAX
    end
})

local function ParseNetworkingParam(params)
    local recip = params.Recipents

    if recip == nil or recip == "none" then
        return nil, nil
    elseif recip == "everyone" then
        return "everyone", nil
    elseif recip == "recvlist" then
        return "list", {}
    else
        BoxRP.Error("'boxRP > UData > Invalid recipent mode '",recip,"'")
    end
end

function BoxRP.UData.RegisterObject(obj_type, params)
    check_ty(obj_type, "obj_type", "string")
    check_ty(params, "params", "table")

    local netmode, netlist = ParseNetworkingParam(params)

    local objdesc = {
        NetMode = netmode,
        NetList = netlist,
        Vars = {},
        Type = obj_type
    }

    if objdescs[obj_type] ~= nil then
        MsgN("'boxRP > UData > Re-registering object '",obj_type,"'")
    end

    objdescs[obj_type] = objdesc
end

local function DefaultVarChecker(val)
    if val == nil then
        return "Value is nil"
    end
end

local function ParseVarTypeParam(params)
    local ty = check_ty(params.Type, "params.Type", "table")
    ty.Checker = check_ty(params.ValueChecker or DefaultVarChecker, "params.ValueChecker", "function")

    return ty
end

local function ParseSaveParam(params)
    return {
        Sv = check_ty(params.SaveOnServer, "params.SaveOnServer", "bool"),
        Cl = check_ty(params.SaveOnClient, "params.SaveOnClient", "bool")
    }
end

local function CheckVarErrorHandler(params, vardesc)
    local hnd = check_ty(params.ErrorHandling, "params.ErrorHandling", "table")

    local any_defaults = hnd.WhenMissing == "set_default" or hnd.WhenMultiple == "set_default"

    if vardesc.Type.Type == "Object" and any_defaults then
        BoxRP.Error("Specifying default value for 'Object'- or 'array(Object)'-typed variables is not supported")
    elseif any_defaults then
        local checker = vardesc.Type.Checker
        local default = hnd.Default

        local errmsg = checker(default)
        if errmsg ~= nil then
            BoxRP.Error("Default value is invalid: ",errmsg)
        end
    end

    return hnd
end

function BoxRP.UData.RegisterVar(obj_type, var_name, params)
    check_ty(obj_type, "obj_type", "string")
    check_ty(var_name, "var_name", "string")
    check_ty(params, "params", "table")

    local objdesc = objdescs[obj_type]
    if objdesc == nil then
        BoxRP.Error("'boxRP > UData > Registering variable '",var_name,"' on non-registere object type '",obj_type,"'")
    end

    local netmode = ParseNetworkingParam(params)
    local vardesc = {
        Save = ParseSaveParam(params),
        NetMode = netmode,
        Type = ParseVarTypeParam(params),
        Name = var_name
    }
    vardesc.ErrorHandler = CheckVarErrorHandler(params, vardesc)

    if objdesc.Vars[var_name] ~= nil then
        MsgN("'boxRP > UData > Re-registering variable '",var_name,"' of object '",obj_type,"'")
    end

    objdescs.Vars[var_name] = vardesc
end

local function GetVariableValue(obj_type, vardesc, init_value)
    if init_value ~= nil then
        local errmsg = vardesc.Type.Checker(init_value)

        if errmsg ~= nil then
            return nil, "'"..obj_type.."'.'"..vardesc.Name.."': value is invalid: "..errmsg
        else
            return init_value
        end
    end

    local missing_action = vardesc.ErrorHandler.WhenMissing

    if missing_action == "set_default" then
        return vardesc.ErrorHandler.Default
    elseif missing_action == "skip_object" then
        return nil, "'"..obj_type.."'.'"..vardesc.Name.."': value not exists, object can not be created"
    end
end

local function PreCreateObject(id, obj_type)
    local objdesc = objdescs[obj_type]
    if objdesc == nil then
        return nil, nil, "Non-registered object type '"..obj_type.."'"
    end

    local obj = setmetatable({}, OBJECT)
    obj.Id = id
    obj.Type = obj_type
    obj._isValid = false
    BoxRP.UData.Objects[id] = obj

    return obj, objdesc
end

local function CreateObject(obj, objdesc, vars)
    obj._desc = objdesc
    obj._vars = {}
    obj._dirtyVars = {}

    for varname, vardesc in pairs(obj._desc.Vars) do
        local error_msg, value = GetVariableValue(objdesc.Type, vardesc, vars[varname])

        if error_msg ~= nil then
            return nil, error_msg
        end

        obj._vars[varname] = value
        obj._dirtyVars[varname] = true
    end

    obj._isValid = true

    return obj, nil
end

local function _DBInsertNew(type)
    local result = SQLSingle([[
        INSERT INTO boxrp_objects (type)
            VALUES ({type})
            RETURNING id
    ]], { type = type })

    return tonumber(result.id)
end

function BoxRP.UData.CreateObject(obj_type, vars)
    check_ty(obj_type, "obj_type", "string")
    check_ty(vars, "vars", "table")

    local obj, objdesc, errmsg = PreCreateObject(_DBInsertNew(obj_type), obj_type)

    if errmsg ~= nil then return nil, errmsg end

    return CreateObject(obj, objdesc, vars)
end

local function GetSupportedKeysExpr(objdesc)
    local var_keys = {}
    local xref_keys = {}

    for varname, vardesc in pairs(objdesc.Vars) do
        if vardesc.Type.Type == "Object" then
            table.insert(xref_keys, SQLEscape(varname))
        else
            table.insert(var_keys, SQLEscape(varname))
        end
    end

    return table.concat(var_keys, ","), table.concat(xref_keys, ",")
end

local function VariableValFromSQL(vardesc, value_raw)
    local type = vardesc.Type.Type

    if type == "table" then
        local tbl = util.JSONToTable(value_raw)
        if tbl == nil then return nil, "value is not a valid JSON" end

        tbl = table.DeSanitise(tbl)

        return tbl
    elseif type == "Object" then
        return BoxRP.UData.LoadObject(value_raw)
    else
        return nil, "unknown type '"..type.."'"
    end
end

local function VariableHandleRepeat(vardesc)
    if vardesc.ErrorHandler.WhenMultiple == "set_default" then
        return vardesc.ErrorHandler.Default
    end

    return nil, "non-array value is repeating"
end

function BoxRP.UData.LoadObject(oid)
    check_ty(oid, "oid", "BoxRP.UData.ObjectId")

    if BoxRP.UData.Objects[oid] ~= nil then
        return BoxRP.UData.Objects[oid]
    end


    local q_object = SQLSingle([[
        SELECT type FROM boxrp_objects
            WHERE boxrp_objects.id == {id}
    ]], { id = oid })

    if q_object == nil then
        return nil, "Object "..tostring(oid).." not stored in database"
    end

    local obj, objdesc, errmsg = PreCreateObject(oid, q_object.type)

    if errmsg ~= nil then return nil, errmsg end

    local supported_vars, supported_xrefs = GetSupportedKeysExpr(objdesc)

    local q_vars = SQL([[
        SELECT key, value FROM boxrp_object_vars AS vars
            WHERE vars.id == {id} AND vars.key IN ({$supported_vars})
        UNION ALL SELECT key, id_value AS value FROM boxrp_object_xrefs AS xrefs
            WHERE xrefs.id_owner == {id} AND vars.key IN ({$supported_xrefs}) 
    ]], { id = oid, supported_vars = supported_vars, supported_xrefs = supported_xrefs })

    local object_vars = {}

    for _, q_var in ipairs(q_vars) do
        local key = q_var.key
        local value_raw = q_var.value

        local vardesc = objdesc.Vars[key]

        local value, errmsg = VariableValFromSQL(vardesc, value_raw)

        if errmsg ~= nil then
            return nil,  "'"..objdesc.Type.."'.'"..key.."': "..errmsg
        end

        if vardesc.Type.IsArray then
            local dest = object_vars[varname] or {}
            object_vars[varname] = dest

            table.insert(dest, value)
        else
            if object_vars[varname] ~= nil then
                local val, error = VariableHandleRepeat(vardesc, objdesc.Type)
                if error ~= nil then return nil, "'"..objdesc.Type.."'.'"..key.."': "..error end

                value = val
            end
            object_vars[varname] = value
        end
    end

    return CreateObject(obj, objdesc, oid)
end

function OBJECT:GetVar(key)
    return self._vars[key]
end

function OBJECT:SetVar(key, value)
    check_ty(key, "key", "string")

    local vardesc = self._desc.Vars[key]
    if vardesc == nil then
        return false, tostring(self).."."..key..": no such variable"
    end

    local errmsg = vardesc.Type.Checker(value)
    if errmsg ~= nil then
        return false, tostring(self).."."..key..": "..errmsg
    end

    self._vars[key] = value

    return true, nil
end

function OBJECT:SetVarIndexed(key, index, value)
    --TODO
end

if SERVER then
    function OBJECT:Sync(target)
        --TODO
    end
end

if SERVER then
    function OBJECT:SaveServer()
        self:_Save()
    end

    function OBJECT:SaveClient()
        --TODO
    end
else
    function OBJECT:SaveClient()
        self:_Save()
    end
end

function OBJECT:_Save()
    --TODO
end

function OBJECT:IsValid()
    return self._isValid
end