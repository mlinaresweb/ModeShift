local ModeShift = _G.ModeShift

local ConfigUI = {
  activeTab = "profile",
  selectedProfileId = nil,
}

local TABS = {
  { key = "profile", text = "Perfil" },
  { key = "equipment", text = "Equipo" },
  { key = "talents", text = "Talentos" },
  { key = "ui", text = "UI" },
  { key = "addons", text = "Addons" },
  { key = "cvars", text = "Avanzado" },
}

local MODE_TYPES = {
  "PVE",
  "PVP",
  "RAID",
  "MYTHIC_PLUS",
  "ARENA",
  "BLITZ",
  "FARMING",
  "CUSTOM",
}

local function contains(list, value)
  if type(list) ~= "table" then
    return false
  end

  for _, current in ipairs(list) do
    if current == value then
      return true
    end
  end

  return false
end

local function removeValue(list, value)
  if type(list) ~= "table" then
    return
  end

  for index = #list, 1, -1 do
    if list[index] == value then
      table.remove(list, index)
    end
  end
end

local function addUnique(list, value)
  if type(list) ~= "table" or not value or value == "" then
    return
  end

  if not contains(list, value) then
    table.insert(list, value)
  end
end

local function makeButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 120, height or 24)
  button:SetText(text or "")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  return button
end

local function makeCheck(parent, text, checked, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetSize(24, 24)
  check.Text:SetText(text or "")
  check:SetChecked(checked and true or false)
  if onClick then
    check:SetScript("OnClick", function(self)
      onClick(self:GetChecked())
    end)
  end
  return check
end

local function makeEditBox(parent, width, text)
  local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  editBox:SetSize(width or 220, 24)
  editBox:SetAutoFocus(false)
  editBox:SetText(text or "")
  editBox:SetCursorPosition(0)
  return editBox
end

local function makeText(parent, text, font)
  local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetText(text or "")
  return label
end

local function setButtonPoint(button, x, y)
  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", x, y)
end

local function clearScroll(scrollFrame)
  if not scrollFrame then
    return nil
  end

  if scrollFrame.modeShiftChild then
    scrollFrame.modeShiftChild:Hide()
  end

  local child = CreateFrame("Frame", nil, scrollFrame)
  child:SetSize(1, 1)
  if child.SetClipsChildren then
    child:SetClipsChildren(true)
  end
  scrollFrame:SetScrollChild(child)
  scrollFrame.modeShiftChild = child
  return child
end

local function setShown(frame, shown)
  if not frame then
    return
  end

  if shown then
    frame:Show()
  else
    frame:Hide()
  end
end

local function escapeValue(value)
  value = tostring(value or "")
  value = value:gsub("\\", "\\\\")
  value = value:gsub("\n", "\\n")
  value = value:gsub("=", "\\e")
  return value
end

local function unescapeValue(value)
  value = tostring(value or "")
  value = value:gsub("\\e", "=")
  value = value:gsub("\\n", "\n")
  value = value:gsub("\\\\", "\\")
  return value
end

function ConfigUI:Initialize()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "ModeShiftConfigFrame", UIParent, "BasicFrameTemplateWithInset")
  frame:SetSize(930, 650)
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnHide", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
    if self.importFrame then
      self.importFrame:Hide()
    end
  end)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  frame.title:SetPoint("LEFT", frame.TitleBg or frame, "LEFT", 8, 0)
  frame.title:SetText("ModeShift")

  frame.leftTitle = makeText(frame, "Perfiles", "GameFontNormal")
  frame.leftTitle:SetPoint("TOPLEFT", 16, -36)

  frame.profileScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.profileScroll:SetPoint("TOPLEFT", 16, -60)
  frame.profileScroll:SetSize(246, 475)

  frame.newButton = makeButton(frame, "Nuevo", 76, 24, function()
    local profile = ModeShift.ProfileManager:CreateProfileFromCurrentState()
    self.selectedProfileId = profile and profile.id
    self.activeTab = "profile"
    self:Refresh()
  end)
  frame.newButton:SetPoint("TOPLEFT", frame.profileScroll, "BOTTOMLEFT", 0, -10)

  frame.duplicateButton = makeButton(frame, "Duplicar", 82, 24, function()
    local copy = ModeShift.ProfileManager:DuplicateProfile(self.selectedProfileId)
    if copy then
      self.selectedProfileId = copy.id
      self:Refresh()
    end
  end)
  frame.duplicateButton:SetPoint("LEFT", frame.newButton, "RIGHT", 4, 0)

  frame.deleteButton = makeButton(frame, "Eliminar", 82, 24, function()
    self:DeleteSelectedProfile()
  end)
  frame.deleteButton:SetPoint("LEFT", frame.duplicateButton, "RIGHT", 4, 0)

  frame.applyButton = makeButton(frame, "Aplicar perfil", 120, 24, function()
    if self.selectedProfileId then
      ModeShift.ApplyEngine:ApplyProfile(self.selectedProfileId, { source = "config" })
    end
  end)
  frame.applyButton:SetPoint("TOPLEFT", frame.newButton, "BOTTOMLEFT", 0, -8)

  frame.reapplyButton = makeButton(frame, "Reaplicar", 120, 24, function()
    ModeShift.ApplyEngine:ReapplyCurrentProfile()
  end)
  frame.reapplyButton:SetPoint("LEFT", frame.applyButton, "RIGHT", 6, 0)

  frame.reloadButton = makeButton(frame, "Reload UI", 120, 24, function()
    ModeShift.Database:SetRequiresReload(false)
    ReloadUI()
  end)
  frame.reloadButton:SetPoint("BOTTOMLEFT", 16, 16)

  frame.tabButtons = {}
  local x = 285
  for _, tab in ipairs(TABS) do
    local button = makeButton(frame, tab.text, 88, 24, function()
      self.activeTab = tab.key
      self:RefreshEditor()
      self:RefreshTabs()
    end)
    button:SetPoint("TOPLEFT", x, -34)
    frame.tabButtons[tab.key] = button
    x = x + 92
  end

  frame.editorScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  frame.editorScroll:SetPoint("TOPLEFT", 285, -66)
  frame.editorScroll:SetSize(610, 540)

  self.frame = frame
