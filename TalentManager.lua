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
    return loadResult == 1 or loadResult == 2 or loadResult == 3
  end

  local text = tostring(loadResult)
  return text == "NoChangesNecessary" or text == "Ready"
end

local function addSpellId(list, seen, spellId)
  spellId = tonumber(spellId)
  if not spellId or seen[spellId] then
    return
  end
  seen[spellId] = true
  table.insert(list, spellId)
end

local function collectSpellIds(value, list, seen)
  if type(value) == "number" or type(value) == "string" then
    addSpellId(list, seen, value)
  elseif type(value) == "table" then
    addSpellId(list, seen, value.spellID or value.spellId or value.id)
    for key, entry in pairs(value) do
      if entry == true and (type(key) == "number" or type(key) == "string") then
        addSpellId(list, seen, key)
      end
      collectSpellIds(entry, list, seen)
    end
  end
end

local function cooldownModRate(modRate)
  modRate = tonumber(modRate)
  if modRate and modRate > 0 then
    return modRate
  end
  return 1
end

local function cooldownRemaining(startTime, duration, modRate)
  if not (startTime and duration and duration > 1.5 and startTime > 0) then
    return 0
  end
  return math.max(0, (startTime + duration - GetTime()) / cooldownModRate(modRate))
end

local function fullChargeCooldownRemaining(currentCharges, maxCharges, startTime, duration, modRate)
  if not (maxCharges and currentCharges and currentCharges < maxCharges) then
    return 0
  end

  local firstChargeRemaining = cooldownRemaining(startTime, duration, modRate)
  if firstChargeRemaining <= 0 then
    return 0
  end

  return firstChargeRemaining + (math.max(0, maxCharges - currentCharges - 1) * (duration / cooldownModRate(modRate)))
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

function TalentManager:GetSpellName(spellId)
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = ModeShift:SafeCall("GetSpellName", C_Spell.GetSpellName, spellId)
    if ok and name then
      return name
    end
  end

  if GetSpellInfo then
    local ok, name = ModeShift:SafeCall("GetSpellInfo", GetSpellInfo, spellId)
    if ok and name then
      return name
    end
  end

  return nil
end

function TalentManager:GetSpellIdByName(spellName)
  if type(spellName) ~= "string" or spellName == "" then
    return nil
  end

  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = ModeShift:SafeCall("GetSpellInfo", C_Spell.GetSpellInfo, spellName)
    if ok and type(info) == "table" then
      return info.spellID or info.spellId
    end
  end

  if GetSpellInfo then
    local ok, _, _, _, _, _, _, spellId = ModeShift:SafeCall("GetSpellInfo", GetSpellInfo, spellName)
    if ok and spellId then
      return spellId
    end
  end

  return nil
end

function TalentManager:ExtractCooldownNameFromMessage(message)
  if type(message) ~= "string" then
    return nil
  end

  local patterns = {
    "mientras%s+(.+)%s+est",
    "mientras%s+(.+)%s+esta",
    "while%s+(.+)%s+is",
    "pendant%s+que%s+(.+)%s+est",
    "während%s+(.+)%s+",
  }

  for _, pattern in ipairs(patterns) do
    local value = message:match(pattern)
    if value and value ~= "" then
      value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[%.。]$", "")
      return value
    end
  end

  return nil
end

function TalentManager:GetSpellChargeCooldownRemaining(spellId)
  if not spellId then
    return 0
  end

  if C_Spell and C_Spell.GetSpellCharges then
    local ok, chargeInfo = ModeShift:SafeCall("GetSpellCharges", C_Spell.GetSpellCharges, spellId)
    if ok and type(chargeInfo) == "table" then
      local currentCharges = chargeInfo.currentCharges or chargeInfo.charges
      local maxCharges = chargeInfo.maxCharges or chargeInfo.maxCharge
      local startTime = chargeInfo.cooldownStartTime or chargeInfo.cooldownStart or chargeInfo.startTime or 0
      local duration = chargeInfo.cooldownDuration or chargeInfo.duration or 0
      local modRate = chargeInfo.chargeModRate or chargeInfo.cooldownModRate or chargeInfo.modRate
      local remaining = fullChargeCooldownRemaining(currentCharges, maxCharges, startTime, duration, modRate)
      if remaining > 0 then
        return remaining
      end
    end
  end

  if GetSpellCharges then
    local ok, currentCharges, maxCharges, startTime, duration, modRate = ModeShift:SafeCall("GetSpellCharges", GetSpellCharges, spellId)
    if ok then
      local remaining = fullChargeCooldownRemaining(currentCharges, maxCharges, startTime, duration, modRate)
      if remaining > 0 then
        return remaining
      end
    end
  end

  return 0
