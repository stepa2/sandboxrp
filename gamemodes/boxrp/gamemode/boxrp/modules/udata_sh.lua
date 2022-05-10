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

local function NameObject(obj, id)
    local objname
    if isstring(obj) then
        objname = obj
    elseif obj._desc ~= nil then
        objname = obj._desc.Type
        if id == nil then
            id = obj.Id
        end
    elseif obj.Type ~= nil then
        objname = obj.Type
    end

    if id == nil then
        return "Object["..objname.."]"
    else
        return "Object["..objname.."|"..tostring(id).."]"
    end
end

local function NameVariable(obj, var, id)
    local objname
    if isstring(obj) then
        objname = obj
    elseif obj._desc ~= nil then
        objname = obj._desc.Type
        if id == nil then
            id = obj.Id
        end
    elseif obj.Type ~= nil then
        objname = obj.Type
    end

    local varname
    if isstring(var) then
        varname = var
    else
        varname = var.Name
    end

    if id == nil then
        return "Variable["..objname.."]["..varname.."]"
    else
        return "Variable["..objname.."|"..tostring(id).."]["..varname.."]"
    end
end

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
        MsgN("'boxRP > UData > Re-registering ",NameObject(objdesc))
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
    ty.Checker = check_ty(params.ItemChecker or DefaultVarChecker, "params.ItemChecker", "function")

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
        BoxRP.Error("Specifying default value for 'Object'-typed variables is not supported")
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
        BoxRP.Error("'boxRP > UData > ",NameVariable(obj_type, var_name),": Object type not registered")
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
        MsgN("'boxRP > UData > Re-registering ",NameVariable(objdesc, vardesc))
    end

    objdescs.Vars[var_name] = vardesc
end

-------------------------------

local function CheckVarValue(obj, vardesc, value)
    local checker = vardesc.Checker

    if vardesc.Type.IsSet then
        for i, value_item in ipairs(value) do
            local errmsg = checker(value_item)
            if errmsg ~= nil then
                return NameVariable(obj, vardesc).."["..tonumber(i).."] will be invalid: "..errmsg
            end
        end
    else
        local errmsg = checker(value)
        if errmsg ~= nil then
            return NameVariable(obj, vardesc).." will be invalid: "..errmsg
        end
    end

    return nil
end

local function GetVariableValue(obj, vardesc, init_value, ignore_init)
    if not ignore_init and init_value ~= nil then
        local errmsg = CheckVarValue(obj, vardesc, init_value)

        if errmsg ~= nil then return nil, nil, errmsg end
        return init_value, false, nil
    end

    local missing_action = vardesc.ErrorHandler.WhenMissing

    if missing_action == "set_default" then
        return vardesc.ErrorHandler.Default, false, nil
    elseif missing_action == "skip_object" then
        if ignore_init then
            return nil, true, nil
        else
            return nil, nil, NameVariable(obj, vardesc)..": not exists, object can not be created"
        end
    end
end

local function PreCreateObject(id, obj_type)
    local objdesc = objdescs[obj_type]
    if objdesc == nil then
        return nil, nil, NameObject(obj_type)..": not registered type"
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
    obj._saveDirtyVars = {}
    obj._invalidVars = {}

    if SERVER then
        obj._sendDirtyVars = {}
        obj.Receivers = RecipientFilter()
    end

    local ignore_init_var = vars == nil

    for varname, vardesc in pairs(obj._desc.Vars) do
        local value, is_invalid, error_msg = GetVariableValue(obj, vardesc, not ignore_init_var and vars[varname], ignore_init_var)

        if error_msg ~= nil then
            return nil, error_msg
        end

        if is_invalid then
            obj._invalidVars[varname] = true
            continue
        end

        obj._vars[varname] = value
        obj:_VarModified(vardesc)
    end

    obj._isValid = table.IsEmpty(obj._invalidVars)

    if SERVER then
        obj:_SyncCreation(nil)
        obj:Sync()
    end

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

local function VariableValToSQLSingle(vardesc, value)
    local type = vardesc.Type.Type

    if type == "table" then
        return util.TableToJSON(table.Sanitise(value))
    elseif type == "Object" then
        return value.Id
    else
        return nil, "unknown type '"..type.."'"
    end
end

