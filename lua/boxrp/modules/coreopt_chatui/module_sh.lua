BoxRP.CoreOpt_ChatUI = BoxRP.CoreOpt_ChatUI or {}

BoxRP.IncludeFile("ui_markuplabel_cl.lua")
BoxRP.IncludeFile("ui_cl.lua")

if CLIENT then
    hook.Add("PlayerBindPress", "BoxRP.MCoreOpt_ChatUI.HookChat", function(ply, bind, is_pressed)
        if not is_pressed then return end
        bind = input.TranslateAlias(bind) or bind

        if string.find(bind, "messagemode2", nil, true) then
            BoxRP.CoreOpt_ChatUI.OpenChat(true)
            return true
        elseif string.find(bind, "messagemode", nil, true) then
            BoxRP.CoreOpt_ChatUI.OpenChat(false)
            return true
        end
    end)

    hook.Add("ChatText", "BoxRP.MCoreOpt_ChatUI.HookChat", function(_, _, text, type)
        BoxRP.CoreOpt_ChatUI.AddMessageSpecial(type, text)
    end)

    hook.Add("HUDShouldDraw", "BoxRP.MCoreOpt_ChatUI.HookChat", function(name)
        if name == "CHudChat" then
            return false
        end
    end)

    local chat_AddText = chat_AddText or chat.AddText

    function chat.AddText(...)
        BoxRP.CoreOpt_ChatUI.AddMessage({...})
        chat_AddText(...)
    end

    function chat.GetChatBoxPos()
        return BoxRP.CoreOpt_ChatUI.GetPos()
    end

    function chat.GetChatBoxSize()
        return BoxRP.CoreOpt_ChatUI.GetSize()
    end

    hook.Add("InitPostEntity", "BoxRP.MCoreOpt_ChatUI.InitChat", function()
        BoxRP.CoreOpt_ChatUI.InitWindow()
    end)

    hook.Add("OnScreenSizeChanged", "BoxRP.MCoreOpt_ChatUI.InitChat", function(_,_)
        BoxRP.CoreOpt_ChatUI.InitWindow()
    end)

    hook.Add("BoxRP.MCoreOpt_ChatUI.ChatStarted", "BoxRP.MCoreOpt_ChatUI.ChatHook", function(_)
        hook.Run("StartChat")
    end)

    hook.Add("BoxRP.MCoreOpt_ChatUI.ChatStopped", "BoxRP.MCoreOpt_ChatUI.ChatHook", function(_)
        hook.Run("FinishChat")
    end)

    hook.Add("BoxRP.MCoreOpt_ChatUI.MessageEntered", "BoxRP.MCoreOpt_ChatUI.SendMessage", function(_, msg)
        net.Start("BoxRP.MCoreOpt_ChatUI.Message")
            net.WriteString(msg)
        net.SendToServer()
    end)
else
    util.AddNetworkString("BoxRP.MCoreOpt_ChatUI.Message")

    net.Receive("BoxRP.MCoreOpt_ChatUI.Message", function(_, ply)
        local msg = net.ReadString()

        if not string.find(msg, "%S") then return end -- Message should have non-space characters

        hook.Run("PlayerSay", ply, msg)
    end)
end

if CLIENT then
    surface.CreateFont("BoxRP.MCoreOpt_ChatUI.Font", {
        font = "Roboto",
        extended = true,
        size = math.max(ScreenScale(7), 17),
        weight = 600,
        antialias = true
    })

    surface.CreateFont("BoxRP.MCoreOpt_ChatUI.FontItalic", {
        font = "Roboto",
        size = math.max(ScreenScale(7), 17),
        extended = true,
        weight = 600,
        antialias = true,
        italic = true
    })
end