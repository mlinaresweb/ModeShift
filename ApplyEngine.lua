local ModeShift = _G.ModeShift

local ApplyEngine = {}

local function appendAll(target, source)
  if type(target) ~= "table" or type(source) ~= "table" then
    return
  end
  for _, value in ipairs(source) do
    table.insert(target, value)
  end
end

local function hasAppliedWork(part)
  return type(part) == "table" and type(part.applied) == "table" and #part.applied > 0
end

function ApplyEngine:NewResult(profileId)
  return {
    profileId = profileId,
    success = true,
    requiresReload = false,
    applied = {},
    skipped = {},
    errors = {},
    warnings = {},
  }
end

function ApplyEngine:TryReload()
  if ModeShift.Database and not ModeShift.Database:GetRequiresReload() then
    return
  end

  self.waitingForTalentReload = nil
  self.deferredReloadPending = nil

  local ok, err = ModeShift:SafeCall("ReloadUI", ReloadUI)
  if not ok then
    ModeShift:Print("no he podido recargar automaticamente: " .. tostring(err) .. ". Usa el boton Reload UI.")
    if ModeShift.RefreshConfig then
      ModeShift:RefreshConfig()
    end
  end
end

function ApplyEngine:MergeResult(result, part)
  if type(part) ~= "table" then
    return
  end

  if part.success == false then
    result.success = false
  end
  if part.requiresReload then
    result.requiresReload = true
  end
  if part.message and (type(part.applied) ~= "table" or #part.applied == 0) then
    table.insert(result.applied, part.message)
  end

  appendAll(result.applied, part.applied)
  appendAll(result.skipped, part.skipped)
  appendAll(result.errors, part.errors)
  appendAll(result.warnings, part.warnings)
end

function ApplyEngine:ApplyCVars(profile, result)
  local cvars = profile and profile.cvars or nil
  if not cvars or not cvars.enabled then
    table.insert(result.skipped, "CVars desactivados")
    return
  end

  for name, value in pairs(cvars.values or {}) do
    if name and value ~= nil then
      local ok, err = ModeShift:SafeCall("SetCVar", SetCVar, name, tostring(value))
      if ok then
        table.insert(result.applied, "CVar: " .. tostring(name))
      else
        result.success = false
        table.insert(result.errors, "No se pudo aplicar CVar " .. tostring(name) .. ": " .. tostring(err))
      end
    end
  end
end

function ApplyEngine:StartReloadPrompt()
  if not ModeShift.Database then
    ReloadUI()
    return
  end

  ModeShift.Database:SetRequiresReload(true)

  if ModeShift.RefreshConfig then
    ModeShift:RefreshConfig()
  end

  if ModeShift.ShowReloadPopup then
    ModeShift:ShowReloadPopup()
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.25, function()
      self:TryReload()
    end)
    C_Timer.After(1.2, function()
      self:TryReload()
    end)
  else
    self:TryReload()
  end
end

function ApplyEngine:CompleteDeferredReload()
  if not self.deferredReloadPending then
    return
  end

  if ModeShift.TalentManager and ModeShift.TalentManager:IsCommitPending() then
    self.deferredReloadWaits = (self.deferredReloadWaits or 0) + 1
    if self.deferredReloadWaits > 12 then
      self.deferredReloadPending = nil
      self.waitingForTalentReload = nil
      self.deferredReloadWaits = nil
      ModeShift:Print("|cffffff66!|r Blizzard sigue mostrando talentos pendientes. No recargo para no perder el cambio; pulsa Aplicar cambios en talentos y luego Reload UI si hace falta.")
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.45, function()
        self:CompleteDeferredReload()
      end)
    else
      self.deferredReloadPending = nil
      self.waitingForTalentReload = nil
      self.deferredReloadWaits = nil
    end
    return
  end

  self.deferredReloadPending = nil
  self.waitingForTalentReload = nil
  self.deferredReloadWaits = nil
  ModeShift:Print("talentos aplicados: recargando interfaz automaticamente...")
  self:StartReloadPrompt()
end

function ApplyEngine:ScheduleReload(options)
  options = options or {}
  if not ModeShift.Database then
    ReloadUI()
    return
  end

  if options.waitForTalents then
    self.waitingForTalentReload = true
    self.deferredReloadPending = true
    self.deferredReloadWaits = 0

    if ModeShift.RefreshConfig then
      ModeShift:RefreshConfig()
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.8, function()
        self:CompleteDeferredReload()
      end)
      C_Timer.After(2.5, function()
        self:CompleteDeferredReload()
      end)
    else
      self:CompleteDeferredReload()
    end
    return
  end

  self:StartReloadPrompt()
end

function ApplyEngine:OnTalentCommitEvent()
  if not self.waitingForTalentReload then
    return
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.25, function()
      self:CompleteDeferredReload()
    end)
  else
    self:CompleteDeferredReload()
  end
end

function ApplyEngine:ApplyAddonProfiles(profile, result)
  if not ModeShift.AddonProfileManager then
    table.insert(result.warnings, "AddonProfileManager no esta disponible")
    return
  end

  self:MergeResult(result, ModeShift.AddonProfileManager:Apply(profile))
end

function ApplyEngine:ApplyEditMode(profile, result)
  if not ModeShift.EditModeManager then
    table.insert(result.warnings, "EditModeManager no esta disponible")
    return
  end

  self:MergeResult(result, ModeShift.EditModeManager:Apply(profile))
