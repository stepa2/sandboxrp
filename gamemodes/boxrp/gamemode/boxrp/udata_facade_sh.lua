local check_ty = BoxRP.CheckType

BoxRP.UDataFacade = {}
BoxRP.UDataFacade.List = {}

local FACT = {}
FACT.__index = FACT

local FACADE = {}
FACADE.__index = FACADE

function BoxRP.UDataFacade.Register(objname)
    check_ty(objname, "objname", "string")

    local oldfact = BoxRP.UDataFacade.List[objname]

    local fact = setmetatable({}, FACT)
    fact.ObjectType = objname
    fact.Metatable = setmetatable({}, FACADE)
    fact.Metatable.__index = fact.Metatable
    fact.Instances = oldfact and oldfact.Instances or {}

    BoxRP.UDataFacade.List[objname] = fact

    BoxRP.RegisterType("BoxRP.UDataFacade.Facade("..objname..")", { IsInstance = function(val)
        if not istable(val) then return false end
        return debug.getmetatable(val) == fact.Metatable
    end})

    return fact
end

hook.Run("BoxRP.UData.ObjectCreated", "BoxRP.UDataFacade", function(obj)
    local fact = BoxRP.UDataFacade.List[obj.Type]
    local oid = obj.Id

    if fact ~= nil and fact.Instances[oid] == nil then
        fact:_CreateFacade(obj)
    end
end)

hook.Run("BoxRP.UData.ObjectPreRemoved", "BoxRP.UDataFacade", function(obj)
    local fact = BoxRP.UDataFacade.List[obj.Type]
    local oid = obj.Id

    if fact ~= nil then
        fact.Instances[oid] = nil
    end
end)

function FACT:_CreateFacade(obj)
    local facade = setmetatable({}, self.Metatable)
    facade.Data = obj
    self.Instances[oid] = facade
    return facade
end

function FACT:Load(id)
    check_ty(id, "id", "BoxRP.UData.ObjectId")

    if self.Instances[id] ~= nil then return self.Instances[id] end

    local obj, err = BoxRP.UData.LoadObject(id)

    if err ~= nil then return nil, err end

    if obj.Type ~= self.ObjectType then
        return nil, tostring(obj)..": excepted type '"..self.ObjectType.."'"
    end

    local facade = self:_CreateFacade(obj)
    return facade, nil
end

function FACT:Create(vars)
    check_ty(vars, "vars", "table")

    local obj, err = BoxRP.UData.CreateObject(self.ObjectType, vars)

    if err ~= nil then return nil, err end

    local facade = self:_CreateFacade(obj)
    return facade, nil
end

function FACADE:Unload()
    assert(IsValid(self), "Facade is invalid")
    self.Data:Unload()
end

function FACADE:Delete()
    assert(IsValid(self), "Facade is invalid")
    self.Data:Delete()
end

function FACADE:IsValid()
    return self.Data:IsValid()
end