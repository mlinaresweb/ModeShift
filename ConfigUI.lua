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

local function makeButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  button:SetSize(width or 120, height or 24)
  button:SetText(text or "")
  button:RegisterForClicks("AnyUp")
  if onClick then
    button:SetScript("OnClick", onClick)
  end
  return button
end

local function raiseFrame(frame)
  if not frame then
    return
  end

  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(9000)
  if frame.SetToplevel then
    frame:SetToplevel(true)
  end
  if frame.Raise then
    frame:Raise()
  end
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

local function styleButton(button, selected)
  if not button then
    return
  end

  if not button.modeShiftSelectedBg then
    button.modeShiftSelectedBg = button:CreateTexture(nil, "BACKGROUND")
    button.modeShiftSelectedBg:SetPoint("TOPLEFT", 2, -2)
    button.modeShiftSelectedBg:SetPoint("BOTTOMRIGHT", -2, 2)
    button.modeShiftSelectedBg:SetColorTexture(0.16, 0.16, 0.16, 0.96)
  end
  button.modeShiftSelectedBg:Hide()

  local fontString = button:GetFontString()
  if fontString then
    fontString:SetTextColor(1, 0.82, 0)
  end

  if button.SetEnabled then
    button:SetEnabled(not selected)
  end

  local normal = button.GetNormalTexture and button:GetNormalTexture()
  if normal and normal.SetVertexColor then
    normal:SetVertexColor(1, 1, 1, 1)
  end
end

local function addHover(button, selected)
  if not button then
    return
  end

  button:SetScript("OnEnter", function(self)
    local fontString = self:GetFontString()
    if fontString then
      fontString:SetTextColor(1, 1, 1)
    end
    if self.modeShiftSelectedBg then
      self.modeShiftSelectedBg:SetColorTexture(selected and 0.24 or 0.4, selected and 0.24 or 0.03, selected and 0.24 or 0.02, selected and 0.98 or 0.55)
      self.modeShiftSelectedBg:Show()
    end
    local normal = self.GetNormalTexture and self:GetNormalTexture()
    if normal and normal.SetVertexColor then
      if selected then
        normal:SetVertexColor(0.62, 0.62, 0.62, 1)
      else
        normal:SetVertexColor(1.25, 1.25, 1.25, 1)
      end
    end
  end)
  button:SetScript("OnLeave", function(self)
    if self.modeShiftSelectedBg then
      self.modeShiftSelectedBg:SetColorTexture(0.16, 0.16, 0.16, 0.96)
      self.modeShiftSelectedBg:SetShown(selected and true or false)
    end
    styleButton(self, selected)
  end)
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

local function isCooldownManagerAddon(addonName)
  return tostring(addonName or ""):lower():find("cooldownmanager", 1, true) ~= nil
end

function ConfigUI:Initialize()
  if self.frame then
    return
  end

  local frame = CreateFrame("Frame", "ModeShiftConfigFrame", UIParent, "BasicFrameTemplateWithInset")
  if UISpecialFrames then
    local alreadyRegistered = false
    for _, frameName in ipairs(UISpecialFrames) do
      if frameName == "ModeShiftConfigFrame" then
        alreadyRegistered = true
        break
      end
    end
    if not alreadyRegistered then
      table.insert(UISpecialFrames, "ModeShiftConfigFrame")
    end
  end
  frame:SetSize(1040, 650)
  frame:SetPoint("CENTER")
  raiseFrame(frame)
  if frame.SetBackdropColor then
    frame:SetBackdropColor(0.025, 0.025, 0.025, 0.96)
  end
  if frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(0.75, 0.08, 0.04, 1)
  end
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnMouseDown", function(self)
    ModeShift.ConfigUI:CloseDropdown()
    raiseFrame(self)
  end)
  frame:SetScript("OnHide", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
    self:CloseDropdown()
    if MenuUtil and MenuUtil.CloseAllMenus then
      MenuUtil.CloseAllMenus()
    end
    if CloseMenus then
      CloseMenus()
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

  frame.leftPanelBg = frame:CreateTexture(nil, "BACKGROUND")
  frame.leftPanelBg:SetColorTexture(0, 0, 0, 0.35)
  frame.leftPanelBg:SetPoint("TOPLEFT", 12, -54)
  frame.leftPanelBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 272, 86)

  frame.editorPanelBg = frame:CreateTexture(nil, "BACKGROUND")
  frame.editorPanelBg:SetColorTexture(0, 0, 0, 0.28)
  frame.editorPanelBg:SetPoint("TOPLEFT", 280, -60)
  frame.editorPanelBg:SetPoint("BOTTOMRIGHT", -24, 18)

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
  frame.editorScroll:SetSize(720, 540)
  frame.editorScroll:HookScript("OnVerticalScroll", function()
    self:CloseDropdown()
  end)
  frame.editorScroll:HookScript("OnMouseWheel", function()
    self:CloseDropdown()
  end)

  frame:Hide()
  self.frame = frame
