local ModeShift = _G.ModeShift

local ApplyEngine = {}

local function L(text, ...)
  if ModeShift and ModeShift.L then
    return ModeShift:L(text, ...)
  end
  if select("#", ...) > 0 then
    return string.format(text, ...)
  end
  return text
end

local function countAddonDelta(message)
  local enabled = 0
  local disabled = 0
  for token in tostring(message or ""):gmatch("([%+%-])[^,%s]+") do
    if token == "+" then
      enabled = enabled + 1
    elseif token == "-" then
      disabled = disabled + 1
    end
  end
  return enabled, disabled
end

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

local function isPermanentSpecSwitchError(err)
  local text = tostring(err or ""):lower()
  return text:find("api", 1, true)
    or text:find("disponible", 1, true)
    or text:find("encuentro", 1, true)
    or text:find("not available", 1, true)
    or text:find("not found", 1, true)
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

function ApplyEngine:CompleteDeferredReload(token)
  if token and self.deferredReloadToken and token ~= self.deferredReloadToken then
    return
  end

  if not self.deferredReloadPending then
    return
  end

  if ModeShift.TalentManager and (ModeShift.TalentManager:IsCommitPending()
    or (ModeShift.TalentManager.IsPlayerCastingOrChanneling and ModeShift.TalentManager:IsPlayerCastingOrChanneling()))
  then
    if ModeShift.TalentManager.ScheduleCommit and ModeShift.TalentManager.pendingConfigId and not ModeShift.TalentManager.commitScheduled then
      ModeShift.TalentManager:ScheduleCommit(ModeShift.TalentManager.pendingConfigId)
    end

    self.deferredReloadWaits = (self.deferredReloadWaits or 0) + 1
    if self.deferredReloadWaits > 60 then
      self.deferredReloadPending = nil
      self.waitingForTalentReload = nil
      self.deferredReloadWaits = nil
      ModeShift:Print("|cffffff66!|r Blizzard tarda demasiado en confirmar talentos. Dejo el reload preparado para que lo pulses cuando veas los talentos aplicados.")
      if ModeShift.Database then
        ModeShift.Database:SetRequiresReload(true)
      end
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      if ModeShift.ShowReloadPopup then
        ModeShift:ShowReloadPopup()
      end
      return
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.45, function()
        self:CompleteDeferredReload(token)
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
    self.deferredReloadToken = (self.deferredReloadToken or 0) + 1
    local token = self.deferredReloadToken
    self.waitingForTalentReload = true
    self.deferredReloadPending = true
    self.deferredReloadWaits = 0

    if ModeShift.RefreshConfig then
      ModeShift:RefreshConfig()
    end

    if C_Timer and C_Timer.After then
      C_Timer.After(0.8, function()
        self:CompleteDeferredReload(token)
      end)
      C_Timer.After(2.5, function()
        self:CompleteDeferredReload(token)
      end)
    else
      self:CompleteDeferredReload(token)
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
    local token = self.deferredReloadToken
    C_Timer.After(0.25, function()
      self:CompleteDeferredReload(token)
    end)
  else
    self:CompleteDeferredReload(self.deferredReloadToken)
  end
end

function ApplyEngine:HideCooldownWaitPopup()
  if self.cooldownWaitFrame then
    self.cooldownWaitFrame:Hide()
  end
end

