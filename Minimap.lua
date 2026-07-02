local ModeShift = _G.ModeShift

local MinimapModule = {}

local function getAngle()
  local char = ModeShift.Database and ModeShift.Database:GetCharDB()
  if char and char.minimapAngle then
    return char.minimapAngle
  end
  return ModeShift.Database and ModeShift.Database:GetGlobalSetting("minimapAngle") or 225
end

local function saveAngle(angle)
  if ModeShift.Database then
    ModeShift.Database:GetCharDB().minimapAngle = angle
  end
end

local function updatePosition(button)
  local angle = math.rad(getAngle())
  local radius = ((Minimap:GetWidth() or 140) / 2) + 6
  local x = math.cos(angle) * radius
  local y = math.sin(angle) * radius
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function updateDragPosition(button)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  px = px / scale
  py = py / scale

  if button.modeShiftDragStartX and button.modeShiftDragStartY then
    local dx = px - button.modeShiftDragStartX
    local dy = py - button.modeShiftDragStartY
    if (dx * dx) + (dy * dy) > 16 then
      button.modeShiftDragged = true
    end
  end

  local atan = math.atan2 or math.atan
  local angle = math.deg(atan(py - my, px - mx))
  saveAngle(angle)
  updatePosition(button)
end

local function minimapButton_OnClick(self, button)
  if self.modeShiftDragged then
    self.modeShiftDragged = nil
    return
  end

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
  button:SetSize(32, 32)
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  updatePosition(button)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetScript("OnClick", minimapButton_OnClick)
  button:SetScript("OnDragStart", function(self)
    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.modeShiftDragStartX = px / scale
    self.modeShiftDragStartY = py / scale
    self.modeShiftDragging = true
    self.modeShiftDragged = false
    self:SetScript("OnUpdate", updateDragPosition)
  end)
  button:SetScript("OnDragStop", function(self)
    self.modeShiftDragging = nil
    self.modeShiftDragStartX = nil
    self.modeShiftDragStartY = nil
    self:SetScript("OnUpdate", nil)
    updatePosition(self)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ModeShift")
    GameTooltip:AddLine("Click izquierdo: configuracion", 1, 1, 1)
    GameTooltip:AddLine("Click derecho: cambio rapido", 1, 1, 1)
    GameTooltip:AddLine("Arrastrar: mover alrededor del minimapa", 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture(ModeShift.Constants.DEFAULT_ICON)
  button.icon:SetSize(20, 20)
  button.icon:SetPoint("CENTER", 0, 0)

  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.border:SetSize(52, 52)
  button.border:SetPoint("TOPLEFT", button, "TOPLEFT", -9, 9)

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
