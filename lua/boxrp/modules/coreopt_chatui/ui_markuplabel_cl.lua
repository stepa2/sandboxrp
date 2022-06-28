local PANEL = {}

function PANEL:Init()
    self:SetText("")
end

function PANEL:SetText(text)
    self._text = text
    self:RecomputeMarkup()
end

function PANEL:RecomputeMarkup()
    self._markup = markup.Parse(self._text, self:GetWide())

    self:SetHeight(self._markup:GetHeight())
end

function PANEL:PerformLayout(width, height)
    if width == self._markup:GetMaxWidth() then return end

    self:RecomputeMarkup()
end

function PANEL:Paint()
    self._markup:Draw(0,0)
end

derma.DefineControl("BoxRP.MCoreOpt_ChatUI.MarkupLabel", "DLabel but with markup support", PANEL, "Panel")