end

function ConfigUI:Open()
  self:Initialize()
  self:EnsureSelection()
  self:Refresh()
  self.frame:Show()
end

function ConfigUI:Toggle()
  self:Initialize()
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Open()
  end
end

function ConfigUI:EnsureSelection()
  local profiles = ModeShift.ProfileManager:GetProfilesForCurrentCharacter()
  if self.selectedProfileId and ModeShift.ProfileManager:GetProfile(self.selectedProfileId) then
    return
  end

  local activeProfileId = ModeShift.Database:GetActiveProfileId()
  if activeProfileId and ModeShift.ProfileManager:GetProfile(activeProfileId) then
    self.selectedProfileId = activeProfileId
    return
  end

  self.selectedProfileId = profiles[1] and profiles[1].id or nil
end

function ConfigUI:GetSelectedProfile()
  self:EnsureSelection()
  if not self.selectedProfileId then
    return nil
  end
  return ModeShift.ProfileManager:GetProfile(self.selectedProfileId)
end

function ConfigUI:SaveProfile(profile)
  ModeShift.ProfileManager:SaveProfile(profile)
  self.selectedProfileId = profile.id
  self:Refresh()
end

function ConfigUI:Refresh()
  if not self.frame then
    return
  end

  self:EnsureSelection()
  self:RefreshProfileList()
  self:RefreshTabs()
  self:RefreshEditor()
  setShown(self.frame.reloadButton, ModeShift.Database:GetRequiresReload())
end

function ConfigUI:RefreshTabs()
  if not self.frame or not self.frame.tabButtons then
    return
  end

  for key, button in pairs(self.frame.tabButtons) do
    button:SetEnabled(key ~= self.activeTab)
  end
end

function ConfigUI:RefreshProfileList()
  local child = clearScroll(self.frame.profileScroll)
  child:SetSize(226, 1)

  local profiles = ModeShift.ProfileManager:GetProfilesForCurrentCharacter()
  local activeProfileId = ModeShift.Database:GetActiveProfileId()
  local y = -2

  if #profiles == 0 then
    local text = makeText(child, "No hay perfiles. Pulsa Nuevo para crear uno.")
    text:SetPoint("TOPLEFT", 4, y)
    text:SetWidth(210)
    child:SetHeight(44)
    return
  end

  for _, profile in ipairs(profiles) do
    local name = profile.name or "Perfil"
    local prefix = profile.id == activeProfileId and "* " or ""
    local button = makeButton(child, prefix .. name, 210, 26, function()
      self.selectedProfileId = profile.id
      self:Refresh()
    end)
    setButtonPoint(button, 2, y)
    if profile.id == self.selectedProfileId then
      button:Disable()
    end
    y = y - 30
  end

  child:SetHeight(math.max(1, -y + 10))
end

function ConfigUI:AddSection(parent, text, y)
  local label = makeText(parent, text, "GameFontNormal")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(560)
  return y - 28
end

function ConfigUI:AddDescription(parent, text, y)
  local label = makeText(parent, text, "GameFontHighlightSmall")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(560)
  return y - 34
end