end

function ConfigUI:CloseDropdown()
  if CloseDropDownMenus then
    CloseDropDownMenus()
  end

  if self.dropdown then
    self.dropdown:Hide()
    if self.dropdown.rows then
      for _, row in ipairs(self.dropdown.rows) do
        row:Hide()
      end
    end
  end

  if self.dropdownBlocker then
    self.dropdownBlocker:Hide()
  end
end

function ConfigUI:OpenDropdown(anchor, title, items, width)
  self:CloseDropdown()
  if not anchor or type(items) ~= "table" then
    return
  end

  if not self.dropdown then
    self.dropdown = CreateFrame("Frame", "ModeShiftDropdownMenu", self.frame or UIParent, "BackdropTemplate")
    self.dropdown:SetFrameStrata("TOOLTIP")
    self.dropdown:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 100) + 100)
    self.dropdown:SetToplevel(true)
    self.dropdown:EnableMouse(true)
    if self.dropdown.EnableMouseWheel then
      self.dropdown:EnableMouseWheel(true)
    end
    self.dropdown:SetClampedToScreen(true)
    self.dropdown.rows = {}
    self.dropdown:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })

    self.dropdown.title = self.dropdown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    self.dropdown.title:SetPoint("TOPLEFT", 12, -10)
    self.dropdown.title:SetJustifyH("LEFT")
  end

  if not self.dropdownBlocker then
    self.dropdownBlocker = CreateFrame("Button", "ModeShiftDropdownBlocker", UIParent)
    self.dropdownBlocker:SetAllPoints(UIParent)
    self.dropdownBlocker:SetFrameStrata("TOOLTIP")
    self.dropdownBlocker:EnableMouse(true)
    if self.dropdownBlocker.EnableMouseWheel then
      self.dropdownBlocker:EnableMouseWheel(true)
    end
    self.dropdownBlocker:RegisterForClicks("AnyUp")
    self.dropdownBlocker:SetScript("OnClick", function()
      self:CloseDropdown()
    end)
    self.dropdownBlocker:SetScript("OnMouseWheel", function()
      self:CloseDropdown()
    end)
  end

  local menuItems = items
  local menuTitle = title or "Seleccion"
  local menuWidth = width or 320
  local rowHeight = 22
  local titleHeight = 30
  local padding = 12
  local dividerHeight = 9
  local maxVisibleRows = 12
  local dropdown = self.dropdown
  local rows = dropdown.rows
  dropdown:SetParent(self.frame or UIParent)
  dropdown:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 100) + 100)
  self.dropdownBlocker:SetFrameLevel(dropdown:GetFrameLevel() - 10)
  self.dropdownBlocker:Show()

  local function runItem(itemData)
    self:CloseDropdown()
    if itemData and type(itemData.onClick) == "function" then
      itemData.onClick()
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if self.frame and self.frame:IsShown() then
          self:Refresh()
        end
      end)
    elseif self.frame and self.frame:IsShown() then
      self:Refresh()
    end
  end

  local renderRows
  local maxOffset = math.max(0, #menuItems - maxVisibleRows)
  local selectedIndex = 1
  for index, item in ipairs(menuItems) do
    if item.selected then
      selectedIndex = index
      break
    end
  end
  dropdown.scrollOffset = math.max(0, math.min(maxOffset, selectedIndex - 4))

  local function scrollDropdown(delta)
    if maxOffset <= 0 then
      return
    end

    local oldOffset = dropdown.scrollOffset or 0
    local newOffset = oldOffset
    if delta and delta < 0 then
      newOffset = math.min(maxOffset, oldOffset + 3)
    else
      newOffset = math.max(0, oldOffset - 3)
    end

    if newOffset ~= oldOffset then
      dropdown.scrollOffset = newOffset
      if renderRows then
        renderRows()
      end
    end
  end

  dropdown:SetScript("OnMouseWheel", function(_, delta)
    scrollDropdown(delta)
  end)

  local function ensureRow(index)
    if rows[index] then
      return rows[index]
    end

    local row = CreateFrame("Button", nil, self.frame or UIParent, "UIPanelButtonTemplate")
    row:SetFrameStrata("TOOLTIP")
    row:SetFrameLevel(dropdown:GetFrameLevel() + 10)
    if row.SetToplevel then
      row:SetToplevel(true)
    end
    row:SetHitRectInsets(0, 0, 0, 0)
    row:EnableMouse(true)
    if row.EnableMouseWheel then
      row:EnableMouseWheel(true)
    end
    row:RegisterForClicks("LeftButtonUp")

    row.bg = row:CreateTexture(nil, "BORDER")
    row.bg:SetAllPoints()

    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.check:SetSize(16, 16)
    row.check:SetPoint("LEFT", 5, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 26, 0)
    row.text:SetPoint("RIGHT", -8, 0)
    row.text:SetJustifyH("LEFT")
    if row.text.SetWordWrap then
      row.text:SetWordWrap(false)
    end

    rows[index] = row
    return row
  end

  dropdown:ClearAllPoints()
  dropdown:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -3)
  dropdown:SetBackdropColor(0.015, 0.015, 0.018, 1)
  dropdown:SetBackdropBorderColor(0.95, 0.82, 0.18, 1)
  dropdown:SetWidth(menuWidth)
  dropdown.title:SetText(menuTitle)
  dropdown.title:SetWidth(menuWidth - 24)

  renderRows = function()
    for _, row in ipairs(rows) do
      row:Hide()
    end

    local y = -titleHeight
    local rowIndex = 0
    local firstItem = (dropdown.scrollOffset or 0) + 1
    local lastItem = math.min(#menuItems, firstItem + maxVisibleRows - 1)

    for itemIndex = firstItem, lastItem do
      local itemData = menuItems[itemIndex]
      if itemData.divider then
        rowIndex = rowIndex + 1
        local row = ensureRow(rowIndex)
        row:SetParent(self.frame or UIParent)
        row:SetFrameStrata("TOOLTIP")
        row:SetFrameLevel(dropdown:GetFrameLevel() + 20)
        if row.SetToplevel then
          row:SetToplevel(true)
        end
        row:ClearAllPoints()
        row:SetSize(menuWidth - 12, dividerHeight)
        row:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 6, y)
        row.bg:ClearAllPoints()
        row.bg:SetColorTexture(0.78, 0.78, 0.78, 0.22)
        row.bg:SetPoint("LEFT", 8, 0)
        row.bg:SetPoint("RIGHT", -8, 0)
        row.bg:SetHeight(1)
        row.check:Hide()
        row.text:SetText("")
        row:SetScript("OnEnter", nil)
        row:SetScript("OnLeave", nil)
        row:SetScript("OnClick", nil)
        row:SetScript("OnMouseWheel", function(_, delta)
          scrollDropdown(delta)
        end)
        row:Disable()
        row:Show()
        y = y - dividerHeight
      else
        rowIndex = rowIndex + 1
        local row = ensureRow(rowIndex)
        local selected = itemData.selected and true or false
        local disabled = itemData.disabled and true or false

        row:SetParent(self.frame or UIParent)
        row:SetFrameStrata("TOOLTIP")
        row:SetFrameLevel(dropdown:GetFrameLevel() + 20)
        if row.SetToplevel then
          row:SetToplevel(true)
        end
        row:ClearAllPoints()
        row.bg:ClearAllPoints()
        row.bg:SetAllPoints()
        row:SetSize(menuWidth - 12, rowHeight)
        row:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 6, y)
        row.text:SetText(tostring(itemData.text or ""))
        row.text:SetTextColor(disabled and 0.45 or 1, disabled and 0.45 or 0.82, disabled and 0.45 or 0.05)
        row:SetText("")
        row.check:SetShown(selected)
        row.bg:SetColorTexture(selected and 0.45 or 0.02, selected and 0.02 or 0.02, selected and 0.02 or 0.025, selected and 1 or 1)
        row:SetScript("OnMouseWheel", function(_, delta)
          scrollDropdown(delta)
        end)

        if disabled then
          row:Disable()
          row:SetScript("OnEnter", nil)
          row:SetScript("OnLeave", nil)
          row:SetScript("OnClick", nil)
        else
          row:Enable()
          row:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.78, 0.58, 0.02, 0.95)
            self.text:SetTextColor(1, 1, 1)
          end)
          row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(selected and 0.45 or 0.02, selected and 0.02 or 0.02, selected and 0.02 or 0.025, selected and 1 or 1)
            self.text:SetTextColor(1, 0.82, 0.05)
          end)
          row:SetScript("OnClick", function()
            runItem(itemData)
          end)
        end
        row:Show()
        y = y - rowHeight
      end
    end

    dropdown:SetHeight(math.abs(y) + padding)
  end

  renderRows()
  dropdown:Show()
