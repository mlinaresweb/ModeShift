local addonName, addonTable = ...

local ModeShift = _G.ModeShift or addonTable or {}
_G.ModeShift = ModeShift

ModeShift.addonName = addonName or "ModeShift"
ModeShift.version = "0.1.0"
ModeShift.modules = ModeShift.modules or {}

local frame = CreateFrame("Frame")
ModeShift.frame = frame

local function call(method, ...)
  if type(method) == "function" then
    return method(...)
  end
end

function ModeShift:RegisterModule(name, module)
  if not name or type(module) ~= "table" then
    return
  end

  self.modules[name] = module
  self[name] = module
  module.name = module.name or name
  module.addon = self
end

function ModeShift:Print(message)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffModeShift:|r " .. tostring(message or ""))
end

function ModeShift:Debug(message)
  if self.Database and self.Database:GetGlobalSetting("debug") then
    self:Print("|cff999999debug:|r " .. tostring(message or ""))
  end
end

function ModeShift:SafeCall(label, fn, ...)
  if type(fn) ~= "function" then
    return false, label .. " is not callable"
  end

  local ok, result1, result2, result3 = pcall(fn, ...)
  if not ok then
    return false, tostring(result1)
  end

  return true, result1, result2, result3
end

function ModeShift:IsInCombat()
  return type(InCombatLockdown) == "function" and InCombatLockdown()
end

function ModeShift:GetPlayerKey()
  local name = UnitName and UnitName("player") or "Unknown"
  local realm = GetRealmName and GetRealmName() or "Unknown"
  name = name or "Unknown"
  realm = realm or "Unknown"
  realm = realm:gsub("%s+", "")
  return realm .. "-" .. name
end

function ModeShift:GetCurrentSpecId()
  if GetSpecialization and GetSpecializationInfo then
    local specIndex = GetSpecialization()
    if specIndex then
      local specId = GetSpecializationInfo(specIndex)
      return specId
    end
  end

  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecializationInfo then
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if specIndex then
      local specId = C_SpecializationInfo.GetSpecializationInfo(specIndex)
      return specId
    end
  end

  return nil
end

function ModeShift:GetCurrentSpecName()
  if GetSpecialization and GetSpecializationInfo then
    local specIndex = GetSpecialization()
    if specIndex then
      local _, specName = GetSpecializationInfo(specIndex)
      return specName
    end
  end

  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecializationInfo then
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if specIndex then
      local _, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
      return specName
    end
  end

  return nil
end

function ModeShift:GetClassFile()
  if not UnitClass then
    return nil
  end

  local _, classFile = UnitClass("player")
  return classFile
end