function ConfigUI:AddLabeledEdit(parent, labelText, value, y, width)
  local label = makeText(parent, labelText, "GameFontNormalSmall")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(170)

  local editBox = makeEditBox(parent, width or 340, value)
  editBox:SetPoint("TOPLEFT", 180, y + 4)
  return editBox, y - 34
end

function ConfigUI:DeleteSelectedProfile()
  local profile = self:GetSelectedProfile()
  if not profile then
    return
  end

  StaticPopupDialogs.MODESHIFT_DELETE_PROFILE = StaticPopupDialogs.MODESHIFT_DELETE_PROFILE or {
    text = "Eliminar este perfil de ModeShift?",
    button1 = DELETE or "Delete",
    button2 = CANCEL or "Cancel",
    OnAccept = function()
      ModeShift.ConfigUI:ConfirmDeleteSelectedProfile()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  StaticPopup_Show("MODESHIFT_DELETE_PROFILE")
end

function ConfigUI:ConfirmDeleteSelectedProfile()
  if self.selectedProfileId then
    ModeShift.ProfileManager:DeleteProfile(self.selectedProfileId)
    self.selectedProfileId = nil
    self:Refresh()
  end
end

function ConfigUI:RefreshEditor()
  local child = clearScroll(self.frame.editorScroll)
  child:SetSize(570, 1)

  local profile = self:GetSelectedProfile()
  if not profile then
    local text = makeText(child, "Crea o selecciona un perfil para empezar.", "GameFontNormal")
    text:SetPoint("TOPLEFT", 4, -8)
    child:SetHeight(80)
    return
  end

  local y = -8
  if self.activeTab == "profile" then
    y = self:BuildProfileTab(child, profile, y)
  elseif self.activeTab == "equipment" then
    y = self:BuildEquipmentTab(child, profile, y)
  elseif self.activeTab == "talents" then
    y = self:BuildTalentsTab(child, profile, y)
  elseif self.activeTab == "ui" then
    y = self:BuildUITab(child, profile, y)
  elseif self.activeTab == "addons" then
    y = self:BuildAddonsTab(child, profile, y)
  elseif self.activeTab == "cvars" then
    y = self:BuildCVarsTab(child, profile, y)
  end

  child:SetHeight(math.max(1, -y + 30))
end

function ConfigUI:BuildProfileTab(parent, profile, y)
  y = self:AddSection(parent, "Datos del perfil", y)
  local nameEdit
  local descriptionEdit
  nameEdit, y = self:AddLabeledEdit(parent, "Nombre", profile.name, y, 350)
  descriptionEdit, y = self:AddLabeledEdit(parent, "Descripcion", profile.description, y, 350)

  local enabledCheck = makeCheck(parent, "Perfil activo en menus", profile.enabled ~= false, function(checked)
    profile.enabled = checked
    self:SaveProfile(profile)
  end)
  enabledCheck:SetPoint("TOPLEFT", 176, y + 6)
  y = y - 34

  local saveButton = makeButton(parent, "Guardar nombre", 130, 24, function()
    profile.name = ModeShift.Utils:Trim(nameEdit:GetText())
    if profile.name == "" then
      profile.name = "Perfil"
    end
    profile.description = ModeShift.Utils:Trim(descriptionEdit:GetText())
    self:SaveProfile(profile)
  end)
  saveButton:SetPoint("TOPLEFT", 180, y + 4)

  local applyButton = makeButton(parent, "Aplicar ahora", 120, 24, function()
    ModeShift.ApplyEngine:ApplyProfile(profile.id, { source = "config" })
  end)
  applyButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)

  local exportButton = makeButton(parent, "Exportar", 100, 24, function()
    self:ShowImportExport("Exportar perfil", self:SerializeProfile(profile), false)
  end)
  exportButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)

  local importButton = makeButton(parent, "Importar", 100, 24, function()
    self:ShowImportExport("Importar perfil", "", true)
  end)
  importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
  y = y - 44

  y = self:AddSection(parent, "Tipo de perfil", y)
  local x = 4
  local rowY = y
  for index, modeType in ipairs(MODE_TYPES) do
    local button = makeButton(parent, (profile.modeType == modeType and "* " or "") .. modeType, 112, 24, function()
      profile.modeType = modeType
      self:SaveProfile(profile)
    end)
    button:SetPoint("TOPLEFT", x, rowY)
    x = x + 118
    if index == 4 then
      x = 4
      rowY = rowY - 30
    end
  end
  y = rowY - 40

  y = self:AddSection(parent, "Spec", y)
  local specText = "Asignada: " .. tostring(profile.specName or profile.specId or "ninguna")
  local specLabel = makeText(parent, specText)
  specLabel:SetPoint("TOPLEFT", 4, y)
  specLabel:SetWidth(360)

  local currentSpecButton = makeButton(parent, "Usar spec actual", 130, 24, function()
    profile.specId = ModeShift:GetCurrentSpecId()
    profile.specName = ModeShift:GetCurrentSpecName()
    profile.classFile = ModeShift:GetClassFile()
    self:SaveProfile(profile)
  end)
  currentSpecButton:SetPoint("TOPLEFT", 180, y + 4)

  local preferredButton = makeButton(parent, "Preferir para esta spec", 160, 24, function()
    if profile.specId then
      ModeShift.Database:SetPreferredProfileForSpec(profile.specId, profile.id)
      ModeShift:Print("perfil recomendado para " .. tostring(profile.specName or profile.specId) .. ".")
      self:Refresh()
    end
  end)
  preferredButton:SetPoint("LEFT", currentSpecButton, "RIGHT", 8, 0)
  y = y - 44

  local internal = makeText(parent, "ID interno: " .. tostring(profile.id), "GameFontDisableSmall")
  internal:SetPoint("TOPLEFT", 4, y)
  internal:SetWidth(560)
  return y - 28