end

function TalentManager:GetActionChargeCooldownRemaining(slot)
  if not (slot and GetActionCharges) then
    return 0
  end

  local ok, currentCharges, maxCharges, startTime, duration, modRate = ModeShift:SafeCall("GetActionCharges", GetActionCharges, slot)
  if ok then
    local remaining = fullChargeCooldownRemaining(currentCharges, maxCharges, startTime, duration, modRate)
    if remaining > 0 then
      return remaining
    end
  end

  return 0
end

function TalentManager:GetSpellCooldownRemaining(spellId)
  if not spellId then
    return 0
  end

  local chargeRemaining = self:GetSpellChargeCooldownRemaining(spellId)
  if chargeRemaining > 0 then
    return chargeRemaining
  end

  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, cooldownInfo = ModeShift:SafeCall("GetSpellCooldown", C_Spell.GetSpellCooldown, spellId)
    if ok and type(cooldownInfo) == "table" then
      if cooldownInfo.isOnGCD then
        return 0
      end

      local startTime = cooldownInfo.startTime or cooldownInfo.start or 0
      local duration = cooldownInfo.duration or 0
      local remaining = cooldownRemaining(startTime, duration, cooldownInfo.modRate or cooldownInfo.cooldownModRate)
      if remaining > 0 then
        return remaining
      end
    end
  end

  if GetSpellCooldown then
    local ok, startTime, duration, _, modRate = ModeShift:SafeCall("GetSpellCooldown", GetSpellCooldown, spellId)
    if ok then
      local remaining = cooldownRemaining(startTime, duration, modRate)
      if remaining > 0 then
        return remaining
      end
    end
  end

  return 0
end

function TalentManager:GetSpellCooldownInfo(spellId)
  local remaining = self:GetSpellCooldownRemaining(spellId)
  if remaining <= 0 then
    return nil
  end

  return {
    remaining = remaining,
    spellId = tonumber(spellId),
    spellName = self:GetSpellName(spellId),
  }
end

function TalentManager:GetActionCooldownInfo(slot, spellId, spellName)
  if not slot then
    return nil
  end

  local remaining = self:GetActionChargeCooldownRemaining(slot)
  if remaining <= 0 and GetActionCooldown then
    local ok, startTime, duration, enabled, modRate = ModeShift:SafeCall("GetActionCooldown", GetActionCooldown, slot)
    if ok and enabled ~= 0 then
      remaining = cooldownRemaining(startTime, duration, modRate)
    end
  end

  if remaining <= 0 then
    return nil
  end

  return {
    remaining = remaining,
    spellId = tonumber(spellId),
    spellName = spellName or (spellId and self:GetSpellName(spellId)) or nil,
    actionSlot = slot,
    exact = true,
  }
end

function TalentManager:GetCooldownInfoForSpellName(spellName)
  if type(spellName) ~= "string" or spellName == "" then
    return nil
  end

  local target = lower(spellName)
  local best = nil

  if GetActionInfo then
    for slot = 1, 180 do
      local ok, actionType, actionId = ModeShift:SafeCall("GetActionInfo", GetActionInfo, slot)
      if ok and actionType == "spell" and actionId then
        local actionName = self:GetSpellName(actionId)
        if actionName and lower(actionName) == target then
          local info = self:GetActionCooldownInfo(slot, actionId, actionName)
          if info and (not best or info.remaining > best.remaining) then
            best = info
          end
        end
      end
    end
  end

  local spellId = self:GetSpellIdByName(spellName)
  local spellInfo = spellId and self:GetSpellCooldownInfo(spellId) or nil
  if spellInfo and (not best or spellInfo.remaining > best.remaining) then
    spellInfo.exact = true
    best = spellInfo
  end

  for _, knownSpellId in ipairs(self:GetKnownSpellIds()) do
    local knownName = self:GetSpellName(knownSpellId)
    if knownName and lower(knownName) == target then
      local info = self:GetSpellCooldownInfo(knownSpellId)
      if info and (not best or info.remaining > best.remaining) then
        info.exact = true
        best = info
      end
    end
  end

  if best then
    best.spellName = best.spellName or spellName
    best.fromErrorMessage = true
    best.spellIds = best.spellId and { best.spellId } or {}
  end

  return best