function ApplyEngine:ShowCooldownWaitPopup(profileId, delay, reason, token, options)
  if not UIParent then
    return
  end

  local cooldownInfo = options and options.retryCooldownInfo or nil
  local hasExactCooldown = cooldownInfo
    and cooldownInfo.exact
    and cooldownInfo.remaining
    and cooldownInfo.remaining > 0
    and (cooldownInfo.spellId or cooldownInfo.actionSlot or cooldownInfo.spellName or (cooldownInfo.spellIds and #cooldownInfo.spellIds > 0))
  if not hasExactCooldown then
    self.cooldownWait = nil
    self:HideCooldownWaitPopup()
    return
  end

  if not self.cooldownWaitFrame then
    local frame = CreateFrame("Frame", "ModeShiftCooldownWaitFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(440, 176)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(8000)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOPLEFT", 16, -8)
    frame.title:SetText("ModeShift")

    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.message:SetPoint("TOPLEFT", 22, -40)
    frame.message:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    frame.message:SetHeight(82)
    frame.message:SetJustifyH("LEFT")
    frame.message:SetJustifyV("TOP")

    frame.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.button:SetSize(190, 26)
    frame.button:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
    frame.button:SetScript("OnClick", function()
      if ModeShift.ApplyEngine then
        ModeShift.ApplyEngine:ContinueCooldownRetry()
      end
    end)

    frame.divider = frame:CreateTexture(nil, "BORDER")
    frame.divider:SetColorTexture(1, 0.82, 0, 0.35)
    frame.divider:SetHeight(1)
    frame.divider:SetPoint("LEFT", frame, "LEFT", 22, 0)
    frame.divider:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    frame.divider:SetPoint("BOTTOM", frame.button, "TOP", 0, 12)

    frame:SetScript("OnHide", function(self)
      self:SetScript("OnUpdate", nil)
    end)

    self.cooldownWaitFrame = frame
  end

  local frame = self.cooldownWaitFrame
  local profile = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfile(profileId)
  local profileName = tostring(profile and (profile.name or profile.id) or profileId)
  local waitSeconds = math.max(1, math.ceil((cooldownInfo and cooldownInfo.remaining) or delay or 1))

  self.cooldownWait = {
    profileId = profileId,
    profileName = profileName,
    reason = reason,
    token = token,
    options = ModeShift.Utils:DeepCopy(options or {}),
    readyAt = (GetTime and GetTime() or 0) + waitSeconds,
    cooldownInfo = cooldownInfo and ModeShift.Utils:DeepCopy(cooldownInfo) or nil,
  }

  local spellText = cooldownInfo and cooldownInfo.spellName or nil
  if spellText and cooldownInfo and cooldownInfo.spellId then
    spellText = spellText .. " (" .. tostring(cooldownInfo.spellId) .. ")"
  elseif cooldownInfo and cooldownInfo.spellId then
    spellText = L("hechizo %s", tostring(cooldownInfo.spellId))
  elseif cooldownInfo and cooldownInfo.spellIds and cooldownInfo.spellIds[1] then
    spellText = L("hechizo %s", tostring(cooldownInfo.spellIds[1]))
  elseif cooldownInfo and cooldownInfo.actionSlot then
    spellText = L("hechizo %s", tostring(cooldownInfo.actionSlot))
  end
  spellText = spellText or L("hechizo %s", "?")
  frame.message:SetText(L("Blizzard no permite cambiar talentos porque hay habilidades en reutilizacion.") .. "\n" .. L("Perfil pendiente: %s", profileName) .. "\n" .. L("Bloquea: %s", spellText))
  frame:Show()

  frame:SetScript("OnUpdate", function(self)
    local wait = ModeShift.ApplyEngine and ModeShift.ApplyEngine.cooldownWait
    if not wait or wait.token ~= token then
      self:Hide()
      return
    end

    local liveRemaining = ModeShift.ApplyEngine:GetCooldownWaitRemaining(wait)
    local remaining = math.max(0, math.ceil(liveRemaining))
    local blocker = wait.cooldownInfo
    if not (blocker and blocker.exact and (blocker.spellId or blocker.actionSlot or blocker.spellName or (blocker.spellIds and #blocker.spellIds > 0))) then
      ModeShift.ApplyEngine.cooldownWait = nil
      self:Hide()
      return
    end
    local blockerText = blocker and blocker.spellName or nil
    if blockerText and blocker and blocker.spellId then
      blockerText = blockerText .. " (" .. tostring(blocker.spellId) .. ")"
    elseif blocker and blocker.spellId then
      blockerText = L("hechizo %s", tostring(blocker.spellId))
    elseif blocker and blocker.spellIds and blocker.spellIds[1] then
      blockerText = L("hechizo %s", tostring(blocker.spellIds[1]))
    elseif blocker and blocker.actionSlot then
      blockerText = L("hechizo %s", tostring(blocker.actionSlot))
    end
    blockerText = blockerText or L("hechizo %s", "?")
    self.message:SetText(L("Blizzard no permite cambiar talentos porque hay habilidades en reutilizacion.") .. "\n" .. L("Perfil pendiente: %s", tostring(wait.profileName or wait.profileId)) .. "\n" .. L("Bloquea: %s", blockerText))
    if remaining > 0 then
      self.button:Disable()
      self.button:SetText(L("Esperar %ds", remaining))
    else
      self.button:Enable()
      self.button:SetText(L("Continuar perfil"))
    end
  end)
end

function ApplyEngine:UpdateCooldownWaitInfo(cooldownInfo)
  local wait = self.cooldownWait
  if not (wait and cooldownInfo and cooldownInfo.remaining and cooldownInfo.remaining > 0) then
    return
  end

  wait.cooldownInfo = ModeShift.Utils:DeepCopy(cooldownInfo)
  wait.readyAt = (GetTime and GetTime() or 0) + cooldownInfo.remaining + 0.5
  wait.lastCooldownCheckAt = nil
  wait.lastCooldownRemaining = nil
end

function ApplyEngine:GetCooldownWaitRemaining(wait)
  if not wait then
    return 0
  end

  local now = GetTime and GetTime() or 0
  local fallbackRemaining = math.max(0, (wait.readyAt or 0) - now)
  if wait.lastCooldownCheckAt and now - wait.lastCooldownCheckAt < 0.25 then
    return math.max(fallbackRemaining, math.max(0, (wait.lastCooldownRemaining or 0) - (now - wait.lastCooldownCheckAt)))
  end

  local info = wait.cooldownInfo
  local live = nil

  if ModeShift.TalentManager then
    live = ModeShift.TalentManager:GetLiveCooldownInfo(info)
  end

  if live and live.remaining and live.remaining > 0 then
    wait.cooldownInfo = live
    wait.readyAt = math.max(wait.readyAt or 0, now + live.remaining + 0.5)
    wait.lastCooldownCheckAt = now
    wait.lastCooldownRemaining = live.remaining + 0.5
    return live.remaining + 0.5
  end

  if info and info.exact and (info.spellId or info.actionSlot or info.spellName or (info.spellIds and #info.spellIds > 0)) then
    wait.lastCooldownCheckAt = now
    wait.lastCooldownRemaining = 0
    return 0
  end

  wait.lastCooldownCheckAt = now
  wait.lastCooldownRemaining = fallbackRemaining
  return fallbackRemaining
end

function ApplyEngine:ContinueCooldownRetry()
  local wait = self.cooldownWait
  if not wait then
    self:HideCooldownWaitPopup()
    return
  end

  if wait.token ~= self.retryToken then
    self.cooldownWait = nil
    self:HideCooldownWaitPopup()
    return
  end

  local remaining = self:GetCooldownWaitRemaining(wait)
  if remaining > 0 then
    return
  end

  local profileId = wait.profileId
  local retryOptions = ModeShift.Utils:DeepCopy(wait.options or {})
  retryOptions.source = wait.reason or "cooldown-retry"
  retryOptions.afterCooldownWait = true
  retryOptions.retryAttempts = self.retryAttempts or 0

  self.cooldownWait = nil
  self:HideCooldownWaitPopup()
  self:ApplyProfile(profileId, retryOptions)
end

function ApplyEngine:ScheduleProfileRetry(profileId, delay, reason, options)
  if not (profileId and C_Timer and C_Timer.After) then
    return
  end

  self.retryToken = (self.retryToken or 0) + 1
  local token = self.retryToken
  self.retryProfileId = profileId
  self.retryReason = reason
  self.retryAttempts = options and options.retryAttempts or self.retryAttempts or 0
  self.retryAttempts = self.retryAttempts + 1

  if self.retryAttempts > 20 then
    local profile = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfile(profileId)
    ModeShift:Print("|cffffff66!|r no he podido aplicar " .. tostring(profile and (profile.name or profile.id) or profileId) .. " tras esperar cooldowns. Lo dejo pendiente para intentarlo de nuevo.")
    if ModeShift.Database then
      ModeShift.Database:SetPendingProfileId(profileId)
    end
    self.retryProfileId = nil
    self.retryReason = nil
    self.retryAttempts = nil
    self.cooldownWait = nil
    self:HideCooldownWaitPopup()
    return
  end

  delay = math.max(0.8, math.min(delay or 1.0, 600)) + 0.35
  local profile = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfile(profileId)
  if reason == "talent-cooldown" then
    local cooldownInfo = options and options.retryCooldownInfo or nil
    local hasExactCooldown = cooldownInfo
      and cooldownInfo.exact
      and cooldownInfo.remaining
      and cooldownInfo.remaining > 0
      and (cooldownInfo.spellId or cooldownInfo.actionSlot or cooldownInfo.spellName or (cooldownInfo.spellIds and #cooldownInfo.spellIds > 0))
    if not hasExactCooldown then
      ModeShift:Print("|cffff5555x|r Blizzard bloqueo talentos, pero no dio un cooldown medible. No continuo con equipo/UI/addons para evitar aplicar el perfil a medias.")
      self.retryProfileId = nil
      self.retryReason = nil
      self.retryAttempts = nil
      self.cooldownWait = nil
      self:HideCooldownWaitPopup()
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return
    end
    ModeShift:Print("perfil en espera por cooldown: " .. tostring(profile and (profile.name or profile.id) or profileId) .. ". Usa la ventana de ModeShift cuando termine la cuenta atras.")
    self:ShowCooldownWaitPopup(profileId, delay, reason, token, options)
    return
  end

  ModeShift:Print("esperando para continuar " .. tostring(profile and (profile.name or profile.id) or profileId) .. " en " .. string.format("%.1f", delay) .. "s.")

  C_Timer.After(delay, function()
    if token ~= self.retryToken or self.retryProfileId ~= profileId then
      return
    end

    local retryOptions = ModeShift.Utils:DeepCopy(options or {})
    retryOptions.source = reason or "cooldown-retry"
    retryOptions.afterCooldownWait = true
    retryOptions.retryAttempts = self.retryAttempts
    self:ApplyProfile(profileId, retryOptions)
  end)
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
  if not options.afterCooldownWait then
    self.retryToken = (self.retryToken or 0) + 1
    self.retryProfileId = nil
    self.retryReason = nil
    self.retryAttempts = nil
    self.cooldownWait = nil
    self:HideCooldownWaitPopup()
  end

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
    if not isPermanentSpecSwitchError(err) then
      result.pendingRetry = true
      result.retryDelay = 1.2
      result.retryReason = "spec-switch-retry"
      self:ScheduleProfileRetry(profile.id, result.retryDelay, result.retryReason, options)
      table.insert(result.warnings, "Cambio de spec bloqueado temporalmente; reintentare el perfil.")
    end
    self:PrintSummary(result)
    return result
  end

  local hadPendingReload = ModeShift.Database and ModeShift.Database:GetRequiresReload()
  if self.deferredReloadPending then
    self.deferredReloadToken = (self.deferredReloadToken or 0) + 1
    self.deferredReloadPending = nil
    self.waitingForTalentReload = nil
    self.deferredReloadWaits = nil
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

  if ModeShift.TalentManager and ModeShift.TalentManager.GetBlockingCooldownForProfile then
    local cooldownInfo, loadout = ModeShift.TalentManager:GetBlockingCooldownForProfile(profile)
    if cooldownInfo and cooldownInfo.remaining and cooldownInfo.remaining > 0 then
      result.success = false
      result.pendingRetry = true
      result.retryDelay = cooldownInfo.remaining + 0.75
      result.retryReason = "talent-cooldown"
      table.insert(result.warnings, "Talentos bloqueados por cooldown: " .. tostring(cooldownInfo.spellName or cooldownInfo.spellId or "?"))
      self:PrintSummary(result)
      local retryOptions = ModeShift.Utils:DeepCopy(options or {})
      retryOptions.retryCooldownInfo = cooldownInfo
      retryOptions.pendingTalentLoadout = loadout and (loadout.name or loadout.id) or nil
      self:ScheduleProfileRetry(profile.id, result.retryDelay, result.retryReason, retryOptions)
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return result
    end
  end

  ModeShift:Print("aplicando perfil " .. (profile.name or profile.id) .. "...")

  if ModeShift.TalentManager then
    local talentResult = ModeShift.TalentManager:Apply(profile)
    talentsChanged = hasAppliedWork(talentResult)
    self:MergeResult(result, talentResult)
    if talentResult and talentResult.pendingRetry then
      result.success = false
      result.pendingRetry = true
      self:PrintSummary(result)
      local retryOptions = ModeShift.Utils:DeepCopy(options or {})
      retryOptions.retryCooldownInfo = talentResult.retryCooldownInfo
      self:ScheduleProfileRetry(profile.id, talentResult.retryDelay or 1.0, talentResult.retryReason or "talent-cooldown", retryOptions)
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return result
    end
    if talentResult and talentResult.success == false then
      self:PrintSummary(result)
      if ModeShift.RefreshConfig then
        ModeShift:RefreshConfig()
      end
      return result
    end
  end

  if ModeShift.EquipmentManager then
    self:MergeResult(result, ModeShift.EquipmentManager:Apply(profile))
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

  if hadPendingReload and not result.requiresReload then
    result.requiresReload = true
    table.insert(result.applied, "Recarga pendiente conservada para el perfil final")
  end

  if options.afterCooldownWait then
    self.retryProfileId = nil
    self.retryReason = nil
    self.retryAttempts = nil
  end

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
  local profileApplied = 0
  local configApplied = 0
  local addonEnabled = 0
  local addonDisabled = 0
  local printedApplied = 0
  for _, message in ipairs(result.applied) do
    local text = tostring(message or "")
    if text:find("^Perfil ") then
      profileApplied = profileApplied + 1
    elseif text:find("^Config ") then
      configApplied = configApplied + 1
    elseif text:find("^Addons modificados:") then
      local enabled, disabled = countAddonDelta(text)
      addonEnabled = addonEnabled + enabled
      addonDisabled = addonDisabled + disabled
    else
      printedApplied = printedApplied + 1
      if printedApplied <= 6 then
        ModeShift:Print("|cff55ff55OK|r " .. text)
      end
    end
  end

  if profileApplied > 0 then
    ModeShift:Print("|cff55ff55OK|r " .. L("perfiles internos de addons aplicados: %d", profileApplied))
  end
  if configApplied > 0 then
    ModeShift:Print("|cff55ff55OK|r " .. L("configs de addons aplicadas: %d", configApplied))
  end
  if addonEnabled > 0 or addonDisabled > 0 then
    ModeShift:Print("|cff55ff55OK|r " .. L("addons modificados: +%d / -%d; recarga necesaria", addonEnabled, addonDisabled))
  end
  if printedApplied > 6 then
    ModeShift:Print("|cff999999...|r " .. L("%d mensajes mas", printedApplied - 6))
  end

  local compatWarnings = 0
  local writtenWarnings = 0
  local printedWarnings = 0
  for _, message in ipairs(result.warnings) do
    local text = tostring(message or "")
    if text:find("No encuentro perfiles compatibles", 1, true) then
      compatWarnings = compatWarnings + 1
    elseif text:find("Perfil escrito en", 1, true) then
      writtenWarnings = writtenWarnings + 1
    else
      printedWarnings = printedWarnings + 1
      if printedWarnings <= 6 then
        ModeShift:Print("|cffffff66!|r " .. text)
      end
    end
  end

  if compatWarnings > 0 then
    ModeShift:Print("|cffffff66!|r " .. L("addons sin perfiles compatibles: %d", compatWarnings))
  end
  if writtenWarnings > 0 then
    ModeShift:Print("|cffffff66!|r " .. L("perfiles escritos en bases de datos de addons: %d", writtenWarnings))
  end
  if printedWarnings > 6 then
    ModeShift:Print("|cff999999...|r " .. L("%d avisos mas", printedWarnings - 6))
  end

  for _, message in ipairs(result.errors) do
    ModeShift:Print("|cffff5555x|r " .. message)
  end

  if result.requiresReload then
    ModeShift:Print("|cffffff66!|r Addons modificados: recarga automatica preparada.")
  end

  if result.pendingRetry then
    ModeShift:Print("perfil en espera; continuare automaticamente cuando Blizzard permita el cambio.")
  elseif result.success then
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
