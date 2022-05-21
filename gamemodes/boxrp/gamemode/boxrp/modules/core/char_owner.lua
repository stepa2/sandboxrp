local FIELDTY = BoxRP.UData2.FIELD_TYPE

BoxRP.UData2.RegisterComp("core_char", "core_owner", {
    SaveSv = true, SaveCl = false, NetMode = "everyone", {
        PlayerData = {
            Type = {FIELDTY.UOBJECT, "core_player"}, ForceNetMode = "none",
            AutoGetter = "Core_GetOwnerData"
        },
        Entity = {
            Type = FIELDTY.ENTITY, SaveSv = false,
            AutoGetter = "Core_GetOwnerEnt"
        }
    }
})

BoxRP.UData2.RegisterNetMode("ownerply", "core_char", function(char, recip)
    local owner = char:Core_GetOwnerEnt()

    if IsValid(owner) and owner:IsPlayer() and not owner:IsBot() then
        recip:AddPlayer(owner)
    end
end)

if SERVER then
    local CHAR = BoxRP.UData2.GetMetatable("core_char")

    function CHAR:Core_SetOwnerData(data, update_ent)
        local comp = self.Data.core_owner

        if update_ent then
            if data ~= nil then
                local ownerent = data:Core_GetEntity()
                if ownerent ~= nil then
                    comp.Entity = ownerent
                end
            else
                comp.Entity = nil
            end

        end

        comp.PlayerData = data
    end

    function CHAR:Core_SetOwnerEnt(ent, update_data)
        local comp = self.Data.core_owner

        if update_data then
            if IsValid(ent) and ent.BoxRP_PlayerData ~= nil then
                comp.PlayerData = ent.BoxRP_PlayerData
            else
                comp.PlayerData = nil
            end
        end

        comp.Entity = ent
    end
end

BoxRP.UData2.RegisterHook("core_char", "core_owner", "Entity", "BoxRP.ModuleCore.Char", function(obj, old, new)
    if old ~= nil then old.BoxRP_Character = nil end
    if IsValid(new) then
        new.BoxRP_Character = obj
        if SERVER then
            new:CallOnRemove("BoxRP.ModuleCore.Char", function()
                if not IsValid(obj) then return end
                local comp = obj.Data.core_owner

                if comp.Entity == new then
                    obj:Core_SetOwnerEnt(nil, true)
                end
            end)
        end
    end
end)