local check_ty = BoxRP.CheckType
local SQL = BoxRP.SQLite.Query

BoxRP.UData2 = BoxRP.UData2 or {}

------ Config

local objdefs = objdefs or {}
local compdefs = compdefs or {}

local netmodes = netmodes or {}
local netmodes_specific = netmodes_specific or {}

------ Utility

local function NameObject(obj, id, saveset)
    local prefix = "BoxRP.UData2.Object["..obj.."]"

    if id ~= nil and saveset ~= nil then
        return prefix.."["..saveset..":"..tostring(id).."]"
    else
        return prefix
    end
end

local function NameComponent(obj, component, id, saveset)
    local prefix = "BoxRP.UData2.ComponentMeta["..obj.."]"
    local postfix = "["..component.."]"

    if id ~= nil and saveset ~= nil then
        return prefix.."["..saveset..":"..tostring(id).."]"..postfix
    else
        return prefix..postfix
    end
end

----- Config

local function ParseSharedParams(params)
    local netmode = check_ty(params.NetMode, "params.NetMode", {"table", "string"})
    if isstring(netmode) then netmode = {netmode} end

    return {
        SaveCl = check_ty(params.SaveCl, "params.SaveCl", "bool"),
        SaveSv = check_ty(params.SaveSv, "params.SaveSv", "bool"),
        NetMode = netmode
    }
end

function BoxRP.UData2.RegisterObj(obj_ty, params)
    check_ty(obj_ty, "obj_ty", "string")
    check_ty(params, "params", "table")

    if objdefs[obj_ty] ~= nil then
        MsgN("'boxRP > UData2 > Re-registering ", NameObject(obj_ty))
    end

    local objdef = ParseSharedParams(params)
    objdef.Type = obj_ty

    objdefs[obj_ty] = objdef
    compdefs[obj_ty] = compdefs[obj_ty] or {}
    netmodes_specific[obj_ty] = netmodes_specific[obj_ty] or {}
end

function BoxRP.UData2.RegisterComp(obj_ty, comp_name, params)
    check_ty(obj_ty, "obj_ty", "string")
    check_ty(comp_name, "comp_name", "string")
    check_ty(params, "params", "table")

    if compdefs[obj_ty] ~= nil then
        BoxRP.Error("Registering component '",comp_name,"' of unregistered object ",NameObject(obj_ty))
    end

    local compdefs = compdefs[obj_ty]
    if compdefs[comp_name] ~= nil then
        MsgN("'boxRP > UData2 > Re-registering ", NameComponent(obj_ty, comp_name))
    else
        BoxRP.UData2._Database.RegisterSupportedComponent(obj_ty, comp_name)
    end

    local compdef = ParseSharedParams(params)
    compdef.ObjType = obj_ty
    compdef.Name = comp_name
    compdef.Fields = check_ty(params.FieldParams, "params.FieldParams", "function")

    compdefs[obj_ty] = compdef
end

function BoxRP.UData2.RegisterNetMode(netmode, obj_ty, recipents)
    check_ty(netmode, "netmode", "string")
    check_ty(obj_ty, "obj_ty", {"string","nil"})
    check_ty(recipents, "recipents", "funciton")

    if obj_ty == nil then
        netmodes[netmode] = recipents
    else
        assert(netmodes[netmode] == nil)
        netmodes_specific[obj_ty][netmode] = recipents
    end
end

----- Networking

local function UD_GetRecipents(netmode, obj)
    if netmodes[netmode] ~= nil then
        return netmodes[netmode](obj)
    end

    return netmodes_specific[obj.Type][netmode](obj)
end

----- Misc

BoxRP.UData2.FIELD_TYPE = {
    NUM = 1,
    STRING = 2,
    VECTOR = 3,
    VMATRIX = 4,
    ANGLE = 5,
    ENTITY = 6,
    TABLE = 7,
    UOBJECT = 8
}

