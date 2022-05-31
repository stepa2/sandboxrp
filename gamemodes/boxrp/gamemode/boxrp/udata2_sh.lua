local check_ty = BoxRP.CheckType

------------------

local LIB = BoxRP.UData2 or {}
BoxRP.UData2 = LIB


--[[
    local objdefs: table(obj_ty: string, {
        Save: { Cl: bool, Sv: bool }
        NetMode: array(string)
    })
]]
local objdefs = objdefs or {}

--[[
    local objcomps: table(obj_ty: string, table(comp_name: string, {
        Save: { Cl: bool|nil, Sv: bool|nil }
        NetMode: nil|array(string)
        Fields: table(field_name: string, {
            Save: { Cl: bool|nil, Sv: bool|nil }
            NetMode: nil|array(string)
            ForceNetMode: nil|array(string)
            Type: .FieldTypeVal
            AutoGetter: string|nil
            AutoSetter: string|nil
            Unique: bool
            FastCheck: bool
        })
    }))
]]
local objcomps = objcomps or {}

--[[
    local netmodes: table(obj_ty: string, 
        table(netmode: string, recipents: fn(obj: .Object, recipents: CRecipentList)))
]]
local objnetmodes = objnetmodes or {}

--[[
    local objmetas: table(obj_ty: string, table(any, any))
]]
local objmetas = objmetas or {}

--[[
    local globalnetmodes: table(netmode: string, recipents: fn(obj: .Object, recipents: CRecipentList))
]]
local globalnetmodes = globalnetmodes or {}

--[[
    local objhooks: table(obj_ty: string, table(comp_name: string, table(field_key: string
        table(hookname: string, hook: fn(obj: .Object(obj_ty), old: nil|.FieldValue, new: nil|.FieldValue)))))
]]
local objhooks = objhooks or {}

------------------

LIB.OBJECT_ID_BITS = 31
LIB.OBJECT_ID_MAX = bit.lshift(1, LIB.OBJECT_ID_BITS) - 1

BoxRP.RegisterType("BoxRP.UData2.ObjectId", {
    IsInstance = function(obj)
        if not isnumber(obj) then return false end
        if bit.tobit(obj) ~= obj then return false end
        return obj > 0 and obj <= LIB.OBJECT_ID_MAX
    end
})

------------------

local FIELD_TYPE = {
    BOOL = 1,
    NUM = 2,
    STRING = 3,
    VECTOR = 4,
    VMATRIX = 5,
    ANGLE = 6,
    ENTITY = 7,
    TABLE = 8,
    UOBJECT = 9,
    UOBJECT_SET = 10,
}
LIB.FIELD_TYPE = FIELD_TYPE