end

function TalentManager:GetBlockingCooldownInfo(spellIds)
  local best = nil
  for _, spellId in ipairs(ModeShift.Utils:SafeArray(spellIds)) do
    local remaining = self:GetSpellCooldownRemaining(spellId)
    if remaining > 0 and (not best or remaining > best.remaining) then
      best = {
        remaining = remaining,
        spellId = tonumber(spellId),
        spellName = self:GetSpellName(spellId),
        exact = true,
      }
    end
  end
  return best
end

function TalentManager:GetLiveCooldownInfo(cooldownInfo)
  if type(cooldownInfo) ~= "table" then
    return nil
  end

  local live = nil
  if cooldownInfo.actionSlot then
    live = self:GetActionCooldownInfo(cooldownInfo.actionSlot, cooldownInfo.spellId, cooldownInfo.spellName)
  end
  if (not live) and cooldownInfo.spellId then
    live = self:GetSpellCooldownInfo(cooldownInfo.spellId)
  end
  if (not live) and cooldownInfo.spellIds and #cooldownInfo.spellIds > 0 then
    live = self:GetBlockingCooldownInfo(cooldownInfo.spellIds)
  end
  if (not live) and cooldownInfo.spellName then
    live = self:GetCooldownInfoForSpellName(cooldownInfo.spellName)
  end

  if live then
    live.exact = cooldownInfo.exact or live.exact
    live.fromErrorMessage = cooldownInfo.fromErrorMessage or live.fromErrorMessage
    live.spellName = live.spellName or cooldownInfo.spellName
    live.spellIds = live.spellIds or cooldownInfo.spellIds or (live.spellId and { live.spellId }) or {}
  end

  return live
end

function TalentManager:MakeTalentPendingResult(result, loadout, delay, reason)
  result.pendingRetry = true
  result.retryDelay = delay or 0.45
  result.retryReason = reason or "talent-settle"
  table.insert(result.warnings, "Esperando confirmacion de talentos: " .. tostring(loadout and (loadout.name or loadout.id) or "?"))
  return result
end

function TalentManager:GetBlockingCooldownForProfile(profile)
  local talents = profile and profile.talents or nil
  if not talents or not talents.enabled then
    return nil
  end

  if ModeShift:IsInCombat() then
    return nil
  end

  local currentSpecId = ModeShift:GetCurrentSpecId()
  if profile.specId and currentSpecId and profile.specId ~= currentSpecId then
    return nil
  end

  if not (C_ClassTalents and C_ClassTalents.LoadConfig) then
    return nil
  end

  local loadout = self:FindLoadout(talents, currentSpecId)
  if not loadout or self:IsLoadoutSettled(loadout.id) then
    return nil
  end

  local liveCooldown = self:GetLiveCooldownInfo(self.lastCooldownBlocker)
  if liveCooldown and liveCooldown.remaining and liveCooldown.remaining > 0 then
    return liveCooldown, loadout
  end

  return nil
end

function TalentManager:GetActionBarBlockingCooldownInfo()
  if not GetActionInfo then
    return nil
  end

  local best = nil
  for slot = 1, 180 do
    local ok, actionType, actionId = ModeShift:SafeCall("GetActionInfo", GetActionInfo, slot)
    if ok and actionType == "spell" and actionId then
      local info = self:GetActionCooldownInfo(slot, actionId, self:GetSpellName(actionId))
      if info and info.remaining and info.remaining > 0 and (not best or info.remaining > best.remaining) then
        info.exact = true
        info.fromActionBarPrecheck = true
        info.spellIds = { actionId }
        best = info
      end
    end
  end

  return best
