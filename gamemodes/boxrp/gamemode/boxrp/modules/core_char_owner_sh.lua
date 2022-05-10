local check_ty = BoxRP.CheckType

BoxRP.UData.RegisterVar("core.char", "core.owner", {
    Type = { Type = "table", IsSet = false },
    ErrorHandling = { WhenMissing = "set_default", WhenMultiple = "set_default", Default = {}},
    SaveOnClient = false, SaveOnServer = false,
    Recipents = "everyone",
    ItemChecker = function(var)
        if not istable(var) then return "not a table" end
        if var[1] == nil or IsEntity(var[1]) then return nil end
        return "var[1] is not an Entity|nil"
    end
})

function BoxRP.StdObj.Char:CoreGetOwner()
    return self.Data:GetVar("core.owner")[1]
end

function BoxRP.StdObj.Char:CoreSetOwner(owner)
    check_ty(owner, "owner", {"nil", "Entity"})

    assert(self.Data:SetVar("core.owner", { owner }))
end

BoxRP.UData.AddItemChangedHook("core.char", "core.owner", "core.owner.networking", function(obj, old, new)
    if IsEntity(old) and old:IsPlayer() then
        obj.Receivers:RemovePlayer(old)
    end

    if IsEntity(new) and new:IsPlayer() then
        obj.Receivers:AddPlayer(new)
    end
end)