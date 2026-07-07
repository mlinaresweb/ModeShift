local ModeShift = _G.ModeShift

local MinimapModule = {}

local function L(text)
  return ModeShift.L and ModeShift:L(text) or text
end

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
  local radius = ((Minimap:GetWidth() or 140) / 2) + 4
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

  if not (button.modeShiftMouseDown and button.modeShiftDragStartX and button.modeShiftDragStartY) then
    return
  end

  local dx = px - button.modeShiftDragStartX
  local dy = py - button.modeShiftDragStartY
  if not button.modeShiftDragged and (dx * dx) + (dy * dy) <= 16 then
    return
  end

  button.modeShiftDragged = true
  local atan = math.atan2 or math.atan
  local angle = math.deg(atan(py - my, px - mx))
  saveAngle(angle)
  updatePosition(button)
end

local function minimapButton_Open(self, button)
  if self.modeShiftDragged then
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
  button:SetSize(31, 31)
  button:SetFrameStrata("HIGH")
  button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
  updatePosition(button)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:SetPushedTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:SetScript("OnMouseDown", function(self, mouseButton)
    if mouseButton ~= "LeftButton" then
      return
    end

    local px, py = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.modeShiftDragStartX = px / scale
    self.modeShiftDragStartY = py / scale
    self.modeShiftMouseDown = true
    self.modeShiftDragged = false
    self:SetScript("OnUpdate", updateDragPosition)
  end)
  button:SetScript("OnMouseUp", function(self, mouseButton)
    local wasDragged = self.modeShiftDragged
    self.modeShiftMouseDown = nil
    self.modeShiftDragStartX = nil
    self.modeShiftDragStartY = nil
    self.modeShiftDragged = nil
    self:SetScript("OnUpdate", nil)
    if wasDragged then
      updatePosition(self)
      return
    end

    minimapButton_Open(self, mouseButton)
  end)
  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("ModeShift")
    GameTooltip:AddLine(L("Click izquierdo: configuracion"), 1, 1, 1)
    GameTooltip:AddLine(L("Click derecho: cambio rapido"), 1, 1, 1)
    GameTooltip:AddLine(L("Arrastrar: mover alrededor del minimapa"), 1, 1, 1)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetTexture(ModeShift.Constants.DEFAULT_ICON)
  button.icon:SetTexCoord(0, 1, 0, 1)
  button.icon:SetSize(20, 20)
  button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
  if button.CreateMaskTexture and button.icon.AddMaskTexture then
    button.iconMask = button:CreateMaskTexture()
    button.iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    button.iconMask:SetSize(20, 20)
    button.iconMask:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -6)
    button.icon:AddMaskTexture(button.iconMask)
  end

  button.border = button:CreateTexture(nil, "OVERLAY")
  button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  button.border:SetSize(53, 53)
  button.border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

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
    GameTooltip:AddLine(L("Click: configuracion"), 1, 1, 1)
    GameTooltip:AddLine(L("Click derecho: menu rapido"), 1, 1, 1)
    GameTooltip:Show()
  end
end

function _G.ModeShift_OnAddonCompartmentLeave()
  if GameTooltip then
    GameTooltip:Hide()
  end
end

ModeShift:RegisterModule("Minimap", MinimapModule)