local function VariableHandleRepeat(objdesc, vardesc)
    if vardesc.ErrorHandler.WhenMultiple == "set_default" then
        return vardesc.ErrorHandler.Default
    end

    return nil, NameVariable(objdesc, vardesc).." is non-set but repeating"
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
        return nil, NameObject("<no data>", oid).." not stored in database"
    end

    local obj, objdesc, errmsg = PreCreateObject(oid, q_object.type)

    if errmsg ~= nil then return nil, errmsg end

    local supported_vars, supported_xrefs = GetSupportedKeysExpr(objdesc)

    local q_vars = SQL([[
        SELECT DISTINCT key, value FROM
            (SELECT key, value FROM boxrp_object_vars AS vars
                WHERE vars.id == {id} AND vars.key IN ({$supported_vars})),
            (SELECT key, id_value AS value FROM boxrp_object_xrefs AS xrefs
                WHERE xrefs.id_owner == {id} AND xrefs.key IN ({$supported_xrefs}))
    ]], { id = oid, supported_vars = supported_vars, supported_xrefs = supported_xrefs })

    local object_vars = {}

    for _, q_var in ipairs(q_vars) do
        local varname = q_var.key
        local value_raw = q_var.value

        local vardesc = objdesc.Vars[varname]

        local value, errmsg = VariableValFromSQL(vardesc, value_raw)

        if errmsg ~= nil then
            return nil,  NameVariable(obj, vardesc)..": "..errmsg
        end

        if vardesc.Type.IsSet then
            local dest = object_vars[varname] or {}
            object_vars[varname] = dest

            table.insert(dest, value)
        else
            if object_vars[varname] ~= nil then
                local val, errmsg = VariableHandleRepeat(objdesc, vardesc)
                if error ~= nil then return nil, NameVariable(obj, vardesc)..": "..errmsg end

                value = val
            end
            object_vars[varname] = value
        end
    end

    return CreateObject(obj, objdesc, oid)
end

function OBJECT:IsValid()
    return self._isValid
end

function OBJECT:Remove()
    SQL([[
        DELETE FROM boxrp_objects
            WHERE boxrp_objects.id == {id}

        -- Values of boxrp_object_vars and boxrp_object_xrefs are deleted via FOREIGN KEY
    ]])

    self:Unload()
end

function OBJECT:Unload()
    if SERVER then
        self:_SyncUnload()
    end

    BoxRP.UData.Objects[self.Id] = nil
    self._vars = nil -- Will probably cause errors on most usages
    self._invalidVars = nil
    self._isValid = false
end

--------------------

function OBJECT:GetVar(key)
    assert(IsValid(self), "Object is not valid")
    return self._vars[key]
end

function OBJECT:_MarkVarValid(key)
    self._invalidVars[key] = nil
    if table.IsEmpty(self._invalidVars) then
        self._isValid = true
    end
end

function OBJECT:_VarModified(vardesc)
    if (SERVER and vardesc.Save.Sv) or (CLIENT and vardesc.Save.Cl) then
        self._saveDirtyVars[vardesc.Name] = true
    end

    if SERVER and vardesc.NetMode ~= nil then
        self._sendDirtyVars[vardesc.Name] = true
    end


end

function OBJECT:_PrepareVarModify(key)
    local vardesc = self._desc.Vars[key]
    if vardesc == nil then
        return nil, NameVariable(self, key)..": undefined"
    end

    return vardesc, nil
end

function OBJECT:_PrepareVarModifySet(key)
    local vardesc, errmsg = self:_PrepareVarModify(key)
    if errmsg ~= nil then return nil, errmsg end

    if not vardesc.IsSet then return nil, NameVariable(self, key)..": not a set" end

    return vardesc, nil
end

function OBJECT:SetVar(key, value)
    assert(IsValid(self), "Object is not valid")
    check_ty(key, "key", "string")

    local vardesc, errmsg = self:_PrepareVarModify(key)
    if errmsg ~= nil then return false, errmsg end

    local errmsg = CheckVarValue(self, vardesc, value)
    if errmsg ~= nil then return false, errmsg end

    self._vars[key] = value
    self:_VarModified(vardesc)
    self:_MarkVarValid(key)

    return true, nil
end

function OBJECT:_CheckIndex(key, index)
    if bit.tobit(index) ~= index then return false end
    if index < 1 then return false end
    if index > #self._vars[key] then return false end

    return true, nil
end

function OBJECT:_FindSet(key, search_val)
    for i, val in ipairs(self._vars[key]) do
        if val == search_val then
            return i
        end
    end
end

