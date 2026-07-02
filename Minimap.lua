local ModeShift = _G.ModeShift

local MinimapModule = {}

local function minimapButton_OnClick(self, button)
  if button == "RightButton" then
    ModeShift.QuickMenu:Open(self)
  else
    ModeShift:OpenConfig()
  end
end

function MinimapModule:Initialize()
  if self.button or not ModeShift.Database:GetGlobalSetting("minimapButton") then
    return
  end

  if not Minimap then
    return
  end

  local button = CreateFrame("Button", "ModeShiftMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetScript("OnClick", minimapButton_OnClick)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ModeShift")
    GameTooltip:AddLine("Click izquierdo: configuracion", 1, 1, 1)
    GameTooltip:AddLine("Click derecho: cambio rapido", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button.icon = button:CreateTexture(nil, "BACKGROUND")
  button.icon:SetTexture(ModeShift.Constants.DEFAULT_ICON)
  button.icon:SetSize(20, 20)
  button.icon:SetPoint("CENTER")

  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.border:SetSize(52, 52)
  button.border:SetPoint("TOPLEFT")

  self.button = button
end

function _G.ModeShift_OnAddonCompartmentClick(addonName, buttonName)
  if buttonName == "RightButton" then
    ModeShift.QuickMenu:Open(nil, { forceMenu = true })
  else
    ModeShift:OpenConfig()
  end
end

function _G.ModeShift_OnAddonCompartmentEnter()
  if GameTooltip then
    GameTooltip:SetOwner(AddonCompartmentFrame or UIParent, "ANCHOR_LEFT")
    GameTooltip:AddLine("ModeShift")
    GameTooltip:AddLine("Click: configuracion", 1, 1, 1)
    GameTooltip:AddLine("Click derecho: menu rapido", 1, 1, 1)
    GameTooltip:Show()
  end
end

function _G.ModeShift_OnAddonCompartmentLeave()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

ModeShift:RegisterModule("Minimap", MinimapModule)
