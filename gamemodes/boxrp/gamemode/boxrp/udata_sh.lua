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

        hook.Run("BoxRP.UData.FieldChanged", self, key, nil, obj)
        self._data[key] = obj
    end

    function OBJ:_Raw_LoadAllLazyObjects()
        for field, fieldval in pairs(self._data) do
            if not isnumber(fieldval) then continue end

            local fieldty = GetFieldDef(self._def, field).Type
            if not (istable(fieldty) and fieldty[1] == "object_lazy") then continue end

            self:_Raw_LoadLazyObject(field, fieldval, fieldty[2])
        end
    end
end


function OBJ:Raw_Get(key)
    key = tostring(key)

    local fielddef = GetFieldDef(self._def, key)
    if fielddef == nil then
        BoxRP.Error("Attempt to access undefined field '",key,"' of ",self)
    end

    if istable(fielddef.Type) and fielddef.Type[1] == "object_lazy" and isnumber(self._data[key]) and SERVER then
        self:_Raw_LoadLazyObject(key, self._data[key], fielddef.Type[2])
    end

    local value = self._data[key]

    -- {"object", ...} or {"object_lazy", ...} 
    if istable(fielddef.Type) and value ~= nil and not value:IsValid() then
        -- BoxRP.UData.FieldChanged not called here
        self._data[key] = nil
        return nil
    end

    return value
end

function OBJ:Raw_Set(key, value, unchecked)
    key = tostring(key)

    local fielddef

    if not unchecked then
        fielddef = GetFieldDef(self._def, key)
        if fielddef == nil then
            BoxRP.Error("Attempt to set undefined field '",key,"' of ",self)
        end

        if not CheckFieldType(value, fielddef.Type) then
            BoxRP.Error("Attempt to set field '",key,"' of ",self," to invalid value ",value)
        end
    end

    local old_value = self._data[key]

    if old_value == value then return end
    
    local run_hook = true
    if isnubmer(value) then
        if fielddef == nil then
            fielddef = GetFieldDef(self._def, key)
        end
        
        if istable(fielddef.Type) and fielddef.Type[1] == "object_lazy" then
            run_hook = false -- You are not supposed to see this
        end
    end

    if run_hook then
        hook.Run("BoxRP.UData.FieldChanged", self, key, old_value, value)
    end

    self._data[key] = value
end

function OBJ:Raw_Iterate(full_load)
    if full_load and SERVER then
        self:_Raw_LoadAllLazyObjects()
    end

    local iterator_fn = function(state)
        local k = next(self._data, state.PrevK)
        state.PrevK = k

        if k == nil then return end
        local v = self:Raw_Get(k)
        if v == nil then return end

        return k, v
    end

    return iterator_fn, {}
end

function OBJ:Raw_IterateArray(full_load)
    if full_load and SERVER then
        self:_Raw_LoadAllLazyObjects()
    end

    local iterator_fn = function(state)
        local index = state.Index

        local v = self:Raw_Get(index)
        if v == nil then return end

        state.Index = index + 1

        return index, v
    end

    return iterator_fn, { Index = 1 }
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

function BoxRP.UData.FindByFieldValue(type, key, value, search_db)
    key = tostring(key)

    local results = {}

    for oid, obj in pairs(BoxRP.UData.Objects) do
        if obj.Type == type and obj._data[key] == value then
            results[oid] = true
        end
    end

    if SERVER and search_db then
        local q_val, q_is_objref = BoxRP.UData.Util_MemToSql(
            value, BoxRP.UData.GetFieldDef(type, key).Type
        )

        local q_result = BoxRP.UData.DB_FindByField(type, key, q_val, q_is_objref)

        local load_ids = {}

        for i, q_ret in ipairs(q_result) do
            load_ids[i] = q_ret.id
            results[q_ret.id] = true
        end

        BoxRP.UData.LoadMany(load_ids)
    end

    local results2 = {}
    for oid, _ in pairs(results) do
        table.insert(results2, BoxRP.UData.Objects[oid])
    end

    return results2
end


function BoxRP.UData.RegHook(objty, key, hook_name, callback)
    hook.Add("BoxRP.UData.FieldChanged", "RegisterHook$"..objty.."$"..key.."$"..hook_name, 
    function(obj, fieldname, old, new)
        if obj.Type == objty and fieldname == key then
            callback(obj, old, new)
        end
    end)
end

function BoxRP.UData.RegHookAll(objty, hook_name, callback)
    hook.Add("BoxRP.UData.FieldChanged", "RegisterHook$"..objty.."$"..hook_name, 
    function(obj, fieldname, old, new)
        if obj.Type == objty then
            callback(obj, key, old, new)
        end
    end)
end

function BoxRP.UData.RegHookLoaded(objty, hook_name, callback)
    hook.Add("BoxRP.UData.ObjectLoaded", "RegisterHook$"..objty.."$"..hook_name, function(obj)
        if obj.Type == objty then callback(obj) end
    end)
end

function BoxRP.UData.RegHookUnloaded(objty, hook_name, callback)
    hook.Add("BoxRP.UData.ObjectUnloaded", "RegisterHook$"..objty.."$"..hook_name, function(obj)
        if obj.Type == objty then callback(obj) end
    end)
end