end

function ConfigUI:Open()
  self:Initialize()
  self:EnsureSelection()
  self:Refresh()
  raiseFrame(self.frame)
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

  if ModeShift.AddonProfileManager and ModeShift.AddonProfileManager.ClearCurrentCache then
    ModeShift.AddonProfileManager:ClearCurrentCache()
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
    local selected = profile.id == activeProfileId
    local button = makeButton(child, name, 210, 26, function()
      self.selectedProfileId = profile.id
      self:Refresh()
    end)
    styleButton(button, selected)
    addHover(button, selected)
    setButtonPoint(button, 2, y)
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
  child:SetSize(680, 1)

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
    local selected = profile.modeType == modeType
    local button = makeButton(parent, modeType, 136, 24, function()
      profile.modeType = modeType
      self:SaveProfile(profile)
    end)
    styleButton(button, selected)
    addHover(button, selected)
    button:SetPoint("TOPLEFT", x, rowY)
    x = x + 142
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
    local button = makeButton(parent, set.name, 300, 24, function()
      profile.equipment.enabled = true
      profile.equipment.setId = set.id
      profile.equipment.setName = set.name
      self:SaveProfile(profile)
    end)
    styleButton(button, selected)
    addHover(button, selected)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:BuildTalentsTab(parent, profile, y)
  y = self:AddSection(parent, "Loadout de talentos de Blizzard", y)
  y = self:AddDescription(parent, "Selecciona una configuracion de talentos de la spec actual. Si el perfil pertenece a otra spec, cambia de spec antes de elegir.", y)

  local activeLoadout = ModeShift.TalentManager and ModeShift.TalentManager:GetCurrentLoadout(ModeShift:GetCurrentSpecId()) or nil
  local activeLabel = makeText(parent, "Talentos activos ahora: " .. (activeLoadout and activeLoadout.name or "desconocidos"), "GameFontHighlight")
  activeLabel:SetPoint("TOPLEFT", 4, y)
  activeLabel:SetWidth(560)
  y = y - 22

  local current = "Este perfil aplicara: "
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
    local selected = profile.talents
      and profile.talents.enabled
      and ((profile.talents.configName and profile.talents.configName == loadout.name) or (profile.talents.configId and profile.talents.configId == loadout.id))
    local button = makeButton(parent, loadout.name, 320, 24, function()
      profile.talents.enabled = true
      profile.talents.configId = loadout.id
      profile.talents.configName = loadout.name
      profile.specId = ModeShift:GetCurrentSpecId()
      profile.specName = ModeShift:GetCurrentSpecName()
      self:SaveProfile(profile)
    end)
    styleButton(button, selected)
    addHover(button, selected)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:BuildUITab(parent, profile, y)
  y = self:AddSection(parent, "Layout de Edit Mode", y)
  y = self:AddDescription(parent, "Selecciona un layout de la UI de Blizzard si la API de Edit Mode esta disponible.", y)

  local activeLayout = ModeShift.EditModeManager and ModeShift.EditModeManager:GetCurrentLayout() or nil
  local activeText = "UI activa ahora: " .. (activeLayout and activeLayout.name or "desconocida")
  local activeLabel = makeText(parent, activeText, "GameFontHighlight")
  activeLabel:SetPoint("TOPLEFT", 4, y)
  activeLabel:SetWidth(560)
  y = y - 22

  local current = "Este perfil aplicara: "
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
    self:RefreshEditor()
  end)
  disabledButton:SetPoint("TOPLEFT", 4, y)
  y = y - 36

  local layouts = ModeShift.EditModeManager and ModeShift.EditModeManager:GetLayouts() or {}
  if #layouts == 0 then
    y = self:AddDescription(parent, "No encuentro layouts de Edit Mode. Puedes seguir usando equipo, talentos, addons y CVars sin problema.", y)
    return y
  end

  for _, layout in ipairs(layouts) do
    local selected = profile.editMode
      and profile.editMode.enabled
      and (tostring(profile.editMode.layoutId or "") == tostring(layout.id or "") or profile.editMode.layoutName == layout.name)
    local button = makeButton(parent, layout.name, 320, 24, function()
      profile.editMode.enabled = true
      profile.editMode.layoutId = layout.id
      profile.editMode.layoutName = layout.name
      self:SaveProfile(profile)
      self:RefreshEditor()
    end)
    styleButton(button, selected)
    addHover(button, selected)
    button:SetPoint("TOPLEFT", 4, y)
    y = y - 28
  end

  return y