end

function TalentManager:GetActionBarSpellIds()
  local ids = {}
  local seen = {}
  if not GetActionInfo then
    return ids
  end

  for slot = 1, 180 do
    local ok, actionType, actionId = ModeShift:SafeCall("GetActionInfo", GetActionInfo, slot)
    if ok and actionType == "spell" and actionId then
      addSpellId(ids, seen, actionId)
    end
  end

  return ids
end

function TalentManager:GetSpellBookSpellIds()
  local ids = {}
  local seen = {}

  if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or nil
    local blanks = 0
    for index = 1, 1000 do
      local ok, info = ModeShift:SafeCall("GetSpellBookItemInfo", C_SpellBook.GetSpellBookItemInfo, index, bank)
      if ok and type(info) == "table" then
        local spellId = info.spellID or info.spellId or info.actionID or info.actionId
        if spellId then
          addSpellId(ids, seen, spellId)
          blanks = 0
        else
          blanks = blanks + 1
        end
      else
        blanks = blanks + 1
      end
      if blanks > 40 then
        break
      end
    end
  end

  if GetSpellBookItemInfo then
    local bookType = BOOKTYPE_SPELL or "spell"
    local blanks = 0
    for index = 1, 1000 do
      local ok, _, spellId = ModeShift:SafeCall("GetSpellBookItemInfo", GetSpellBookItemInfo, index, bookType)
      if ok and spellId then
        addSpellId(ids, seen, spellId)
        blanks = 0
      else
        blanks = blanks + 1
      end
      if blanks > 40 then
        break
      end
    end
  end

  return ids
end

function TalentManager:GetKnownSpellIds()
  local ids = {}
  local seen = {}
  for _, spellId in ipairs(self:GetActionBarSpellIds()) do
    addSpellId(ids, seen, spellId)
  end
  for _, spellId in ipairs(self:GetSpellBookSpellIds()) do
    addSpellId(ids, seen, spellId)
  end
  return ids
end

function TalentManager:FindCooldownBlockerInMessage(message)
  if type(message) ~= "string" or message == "" then
    return nil
  end

  local lowerMessage = string.lower(message)
  local looksRelevant = lowerMessage:find("talent", 1, true)
    or lowerMessage:find("talento", 1, true)
    or lowerMessage:find("talentos", 1, true)
  local mentionsCooldown = lowerMessage:find("cooldown", 1, true)
    or lowerMessage:find("reutil", 1, true)
  if not (looksRelevant and mentionsCooldown) then
    return nil
  end

  local extractedName = self:ExtractCooldownNameFromMessage(message)
  if extractedName then
    local namedInfo = self:GetCooldownInfoForSpellName(extractedName)
    if namedInfo and namedInfo.remaining and namedInfo.remaining > 0 then
      return namedInfo
    end
  end

  local best = nil
  for _, spellId in ipairs(self:GetKnownSpellIds()) do
    local name = self:GetSpellName(spellId)
    if name and name ~= "" and message:find(name, 1, true) then
      local info = self:GetSpellCooldownInfo(spellId)
      if info and info.remaining and info.remaining > 0 and (not best or info.remaining > best.remaining) then
        info.exact = true
        info.fromErrorMessage = true
        info.spellIds = { spellId }
        best = info
      end
    end
  end

  local extractedSpellId = self:GetSpellIdByName(extractedName)
  if extractedSpellId then
    local info = self:GetSpellCooldownInfo(extractedSpellId)
    if info and info.remaining and info.remaining > 0 then
      info.exact = true
      info.fromErrorMessage = true
      info.spellName = info.spellName or extractedName
      info.spellIds = { extractedSpellId }
      return info
    end
  end

  local fallback = self:GetActionBarBlockingCooldownInfo() or self:GetSpellBookBlockingCooldownInfo()
  if fallback and fallback.remaining and fallback.remaining > 0 then
    fallback.exact = true
    fallback.fromErrorMessage = true
    fallback.errorBlockerName = extractedName
    return fallback
  end

  return best
end

