local FIELDTY = BoxRP.UData2.FIELD_TYPE


BoxRP.UData2.RegisterComp("core_player", "core_plyinfo", {
    SaveSv = true, SaveCl = false, Fields = {
        SteamId = { Type = FIELDTY.STRING, AutoGetter = "Core_GetSteamId", Unique = true },
        Entity = { Type = FIELDTY.ENTITY, AutoGetter = "Core_GetEntity", SaveSv = false}
    }
})

if SERVER and not game.SinglePlayer() then
    local function PlayerConnected(ply)
        if ply:IsBot() then return end

        local steamid = ply:SteamID()

        local plydata = BoxRP.UData2.ActiveMgr:FindLoadObject("core_player", {{
            Name = "core_steamid", Value = steamid
        }})

        if plydata == nil then
            plydata = BoxRP.UData2.ActiveMgr:CreateObject("core_player")
            plydata.Data.core_plyinfo.SteamId = steamid
        end

        plydata.Data.core_plyinfo.Entity = ply
        ply.BoxRP_PlayerData = plydata
    end

    gameevent.Listen("player_connect")
    hook.Add("player_connect", "BoxRP.ModuleCore.Base", function(data)
        PlayerConnected(Player(data.userid))
    end)

    -- Wiki about player_connect:
    -- This is only called clientside for the listen server host and in single-player.
    hook.Add("PostGamemodeLoaded", "BoxRP.ModuleCore.Base", function()
        for _, ply in ipairs(player.GetHumans()) do
            if ply:IsListenServerHost() then
                PlayerConnected(ply)
            end
        end
    end)
end