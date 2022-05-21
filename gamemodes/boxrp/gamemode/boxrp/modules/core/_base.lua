BoxRP.UData2.RegisterNetMode("everyone", nil, function(_obj, recip) recip:AddAllPlayers() end)
BoxRP.UData2.RegisterNetMode("none", nil, function(_obj, recip) end)

BoxRP.UData2.RegisterObj("core_char", { SaveSv = true, SaveCl = true, NetMode = "everyone"})
BoxRP.UData2.RegisterObj("core_player", { SaveSv = true, SaveCl = false, NetMode = "none"})
BoxRP.UData2.RegisterObj("core_charmemory", { SaveSv = true, SaveCl = true, NetMode = "ownerply"})