function TalentManager:GetSpellBookBlockingCooldownInfo()
  local best = nil
  for _, spellId in ipairs(self:GetSpellBookSpellIds()) do
    local info = self:GetSpellCooldownInfo(spellId)
    if info and (not best or info.remaining > best.remaining) then
      info.exact = false
      best = info
    end
  end
  return best
end

function TalentManager:GetBestCooldownBlocker(spellIds)
  local candidates = {}
  local seen = {}
  collectSpellIds(spellIds, candidates, seen)

  local best = self:GetBlockingCooldownInfo(candidates)
  if best then
    best.spellIds = candidates
    return best
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
  if self.pendingConfigId then
    self:ConfirmPendingLoadout()
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

  if not self:CanCommitPendingChanges() then
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

function TalentManager:ClearPendingLoadout()
  self.commitToken = (self.commitToken or 0) + 1
  self.pendingConfigId = nil
  self.pendingConfigName = nil
  self.pendingAutoApply = nil
  self.pendingStartedAt = nil
  self.pendingStableSince = nil
  self.commitScheduled = nil
  self.commitAttemptsLeft = nil
  self.commitStartedAt = nil
end

function TalentManager:IsCommitPending()
  if self.pendingConfigId then
    self:ConfirmPendingLoadout()
  end
  return self.pendingConfigId and true or false
end

function TalentManager:IsPlayerCastingOrChanneling()
  if UnitCastingInfo then
    local ok, name = ModeShift:SafeCall("UnitCastingInfo", UnitCastingInfo, "player")
    if ok and name then
      return true
    end
  end

  if UnitChannelInfo then
    local ok, name = ModeShift:SafeCall("UnitChannelInfo", UnitChannelInfo, "player")
    if ok and name then
      return true
    end
  end

  return false
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
      if not applyButton.IsEnabled then
        return true
      end
      local ok, enabled = ModeShift:SafeCall("TalentApplyButton.IsEnabled", applyButton.IsEnabled, applyButton)
      if not ok or enabled then
        return true
      end
    end
  end

  return false
end

function TalentManager:CanCommitPendingChanges()
  if ModeShift:IsInCombat() then
    return false
  end

  local activeConfigId = self:GetActiveTraitConfigId()
  if activeConfigId and C_Traits and C_Traits.ConfigHasStagedChanges then
    local ok, hasChanges = ModeShift:SafeCall("ConfigHasStagedChanges", C_Traits.ConfigHasStagedChanges, activeConfigId)
    if ok and hasChanges then
      return true
    end
  end

  for _, talentFrame in ipairs(self:GetTalentFrames()) do
    local applyButton = talentFrame and talentFrame.ApplyButton
    if applyButton and applyButton.IsShown and applyButton:IsShown() and applyButton.IsEnabled then
      local ok, enabled = ModeShift:SafeCall("TalentApplyButton.IsEnabled", applyButton.IsEnabled, applyButton)
      if ok and enabled then
        return true
      end
    end
  end

  return false
end

function TalentManager:IsLoadoutSettled(loadoutId)
  if not loadoutId then
    return false
  end

  if self:IsPlayerCastingOrChanneling() then
    return false
  end

  local selectedLoadoutId = self:GetSelectedLoadoutId(ModeShift:GetCurrentSpecId())
  if selectedLoadoutId ~= loadoutId then
    return false
  end

  return not self:HasPendingTalentChanges()
end

function TalentManager:ConfirmPendingLoadout()
  if not self.pendingConfigId then
    return true
  end

  if self:IsLoadoutSettled(self.pendingConfigId) then
    local now = GetTime and GetTime() or 0
    if not self.pendingStableSince then
      self.pendingStableSince = now
      return false
    end

    if now - self.pendingStableSince < 0.2 then
      return false
    end

    self:ClearPendingLoadout()
    return true
  end

  self.pendingStableSince = nil
  return false
end

