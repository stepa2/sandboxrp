BoxRP.RequireModules({"core_ply"})

local UData = BoxRP.UData

local RField = UData.RegField
local RFieldTable = UData.RegTableField
local RObject = UData.RegObject

RObject("core.char", {
    Save = true,
    NetMode = {"everyone"}
})

local CHAR = BoxRP.UData.GetMetatable("core.char")

RField("core.player", "core.cur_char", {
    Type = {"object", "core.player"},
    SaveOverride = false,
    AutoGetter = "Core_CurrentChar",
    AutoSetter = "Core_SetCurrentChar"
})

RField("core.char", "core.ownerply", {
    Type = {"object", "core.player"},

    AutoGetter = SERVER and "Core_OwnerPly",
    AutoSetter = "Core_SetOwnerPly"
})

RFieldTable("core.char", "core.ownerents", {
    Type = "entity",
    Save = false,
    NetMode = {"everyone"},
    AutoCreate = true
})

function CHAR:Core_OwnerEnts() return self:Raw_Get("core.ownerents") end