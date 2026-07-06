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

  local result = self:NewResult(profileId)
  ModeShift:Print("aplicando perfil " .. (profile.name or profile.id) .. "...")

  if ModeShift.EquipmentManager then
    self:MergeResult(result, ModeShift.EquipmentManager:Apply(profile))
  end

  if ModeShift.TalentManager then
    self:MergeResult(result, ModeShift.TalentManager:Apply(profile))
  end

  self:ApplyEditMode(profile, result)
  self:ApplyAddonProfiles(profile, result)

  if ModeShift.AddonManager then
    self:MergeResult(result, ModeShift.AddonManager:Apply(profile))
  end

  self:ApplyCVars(profile, result)

  ModeShift.Database:SetActiveProfileId(profile.id)
  ModeShift.Database:SetLastAppliedProfileId(profile.id)
  if profile.specId then
    ModeShift.Database:SetPreferredProfileForSpec(profile.specId, profile.id)
  end

  self:PrintSummary(result)

  if result.requiresReload then
    ModeShift.Database:SetRequiresReload(false)
    ModeShift:Print("addons cambiados: recargando interfaz automaticamente...")
    if C_Timer and C_Timer.After then
      C_Timer.After(0.2, function()
        ReloadUI()
      end)
    else
      ReloadUI()
    end
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

ModeShift:RegisterModule("ApplyEngine", ApplyEngine)