function TalentManager:ScheduleCommit(loadoutId, attemptsLeft)
  if self.commitScheduled and self.pendingConfigId == loadoutId then
    return
  end

  self.commitToken = (self.commitToken or 0) + 1
  local token = self.commitToken
  self.commitScheduled = true
  self.commitAttemptsLeft = attemptsLeft or 50
  self.commitStartedAt = GetTime and GetTime() or 0
  self:RefreshBlizzardTalentUI(loadoutId)

  local function finishStep()
    if token ~= self.commitToken then
      return
    end

    if not self.pendingConfigId then
      self.commitScheduled = nil
      self.commitAttemptsLeft = nil
      return
    end

    if self.pendingConfigId ~= loadoutId then
      return
    end

    self:SetSelectedLoadoutId(ModeShift:GetCurrentSpecId(), loadoutId)

    if self:ConfirmPendingLoadout() then
      self:RefreshBlizzardTalentUI(loadoutId)
      return
    end

    local now = GetTime and GetTime() or 0
    if not self.pendingAutoApply and now - (self.commitStartedAt or 0) >= 1.4 and self:CanCommitPendingChanges() then
      self:CommitActiveConfig(loadoutId)
    end

    if self:ConfirmPendingLoadout() then
      self:RefreshBlizzardTalentUI(loadoutId)
      return
    end

    self.commitAttemptsLeft = (self.commitAttemptsLeft or 0) - 1
    if self.commitAttemptsLeft <= 0 then
      self.commitScheduled = nil
      self.pendingStableSince = nil
      local now = GetTime and GetTime() or 0
      if not self.lastPendingTalentMessageAt or now - self.lastPendingTalentMessageAt > 8 then
        self.lastPendingTalentMessageAt = now
        ModeShift:Print("|cffffff66!|r Blizzard aun no ha confirmado los talentos. Mantengo el reload en espera hasta que no queden cambios pendientes.")
      end
      return
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.5, finishStep)
    end
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.75, finishStep)
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

  if self.pendingConfigId and self.pendingConfigId ~= loadout.id then
    self:ClearPendingLoadout()
  end

  if self:IsLoadoutSettled(loadout.id) then
    table.insert(result.skipped, "Talentos ya activos: " .. tostring(loadout.name or loadout.id))
    self:RefreshBlizzardTalentUI()
    return result
  end

  if self.pendingConfigId == loadout.id then
    if not self.commitScheduled then
      self:ScheduleCommit(loadout.id)
    end
    table.insert(result.skipped, "Talentos aun confirmando: " .. tostring(loadout.name or loadout.id))
    self:RefreshBlizzardTalentUI(loadout.id)
    return result
  end

  local liveCooldown = self:GetLiveCooldownInfo(self.lastCooldownBlocker)
  if liveCooldown and liveCooldown.remaining and liveCooldown.remaining > 0 then
    result.pendingRetry = true
    result.retryDelay = liveCooldown.remaining + 0.75
    result.retryReason = "talent-cooldown"
    result.retryCooldownInfo = liveCooldown
    table.insert(result.warnings, "Talentos bloqueados por cooldown")
    return result
  end

  self.lastCooldownBlocker = nil
  self.lastCooldownErrorAt = nil
  local ok, loadResult, loadErr, affectedSpellIds, extraAffected1, extraAffected2, extraAffected3, extraAffected4, extraAffected5, extraAffected6 = ModeShift:SafeCall("LoadConfig", C_ClassTalents.LoadConfig, loadout.id, talents.autoApply ~= false)
  if ok then
    local loadMessageCooldown = self:FindCooldownBlockerInMessage(type(loadErr) == "string" and loadErr or type(loadResult) == "string" and loadResult or nil)
    if loadMessageCooldown and loadMessageCooldown.exact and loadMessageCooldown.remaining and loadMessageCooldown.remaining > 0 then
      result.pendingRetry = true
      result.retryDelay = loadMessageCooldown.remaining + 0.75
      result.retryReason = "talent-cooldown"
      result.retryCooldownInfo = loadMessageCooldown
      self.cooldownBlockedProfileId = nil
      self.cooldownBlockedLoadoutName = nil
      table.insert(result.warnings, "Talentos bloqueados por cooldown")
      return result
    end

    if not loadResultIsReady(loadResult) then
      local affectedCandidates = {}
      local affectedSeen = {}
      if type(loadResult) == "table" then
        collectSpellIds(loadResult, affectedCandidates, affectedSeen)
      end
      collectSpellIds(loadErr, affectedCandidates, affectedSeen)
      collectSpellIds(affectedSpellIds, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected1, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected2, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected3, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected4, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected5, affectedCandidates, affectedSeen)
      collectSpellIds(extraAffected6, affectedCandidates, affectedSeen)
      local cooldownInfo = self:GetBestCooldownBlocker(#affectedCandidates > 0 and affectedCandidates or affectedSpellIds)
      if not cooldownInfo and self.lastCooldownBlocker then
        cooldownInfo = self.lastCooldownBlocker
      end
      if not cooldownInfo then
        cooldownInfo = self:FindCooldownBlockerInMessage(type(loadErr) == "string" and loadErr or type(loadResult) == "string" and loadResult or nil)
      end
      local cooldown = cooldownInfo and cooldownInfo.remaining or 0

      if cooldownInfo and cooldownInfo.exact and cooldown > 0 then
        result.pendingRetry = true
        result.retryDelay = cooldown + 0.75
        result.retryReason = "talent-cooldown"
        result.retryCooldownInfo = cooldownInfo
        self.cooldownBlockedProfileId = nil
        self.cooldownBlockedLoadoutName = nil
        table.insert(result.warnings, "Talentos bloqueados por cooldown")
        return result
      end

      result.success = false
      self.cooldownBlockedProfileId = profile and profile.id or nil
      self.cooldownBlockedLoadoutName = loadout and (loadout.name or loadout.id) or nil
      table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(loadErr or loadResult))
      return result
    end

    self.pendingConfigId = loadout.id
    self.pendingConfigName = loadout.name
    self.pendingAutoApply = talents.autoApply ~= false
    self.pendingStartedAt = GetTime and GetTime() or nil
    self.cooldownBlockedProfileId = nil
    self.cooldownBlockedLoadoutName = nil
    self:SetSelectedLoadoutId(currentSpecId, loadout.id)
    result.message = "Talentos: " .. (loadout.name or loadout.id)
    if talents.autoApply ~= false then
      self:ScheduleCommit(loadout.id)
      table.insert(result.applied, result.message)
    else
      self:RefreshBlizzardTalentUI(loadout.id)
      table.insert(result.applied, result.message)
    end
  else
    local cooldownInfo = self:FindCooldownBlockerInMessage(tostring(loadResult or ""))
    if cooldownInfo and cooldownInfo.exact and cooldownInfo.remaining and cooldownInfo.remaining > 0 then
      result.pendingRetry = true
      result.retryDelay = cooldownInfo.remaining + 0.75
      result.retryReason = "talent-cooldown"
      result.retryCooldownInfo = cooldownInfo
      table.insert(result.warnings, "Talentos bloqueados por cooldown")
      return result
    end

    result.success = false
    table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(loadResult))
  end

  return result