end

function ConfigUI:BuildEquipmentTab(parent, profile, y)
  y = self:AddSection(parent, "Set de equipo de Blizzard", y)
  y = self:AddDescription(parent, "Selecciona un set por nombre. ModeShift guardara el nombre y el ID si Blizzard lo expone.", y)

  local current = "Seleccion actual: "
  if profile.equipment and profile.equipment.enabled and profile.equipment.setName then
    current = current .. profile.equipment.setName
  else
    current = current .. "no cambiar equipo"
  end
  local label = makeText(parent, current, "GameFontHighlight")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(560)
  y = y - 30

  local disabledButton = makeButton(parent, "No cambiar equipo", 150, 24, function()
    profile.equipment.enabled = false
    profile.equipment.setId = nil
    profile.equipment.setName = nil
    self:SaveProfile(profile)
  end)
  disabledButton:SetPoint("TOPLEFT", 4, y)
  y = y - 36

  local sets = ModeShift.EquipmentManager:GetEquipmentSets()
  if #sets == 0 then
    y = self:AddDescription(parent, "No encuentro sets de equipo. Crea sets desde el gestor de equipo de Blizzard y vuelve a abrir esta pestana.", y)
    return y
  end

  for _, set in ipairs(sets) do
    local selected = profile.equipment and profile.equipment.enabled and profile.equipment.setName == set.name
    local button = makeButton(parent, (selected and "* " or "") .. set.name, 300, 24, function()
      profile.equipment.enabled = true
      profile.equipment.setId = set.id
      profile.equipment.setName = set.name
      self:SaveProfile(profile)
    end)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:BuildTalentsTab(parent, profile, y)
  y = self:AddSection(parent, "Loadout de talentos de Blizzard", y)
  y = self:AddDescription(parent, "Selecciona una configuracion de talentos de la spec actual. Si el perfil pertenece a otra spec, cambia de spec antes de elegir.", y)

  local current = "Seleccion actual: "
  if profile.talents and profile.talents.enabled and profile.talents.configName then
    current = current .. profile.talents.configName
  else
    current = current .. "no cambiar talentos"
  end
  local label = makeText(parent, current, "GameFontHighlight")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(560)
  y = y - 30

  local disabledButton = makeButton(parent, "No cambiar talentos", 160, 24, function()
    profile.talents.enabled = false
    profile.talents.configId = nil
    profile.talents.configName = nil
    self:SaveProfile(profile)
  end)
  disabledButton:SetPoint("TOPLEFT", 4, y)

  local autoCheck = makeCheck(parent, "Aplicar automaticamente", profile.talents and profile.talents.autoApply ~= false, function(checked)
    profile.talents.autoApply = checked
    self:SaveProfile(profile)
  end)
  autoCheck:SetPoint("TOPLEFT", 180, y + 3)
  y = y - 38

  local loadouts = ModeShift.TalentManager:GetTalentLoadouts(ModeShift:GetCurrentSpecId())
  if #loadouts == 0 then
    y = self:AddDescription(parent, "No encuentro loadouts de talentos para la spec actual o la API no esta disponible.", y)
    return y
  end

  for _, loadout in ipairs(loadouts) do
    local selected = profile.talents and profile.talents.enabled and profile.talents.configName == loadout.name
    local button = makeButton(parent, (selected and "* " or "") .. loadout.name, 320, 24, function()
      profile.talents.enabled = true
      profile.talents.configId = loadout.id
      profile.talents.configName = loadout.name
      profile.specId = ModeShift:GetCurrentSpecId()
      profile.specName = ModeShift:GetCurrentSpecName()
      self:SaveProfile(profile)
    end)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:BuildUITab(parent, profile, y)
  y = self:AddSection(parent, "Layout de Edit Mode", y)
  y = self:AddDescription(parent, "Selecciona un layout de la UI de Blizzard si la API de Edit Mode esta disponible.", y)

  local current = "Seleccion actual: "
  if profile.editMode and profile.editMode.enabled and profile.editMode.layoutName then
    current = current .. profile.editMode.layoutName
  else
    current = current .. "no cambiar layout"
  end
  local label = makeText(parent, current, "GameFontHighlight")
  label:SetPoint("TOPLEFT", 4, y)
  label:SetWidth(560)
  y = y - 30

  local disabledButton = makeButton(parent, "No cambiar layout", 160, 24, function()
    profile.editMode.enabled = false
    profile.editMode.layoutId = nil
    profile.editMode.layoutName = nil
    self:SaveProfile(profile)
  end)
  disabledButton:SetPoint("TOPLEFT", 4, y)
  y = y - 36

  local layouts = ModeShift.EditModeManager and ModeShift.EditModeManager:GetLayouts() or {}
  if #layouts == 0 then
    y = self:AddDescription(parent, "No encuentro layouts de Edit Mode. Puedes seguir usando equipo, talentos, addons y CVars sin problema.", y)
    return y
  end

  for _, layout in ipairs(layouts) do
    local selected = profile.editMode and profile.editMode.enabled and profile.editMode.layoutName == layout.name
    local button = makeButton(parent, (selected and "* " or "") .. layout.name, 320, 24, function()
      profile.editMode.enabled = true
      profile.editMode.layoutId = layout.id
      profile.editMode.layoutName = layout.name
      self:SaveProfile(profile)
    end)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:SetAddonState(profile, addonName, state)
  profile.addons.enabled = true
  profile.addons.enable = ModeShift.Utils:SafeArray(profile.addons.enable)
  profile.addons.disable = ModeShift.Utils:SafeArray(profile.addons.disable)
  removeValue(profile.addons.enable, addonName)
  removeValue(profile.addons.disable, addonName)

  if state == "enable" then
    addUnique(profile.addons.enable, addonName)
  elseif state == "disable" then
    addUnique(profile.addons.disable, addonName)
  end

  self:SaveProfile(profile)