end

function ConfigUI:BuildAddonsTab(parent, profile, y)
  y = self:AddSection(parent, "Addons y perfiles internos", y)
  y = self:AddDescription(parent, "Marca los addons que deben cargarse en este perfil. Los no marcados se desactivaran al aplicar el perfil. Si hay perfiles internos, puedes elegirlos a la derecha.", y)
  ModeShift.ProfileManager:EnsureAddonSnapshot(profile)

  local enabledCheck = makeCheck(parent, "Gestionar addons en este perfil", profile.addons and profile.addons.enabled, function(checked)
    profile.addons.enabled = checked
    self:SaveProfile(profile)
  end)
  enabledCheck:SetPoint("TOPLEFT", 0, y + 4)
  y = y - 34

  local snapshotText = makeText(parent, "Estado inicial capturado automaticamente al crear el perfil.", "GameFontDisableSmall")
  snapshotText:SetPoint("TOPLEFT", 4, y)
  snapshotText:SetWidth(300)

  local captureButton = makeButton(parent, "Actualizar desde estado actual", 190, 22, function()
    ModeShift.ProfileManager:CaptureCurrentAddons(profile)
    self:SaveProfile(profile)
  end)
  captureButton:SetPoint("TOPLEFT", 320, y + 5)
  y = y - 38

  local addons = ModeShift.AddonManager:GetInstalledAddons()
  for _, addon in ipairs(addons) do
    addon.modeShiftSelected = ModeShift.AddonManager:ShouldLoadInProfile(profile, addon)
    addon.modeShiftHasEntry = profile.addonProfiles and profile.addonProfiles.entries and profile.addonProfiles.entries[addon.name] ~= nil
  end
  table.sort(addons, function(a, b)
    if a.modeShiftSelected ~= b.modeShiftSelected then
      return a.modeShiftSelected
    end
    if a.modeShiftHasEntry ~= b.modeShiftHasEntry then
      return a.modeShiftHasEntry
    end
    return string.lower(a.name or "") < string.lower(b.name or "")
  end)

  if #addons == 0 then
    y = self:AddDescription(parent, "No encuentro la lista de addons instalados.", y)
    return y
  end

  local profileCheck = makeCheck(parent, "Aplicar perfiles internos de addons cuando existan", profile.addonProfiles and profile.addonProfiles.enabled, function(checked)
    profile.addonProfiles.enabled = checked
    self:SaveProfile(profile)
  end)
  profileCheck:SetPoint("TOPLEFT", 0, y + 4)
  y = y - 36

  local header = makeText(parent, "Addon", "GameFontNormalSmall")
  header:SetPoint("TOPLEFT", 30, y)
  header:SetWidth(190)
  local stateHeader = makeText(parent, "Cargar", "GameFontNormalSmall")
  stateHeader:SetPoint("TOPLEFT", 4, y)
  stateHeader:SetWidth(55)
  local profileHeader = makeText(parent, "Perfil interno", "GameFontNormalSmall")
  profileHeader:SetPoint("TOPLEFT", 320, y)
  profileHeader:SetWidth(210)
  local configHeader = makeText(parent, "Disenos", "GameFontNormalSmall")
  configHeader:SetPoint("TOPLEFT", 560, y)
  configHeader:SetWidth(100)
  y = y - 22

  for _, addon in ipairs(addons) do
    local installedState = addon.enabled and "cargado/activo" or "desactivado"
    local shouldLoad = ModeShift.AddonManager:ShouldLoadInProfile(profile, addon)

    local loadCheck = makeCheck(parent, "", shouldLoad, function(checked)
      ModeShift.AddonManager:SetProfileAddonState(profile, addon.name, checked)
      self:SaveProfile(profile)
    end)
    loadCheck:SetPoint("TOPLEFT", 0, y + 3)
    if addon.name == ModeShift.addonName then
      loadCheck:Disable()
    end

    local label = makeText(parent, addon.name)
    label:SetPoint("TOPLEFT", 30, y - 2)
    label:SetWidth(190)
    if label.SetWordWrap then
      label:SetWordWrap(false)
    end

    local details = makeText(parent, installedState, "GameFontDisableSmall")
    details:SetPoint("TOPLEFT", 30, y - 16)
    details:SetWidth(190)

    y = self:BuildAddonProfilePicker(parent, profile, addon.name, y)
    self:BuildAddonOptionPicker(parent, profile, addon.name, y)
    y = y - 32
  end

  return y
