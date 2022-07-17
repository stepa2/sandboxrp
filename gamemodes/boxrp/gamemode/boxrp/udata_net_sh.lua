BoxRP.UData = BoxRP.UData or {}

local OBJECT_ID_BITS = BoxRP.UData.OBJECT_ID_BITS

if SERVER then
    util.AddNetworkString("BoxRP.UData.Field")
    util.AddNetworkString("BoxRP.UData.Object")

    local function WriteField(obj, key, type)
        local value = obj:Raw_Get(key)

        if value == nil then
            net.WriteBool(false)
            return
        else
            net.WriteBool(true)
        end

        if type == "bool" then
            net.WriteBit(value)
        elseif type == "number" then
            net.WriteDouble(value)
        elseif type == "string" then
            net.WriteString(value)
        elseif type == "vector" then
            net.WriteVector(value)
        elseif type == "angle" then
            net.WriteAngle(value)
        elseif type == "matrix" then
            net.WriteMatrix(value)
        elseif type == "entity" then
            net.WriteEntity(value)
        elseif isarray(type) then -- {"object", ...} or {"object_lazy", ...}
            net.WriteUInt(value.Id, OBJECT_ID_BITS)
        else
            STPLib.Error("Invalid type ",type)
        end
    end

    local function SendField(recip, obj, key)
        local field_type = BoxRP.UData.GetFieldDef(obj.Type, key).Type

        net.Start("BoxRP.UData.Field")
            net.WriteUInt(obj.Id, OBJECT_ID_BITS)
            net.WriteString(key)
            WriteField(obj, key, field_type)
        net.Send(recip)
    end

    local function SendObjLoaded(recip, obj)
        net.Start("BoxRP.UData.Object")
            net.WriteUInt(obj.Id, OBJECT_ID_BITS)
            net.WriteString(obj.Type)
        net.Send(recip)
    end

    local function SendObjUnloaded(recip, obj)
        net.Start("BoxRP.UData.Object")
            net.WriteUInt(obj.Id, OBJECT_ID_BITS)
            net.WriteString("")
        net.Send(recip)
    end

    hook.Add("BoxRP.UData.FieldChanged", "BoxRP.UData.SendField", function(obj, field, _, _)
        local field_def = BoxRP.UData.GetFieldDef(obj.Type, field)
        local netmode = field_def.NetMode or obj._def.Obj.NetMode

        local recip = BoxRP.UData.GetRecipents(obj, netmode)

        if recip:GetCount() ~= 0 then
            SendField(recip, obj, field)
        end
    end)

    hook.Add("BoxRP.UData.ObjectLoaded", "BoxRP.UData.SendObjLoaded", function(obj)
        local recip = BoxRP.UData.GetRecipents(obj, obj._def.Obj.NetMode)

        if recip:GetCount() ~= 0 then
            SendObjLoaded(recip, obj)
        end
    end)
    hook.Add("BoxRP.UData.ObjectPreUnloaded", "BoxRP.UData.SendObjUnloaded", function(obj)
        local recip = BoxRP.UData.GetRecipents(obj, obj._def.Obj.NetMode)

        if recip:GetCount() ~= 0 then
            SendObjUnloaded(recip, obj)
        end
    end)

    local function RecipentListIncludes(recip, ply)
        local cnt1 = recip:GetCount()
        recip:RemovePlayer(ply)
        return recip:GetCount() ~= cnt1
    end

    local function SendObjectsInitial(ply)
        local real_recip = RecipientFilter()
        real_recip:AddPlayer(ply)

        for _, obj in pairs(BoxRP.UData.Objects) do
            local def = obj._def

            local obj_recip = BoxRP.UData.GetRecipents(obj, def.Obj.NetMode)
            if not RecipentListIncludes(obj_recip, ply) then
                continue
            end

            SendObjLoaded(real_reicp, obj)

            if def.EveryField ~= nil and def.EveryField.NetMode ~= nil then
                local efield_recip = BoxRP.UData.GetRecipents(obj, def.EveryField.NetMode)

                if not RecipentListIncludes(efield_recip, ply) then
                    continue
                end
            end

            for field, _ in pairs(obj._data) do
                if def.Fields ~= nil and def.Fields[field].NetMode ~= nil then
                    local field_recip = BoxRP.UData.GetRecipents(obj, def.Fields[field].NetMode)

                    if not RecipentListIncludes(field_recip, ply) then
                        continue
                    end
                end

                SendField(real_recip, obj, field)
            end
        end
    end

    gameevent.Listen("player_connect")
    hook.Add("player_connect", "BoxRP.UData.SendObjects", function(data)
        if data.bot == 1 then return end

        local ply = Entity(data.index + 1)

        if IsValid(ply) then
            SendObjectsInitial(ply)
        end
    end)


elseif CLIENT then
    local function ReadField(type)
        if not net.ReadBit() then
            return nil
        end

        if type == "bool" then
            return net.ReadBit()
        elseif type == "number" then
            return net.ReadData()
        elseif type == "string" then
            return net.ReadString()
        elseif type == "vector" then
            return net.ReadVector()
        elseif type == "angle" then
            return net.ReadAngle()
        elseif type == "matrix" then
            return net.ReadMatrix()
        elseif type == "entity" then
            return net.ReadEntity()
        elseif isarray(type) then -- {"object", ...} or {"object_lazy", ...}
            local oid = net.ReadUInt(OBJECT_ID_BITS)

            local obj = BoxRP.UData.Objects[oid]
            assert(obj ~= nil, "Received invalid object")

            return obj
        else
            STPLib.Error("Invalid type ",type)
        end
    end

    net.Receive("BoxRP.UData.Object", function()
        local oid = net.ReadUInt(OBJECT_ID_BITS)
        local obj_ty = net.ReadString()

        -- Remove existing object
        local obj = BoxRP.UData.Objects[oid]
        if IsValid(obj) then
            obj:Unload()
        end

        if obj_ty ~= "" then
            BoxRP.UData._Create(obj_ty, oid)
        end
    end)

    net.Receive("BoxRP.UData.Field", function()
        local oid = net.ReadUInt(OBJECT_ID_BITS)
        local key = net.ReadString()

        local obj = BoxRP.UData.Objects[oid]
        if obj ~= nil then
            ErrorNoHalt("BoxRP > UData > Receiving data for non-existant object ",oid,"\n")
            return
        end

        local type = BoxRP.UData.GetFieldDef(obj.Type, key).Type
        local value = ReadField(type)

        obj:Raw_Set(key, value, true) -- Unchecked
    end)
end