BoxRP.UData2.OBJECT_ID_BITS = 31
BoxRP.UData2.OBJECT_ID_MAX = bit.lshift(1, BoxRP.UData2.OBJECT_ID_BITS) - 1

BoxRP.RegisterType("BoxRP.UData2.ObjectId", {
    IsInstance = function(val)
        if not isnumber(val) then return false end
        if bit.tobit(val) ~= val then return false end

        return val > 0 and val <= BoxRP.UData2.OBJECT_ID_MAX
    end
})

----- Object manager

BoxRP.UData2.Managers = BoxRP.UData2.Managers or {}

local MGR = MGR or {}
MGR.__index = MGR

function BoxRP.UData2.Manager(save_set, allow_db)
    check_ty(save_set, "save_set", "string")
    check_ty(allow_db, "allow_db", "bool")

    local mgr = BoxRP.UData2.Managers[save_set]
    if mgr ~= nil then return mgr end

    local mgr = setmetatable({}, MGR)
    mgr.Instances = {}
    mgr.AllowDatabaseIO = allow_db
    mgr.SaveSet = save_set

    BoxRP.UData2.Managers[save_set] = mgr

    return mgr
end

function MGR:__tostring()
    return "BoxRP.UData2.Manager["..self.SaveSet.."]"
end

function MGR:LoadObject(oid)
    check_ty(oid, "oid", "BoxRP.UData2.ObjectId")

    if self.Instances[oid] ~= nil then return self.Instances[oid] end

    if not self.AllowDatabaseIO then return nil end

    local obj_ty = BoxRP.UData2._Database.LoadObject(self.SaveSet, oid)
    if obj_ty == nil then return nil end
    if objdefs[obj_ty] == nil then return nil end

    return self:_CreateObject(oid, obj_ty)
end

function MGR:CreateObject(type)
    check_ty(type, "type", "string")

    if not self.AllowDatabaseIO then return nil end
    if objdefs[type] == nil then return nil end

    local oid = BoxRP.UData2._Database.CreateSaveObject(self.SaveSet, type)

    return self:_CreateObject(oid, type)
end

function MGR:SaveObjects()
    if not self.AllowDatabaseIO then return end

    SQL "BEGIN TRANSACTION"
        for _, obj in pairs(self.Instances) do
            obj:Save(false)
        end
    SQL "COMMIT TRANSACTION"
end

function MGR:DeleteUnloadAll()
    for _, obj in pairs(self.Instances) do
        hook.Run("BoxRP.UData2.ObjectPreRemoved", obj)
    end

    if self.AllowDatabaseIO then
        SQL "BEGIN TRANSACTION"
            BoxRP.UData2._Database.DeleteAllObjects(self.SaveSet)
        SQL "COMMIT TRANSACTION"
    end

    self.Instances = {}
end

function MGR:Shutdown()
    self.Instances = nil
    BoxRP.UData2.Managers[self.SaveSet] = nil
end

------ Objects
local OBJ = OBJ or {}
OBJ.__index = OBJ

function MGR:_CreateObject(oid, type)
    local obj = setmetatable({}, OBJ)

    obj.Id = oid
    obj.Type = type
    obj.SaveSet = self.SaveSet
    obj.Manager = self

    self.Instances[oid] = obj

    obj:_Init()

    hook.Run("BoxRP.UData2.ObjectCreated", obj)

    return obj
end

function OBJ:__tostring()
    return NameObject(self.Type, self.Id, self.SaveSet)
end

function OBJ:_Init()
    self.Manager
end

function OBJ:IsValid()
    if self.Manager == nil then return nil end

    -- Object is currently tracked
    return self.Manager.Instances[self.Id] ~= nil
end

function OBJ:Unload()
    self.Manager.Instances[self.Id] = nil
    self.Manager = nil
end

function OBJ:DeleteUnload()
    BoxRP.UData2._Database.DeleteObject(self.SaveSet, self.Id)

    self:Unload()
end

function OBJ:Save(start_transaction)
    check_ty(start_transaction, "start_transaction", "bool")

    -- TODO
end