end

function ConfigUI:BuildAddonProfilePicker(parent, profile, addonName, y)
  profile.addonProfiles = profile.addonProfiles or { enabled = false, entries = {} }
  profile.addonProfiles.entries = profile.addonProfiles.entries or {}

  local entry = profile.addonProfiles.entries[addonName] or { enabled = false, profileName = nil }
  local hasSavedProfile = entry.enabled and entry.profileName and entry.profileName ~= ""
  local canPickProfile = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:CanShowProfilePicker(addonName)
  if not hasSavedProfile and not canPickProfile then
    return y
  end

  local currentProfile = nil
  if ModeShift.AddonProfileManager then
    currentProfile = ModeShift.AddonProfileManager:GetCurrentProfile(addonName, false)
  end
  local text = "Elegir perfil"
  if currentProfile then
    text = currentProfile
  elseif hasSavedProfile then
    text = entry.profileName
  end

  local currentButton = makeButton(parent, text, 220, 22, function(button)
    self:OpenAddonProfileDropdown(button, profile, addonName)
  end)
  styleButton(currentButton, false)
  addHover(currentButton, false)
  currentButton:SetPoint("TOPLEFT", 320, y)

  return y
end

function ConfigUI:SetAddonProfile(profile, addonName, profileName)
  profile.addonProfiles.enabled = true
  if profileName == nil then
    local entry = profile.addonProfiles.entries[addonName]
    if type(entry) == "table" and entry.optionName then
      entry.enabled = true
      entry.profileName = nil
      profile.addonProfiles.entries[addonName] = entry
    else
      profile.addonProfiles.entries[addonName] = nil
    end
    self:SaveProfile(profile)
    return
  end

  local entry = profile.addonProfiles.entries[addonName] or { enabled = true }
  entry.enabled = true
  entry.profileName = profileName
  profile.addonProfiles.entries[addonName] = {
    enabled = true,
    profileName = entry.profileName,
    optionName = entry.optionName,
  }
  self:SaveProfile(profile)