end

function ConfigUI:GetAddonState(profile, addonName)
  if contains(profile.addons.enable, addonName) then
    return "enable"
  end
  if contains(profile.addons.disable, addonName) then
    return "disable"
  end
  return "ignore"
end

function ConfigUI:BuildAddonsTab(parent, profile, y)
  y = self:AddSection(parent, "Addons y perfiles internos", y)
  y = self:AddDescription(parent, "Click en Estado para alternar Ignorar, Activar y Desactivar. Los perfiles internos aparecen solo para addons soportados.", y)

  local enabledCheck = makeCheck(parent, "Gestionar addons en este perfil", profile.addons and profile.addons.enabled, function(checked)
    profile.addons.enabled = checked
    self:SaveProfile(profile)
  end)
  enabledCheck:SetPoint("TOPLEFT", 0, y + 4)
  y = y - 34

  local addons = ModeShift.AddonManager:GetInstalledAddons()
  for _, addon in ipairs(addons) do
    addon.modeShiftProfiles = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetAvailableProfiles(addon.name) or {}
    addon.modeShiftProfileCount = #addon.modeShiftProfiles
    addon.modeShiftSelected = self:GetAddonState(profile, addon.name) ~= "ignore"
  end
  table.sort(addons, function(a, b)
    if a.modeShiftSelected ~= b.modeShiftSelected then
      return a.modeShiftSelected
    end
    if (a.modeShiftProfileCount or 0) ~= (b.modeShiftProfileCount or 0) then
      return (a.modeShiftProfileCount or 0) > (b.modeShiftProfileCount or 0)
    end
    return string.lower(a.name or "") < string.lower(b.name or "")
  end)

  if #addons == 0 then
    y = self:AddDescription(parent, "No encuentro la lista de addons instalados.", y)
    return y
  end

  local profileCheck = makeCheck(parent, "Gestionar perfiles internos de addons soportados", profile.addonProfiles and profile.addonProfiles.enabled, function(checked)
    profile.addonProfiles.enabled = checked
    self:SaveProfile(profile)
  end)
  profileCheck:SetPoint("TOPLEFT", 0, y + 4)
  y = y - 36

  local header = makeText(parent, "Addon", "GameFontNormalSmall")
  header:SetPoint("TOPLEFT", 4, y)
  header:SetWidth(190)
  local stateHeader = makeText(parent, "Estado", "GameFontNormalSmall")
  stateHeader:SetPoint("TOPLEFT", 205, y)
  stateHeader:SetWidth(90)
  local profileHeader = makeText(parent, "Perfil interno", "GameFontNormalSmall")
  profileHeader:SetPoint("TOPLEFT", 320, y)
  profileHeader:SetWidth(200)
  y = y - 22

  for _, addon in ipairs(addons) do
    local state = self:GetAddonState(profile, addon.name)
    local installedState = addon.enabled and "cargado/activo" or "desactivado"
    local label = makeText(parent, addon.name)
    label:SetPoint("TOPLEFT", 4, y - 2)
    label:SetWidth(190)
    if label.SetWordWrap then
      label:SetWordWrap(false)
    end

    local stateText = "Ignorar"
    if state == "enable" then
      stateText = "Activar"
    elseif state == "disable" then
      stateText = "Desactivar"
    end

    local stateButton = makeButton(parent, stateText, 96, 22, function()
      local current = self:GetAddonState(profile, addon.name)
      local nextState = "enable"
      if current == "enable" then
        nextState = "disable"
      elseif current == "disable" then
        nextState = "ignore"
      end
      self:SetAddonState(profile, addon.name, nextState)
    end)
    stateButton:SetPoint("TOPLEFT", 205, y)

    local details = makeText(parent, installedState, "GameFontDisableSmall")
    details:SetPoint("TOPLEFT", 4, y - 16)
    details:SetWidth(190)

    y = self:BuildAddonProfilePicker(parent, profile, addon.name, y)
    y = y - 32
  end

  return y