end

function ApplyEngine:ApplyProfile(profileId, options)
  options = options or {}

  local profile = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfile(profileId)
  if not profile then
    ModeShift:Print("no encuentro el perfil \"" .. tostring(profileId) .. "\".")
    local missing = self:NewResult(profileId)
    missing.success = false
    table.insert(missing.errors, "Perfil no encontrado")
    return missing
  end

  if ModeShift:IsInCombat() then
    ModeShift.Database:SetPendingProfileId(profileId)
    ModeShift:Print("estas en combate. Dejo pendiente el perfil " .. (profile.name or profile.id) .. ".")
    local pending = self:NewResult(profileId)
    pending.success = false
    table.insert(pending.warnings, "Perfil pendiente por combate")
    return pending
  end

  if ModeShift.SpecManager and ModeShift.SpecManager:ProfileNeedsSpecSwitch(profile, options) then
    local result = self:NewResult(profileId)
    local switched, err = ModeShift.SpecManager:SwitchForProfile(profile, options)
    if switched then
      table.insert(result.applied, "Cambio de spec: " .. tostring(profile.specName or profile.specId))
      table.insert(result.skipped, "El resto del perfil se aplicara al terminar el cambio de spec")
      return result
    end

    result.success = false
    table.insert(result.errors, "No se pudo cambiar de spec: " .. tostring(err or "error desconocido"))
    self:PrintSummary(result)
    return result
  end

  local result = self:NewResult(profileId)
  local talentsChanged = false
  local previousProfile = nil
  if ModeShift.Database and ModeShift.ProfileManager then
    local previousProfileId = ModeShift.Database:GetActiveProfileId() or ModeShift.Database:GetLastAppliedProfileId()
    if previousProfileId and previousProfileId ~= profile.id then
      previousProfile = ModeShift.ProfileManager:GetProfile(previousProfileId)
    end
  end

  ModeShift:Print("aplicando perfil " .. (profile.name or profile.id) .. "...")

  if ModeShift.EquipmentManager then
    self:MergeResult(result, ModeShift.EquipmentManager:Apply(profile))
  end

  if ModeShift.TalentManager then
    local talentResult = ModeShift.TalentManager:Apply(profile)
    talentsChanged = hasAppliedWork(talentResult)
    self:MergeResult(result, talentResult)
    if talentResult and talentResult.pendingRetry then
      self:PrintSummary(result)
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return result
    end
  end

  self:ApplyEditMode(profile, result)
  self:ApplyAddonProfiles(profile, result)

  if ModeShift.AddonManager then
    self:MergeResult(result, ModeShift.AddonManager:Apply(profile))
    if not result.requiresReload
      and previousProfile
      and ModeShift.AddonManager:ProfilesHaveDifferentAddonState(previousProfile, profile)
    then
      result.requiresReload = true
      table.insert(result.applied, "Addons del perfil cambiados: recarga necesaria")
    end
  end

  self:ApplyCVars(profile, result)

  ModeShift.Database:SetActiveProfileId(profile.id)
  ModeShift.Database:SetLastAppliedProfileId(profile.id)
  if profile.specId then
    ModeShift.Database:SetPreferredProfileForSpec(profile.specId, profile.id)
  end

  self:PrintSummary(result)

  if result.requiresReload then
    if talentsChanged then
      ModeShift:Print("addons cambiados: recargare la interfaz al terminar de aplicar talentos...")
    else
      ModeShift:Print("addons cambiados: recargando interfaz automaticamente...")
    end
    self:ScheduleReload({ waitForTalents = talentsChanged })
    return result
  end

  if ModeShift.RefreshConfig then
    ModeShift:RefreshConfig()
  end

  return result
end

function ApplyEngine:ReapplyCurrentProfile()
  local profileId = ModeShift.Database:GetActiveProfileId() or ModeShift.Database:GetLastAppliedProfileId()
  if not profileId and ModeShift.ProfileManager then
    local profile = ModeShift.ProfileManager:GetCurrentOrPreferredProfile()
    profileId = profile and profile.id
  end

  if not profileId then
    ModeShift:Print("no hay perfil actual para reaplicar.")
    return nil
  end

  return self:ApplyProfile(profileId, { reapply = true })
end

function ApplyEngine:PrintSummary(result)
  for _, message in ipairs(result.applied) do
    ModeShift:Print("|cff55ff55OK|r " .. message)
  end

  for _, message in ipairs(result.warnings) do
    ModeShift:Print("|cffffff66!|r " .. message)
  end

  for _, message in ipairs(result.errors) do
    ModeShift:Print("|cffff5555x|r " .. message)
  end

  if result.requiresReload then
    ModeShift:Print("|cffffff66!|r Addons modificados: recarga automatica preparada.")
  end

  if result.success then
    ModeShift:Print("perfil aplicado.")
  else
    ModeShift:Print("el perfil se ha aplicado parcialmente.")
  end
end

function ApplyEngine:OnEvent(event)
  if event == "PLAYER_TALENT_UPDATE"
    or event == "TRAIT_CONFIG_UPDATED"
    or event == "ACTIVE_COMBAT_CONFIG_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED"
  then
    self:OnTalentCommitEvent()
  end
end

ModeShift:RegisterModule("ApplyEngine", ApplyEngine)
