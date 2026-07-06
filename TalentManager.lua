local ModeShift = _G.ModeShift

local TalentManager = {}

local function lower(value)
  if type(value) ~= "string" then
    return nil
  end
  return string.lower(value)
end

function TalentManager:GetConfigName(configId)
  if configId and C_Traits and C_Traits.GetConfigInfo then
    local ok, info = ModeShift:SafeCall("GetConfigInfo", C_Traits.GetConfigInfo, configId)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
  end
  return nil
end

function TalentManager:GetActiveTraitConfigId()
  if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
    local ok, configId = ModeShift:SafeCall("GetActiveConfigID", C_ClassTalents.GetActiveConfigID)
    if ok and configId then
      return configId
    end
  end

  return nil
end

function TalentManager:GetSelectedLoadoutId(specId)
  specId = specId or ModeShift:GetCurrentSpecId()
  if specId and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
    local ok, configId = ModeShift:SafeCall("GetLastSelectedSavedConfigID", C_ClassTalents.GetLastSelectedSavedConfigID, specId)
    if ok and configId then
      return configId
    end
  end

  return nil
end

function TalentManager:GetTalentLoadouts(specId)
  local loadouts = {}
  specId = specId or ModeShift:GetCurrentSpecId()
  local selectedLoadoutId = self:GetSelectedLoadoutId(specId)

  if C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
    local ok, configIds = ModeShift:SafeCall("GetConfigIDsBySpecID", C_ClassTalents.GetConfigIDsBySpecID, specId)
    if ok and type(configIds) == "table" then
      for _, configId in ipairs(configIds) do
        local name = self:GetConfigName(configId)
        table.insert(loadouts, {
          id = configId,
          name = name or tostring(configId),
          specId = specId,
          active = selectedLoadoutId and configId == selectedLoadoutId,
        })
      end
    end
  end

  return loadouts
end

function TalentManager:GetCurrentLoadout(specId)
  if self.pendingConfigName then
    return {
      id = self.pendingConfigId,
      name = self.pendingConfigName,
      specId = specId or ModeShift:GetCurrentSpecId(),
      active = true,
    }
  end

  local selectedLoadoutId = self:GetSelectedLoadoutId(specId)
  local loadouts = self:GetTalentLoadouts(specId)

  if selectedLoadoutId then
    for _, loadout in ipairs(loadouts) do
      if loadout.id == selectedLoadoutId then
        return loadout
      end
    end
  end

  local activeConfigId = self:GetActiveTraitConfigId()
  if activeConfigId then
    local name = self:GetConfigName(activeConfigId)
    if name then
      return { id = activeConfigId, name = name, specId = specId or ModeShift:GetCurrentSpecId(), active = true }
    end
  end

  return nil
end

function TalentManager:FindLoadout(talents, specId)
  talents = talents or {}
  local loadouts = self:GetTalentLoadouts(specId)

  if talents.configName then
    local wanted = lower(talents.configName)
    for _, loadout in ipairs(loadouts) do
      if lower(loadout.name) == wanted then
        return loadout
      end
    end
  end

  if talents.configId then
    for _, loadout in ipairs(loadouts) do
      if loadout.id == talents.configId then
        return loadout
      end
    end
  end

  return nil
end

function TalentManager:GetTalentFrames()
  local frames = {}
  if ClassTalentFrame and ClassTalentFrame.TalentsTab then
    table.insert(frames, ClassTalentFrame.TalentsTab)
  end
  if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
    table.insert(frames, PlayerSpellsFrame.TalentsFrame)
  end
  return frames
end

function TalentManager:InstallTalentFrameHooks()
  for _, talentFrame in ipairs(self:GetTalentFrames()) do
    if talentFrame and not talentFrame.modeShiftHooked then
      talentFrame.modeShiftHooked = true
      talentFrame:HookScript("OnShow", function()
        if C_Timer and C_Timer.After then
          C_Timer.After(0.1, function()
            self:RefreshBlizzardTalentUI()
          end)
        else
          self:RefreshBlizzardTalentUI()
        end
      end)
    end
  end
end

