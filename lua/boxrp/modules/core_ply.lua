local UData = BoxRP.UData

local RField = UData.RegField
local RObject = UData.RegObject

RObject("core.player", {
    Save = true,
    NetMode = {}
})

RField("core.player", "core.steamid", {
    Type = "string",
    AutoGetter = "Core_SteamId"
})

RField("core.player", "core.entity", {
    Type = "entity",
    SaveOverride = false,
    AutoGetter = "Core_Entity"
})

if SERVER then
    local function PlayerConnected(ply)
        local existing = UData.FindByFieldValue(
            "core.player", "core.steamid",
            ply:SteamID(), true)

        if #existing > 1 then
            for _, obj in ipairs(existing) do obj:DeleteUnload() end
        end

        local obj = existing[1]

        if #existing ~= 1 then
            obj = UData.Create("core.player")
            obj:Raw_Set("core.steamid", ply:SteamID())
        end

        obj:Raw_Set("core.entity", ply)

        ply.BoxRP_PlyInfo = obj
    end

    gameevent.Listen("player_connect")
    hook.Add("player_connect", "BoxRP.MCore.LoadPlayer", function(data)
        if data.bot == 1 then return end
        local ply = Entity(data.index + 1)
        if IsValid(ply) then
            PlayerConnected(ply)
        end
    end)

    for _, ply in ipairs(player.GetHumans()) do
        if ply:IsListenServerHost() then
            timer.Simple(0, function() if IsValid(ply) then PlayerConnected(ply) end end)
        end
    end

    hook.Add("PlayerDisconnected", "BoxRP.MCore.UnloadPlayer", function(ply)
        ply.BoxRP_PlyInfo:Unload()
    end)
end