do
    local field_checkers = {
        [FIELD_TYPE.BOOL] = { isbool, "Not a boolean nor nil" },
        [FIELD_TYPE.NUM] = { isnumber, "Not a number nor nil" },
        [FIELD_TYPE.STRING] = { isstring, "Not a string nor nil" },
        [FIELD_TYPE.VECTOR] = { isvector, "Not a vector nor nil" },
        [FIELD_TYPE.VMATRIX] = { ismatrix, "Not a matrix nor nil" },
        [FIELD_TYPE.ANGLE] = { isangle, "Not an angle nor nil" },
        [FIELD_TYPE.ENTITY] = { IsEntity, "Not an entity nor nil" },
        [FIELD_TYPE.TABLE] = { istable, "Not a table nor nil" },
        [FIELD_TYPE.UOBJECT] = { function(v)
            return BoxRP.IsType(v, "BoxRP.UData2.Object")
        end, "Not a UData object nor nil" },
        [FIELD_TYPE.UOBJECT_SET] = { function(v)
            return BoxRP.IsType(v, "BoxRP.UData2.ObjectSet")
        end, "Not a UData object set nor nil" }
    }

    local function CheckTable(tbl, visited_tables, parent_path)
        visited_tables[tbl] = parent_path

        for key, value in pairs(tbl) do
            local key_path = parent_path.."."..tostring(value)

            if not (isbool(key) or isnumber(key) or isstring(key) or IsEntity(key)) then
                return "Key "..key_path.." has invalid type "..type(key)
            end

            if isbool(value) or isstring(value) or isnumber(value) then continue end
            if isangle(value) or ismatrix(value) or isvector(value) then continue end
            if IsEntity(value) then continue end

            if istable(value) then
                if visited_tables[value] ~= nil then
                    return "Value at "..key_path.." repeated at '"..visited_tables[value].."'"
                elseif BoxRP.IsType(value, "BoxRP.UData2.Object") then
                    return "Value at "..key_path.." has invalid type BoxRP.UData2.Object"
                elseif BoxRP.IsType(value, "BoxRP.UData2.ObjectSet") then
                    return "Value at "..key_path.." has invalid type BoxRP.UData2.ObjectSet"
                end

                local errmsg = CheckTable(value, visited_tables, key_path)
                if errmsg ~= nil then return errmsg end
            else
                return "Value at "..key_path.." has invalid type "..type(value)
            end
        end
    end

    function LIB.CheckField(value, excepted_type, fast_check)
        check_ty(excepted_type, "excepted_type", "number")
        check_ty(fast_check, "fast_check", "bool")

        if value == nil then return nil end -- Nil is supported everywhere

        local checker, errmsg = unpack(field_checkers[excepted_type])
        if not checker(value) then return errmsg end

        if excepted_type == FIELD_TYPE.TABLE and not fast_check then
            return CheckTable(value, {}, "")
        else
            return nil
        end
    end
end

do
    function ParseNetMode(val, allow_nil)
        local netmode = check_ty(val, "??", {"table", "string", Either(allow_nil, "nil", nil)})
        if isstring(netmode) then
            return {netmode}
        else
            return netmode
        end
    end

    function LIB.RegisterObject(obj_ty, params)
        check_ty(obj_ty, "obj_ty", "string")
        check_ty(params, "params", "table")

        if objdefs[obj_ty] ~= nil then
            MsgN("BoxRP > UData2 > Overwriting object defenition of '",obj_ty,"'")
        end

        local objdef = {}
        objdef.Save = {
            Cl = false,
            Sv = check_ty(params.SaveSv, "params.SaveSv", "bool")
        }
        objdef.NetMode = ParseNetMode(params.NetMode, false)

        objdefs[obj_ty] = objdef

        if objcomps[obj_ty] == nil then objcomps[obj_ty] = {} end
        if objnetmodes[obj_ty] == nil then objnetmodes[obj_ty] = {} end
    end

    function LIB.RegisterComp(obj_ty, comp_name, params)
        check_ty(obj_ty, "obj_ty", "string")
        check_ty(comp_name, "comp_name", "string")
        check_ty(params, "params", "table")

        if objcomps[obj_ty] == nil then objcomps[obj_ty] = {} end

        if objcomps[obj_ty][comp_name] ~= nil then
            MsgN("BoxRP > UData2 > Overwriting component defenition of '",obj_ty,".",comp_name,"'")
        end

        local compdef = {}
        compdef.Save = {
            Cl = false,
            Sv = check_ty(params.SaveSv, "params.SaveSv", {"bool", "nil"})
        }
        compdef.NetMode = ParseNetMode(params.NetMode, true)

        compdef.Fields = {}
        for fieldname, fieldparams in pairs(params.Fields) do
            local fielddef = {}
            fielddef.Save = {
                Cl = false,
                Sv = check_ty(fieldparams.SaveSv, "params.Fields.??.SaveSv", {"bool", "nil"})
            }
            fielddef.NetMode = ParseNetMode(fieldparams.NetMode, true)
            fielddef.ForceNetMode = ParseNetMode(fieldparams.ForceNetMode, true)
            fielddef.Type = check_ty(fieldparams.Type, "params.Fields.??.Type", "number")
            fielddef.AutoGetter = check_ty(fieldparams.AutoGetter, "params.Fields.??.AutoGetter", {"string", "nil"})
            fielddef.AutoSetter = check_ty(fieldparams.AutoSetter, "params.Fields.??.AutoSetter", {"string", "nil"})
            fielddef.Unique = check_ty(fieldparams.Unique, "params.Fields.??.Unique", {"bool","nil"}) or false
            fielddef.FastCheck = check_ty(fieldparams.FastCheck, "params.Fields.??.FastCheck", {"bool","nil"}) or false

            compdef.Fields[fieldname] = fielddef
        end

        objcomps[obj_ty][comp_name] = compdef
    end