end

function ConfigUI:OpenAddonProfileDropdown(anchor, profile, addonName)
  raiseFrame(self.frame)
  if ModeShift.AddonProfileManager then
    ModeShift.AddonProfileManager:ClearCache(addonName)
  end
  local profiles = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetAvailableProfiles(addonName, true) or {}
  local currentProfile = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetCurrentProfile(addonName, true) or nil

  local entry = profile.addonProfiles and profile.addonProfiles.entries and profile.addonProfiles.entries[addonName] or nil
  local selected = entry and entry.profileName or nil
  local effectiveSelected = currentProfile or selected
  local items = {}
  local seen = {}

  if currentProfile then
    table.insert(items, {
      text = "Actual: " .. currentProfile,
      selected = effectiveSelected == currentProfile,
      onClick = function()
        self:SetAddonProfile(profile, addonName, currentProfile)
      end,
    })
    seen[currentProfile] = true
  end

  for _, profileName in ipairs(profiles or {}) do
    local profileValue = profileName
    if not seen[profileValue] then
      table.insert(items, {
        text = profileValue,
        selected = effectiveSelected == profileValue,
        onClick = function()
          self:SetAddonProfile(profile, addonName, profileValue)
        end,
      })
      seen[profileValue] = true
    end
  end

  if #items == 0 then
    table.insert(items, { text = "No he encontrado perfiles", disabled = true })
  end

  table.insert(items, { divider = true })
  table.insert(items, {
    text = "Limpiar seleccion",
    onClick = function()
      self:SetAddonProfile(profile, addonName, nil)
    end,
  })

  self:OpenDropdown(anchor, addonName, items, 320)