function OBJECT:SetVarIndexed(key, index, value)
    assert(IsValid(self), "Object is not valid")
    check_ty(key, "key", "string")
    check_ty(index, "index", "number")

    local vardesc, errmsg = self:_PrepareVarModifySet(key)
    if errmsg ~= nil then return false, errmsg end

    if not self:_CheckIndex(key, index) then 
        return false, NameVariable(self, vardesc).."["..tostring(index).."]: index is invalid"
    end

    local errmsg = vardesc.Type.Checker(value)
    if errmsg ~= nil then
        return false, NameVariable(self, vardesc).."["..tostring(index).."] will be invalid: "..errmsg
    end

    local existent_i = self:_FindSet(key, value)

    if existent_i == nil then
        self._vars[key][index] = value
    else
        table.remove(self._vars[key], index)
    end

    self:_VarModified(vardesc)

    return true, nil
end

function OBJECT:InsertSet(key, value)
    assert(IsValid(self), "Object is not valid")
    check_ty(key, "key", "string")

    local vardesc, errmsg = self:_PrepareVarModifySet(key)
    if errmsg ~= nil then return nil, errmsg end

    local errmsg = vardesc.Type.Checker(value)
    if errmsg ~= nil then
        return nil, NameVariable(self, vardesc)..": attempt to insert invalid value: "..errmsg
    end

    local existent_i = self:_FindSet(key, value)
    if existent_i == nil then
        local i = table.insert(self._vars[key], value), nil
        self:_VarModified(vardesc)
        return i, nil
    else
        return existent_i, nil
    end
end

function OBJECT:RemoveSet(key, idx)
    assert(IsValid(self), "Object is not valid")
    check_ty(key, "key", "string")
    check_ty(idx, "idx", "number")

    local vardesc, errmsg = self:_PrepareVarModifySet(key)
    if errmsg ~= nil then return nil, errmsg end

    if not self:_CheckIndex(key, idx) then
        return nil, NameVariable(self, vardesc).."["..tostring(idx).."]: index is invalid"
    end

    local i = table.remove(self._vars[key])
    self:_VarModified(vardesc)
    return i, nil
end

function OBJECT:FindSet(key, value)
    assert(IsValid(self), "Object is not valid")
    check_ty(key, "key", "string")

    local _vardesc, errmsg = self:_PrepareVarModifySet(key)
    if errmsg ~= nil then return nil, errmsg end

    return self:_FindSet(key, value), nil
end

