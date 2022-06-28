local CHAT_BORDER = 32

local PANEL = {}
PANEL.AllowAutoRefresh = true

function PANEL:GetDefaultSize()
    return ScrW() * 0.4, ScrH() * 0.375
end

function PANEL:GetDefaultPos()
    return CHAT_BORDER, ScrH() - self:GetTall() - CHAT_BORDER
end

function PANEL:Init()

    self:SetSize(self:GetDefaultSize())
    self:SetPos(self:GetDefaultPos())

    self._pnlEntry = self:Add("DTextEntry")
    self._pnlEntry:Dock(BOTTOM)
    self._pnlEntry:SetUpdateOnType(true)
    self._pnlEntry:SetHistoryEnabled(true)
    self._pnlEntry.OnEnter = function(_,txt) self:OnMessageEntered(txt) end

    do
        local old = self._pnlEntry.OnKeyCodeTyped
        self._pnlEntry.OnKeyCodeTyped = function(ctrl,kc)
            return self:OnTextKeyCode(kc) or old(ctrl,kc)
        end
    end


    self._pnlHistory = self:Add("DScrollPanel") -- .ChatHistory
    self._pnlHistory:Dock(FILL)
    self._pnlHistory:DockMargin(0,0,0,4)
    self._pnlHistory:GetVBar():SetWide(0) --Dock(LEFT)
    --self._pnlHistory:SetVisible(true)
    self:SetVisible(true)

    self:SetActive(false)
end

function PANEL:OpenChat(team_chat)
    self:SetActive(true)
    --print("OpenChat",team_chat)
end

function PANEL:OnMessageEntered(txt)
    if string.find(txt, "%S") then -- Message should have non-space characters
        self:AddHistoryLine({LocalPlayer(), ": ",txt})
        hook.Run("BoxRP.MCoreOpt_ChatUI.MessageEntered", self, txt)
    end

    self:SetActive(false)
end

function PANEL:AddMessageSpecial(type, text)
    self:AddHistoryLine({"[Notification '"..type.."'] ", text})
end

function PANEL:AddMessage(args)
    self:AddHistoryLine(args)
end

function PANEL:SetActive(is_active)
    self._isActive = is_active
    self._pnlEntry:SetAlpha(is_active and 255 or 0)

    if is_active then
        self:MakePopup()
        self._pnlEntry:RequestFocus()
        hook.Run("BoxRP.MCoreOpt_ChatUI.ChatStarted",self)
    else
        self:SetMouseInputEnabled(false)
        self:SetKeyboardInputEnabled(false)

        self:ClearEntry()
        --gui.EnableScreenClicker(false)
        hook.Run("BoxRP.MCoreOpt_ChatUI.ChatStopped",self)
    end
end

function PANEL:OnTextKeyCode(keycode)
    if keycode == KEY_ESCAPE then
        self:SetActive(false)
        gui.HideGameUI()
        return true
    end
end

function PANEL:GetActive() return self._isActive end

function PANEL:ClearEntry()
    self._pnlEntry:SetText("")
end

local function IsFontSpec(tbl)
    if not istable(tbl) then return false end

    local k1, v1 = next(tbl, nil)
    if k1 ~= "font" or not isstring(v1) then return false end

    local k2, v2 = next(tbl, "font")
    return k2 == nil
end

local function TextPartToMarkup(part, out_parts, console_parts)
    if istable(part) and part.r and part.g and part.b then
        table.insert(out_parts, "<color="..markup.Color(part)..">")
        table.insert(console_parts, part)
    elseif IsFontSpec(part) then
        table.insert(out_parts, "<font="..out_parts.font..">")
    elseif IsEntity(part) and part:IsPlayer() then
        local teamcolor = team.GetColor(part:Team())

        table.insert(out_parts, "<font=BoxRP.MCoreOpt_ChatUI.FontItalic>")
        TextPartToMarkup(teamcolor, out_parts, console_parts)
        TextPartToMarkup(part:Nick(), out_parts, console_parts)
        table.insert(out_parts, "<font=BoxRP.MCoreOpt_ChatUI.Font>")
    else
        table.insert(out_parts, markup.Escape(tostring(part)))
        table.insert(console_parts, tostring(part))
    end
end

function PANEL:AddHistoryLine(parts)
    local markup_parts = {"<font=BoxRP.MCoreOpt_ChatUI.Font>"}
    local console_parts = {}

    for _, part in ipairs(parts) do
        TextPartToMarkup(part, markup_parts, console_parts)
    end

    table.insert(console_parts, "\n")
    local markup = table.concat(markup_parts,"")

    local markuplabel = self._pnlHistory:Add("BoxRP.MCoreOpt_ChatUI.MarkupLabel")
    markuplabel:Dock(TOP)
    markuplabel:InvalidateParent(true)
    markuplabel:SetText(markup)

    self._pnlHistory:ScrollToChild(markuplabel)

    MsgC(unpack(console_parts))
end

-- TODO: keep chat history between reloads

--function PANEL:PreAutoRefresh()
    --print("PreAutoRefresh")
--end

function PANEL:PostAutoRefresh()
    --print("PostAutoRefresh")
    self:Remove()
end

derma.DefineControl("BoxRP.MCoreOpt_ChatUI.ChatBox", "Chatbox, ported from Helix", PANEL, "EditablePanel")

local ChatWindow = ChatWindow

function BoxRP.CoreOpt_ChatUI.InitWindow()
    if IsValid(ChatWindow) then
        ChatWindow:Remove()
    end

    ChatWindow = vgui.Create("BoxRP.MCoreOpt_ChatUI.ChatBox")
end

function BoxRP.CoreOpt_ChatUI.OpenChat(team_chat)
    if not IsValid(ChatWindow) then BoxRP.CoreOpt_ChatUI.InitWindow() end

    ChatWindow:OpenChat(team_chat)
end

function BoxRP.CoreOpt_ChatUI.AddMessageSpecial(type, text)
    if not IsValid(ChatWindow) then BoxRP.CoreOpt_ChatUI.InitWindow() end

    ChatWindow:AddMessageSpecial(type, text)
end

function BoxRP.CoreOpt_ChatUI.AddMessage(args)
    ChatWindow:AddMessage(args)
end

function BoxRP.CoreOpt_ChatUI.GetPos()
    if not IsValid(ChatWindow) then BoxRP.CoreOpt_ChatUI.InitWindow() end

    return ChatWindow:GetPos()
end

function BoxRP.CoreOpt_ChatUI.GetSize()
    if not IsValid(ChatWindow) then BoxRP.CoreOpt_ChatUI.InitWindow() end

    return ChatWindow:GetSize()
end