end

function ConfigUI:BuildAddonOptionPicker(parent, profile, addonName, y)
  if not (ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:CanShowOptionPicker(addonName)) then
    return
  end

  profile.addonProfiles = profile.addonProfiles or { enabled = false, entries = {} }
  profile.addonProfiles.entries = profile.addonProfiles.entries or {}
  local entry = profile.addonProfiles.entries[addonName] or { enabled = false, profileName = nil, optionName = nil }
  local currentOption = nil
  if ModeShift.AddonProfileManager then
    currentOption = ModeShift.AddonProfileManager:GetCurrentOption(addonName, false)
  end
  local defaultText = isCooldownManagerAddon(addonName) and "Disenos CDM" or "Config..."
  local selected = currentOption or entry.optionName or defaultText

  local button = makeButton(parent, selected, 150, 22, function(anchor)
    self:OpenAddonOptionDropdown(anchor, profile, addonName)
  end)
  styleButton(button, false)
  addHover(button, false)
  button:SetPoint("TOPLEFT", 560, y)
end

function ConfigUI:SetAddonOption(profile, addonName, optionName)
  profile.addonProfiles.enabled = true
  local entry = profile.addonProfiles.entries[addonName] or { enabled = true }
  if optionName == nil and not entry.profileName then
    profile.addonProfiles.entries[addonName] = nil
    self:SaveProfile(profile)
    return
  end

  entry.enabled = true
  entry.optionName = optionName
  profile.addonProfiles.entries[addonName] = entry
  self:SaveProfile(profile)
end

function ConfigUI:OpenAddonOptionDropdown(anchor, profile, addonName)
  raiseFrame(self.frame)
  if ModeShift.AddonProfileManager then
    ModeShift.AddonProfileManager:ClearCache(addonName)
  end
  local options = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetAvailableOptions(addonName, true) or {}
  local currentOption = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetCurrentOption(addonName, true) or nil

  local entry = profile.addonProfiles and profile.addonProfiles.entries and profile.addonProfiles.entries[addonName] or nil
  local selected = entry and entry.optionName or nil
  local effectiveSelected = currentOption or selected
  local items = {}
  local seen = {}

  if currentOption then
    table.insert(items, {
      text = (isCooldownManagerAddon(addonName) and "Diseno actual: " or "Actual: ") .. currentOption,
      selected = effectiveSelected == currentOption,
      onClick = function()
        self:SetAddonOption(profile, addonName, currentOption)
      end,
    })
    seen[currentOption] = true
  end

  for _, optionName in ipairs(options or {}) do
    local optionValue = optionName
    if not seen[optionValue] then
      table.insert(items, {
        text = optionValue,
        selected = effectiveSelected == optionValue,
        onClick = function()
          self:SetAddonOption(profile, addonName, optionValue)
        end,
      })
      seen[optionValue] = true
    end
  end

  if #items == 0 then
    local emptyText = isCooldownManagerAddon(addonName) and "No he encontrado disenos" or "No he encontrado configs"
    table.insert(items, { text = emptyText, disabled = true })
  end

  table.insert(items, { divider = true })
  table.insert(items, {
    text = "Limpiar seleccion",
    onClick = function()
      self:SetAddonOption(profile, addonName, nil)
    end,
  })

  local title = isCooldownManagerAddon(addonName) and (addonName .. " disenos") or (addonName .. " config")
  self:OpenDropdown(anchor, title, items, 320)
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
    if type(entry) == "table" and entry.enabled and entry.optionName then
      table.insert(lines, "addonOption." .. escapeValue(addonName) .. "=" .. escapeValue(entry.optionName))
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
          profile.addonProfiles.entries[addonName] = profile.addonProfiles.entries[addonName] or { enabled = true }
          profile.addonProfiles.entries[addonName].enabled = true
          profile.addonProfiles.entries[addonName].profileName = value
        elseif key:match("^addonOption%.") then
          local addonName = unescapeValue(key:gsub("^addonOption%.", ""))
          profile.addonProfiles.enabled = true
          profile.addonProfiles.entries[addonName] = profile.addonProfiles.entries[addonName] or { enabled = true }
          profile.addonProfiles.entries[addonName].enabled = true
          profile.addonProfiles.entries[addonName].optionName = value
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
    raiseFrame(frame)
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
