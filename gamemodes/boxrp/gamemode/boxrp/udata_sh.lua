local check_ty = BoxRP.CheckType

BoxRP.UData = BoxRP.UData or {}

local ObjectDefs = BoxRP.UData.ObjectDefs
local GetFieldDef = BoxRP.UData.GetFieldDef
local CheckFieldType = BoxRP.UData.CheckFieldType

local OBJ_OUTER = OBJ_OUTER or {}
local OBJ = OBJ or {}
BoxRP.UData.Object = OBJ

BoxRP.UData.Objects = BoxRP.UData.Objects or {}

function BoxRP.UData._Create(objtype, id)
    check_ty(objtype, "objtype", "string")
    check_ty(id, "id", "number")

    local def = BoxRP.UData.ObjectDefs[objtype]

    if def == nil then
        BoxRP.Error("Attempt to create object of invalid type ",objtype)
    end

    if BoxRP.UData.Objects[id] ~= nil then
        BoxRP.Error("Attempt to create already-created object #",id)
    end

    local obj = setmetatable({}, OBJ)
    obj.Id = id
    obj.Type = objtype
    obj._data = {}
    obj._def = def

    BoxRP.UData.Objects[id] = obj

    hook.Run("BoxRP.UData.ObjectCreated", obj)

    return obj
end

if SERVER then
    function OBJ:_Raw_LoadLazyObject(key, oid, obj_type)
        local obj = BoxRP.UData.Load(oid)
        if obj_type ~= nil and obj.Type ~= obj_type then
            obj = nil
        end

        -- BoxRP.UData.FieldChanged not called here
        self._data[key] = obj
    end
end


function OBJ:Raw_Get(key)
    local fielddef = GetFieldDef(self._def, key)
    if fielddef == nil then
        BoxRP.Error("Attempt to access undefined field '",key,"' of ",self)
    end

    local value = self._data[key]
    if istable(fielddef.Type) and fielddef.Type[1] == "object_lazy" and isnumber(value) then
        if CLIENT then
            return nil
        else
            self:_Raw_LoadLazyObject(key, value, fielddef.Type[2])
            return self._data[key]
        end
    end

    return value
end

function OBJ:Raw_Set(key, value, unchecked)
    key = tostring(key)

    if not unchecked then
        local fielddef = GetFieldDef(self._def, key)
        if fielddef == nil then
            BoxRP.Error("Attempt to set undefined field '",key,"' of ",self)
        end

        if not CheckFieldType(value, fielddef.Type) then
            BoxRP.Error("Attempt to set field '",key,"' of ",self," to invalid value ",value)
        end
    end

    local old_value = self._data[key]

    if old_value == value then return end

    hook.Run("BoxRP.UData.FieldChanged", self, key, old_value, value)

    self._data[key] = value
end

function OBJ:Raw_Iterate(full_load)
    if full_load and SERVER then
        -- TODO
    end

    -- TODO
end

function OBJ:Raw_IterateArray(full_load)
    -- TODO
end

function OBJ:Unload()
    hook.Run("BoxRP.UData.ObjectPreUnloaded", self)
    BoxRP.UData.Objects[self.Id] = nil
end

function OBJ:IsValid()
    return BoxRP.UData.Objects[self.Id] == self
end

function OBJ_OUTER:__tostring()
    return "BoxRP.UData.Object["..self.Type.."#"..tostring(self.Id).."]"
end

function OBJ_OUTER:__index(k)
    if OBJ[k] ~= nil then return OBJ[k] end

    local meta = ObjectDefs[self.Type].Metatable
    if meta and meta[k] ~= nil then return meta[k] end
end