if SERVER then
    util.AddNetworkString("BoxRP.UData")
    util.AddNetworkString("BoxRP.UData.Variable")

    function OBJECT:_SyncCreation(target)
        net.Start("BoxRP.UData")
            net.WriteUInt(self.Id, BoxRP.UData.OBJECT_ID_BITS)
            net.WriteBit(1) -- Create
            net.WriteString(self.Type)

        if target == nil then
            net.Broadcast()
        else
            net.Send(target)
        end
    end

    gameevent.Listen("player_connect")
    hook.Add("player_connect", "BoxRP.UData", function(data)
        local ply = Entity(data.index + 1)

        for _, obj in pairs(BoxRP.UData.Objects) do
            obj:_SyncCreation(ply)
        end
    end)

    function OBJECT:_SyncUnload()
        net.Start("BoxRP.UData")
            net.WriteUInt(self.Id, BoxRP.UData.OBJECT_ID_BITS)
            net.WriteBit(0) -- Unload
        net.Broadcast()
    end

    local function WriteValue(is_set, val, item_writer)
        if is_set then
            net.WriteUInt(#val, 32)

            for _, val_item in ipairs(val) do
                item_writer(val_item)
            end
        else
            item_writer(val)
        end
    end

    function OBJECT:Sync(force)
        for varname, _ in pairs(force and self._vars or self._sendDirtyVars) do
            local value = self._vars[varname]
            local desc = self._desc.Vars[varname]
            local netmode = desc.NetMode

            if netmode ~= nil then
                net.Start("BoxRP.UData.Variable")
                    net.WriteUInt(self.Id, BoxRP.UData.OBJECT_ID_BITS)
                    net.WriteString(varname)

                    if desc.Type.Type == "Object" then
                        WriteValue(desc.Type.IsSet, value, function(item)
                            net.WriteUInt(item.Id, BoxRP.UData.OBJECT_ID_BITS)
                        end)
                    else
                        WriteValue(desc.Type.IsSet, value, net.WriteTable)
                    end

                if netmode == "recvlist" then
                    net.Send(self.Receivers)
                else
                    net.Broadcast()
                end
            end
        end

        self._sendDirtyVars = {}
    end

else
    local function ReadValue(is_set, item_reader)
        if is_set then
            local count = net.ReadUInt(32)
            local result = {}

            for i = 1, count do
                result[i] = item_reader()
            end

            return result
        else
            return item_reader()
        end
    end

    net.Receive("BoxRP.UData", function()
        local id = net.ReadUInt(BoxRP.UData.OBJECT_ID_BITS)

        if net.ReadBit() then -- Create
            local type = net.ReadString()
            local obj, objdesc, errmsg = PreCreateObject(id, type)

            if errmsg ~= nil then
                MsgN("DevM > UData > Networked object creation: ",errmsg)
                return
            end

            local obj, errmsg = CreateObject(obj, objdesc, nil)

            if errmsg ~= nil then
                MsgN("DevM > UData > Networked object creation: ",errmsg)
                return
            end
        else
            local obj = BoxRP.UData.Objects[id]

            if obj ~= nil then obj:Unload() end
        end
    end)

    net.Receive("BoxRP.UData.Variable", function()
        local id = net.ReadUInt(BoxRP.UData.OBJECT_ID_BITS)
        local obj = BoxRP.UData.Objects[id]
        if obj == nil then return end

        local varname = net.ReadString()

        local vardesc = obj._desc.Vars[varname]

        if vardesc.Type.Type == "Object" then
            obj._vars[varname] = ReadValue(vardesc.Type.IsSet, function()
                return BoxRP.UData.Objects[net.ReadUInt(BoxRP.UData.OBJECT_ID_BITS)]
            end)
        else
            obj._vars[varname] = ReadValue(vardesc.Type.IsSet, net.ReadTable)
        end
        self:_VarModified(vardesc)
        obj:_MarkVarValid(varname)
    end)
end

if SERVER then
    function OBJECT:SaveServer()
        self:_Save()
    end

    function OBJECT:SaveClient(client)
        BoxRP.Error("Unimplemented")
        --TODO
    end

    timer.Create("BoxRP.UData.SaveSv", 20, 0, function()
        for _, obj in pairs(BoxRP.UData.Objects) do
            obj:SaveServer(s)
        end
    end)
else
    function OBJECT:SaveClient()
        BoxRP.Error("Unimplemented")
        --TODO
        self:_Save()
    end
end

function OBJECT:_SaveXref(vardesc, value)
    SQL([[
        DELETE FROM boxrp_object_xrefs AS xrefs
            WHERE xrefs.id_owner == {id} AND xrefs.key == {varname}
    ]], { id = self.Id, varname = vardesc.Name })

    local valmulti = value
    if not vardesc.Type.IsSet then valmulti = { value } end

    for _, val in ipairs(valmulti) do
        SQL([[
            INSERT INTO boxrp_object_xrefs
                (id_owner, key, id_value)
                VALUES ({id}, {varname}, {value})
        ]], { id = self.Id, varname = vardesc.Name, value = VariableValToSQLSingle(vardesc, value)})
    end
end

function OBJECT:_SaveVar(vardesc, value)
    SQL([[
        DELETE FROM boxrp_object_vars AS vars
            WHERE vars.id == {id} AND vars.key == {varname}
    ]], { id = self.Id, varname = vardesc.Name})

    local valmulti = value
    if not vardesc.Type.IsSet then valmulti = { value } end

    for _, val in ipairs(valmulti) do
        SQL([[
            INSERT INTO boxrp_object_vars
                (id, key, value)
                VALUES ({id}, {varname}, {value})
        ]], { id = self.Id, varname = vardesc.Name, value = VariableValToSQLSingle(vardesc, value)})
    end
end

function OBJECT:_Save()
    if not IsValid(self) then return end
    if table.IsEmpty(self._saveDirtyVars) then return end

    SQL("BEGIN TRANSACTION")

    for varname, _ in pairs(self._saveDirtyVars) do
        local vardesc = self._desc.Vars[varname]
        local value = self._vars[varname]

        if vardesc.Type.Type == "Object" then
            self:_SaveXref(vardesc, value)
        else
            self:_SaveVar(vardesc, value)
        end
    end

    SQL("COMMIT TRANSACTION")
    self._saveDirtyVars = {}
end