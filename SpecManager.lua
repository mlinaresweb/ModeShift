local ModeShift = _G.ModeShift

local SpecManager = {}

local function getNumSpecializations()
  if GetNumSpecializations then
    return GetNumSpecializations()
  end

  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations then
    return C_SpecializationInfo.GetNumSpecializations()
  end

  if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID and PlayerUtil and PlayerUtil.GetClassID then
    local classId = PlayerUtil.GetClassID()
    if classId then
      return C_SpecializationInfo.GetNumSpecializationsForClassID(classId)
    end
  end

  return 0
end

local function getSpecInfo(index)
  if GetSpecializationInfo then
    local specId, specName = GetSpecializationInfo(index)
    if specId then
      return specId, specName
    end
  end

  if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
    local specId, specName = C_SpecializationInfo.GetSpecializationInfo(index)
    if specId then
      return specId, specName
    end
  end

  if GetSpecializationInfoForClassID and PlayerUtil and PlayerUtil.GetClassID then
    local classId = PlayerUtil.GetClassID()
    if classId then
      local specId, specName = GetSpecializationInfoForClassID(classId, index)
      if specId then
        return specId, specName
      end
    end
  end

  return nil, nil
end

local function setSpecialization(index)
  if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
    return ModeShift:SafeCall("C_SpecializationInfo.SetSpecialization", C_SpecializationInfo.SetSpecialization, index)
  end

  if SetSpecialization then
    return ModeShift:SafeCall("SetSpecialization", SetSpecialization, index)
  end

  return false, "La API para cambiar especializacion no esta disponible"
end

function SpecManager:GetSpecIndex(specId)
  if not specId then
    return nil
  end

  for index = 1, getNumSpecializations() do
    local currentSpecId = getSpecInfo(index)
    if currentSpecId == specId then
      return index
    end
  end

  return nil
end

function SpecManager:ProfileNeedsSpecSwitch(profile, options)
  if options and options.afterSpecSwitch then
    return false
  end

  local targetSpecId = profile and profile.specId
  local currentSpecId = ModeShift:GetCurrentSpecId()
  return targetSpecId and currentSpecId and targetSpecId ~= currentSpecId
end

function SpecManager:ApplyPendingProfile()
  if not self.pendingProfileId then
    return
  end

  if self.pendingTargetSpecId and ModeShift:GetCurrentSpecId() ~= self.pendingTargetSpecId then
    return
  end

  local profileId = self.pendingProfileId
  local options = self.pendingOptions or {}
  self.pendingProfileId = nil
  self.pendingTargetSpecId = nil
  self.pendingOptions = nil
  self.pendingAttempts = nil

  options.afterSpecSwitch = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.8, function()
      if ModeShift.ApplyEngine then
        ModeShift.ApplyEngine:ApplyProfile(profileId, options)
      end
    end)
  elseif ModeShift.ApplyEngine then
    ModeShift.ApplyEngine:ApplyProfile(profileId, options)
  end
end

function SpecManager:CheckPendingProfile()
  if not self.pendingProfileId then
    return
  end

  if self.pendingTargetSpecId and ModeShift:GetCurrentSpecId() == self.pendingTargetSpecId then
    self:ApplyPendingProfile()
    return
  end

  self.pendingAttempts = (self.pendingAttempts or 0) + 1
  if self.pendingAttempts > 20 then
    local profile = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfile(self.pendingProfileId)
    ModeShift:Print("|cffffff66!|r no he podido confirmar el cambio a " .. tostring(profile and (profile.specName or profile.specId) or self.pendingTargetSpecId) .. ".")
    self.pendingProfileId = nil
    self.pendingTargetSpecId = nil
    self.pendingOptions = nil
    self.pendingAttempts = nil
    return
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0.4, function()
      self:CheckPendingProfile()
    end)
  end
end

function SpecManager:SwitchForProfile(profile, options)
  if not profile then
    return false, "Perfil no encontrado"
  end

  if not self:ProfileNeedsSpecSwitch(profile, options) then
    return false, nil
  end

  if ModeShift:IsInCombat() then
    return false, "No se puede cambiar de especializacion en combate"
  end

  local specIndex = self:GetSpecIndex(profile.specId)
  if not specIndex then
    return false, "No encuentro la especializacion " .. tostring(profile.specName or profile.specId)
  end

  self.pendingProfileId = profile.id
  self.pendingTargetSpecId = profile.specId
  self.pendingOptions = ModeShift.Utils:DeepCopy(options or {})
  self.pendingAttempts = 0

  local ok, err = setSpecialization(specIndex)
  if not ok then
    self.pendingProfileId = nil
    self.pendingTargetSpecId = nil
    self.pendingOptions = nil
    self.pendingAttempts = nil
    return false, err
  end

  ModeShift:Print("cambiando a " .. tostring(profile.specName or profile.specId) .. " para aplicar " .. tostring(profile.name or profile.id) .. "...")
  self:CheckPendingProfile()
  return true, nil
end

function SpecManager:OnEvent(event)
  if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" then
    self:CheckPendingProfile()
  end
end

ModeShift:RegisterModule("SpecManager", SpecManager)