end

function ConfigUI:BuildAddonProfilePicker(parent, profile, addonName, y)
  profile.addonProfiles = profile.addonProfiles or { enabled = false, entries = {} }
  profile.addonProfiles.entries = profile.addonProfiles.entries or {}

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  local profiles = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetAvailableProfiles(addonName) or {}
  if not integration and #profiles == 0 then
    local unsupported = makeText(parent, "sin perfiles soportados", "GameFontDisableSmall")
    unsupported:SetPoint("TOPLEFT", 320, y + 2)
    unsupported:SetWidth(220)
    return y
  end

  local entry = profile.addonProfiles.entries[addonName] or { enabled = false, profileName = nil }
  local label = integration and integration.displayName or addonName
  local selected = entry.enabled and entry.profileName or "No cambiar"

  local currentButton = makeButton(parent, selected, 190, 22, function()
    if #profiles == 0 then
      entry.enabled = not entry.enabled
    elseif not entry.enabled or not entry.profileName then
      entry.enabled = true
      entry.profileName = profiles[1]
    else
      local nextIndex = nil
      for index, profileName in ipairs(profiles) do
        if profileName == entry.profileName then
          nextIndex = index + 1
          break
        end
      end
      if not nextIndex or nextIndex > #profiles then
        entry.enabled = false
        entry.profileName = nil
      else
        entry.profileName = profiles[nextIndex]
      end
    end

    if not entry.enabled then
      entry.profileName = nil
    end
    profile.addonProfiles.entries[addonName] = entry
    profile.addonProfiles.enabled = true
    self:SaveProfile(profile)
  end)
  currentButton:SetPoint("TOPLEFT", 320, y)

  local clearButton = makeButton(parent, "X", 24, 22, function()
    profile.addonProfiles.entries[addonName] = nil
    self:SaveProfile(profile)
  end)
  clearButton:SetPoint("LEFT", currentButton, "RIGHT", 4, 0)

  if #profiles == 0 then
    local note = makeText(parent, label .. ": sin lista disponible", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", 320, y - 16)
    note:SetWidth(230)
    return y
  end

  local x = 320
  local rowY = y - 26
  for index, profileName in ipairs(profiles) do
    if index <= 2 then
      local button = makeButton(parent, profileName, 88, 20, function()
        profile.addonProfiles.enabled = true
        profile.addonProfiles.entries[addonName] = {
          enabled = true,
          profileName = profileName,
        }
        self:SaveProfile(profile)
      end)
      button:SetPoint("TOPLEFT", x, rowY)
      x = x + 94
    end
  end

  if #profiles > 2 then
    local more = makeText(parent, "+" .. tostring(#profiles - 2) .. " mas", "GameFontDisableSmall")
    more:SetPoint("TOPLEFT", x, rowY + 3)
    more:SetWidth(70)
  end

  return y - 24
end

function ConfigUI:BuildCVarsTab(parent, profile, y)
  y = self:AddSection(parent, "Opciones avanzadas de consola", y)
  y = self:AddDescription(parent, "CVars son variables internas de configuracion de WoW. No las necesitas salvo que sepas exactamente que ajuste quieres guardar.", y)

  local enabledCheck = makeCheck(parent, "Aplicar variables de consola en este perfil", profile.cvars and profile.cvars.enabled, function(checked)
    profile.cvars.enabled = checked
    self:SaveProfile(profile)
  end)
  enabledCheck:SetPoint("TOPLEFT", 0, y + 4)
  y = y - 36

  local nameEdit = makeEditBox(parent, 200, "")
  nameEdit:SetPoint("TOPLEFT", 4, y)
  local valueEdit = makeEditBox(parent, 160, "")
  valueEdit:SetPoint("LEFT", nameEdit, "RIGHT", 12, 0)
  local addButton = makeButton(parent, "Anadir ajuste", 120, 24, function()
    local name = ModeShift.Utils:Trim(nameEdit:GetText())
    local value = ModeShift.Utils:Trim(valueEdit:GetText())
    if name ~= "" then
      profile.cvars.values = profile.cvars.values or {}
      profile.cvars.values[name] = value
      profile.cvars.enabled = true
      self:SaveProfile(profile)
    end
  end)
  addButton:SetPoint("LEFT", valueEdit, "RIGHT", 12, 0)
  y = y - 38

  local hasAny = false
  for name, value in pairs(profile.cvars.values or {}) do
    hasAny = true
    local row = makeText(parent, tostring(name) .. " = " .. tostring(value))
    row:SetPoint("TOPLEFT", 4, y)
    row:SetWidth(360)
    local deleteButton = makeButton(parent, "Quitar", 80, 22, function()
      profile.cvars.values[name] = nil
      self:SaveProfile(profile)
    end)
    deleteButton:SetPoint("TOPLEFT", 390, y + 4)
    y = y - 28
  end

  if not hasAny then
    y = self:AddDescription(parent, "No hay variables de consola configuradas.", y)
  end

  return y
end

function ConfigUI:SerializeProfile(profile)
  local lines = { "MODESHIFT_PROFILE_V1" }
  table.insert(lines, "name=" .. escapeValue(profile.name))
  table.insert(lines, "description=" .. escapeValue(profile.description))
  table.insert(lines, "modeType=" .. escapeValue(profile.modeType))
  table.insert(lines, "classFile=" .. escapeValue(profile.classFile))
  table.insert(lines, "specId=" .. escapeValue(profile.specId))
  table.insert(lines, "specName=" .. escapeValue(profile.specName))
  table.insert(lines, "equipment.enabled=" .. (profile.equipment.enabled and "1" or "0"))
  table.insert(lines, "equipment.setName=" .. escapeValue(profile.equipment.setName))
  table.insert(lines, "talents.enabled=" .. (profile.talents.enabled and "1" or "0"))
  table.insert(lines, "talents.configName=" .. escapeValue(profile.talents.configName))
  table.insert(lines, "talents.autoApply=" .. (profile.talents.autoApply ~= false and "1" or "0"))
  table.insert(lines, "editMode.enabled=" .. (profile.editMode.enabled and "1" or "0"))
  table.insert(lines, "editMode.layoutName=" .. escapeValue(profile.editMode.layoutName))
  table.insert(lines, "addons.enabled=" .. (profile.addons.enabled and "1" or "0"))

  for _, addonName in ipairs(profile.addons.enable or {}) do
    table.insert(lines, "addon.enable=" .. escapeValue(addonName))
  end
  for _, addonName in ipairs(profile.addons.disable or {}) do
    table.insert(lines, "addon.disable=" .. escapeValue(addonName))
  end
  for addonName, entry in pairs(profile.addonProfiles.entries or {}) do
    if type(entry) == "table" and entry.enabled and entry.profileName then
      table.insert(lines, "addonProfile." .. escapeValue(addonName) .. "=" .. escapeValue(entry.profileName))
    end
  end

  table.insert(lines, "cvars.enabled=" .. (profile.cvars.enabled and "1" or "0"))
  for name, value in pairs(profile.cvars.values or {}) do
    table.insert(lines, "cvar." .. escapeValue(name) .. "=" .. escapeValue(value))
  end

  return table.concat(lines, "\n")
end

function ConfigUI:DeserializeProfile(text)
  local profile = {
    name = "Perfil importado",
    description = "",
    modeType = "CUSTOM",
    classFile = ModeShift:GetClassFile(),
    specId = ModeShift:GetCurrentSpecId(),
    specName = ModeShift:GetCurrentSpecName(),
    equipment = { enabled = false, setName = nil },
    talents = { enabled = false, configName = nil, autoApply = true },
    editMode = { enabled = false, layoutName = nil },
    addons = { enabled = true, enable = {}, disable = {} },
    addonProfiles = { enabled = false, entries = {} },
    cvars = { enabled = false, values = {} },
  }

  local firstLine = true
  local sawHeader = false
  for line in string.gmatch(text or "", "([^\n]+)") do
    if firstLine then
      firstLine = false
      if ModeShift.Utils:Trim(line) ~= "MODESHIFT_PROFILE_V1" then
        return nil, "Formato de importacion no reconocido"
      end
      sawHeader = true
    else
      local key, value = line:match("^([^=]+)=(.*)$")
      if key then
        value = unescapeValue(value)
        if key == "name" then
          profile.name = value
        elseif key == "description" then
          profile.description = value
        elseif key == "modeType" then
          profile.modeType = value
        elseif key == "classFile" then
          profile.classFile = value ~= "" and value or nil
        elseif key == "specId" then
          profile.specId = tonumber(value)
        elseif key == "specName" then
          profile.specName = value ~= "" and value or nil
        elseif key == "equipment.enabled" then
          profile.equipment.enabled = value == "1"
        elseif key == "equipment.setName" then
          profile.equipment.setName = value ~= "" and value or nil
        elseif key == "talents.enabled" then
          profile.talents.enabled = value == "1"
        elseif key == "talents.configName" then
          profile.talents.configName = value ~= "" and value or nil
        elseif key == "talents.autoApply" then
          profile.talents.autoApply = value ~= "0"
        elseif key == "editMode.enabled" then
          profile.editMode.enabled = value == "1"
        elseif key == "editMode.layoutName" then
          profile.editMode.layoutName = value ~= "" and value or nil
        elseif key == "addons.enabled" then
          profile.addons.enabled = value == "1"
        elseif key == "addon.enable" then
          table.insert(profile.addons.enable, value)
        elseif key == "addon.disable" then
          table.insert(profile.addons.disable, value)
        elseif key:match("^addonProfile%.") then
          local addonName = unescapeValue(key:gsub("^addonProfile%.", ""))
          profile.addonProfiles.enabled = true
          profile.addonProfiles.entries[addonName] = {
            enabled = true,
            profileName = value,
          }
        elseif key == "cvars.enabled" then
          profile.cvars.enabled = value == "1"
        elseif key:match("^cvar%.") then
          local cvarName = unescapeValue(key:gsub("^cvar%.", ""))
          profile.cvars.values[cvarName] = value
        end
      end
    end
  end

  if not sawHeader then
    return nil, "Pega primero un perfil exportado de ModeShift"
  end

  profile.name = ModeShift.Utils:Trim(profile.name)
  if profile.name == "" then
    profile.name = "Perfil importado"
  end

  return profile
end

function ConfigUI:ShowImportExport(title, text, canImport)
  if not self.importFrame then
    local frame = CreateFrame("Frame", "ModeShiftImportExportFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(620, 430)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg or frame, "LEFT", 8, 0)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 16, -42)
    frame.scroll:SetSize(570, 310)

    frame.editBox = CreateFrame("EditBox", nil, frame.scroll)
    frame.editBox:SetMultiLine(true)
    frame.editBox:SetAutoFocus(false)
    frame.editBox:SetFontObject(ChatFontNormal)
    frame.editBox:SetWidth(540)
    frame.editBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)
    frame.scroll:SetScrollChild(frame.editBox)

    frame.importButton = makeButton(frame, "Importar", 110, 24, function()
      local data, err = ModeShift.ConfigUI:DeserializeProfile(frame.editBox:GetText())
      if not data then
        ModeShift:Print(err or "No se pudo importar el perfil.")
        return
      end
      local profile = ModeShift.ProfileManager:CreateProfile(data)
      ModeShift.ConfigUI.selectedProfileId = profile.id
      ModeShift.ConfigUI.importFrame:Hide()
      ModeShift.ConfigUI:Refresh()
      ModeShift:Print("perfil importado: " .. profile.name)
    end)
    frame.importButton:SetPoint("BOTTOMLEFT", 16, 16)

    frame.closeButton = makeButton(frame, "Cerrar", 110, 24, function()
      frame:Hide()
    end)
    frame.closeButton:SetPoint("LEFT", frame.importButton, "RIGHT", 8, 0)

    self.importFrame = frame
  end

  self.importFrame.title:SetText(title or "Perfil")
  self.importFrame.editBox:SetText(text or "")
  self.importFrame.editBox:SetCursorPosition(0)
  self.importFrame.editBox:SetHeight(300)
  setShown(self.importFrame.importButton, canImport)
  self.importFrame:Show()
end

ModeShift:RegisterModule("ConfigUI", ConfigUI)
