local ModeShift = _G.ModeShift

local TalentManager = {}

local function lower(value)
  if type(value) ~= "string" then
    return nil
  end
  return string.lower(value)
end

local function loadResultIsReady(loadResult)
  if loadResult == nil then
    return true
  end

  if type(loadResult) == "number" then
    return loadResult == 1 or loadResult == 3
  end

  local text = tostring(loadResult)
  return text == "NoChangesNecessary" or text == "Ready"
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

function TalentManager:GetSpellCooldownRemaining(spellId)
  if not spellId then
    return 0
  end

  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, cooldownInfo = ModeShift:SafeCall("GetSpellCooldown", C_Spell.GetSpellCooldown, spellId)
    if ok and type(cooldownInfo) == "table" then
      if cooldownInfo.isOnGCD then
        return 0
      end

      local startTime = cooldownInfo.startTime or cooldownInfo.start or 0
      local duration = cooldownInfo.duration or 0
      if duration > 1.5 and startTime > 0 then
        return math.max(0, startTime + duration - GetTime())
      end
    end
  end

  if GetSpellCooldown then
    local ok, startTime, duration = ModeShift:SafeCall("GetSpellCooldown", GetSpellCooldown, spellId)
    if ok and duration and duration > 1.5 and startTime and startTime > 0 then
      return math.max(0, startTime + duration - GetTime())
    end
  end

  return 0
end

function TalentManager:GetBlockingCooldown(spellIds)
  local longest = 0
  for _, spellId in ipairs(ModeShift.Utils:SafeArray(spellIds)) do
    local remaining = self:GetSpellCooldownRemaining(spellId)
    if remaining > longest then
      longest = remaining
    end
  end
  return longest
end

function TalentManager:ScheduleProfileRetry(profile, delay)
  if not (profile and profile.id and ModeShift.ApplyEngine and C_Timer and C_Timer.After) then
    return
  end

  self.retryCounts = self.retryCounts or {}
  local attempts = (self.retryCounts[profile.id] or 0) + 1
  self.retryCounts[profile.id] = attempts
  if attempts > 6 then
    ModeShift:Print("|cffffff66!|r no he podido aplicar talentos tras esperar cooldowns. Reintentalo cuando no haya habilidades en reutilizacion.")
    self.retryCounts[profile.id] = nil
    return
  end

  delay = math.max(1.0, math.min(delay or 1.0, 120)) + 0.4
  ModeShift:Print("talentos esperando cooldown: reintentare " .. tostring(profile.name or profile.id) .. " en " .. string.format("%.1f", delay) .. "s.")
  C_Timer.After(delay, function()
    if ModeShift.ApplyEngine then
      ModeShift.ApplyEngine:ApplyProfile(profile.id, { source = "talent-cooldown-retry", afterTalentCooldown = true })
    end
  end)
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

function TalentManager:SetSelectedLoadoutId(specId, configId)
  specId = specId or ModeShift:GetCurrentSpecId()
  if specId and configId and C_ClassTalents and C_ClassTalents.UpdateLastSelectedSavedConfigID then
    ModeShift:SafeCall("UpdateLastSelectedSavedConfigID", C_ClassTalents.UpdateLastSelectedSavedConfigID, specId, configId)
  end
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

function TalentManager:GetLoadoutById(configId, specId)
  if not configId then
    return nil
  end

  local loadouts = self:GetTalentLoadouts(specId)
  for _, loadout in ipairs(loadouts) do
    if loadout.id == configId then
      return loadout
    end
  end

  local name = self:GetConfigName(configId)
  if name then
    return { id = configId, name = name, specId = specId or ModeShift:GetCurrentSpecId(), active = true }
  end

  return nil
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

function TalentManager:CommitActiveConfig(loadoutId)
  if ModeShift:IsInCombat() then
    return false
  end

  if C_Traits and C_Traits.IsReadyForCommit then
    local readyOk, ready = ModeShift:SafeCall("IsReadyForCommit", C_Traits.IsReadyForCommit)
    if readyOk and ready == false then
      return false
    end
  end

  local committed = false
  local activeConfigId = self:GetActiveTraitConfigId()
  if activeConfigId and C_Traits and C_Traits.CommitConfig then
    local ok, didCommit = ModeShift:SafeCall("CommitConfig", C_Traits.CommitConfig, activeConfigId)
    committed = committed or (ok and didCommit ~= false)
  end

  if loadoutId then
    self:SetSelectedLoadoutId(ModeShift:GetCurrentSpecId(), loadoutId)
  end

  return committed