end

function TalentManager:OnEvent(event, addonName, messageText)
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
  elseif event == "UI_ERROR_MESSAGE" then
    local message = messageText or addonName
    local info = self:FindCooldownBlockerInMessage(message)
    if info then
      self.lastCooldownBlocker = info
      self.lastCooldownErrorAt = GetTime and GetTime() or 0
      if ModeShift.ApplyEngine and ModeShift.ApplyEngine.UpdateCooldownWaitInfo then
        ModeShift.ApplyEngine:UpdateCooldownWaitInfo(info)
      end
      if info.exact and info.remaining and info.remaining > 0 and self.cooldownBlockedProfileId and ModeShift.ApplyEngine then
        local blockedProfileId = self.cooldownBlockedProfileId
        local blockedLoadoutName = self.cooldownBlockedLoadoutName
        self.cooldownBlockedProfileId = nil
        self.cooldownBlockedLoadoutName = nil
        ModeShift.ApplyEngine:ScheduleProfileRetry(blockedProfileId, info.remaining + 0.75, "talent-cooldown", {
          retryCooldownInfo = info,
          pendingTalentLoadout = blockedLoadoutName,
          source = "talent-ui-error",
        })
      end
    end
  end
end

ModeShift:RegisterModule("TalentManager", TalentManager)