function TalentManager:RefreshBlizzardTalentUI(preferredLoadoutId)
  if ModeShift.RefreshConfig then
    ModeShift:RefreshConfig()
  end

  self:InstallTalentFrameHooks()
  local frames = self:GetTalentFrames()

  if #frames == 0 then
    return
  end

  local selectionId = preferredLoadoutId or self.pendingConfigId or self:GetSelectedLoadoutId(ModeShift:GetCurrentSpecId())
  local methods = {
    "RefreshLoadoutOptions",
    "UpdateLoadoutDropDown",
    "UpdateLoadoutDropdown",
    "Refresh",
  }

  for _, talentFrame in ipairs(frames) do
    if selectionId and talentFrame.LoadSystem and type(talentFrame.LoadSystem.SetSelectionID) == "function" then
      ModeShift:SafeCall("TalentFrame.LoadSystem.SetSelectionID", talentFrame.LoadSystem.SetSelectionID, talentFrame.LoadSystem, selectionId)
    end

    if selectionId and type(talentFrame.CheckUpdateLastSelectedConfigID) == "function" then
      ModeShift:SafeCall("TalentFrame.CheckUpdateLastSelectedConfigID", talentFrame.CheckUpdateLastSelectedConfigID, talentFrame, selectionId)
    end

    for _, methodName in ipairs(methods) do
      local method = talentFrame[methodName]
      if type(method) == "function" then
        ModeShift:SafeCall("TalentFrame." .. methodName, method, talentFrame)
      end
    end
  end
end

function TalentManager:CommitActiveConfig()
  if ModeShift:IsInCombat() then
    return false
  end

  if not (C_Traits and C_Traits.CommitConfig) then
    return false
  end

  local activeConfigId = self:GetActiveTraitConfigId()
  if not activeConfigId then
    return false
  end

  local ok = ModeShift:SafeCall("CommitConfig", C_Traits.CommitConfig, activeConfigId)
  return ok and true or false
end

function TalentManager:ScheduleCommit(loadoutId)
  if C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
      self:CommitActiveConfig()
      self:RefreshBlizzardTalentUI(loadoutId)
    end)
    C_Timer.After(0.5, function()
      self:CommitActiveConfig()
      self:RefreshBlizzardTalentUI(loadoutId)
    end)
    C_Timer.After(1.2, function()
      self:CommitActiveConfig()
      self:RefreshBlizzardTalentUI(loadoutId)
    end)
  else
    self:CommitActiveConfig()
    self:RefreshBlizzardTalentUI(loadoutId)
  end
end

function TalentManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local talents = profile and profile.talents or nil

  if not talents or not talents.enabled then
    table.insert(result.skipped, "Talentos desactivados")
    return result
  end

  if ModeShift:IsInCombat() then
    result.success = false
    table.insert(result.warnings, "No se pueden cambiar talentos en combate")
    return result
  end

  local currentSpecId = ModeShift:GetCurrentSpecId()
  if profile.specId and currentSpecId and profile.specId ~= currentSpecId then
    table.insert(result.warnings, "El loadout de talentos pertenece a otra spec")
    return result
  end

  if not (C_ClassTalents and C_ClassTalents.LoadConfig) then
    table.insert(result.warnings, "La API de loadouts de talentos no esta disponible")
    return result
  end

  local loadout = self:FindLoadout(talents, currentSpecId)
  if not loadout then
    table.insert(result.warnings, "No encuentro el loadout \"" .. tostring(talents.configName or talents.configId or "?") .. "\"")
    return result
  end

  local current = self:GetCurrentLoadout(currentSpecId)
  if current and current.id == loadout.id then
    table.insert(result.skipped, "Talentos ya activos: " .. tostring(loadout.name or loadout.id))
    self:RefreshBlizzardTalentUI()
    return result
  end

  local ok, err = ModeShift:SafeCall("LoadConfig", C_ClassTalents.LoadConfig, loadout.id, talents.autoApply ~= false)
  if ok then
    self.pendingConfigId = loadout.id
    self.pendingConfigName = loadout.name
    result.message = "Talentos: " .. (loadout.name or loadout.id)
    table.insert(result.applied, result.message)
    if talents.autoApply ~= false then
      self:ScheduleCommit(loadout.id)
    else
      self:RefreshBlizzardTalentUI(loadout.id)
    end
  else
    result.success = false
    table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(err))
  end

  return result
end

function TalentManager:OnEvent(event, addonName)
  if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
    if not addonName or addonName == "Blizzard_PlayerSpells" or addonName == "Blizzard_ClassTalentUI" then
      if C_Timer and C_Timer.After then
        C_Timer.After(0.2, function()
          self:RefreshBlizzardTalentUI()
        end)
      else
        self:RefreshBlizzardTalentUI()
      end
    end
  elseif event == "PLAYER_TALENT_UPDATE"
    or event == "TRAIT_CONFIG_UPDATED"
    or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
  then
    local pendingConfigId = self.pendingConfigId
    if self.pendingConfigId then
      local current = self:GetCurrentLoadout(ModeShift:GetCurrentSpecId())
      if current and (current.id == self.pendingConfigId or lower(current.name) == lower(self.pendingConfigName)) then
        self.pendingConfigId = nil
        self.pendingConfigName = nil
      end
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.2, function()
        self:RefreshBlizzardTalentUI(pendingConfigId)
      end)
    else
      self:RefreshBlizzardTalentUI(pendingConfigId)
    end
  end
end

ModeShift:RegisterModule("TalentManager", TalentManager)