function ModeShift:ShowReloadPopup()
  if self.Database and not self.Database:GetGlobalSetting("showReloadPopup") then
    self:Print("Hay cambios pendientes de addons. Usa /ms reload para recargar cuando quieras.")
    return
  end

  if not StaticPopupDialogs then
    self:Print("Hay cambios pendientes de addons. Usa /reload cuando quieras.")
    return
  end

  StaticPopupDialogs.MODESHIFT_RELOAD_UI = StaticPopupDialogs.MODESHIFT_RELOAD_UI or {
    text = "ModeShift ha cambiado addons. Es necesario recargar la interfaz para completar el cambio.",
    button1 = RELOADUI or "Reload UI",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
      if ModeShift.Database then
        ModeShift.Database:SetRequiresReload(false)
      end
      ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  StaticPopup_Show("MODESHIFT_RELOAD_UI")
end

function ModeShift:ReloadUI()
  ReloadUI()
end

function ModeShift:OpenConfig()
  if self.ConfigUI then
    self.ConfigUI:Toggle()
    return
  end

  if self.ConfigFrame and self.ConfigFrame:IsShown() then
    self.ConfigFrame:Hide()
    return
  end

  if not self.ConfigFrame then
    local f = CreateFrame("Frame", "ModeShiftConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(560, 420)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("LEFT", f.TitleBg or f, "LEFT", 8, 0)
    f.title:SetText("ModeShift")

    f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subtitle:SetPoint("TOPLEFT", 16, -38)
    f.subtitle:SetText("Perfiles disponibles")

    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body:SetPoint("TOPLEFT", 16, -64)
    f.body:SetPoint("BOTTOMRIGHT", -16, 56)
    f.body:SetJustifyH("LEFT")
    f.body:SetJustifyV("TOP")

    f.apply = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.apply:SetSize(130, 24)
    f.apply:SetPoint("BOTTOMLEFT", 16, 16)
    f.apply:SetText("Reaplicar")
    f.apply:SetScript("OnClick", function()
      if ModeShift.ApplyEngine then
        ModeShift.ApplyEngine:ReapplyCurrentProfile()
      end
    end)

    f.quick = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.quick:SetSize(130, 24)
    f.quick:SetPoint("LEFT", f.apply, "RIGHT", 8, 0)
    f.quick:SetText("Menu rapido")
    f.quick:SetScript("OnClick", function(button)
      if ModeShift.QuickMenu then
        ModeShift.QuickMenu:Open(button, { forceMenu = true })
      end
    end)

    f.create = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.create:SetSize(130, 24)
    f.create:SetPoint("LEFT", f.quick, "RIGHT", 8, 0)
    f.create:SetText("Crear ejemplos")
    f.create:SetScript("OnClick", function()
      if ModeShift.ProfileManager then
        ModeShift.ProfileManager:EnsureExampleProfiles()
        ModeShift:RefreshConfig()
      end
    end)

    self.ConfigFrame = f
  end

  self:RefreshConfig()
  self.ConfigFrame:Show()
end

function ModeShift:ShowConfig()
  if self.ConfigUI then
    self.ConfigUI:Open()
    return
  end

  self:OpenConfig()
end

function ModeShift:BuildOptionsPanel(panel)
  if panel.modeShiftBuilt then
    return
  end
  panel.modeShiftBuilt = true

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 24, -24)
  title:SetText("ModeShift")

  local version = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  version:SetText("Version: " .. tostring(self.version or "0.1.0"))

  local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  description:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -18)
  description:SetWidth(620)
  description:SetJustifyH("LEFT")
  description:SetText("Gestiona perfiles de spec, equipo, talentos, UI, addons, perfiles internos de addons y CVars.")

  local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  openButton:SetSize(220, 28)
  openButton:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -24)
  openButton:SetText("Abrir ModeShift")
  openButton:SetScript("OnClick", function()
    ModeShift:ShowConfig()
  end)

  local quickButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  quickButton:SetSize(180, 28)
  quickButton:SetPoint("LEFT", openButton, "RIGHT", 10, 0)
  quickButton:SetText("Menu rapido")
  quickButton:SetScript("OnClick", function(button)
    if ModeShift.QuickMenu then
      ModeShift.QuickMenu:Open(button, { forceMenu = true })
    end
  end)

  local commands = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  commands:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", 0, -28)
  commands:SetText("Comandos principales")

  local body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  body:SetPoint("TOPLEFT", commands, "BOTTOMLEFT", 0, -10)
  body:SetWidth(620)
  body:SetJustifyH("LEFT")
  body:SetText("/ms config - abrir configuracion\n/ms quick - menu rapido\n/ms current - perfil actual\n/ms reload - recargar interfaz\n/ms doctor - diagnostico rapido")
end

function ModeShift:RegisterOptionsPanel()
  if self.optionsPanel then
    return
  end

  local panel = CreateFrame("Frame", "ModeShiftOptionsPanel")
  panel.name = "ModeShift"
  panel:SetScript("OnShow", function()
    ModeShift:BuildOptionsPanel(panel)
  end)
  self.optionsPanel = panel

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "ModeShift")
    Settings.RegisterAddOnCategory(category)
    self.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