end

function TalentManager:IsCommitPending()
  return self.pendingConfigId and true or false
end

function TalentManager:HasPendingTalentChanges()
  local activeConfigId = self:GetActiveTraitConfigId()
  if activeConfigId and C_Traits and C_Traits.ConfigHasStagedChanges then
    local ok, hasChanges = ModeShift:SafeCall("ConfigHasStagedChanges", C_Traits.ConfigHasStagedChanges, activeConfigId)
    if ok and hasChanges then
      return true
    end
  end

  for _, talentFrame in ipairs(self:GetTalentFrames()) do
    local applyButton = talentFrame and talentFrame.ApplyButton
    if applyButton and applyButton.IsShown and applyButton:IsShown() then
      return true
    end
  end

  return false
end

function TalentManager:ConfirmPendingLoadout()
  if not self.pendingConfigId then
    return true
  end

  local selectedLoadoutId = self:GetSelectedLoadoutId(ModeShift:GetCurrentSpecId())
  if selectedLoadoutId == self.pendingConfigId and not self:HasPendingTalentChanges() then
    self.pendingConfigId = nil
    self.pendingConfigName = nil
    self.commitScheduled = nil
    self.commitAttemptsLeft = nil
    return true
  end

  return false
end

function TalentManager:ScheduleCommit(loadoutId, attemptsLeft)
  if self.commitScheduled and self.pendingConfigId == loadoutId then
    return
  end

  self.commitScheduled = true
  self.commitAttemptsLeft = attemptsLeft or 6
  self:RefreshBlizzardTalentUI(loadoutId)

  local function finishStep()
    if not self.pendingConfigId then
      self.commitScheduled = nil
      self.commitAttemptsLeft = nil
      return
    end

    self:SetSelectedLoadoutId(ModeShift:GetCurrentSpecId(), loadoutId)

    if self:ConfirmPendingLoadout() then
      self:RefreshBlizzardTalentUI(loadoutId)
      return
    end

    if self:HasPendingTalentChanges() then
      self:CommitActiveConfig(loadoutId)
    end

    if self:ConfirmPendingLoadout() then
      self:RefreshBlizzardTalentUI(loadoutId)
      return
    end

    self.commitAttemptsLeft = (self.commitAttemptsLeft or 0) - 1
    if self.commitAttemptsLeft <= 0 then
      self.commitScheduled = nil
      ModeShift:Print("|cffffff66!|r talentos cargados, pero Blizzard aun muestra cambios pendientes. Pulsa Aplicar cambios si la ventana de talentos sigue abierta.")
      return
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.45, finishStep)
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.35, finishStep)
  else
    finishStep()
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

  local ok, loadResult, loadErr, affectedSpellIds = ModeShift:SafeCall("LoadConfig", C_ClassTalents.LoadConfig, loadout.id, talents.autoApply ~= false)
  if ok then
    if not loadResultIsReady(loadResult) then
      local cooldown = self:GetBlockingCooldown(affectedSpellIds)
      if cooldown <= 0 and loadResult == 2 then
        cooldown = 1.0
      end

      if cooldown > 0 then
        result.pendingRetry = true
        table.insert(result.warnings, "Talentos bloqueados por cooldown")
        self:ScheduleProfileRetry(profile, cooldown)
        return result
      end

      result.success = false
      table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(loadErr or loadResult))
      return result
    end

    if self.retryCounts then
      self.retryCounts[profile.id] = nil
    end
    self.pendingConfigId = loadout.id
    self.pendingConfigName = loadout.name
    self:SetSelectedLoadoutId(currentSpecId, loadout.id)
    result.message = "Talentos: " .. (loadout.name or loadout.id)
    table.insert(result.applied, result.message)
    if talents.autoApply ~= false then
      self:ScheduleCommit(loadout.id)
    else
      self:RefreshBlizzardTalentUI(loadout.id)
    end
  else
    result.success = false
    table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(loadResult))
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
      if self:ConfirmPendingLoadout() then
        pendingConfigId = nil
      elseif not self.commitScheduled then
        self:ScheduleCommit(self.pendingConfigId)
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