end



function LIB.RegisterNetMode(netmode, obj_ty, recipent_fn)
    check_ty(netmode, "netmode", "string")
    check_ty(obj_ty, "obj_ty", {"string","nil"})
    check_ty(recipent_fn, "recipent_fn", "function")

    if obj_ty == nil then
        if globalnetmodes[netmode] ~= nil then
            MsgN("BoxRP > UData2 > Overwriting global netmode '",netmode,"'")
        end

        globalnetmodes[netmode] = recipent_fn
    else
        if objnetmodes[obj_ty] == nil then objnetmodes[obj_ty] = {} end

        if objnetmodes[obj_ty][netmode] ~= nil then
            MsgN("BoxRP > UData2 > Overwriting netmode '",netmode,"' for object '",obj_ty,"'")
        end

        objnetmodes[obj_ty][netmode] = recipent_fn
    end
end

function LIB.GetMetatable(obj_ty)
    check_ty(obj_ty, "obj_ty", "string")
    if objmetas[obj_ty] == nil then objmetas[obj_ty] = {} end

    return objmetas[obj_ty]
end

function LIB.RegisterHook(obj_ty, comp_name, field_key, hook_name, hook)
    check_ty(obj_ty, "obj_ty", "string")
    check_ty(comp_name, "comp_name", "string")
    check_ty(field_key, "field_key", "string")
    check_ty(hook_name, "hook_name", "string")
    check_ty(hook, "hook", "function")

    local comps = objhooks[obj_ty]
    if comps == nil then comps = {} objhooks[obj_ty] = comps end

    local fields = comps[comp_name]
    if fields == nil then fields = {} comps[comp_name] = fields end

    local hooks = fields[field_key]
    if hooks == nil then hooks = {} fields[field_key] = hooks end

    if hooks[hook_name] ~= nil then
        MsgN("BoxRP > UData2 > Overwriting hook '",hook_name,"' for '",obj_ty,".Data.",comp_name,".",field_key,"'")
    end

    hooks[hook_name] = hook
end

-------------------------------------------

local MGR = MGR or {}
MGR.__index = MGR

LIB.Managers = LIB.Managers or {}
LIB.Cur = LIB.Cur

function LIB.Manager(save_set, allow_db)
    check_ty(save_set, "save_set", "string")
    check_ty(allow_db, "allow_db", "bool")

    do
        local mgr = LIB.Managers[save_set]
        if mgr ~= nil then
            if mgr.AllowDatabaseIO ~= allow_db then
                local w1 = allow_db and "disabled" or "enabled"
                local w2 = allow_db and "enabled" or "disabled"
                MsgN("BoxRP > UData2 > Database saving is ",w1,", but should be ",w2,". Reload the map.")
            end

            return mgr
        end
    end

    local mgr = setmetatable({}, MGR)
    mgr.Instances = {}
    mgr.SaveSet = save_set
    mgr.AllowDatabaseIO = allow_db

    LIB.Managers[save_set] = mgr

    return mgr
end

function MGR:__tostring()
    return "BoxRP.UData2.Manager["..self.SaveSet.."]"
end

function MGR:IsValid()
    return LIB.Managers[self.SaveSet] == self
end

function MGR:Shutdown()
    assert(self:IsValid())

    for _, obj in pairs(self.Instances) do
        obj:Unload()
    end

    self.Instances = nil

    LIB.Managers[self.SaveSet] = nil
    if LIB.Cur == self then LIB.Cur = nil end
end


local OBJ_OUTER = OBJ_OUTER or {}
local OBJ = OBJ or {}