function ModeShift:OpenAddonOptions()
  if not self.optionsPanel then
    self:RegisterOptionsPanel()
  end

  if Settings and Settings.OpenToCategory and self.optionsCategory then
    local categoryId = self.optionsCategory.ID
    if not categoryId and self.optionsCategory.GetID then
      categoryId = self.optionsCategory:GetID()
    end
    Settings.OpenToCategory(categoryId or self.optionsCategory)
  elseif InterfaceOptionsFrame_OpenToCategory and self.optionsPanel then
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
  end
end

function ModeShift:RefreshConfig()
  if self.ConfigUI then
    self.ConfigUI:Refresh()
    return
  end

  if not self.ConfigFrame or not self.ProfileManager then
    return
  end

  local lines = {}
  local activeProfileId = self.Database and self.Database:GetActiveProfileId() or nil
  local profiles = self.ProfileManager:GetProfilesForCurrentCharacter()
  table.sort(profiles, function(a, b)
    return (a.order or 0) < (b.order or 0)
  end)

  for _, profile in ipairs(profiles) do
    local marker = profile.id == activeProfileId and "*" or " "
    local spec = profile.specName or profile.specId or "sin spec"
    local mode = profile.modeType or "CUSTOM"
    table.insert(lines, string.format("%s %s  [%s / %s]\n    id: %s", marker, profile.name or profile.id, spec, mode, profile.id))
  end

  if #lines == 0 then
    table.insert(lines, "No hay perfiles todavia. Usa /ms create para crear ejemplos para la spec actual.")
  end

  self.ConfigFrame.body:SetText(table.concat(lines, "\n\n"))
end

function ModeShift:OnAddonLoaded(loadedAddonName)
  if loadedAddonName ~= self.addonName then
    return
  end

  if self.Database then
    self.Database:Initialize()
  end
end

function ModeShift:OnPlayerLogin()
  if self.Database then
    self.Database:Initialize()
    if self.Database:GetRequiresReload() then
      self.Database:SetRequiresReload(false)
    end
  end

  if self.Minimap then
    self.Minimap:Initialize()
  end

  if self.SlashCommands then
    self.SlashCommands:Register()
  end

  self:RegisterOptionsPanel()

  self:Print("cargado. Usa /ms list para ver perfiles.")
end

function ModeShift:OnPlayerRegenEnabled()
  if not self.Database then
    return
  end

  local pendingProfileId = self.Database:GetPendingProfileId()
  if not pendingProfileId then
    return
  end

  if self.Database:GetGlobalSetting("autoApplyPendingAfterCombat") then
    self.Database:SetPendingProfileId(nil)
    self:Print("fuera de combate, aplicando perfil pendiente.")
    if self.ApplyEngine then
      self.ApplyEngine:ApplyProfile(pendingProfileId, { fromPending = true })
    end
  else
    self:Print("hay un perfil pendiente. Usa /ms apply " .. pendingProfileId .. " para aplicarlo.")
  end
end

function ModeShift:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    self:OnAddonLoaded(...)
  elseif event == "PLAYER_LOGIN" then
    self:OnPlayerLogin()
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:OnPlayerRegenEnabled()
  end

  for _, module in pairs(self.modules) do
    call(module.OnEvent, module, event, ...)
  end
end

frame:SetScript("OnEvent", function(_, event, ...)
  ModeShift:OnEvent(event, ...)
end)

local function registerEvent(event)
  if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
    return
  end
  pcall(frame.RegisterEvent, frame, event)
end

registerEvent("ADDON_LOADED")
registerEvent("PLAYER_LOGIN")
registerEvent("PLAYER_REGEN_ENABLED")
registerEvent("PLAYER_SPECIALIZATION_CHANGED")
registerEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
registerEvent("PLAYER_EQUIPMENT_CHANGED")
registerEvent("PLAYER_TALENT_UPDATE")
registerEvent("TRAIT_CONFIG_UPDATED")
registerEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