function MGR:CreateObject(type, oid)
    check_ty(type, "type", "string")
    check_ty(oid, "oid", {"BoxRP.UData2.ObjectId", "nil"})
    assert((oid == nil) == self.AllowDatabaseIO)
    assert(objdefs[type] ~= nil, "'type' is not a valid object type")

    if oid ~= nil and self.Instances[oid] then
        return self.Instances[oid]
    end

    if self.AllowDatabaseIO then
        oid = BoxRP.UData2._Database.CreateSaveObject(self.SaveSet, type)
    end

    assert(oid ~= nil)

    local obj = setmetatable({}, OBJ_OUTER)
    obj.Id = oid
    obj.SaveSet = self.SaveSet
    obj.Type = type
    obj.Manager = self
    obj._comps = {}
    obj._compMetatables = {}
    obj.Data = setmetatable({},{
        __index = function(_, key)
            return obj:_CompIndex(key)
        end,
        __newindex = function(_, key, value)
            BoxRP.Error("Assigning anything to .Data of BoxRP.UData2.Object is not allowed")
        end
    })

    self.Instances[oid] = obj

    return obj
end

BoxRP.RegisterType("BoxRP.UData2.Object", function(val)
    return istable(val) and debug.getmetatable(val) == OBJ_OUTER
end)

function OBJ_OUTER:__index(key)
    local value = OBJ[key]
    if value ~= nil then return value end

    local value = (objmetas[self.Type] or {})[key]
    if value ~= nil then return value end
end

function OBJ_OUTER:__tostring()
    return "BoxRP.UData2.Object["..self.SaveSet.."]["..tostring(self.Id).."]"
end

function OBJ:_CompIndex(key)
    if objcomps[self.Type][key] == nil then return nil end

    if self._comps[key] == nil then
        self._comps[key] = {}
        self._compMetatables[key] = setmetatable({}, {
            __index = function(_, key2)
                return self:_CompFieldIndex(key, key2)
            end,
            __newindex = function(_, key2, value)
                self:_CompFieldNewindex(key, key2, value)
            end
        })
    end

    return self._compMetatables[key]
end

local TRIVIAL_FIELD_TYPES = {
    [FIELD_TYPE.BOOL] = true,
    [FIELD_TYPE.STRING] = true,
    [FIELD_TYPE.NUM] = true,
    [FIELD_TYPE.ENTITY] = true
}

function OBJ:_CompFieldIndex(comp_name, field_key)
    local fieldinfo = objcomps[self.Type][comp_name].Fields[field_key]
    if fieldinfo == nil then return nil end

    local rawdata = self._comps[comp_name][field_key]

    if fieldinfo.Type == FIELD_TYPE.UOBJECT then
        return rawdata
    elseif fieldinfo.Type == FIELD_TYPE.UOBJECT_SET then
        if rawdata == nil then
            -- TODO rawdata = ?
        end

        return rawdata
    elseif TRIVIAL_FIELD_TYPES[fieldinfo.Type] then
        return rawdata
    else
        -- TODO: table, vector, angle, matrix handling
    end
end

function OBJ:_CompFieldNewindex(comp_name, field_key, field_value)
    local fieldinfo = objcomps[self.Type][comp_name].Fields[field_key]
    if fieldinfo == nil then
        BoxRP.Error("Attempt to assign value to non-existent field '",field_key,"' of '",comp_name,"' of object ",self)
    end

    if fieldinfo.Type == FIELD_TYPE.UOBJECT_SET then
        BoxRP.Error("Attempt to assign value to field of type UOBJECT_SET")
    end


    local errmsg = LIB.CheckField(field_value, fieldinfo.Type, fieldinfo.FastCheck)
    if errmsg ~= nil then
        BoxRP.Error("Error assigning value to field '",field_key,"' of '",comp_name,"' of object ",self,": ",errmsg)
    end

    assert(not fieldinfo.Unique, "TODO: Unique constraint support")

    local prev = self._comps[comp_name][field_key]

    if prev == field_value then return end

    self:_HookPreChanged(comp_name, field_key, prev, field_value)
    self._comps[comp_name][field_key] = field_value

    self:_HookPostChanged(comp_name, field_key, field_value)
end