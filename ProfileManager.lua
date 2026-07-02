local ModeShift = _G.ModeShift

local ProfileManager = {}

local function normalizeProfile(profile)
  profile.enabled = profile.enabled ~= false
  profile.icon = profile.icon or ModeShift.Constants.DEFAULT_ICON
  profile.modeType = profile.modeType or ModeShift.Constants.MODE_TYPES.CUSTOM
  profile.equipment = ModeShift.Utils:CopyDefaults(profile.equipment, { enabled = false, setId = nil, setName = nil })
  profile.talents = ModeShift.Utils:CopyDefaults(profile.talents, { enabled = false, configId = nil, configName = nil, autoApply = true })
  profile.editMode = ModeShift.Utils:CopyDefaults(profile.editMode, { enabled = false, layoutId = nil, layoutName = nil })
  profile.addons = ModeShift.Utils:CopyDefaults(profile.addons, { enabled = false, enable = {}, disable = {} })
  profile.addonProfiles = ModeShift.Utils:CopyDefaults(profile.addonProfiles, { enabled = false, entries = {} })
  profile.cvars = ModeShift.Utils:CopyDefaults(profile.cvars, { enabled = false, values = {} })
  return profile
end

function ProfileManager:GenerateProfileId(name, specId, modeType)
  local base = ModeShift.Utils:MakeProfileId(name, specId, modeType)
  local profileId = base
  local index = 2

  while ModeShift.Database:GetProfile(profileId) do
    profileId = base .. "_" .. index
    index = index + 1
  end

  return profileId
end

function ProfileManager:CreateProfile(data)
  data = data or {}

  local specId = data.specId or ModeShift:GetCurrentSpecId()
  local specName = data.specName or ModeShift:GetCurrentSpecName()
  local modeType = data.modeType or ModeShift.Constants.MODE_TYPES.CUSTOM
  local name = data.name or ((specName or "Current Spec") .. " " .. modeType)
  local profileId = data.id or self:GenerateProfileId(name, specId, modeType)

  local profile = normalizeProfile({
    id = profileId,
    name = name,
    description = data.description or "",
    icon = data.icon or ModeShift.Constants.DEFAULT_ICON,
    enabled = data.enabled ~= false,
    order = data.order or 100,
    classFile = data.classFile or ModeShift:GetClassFile(),
    specId = specId,
    specName = specName,
    modeType = modeType,
    characterScope = data.characterScope,
    equipment = data.equipment,
    talents = data.talents,
    editMode = data.editMode,
    addons = data.addons,
    addonProfiles = data.addonProfiles,
    cvars = data.cvars,
  })

  ModeShift.Database:SaveProfile(profile)
  if specId and not ModeShift.Database:GetPreferredProfileForSpec(specId) then
    ModeShift.Database:SetPreferredProfileForSpec(specId, profile.id)
  end

  return profile
end

function ProfileManager:SaveProfile(profile)
  if type(profile) ~= "table" or not profile.id then
    return nil
  end

  normalizeProfile(profile)
  ModeShift.Database:SaveProfile(profile)
  return profile
end

function ProfileManager:DeleteProfile(profileId)
  if not profileId then
    return false
  end

  ModeShift.Database:DeleteProfile(profileId)
  if ModeShift.Database:GetActiveProfileId() == profileId then
    ModeShift.Database:SetActiveProfileId(nil)
  end
  if ModeShift.Database:GetLastAppliedProfileId() == profileId then
    ModeShift.Database:SetLastAppliedProfileId(nil)
  end
  if ModeShift.Database:GetPendingProfileId() == profileId then
    ModeShift.Database:SetPendingProfileId(nil)
  end

  return true
end

function ProfileManager:DuplicateProfile(profileId)
  local source = self:GetProfile(profileId)
  if not source then
    return nil
  end

  local copy = ModeShift.Utils:DeepCopy(source)
  copy.name = (copy.name or "Perfil") .. " copia"
  copy.id = self:GenerateProfileId(copy.name, copy.specId, copy.modeType)
  copy.order = (copy.order or 100) + 1
  return self:SaveProfile(copy)
end

function ProfileManager:CreateProfileFromCurrentState(name, modeType)
  local specId = ModeShift:GetCurrentSpecId()
  local specName = ModeShift:GetCurrentSpecName()
  local profile = self:CreateProfile({
    name = name or ((specName or "Spec") .. " " .. (modeType or "CUSTOM")),
    specId = specId,
    specName = specName,
    classFile = ModeShift:GetClassFile(),
    modeType = modeType or "CUSTOM",
    equipment = { enabled = false, setName = nil, setId = nil },
    talents = { enabled = false, configName = nil, configId = nil, autoApply = true },
    addons = { enabled = true, enable = {}, disable = {} },
    cvars = { enabled = false, values = {} },
  })

  self:CaptureCurrentAddons(profile)
  self:SaveProfile(profile)

  return profile
end

function ProfileManager:CaptureCurrentAddons(profile)
  if type(profile) ~= "table" or not ModeShift.AddonManager then
    return profile
  end

  profile.addons = ModeShift.Utils:CopyDefaults(profile.addons, { enabled = true, enable = {}, disable = {} })
  profile.addons.enabled = true
  profile.addons.enable = {}
  profile.addons.disable = {}

  for _, addon in ipairs(ModeShift.AddonManager:GetInstalledAddons()) do
    if addon.name == ModeShift.addonName then
      table.insert(profile.addons.enable, addon.name)
    elseif addon.enabled then
      table.insert(profile.addons.enable, addon.name)
    else
      table.insert(profile.addons.disable, addon.name)
    end
  end

  return profile
end

function ProfileManager:EnsureAddonSnapshot(profile)
  if type(profile) ~= "table" then
    return profile
  end

  profile.addons = ModeShift.Utils:CopyDefaults(profile.addons, { enabled = true, enable = {}, disable = {} })
  profile.addons.enabled = true
  profile.addons.enable = ModeShift.Utils:SafeArray(profile.addons.enable)
  profile.addons.disable = ModeShift.Utils:SafeArray(profile.addons.disable)

  if #profile.addons.enable == 0 and #profile.addons.disable == 0 then
    self:CaptureCurrentAddons(profile)
    self:SaveProfile(profile)
  end

  return profile
end

function ProfileManager:EnsureExampleProfiles()
  if not ModeShift.Database then
    return
  end

  local specId = ModeShift:GetCurrentSpecId()
  local specName = ModeShift:GetCurrentSpecName() or "Spec"
  local classFile = ModeShift:GetClassFile()
  local pveId = ModeShift.Utils:MakeProfileId(specName .. " PVE", specId, "PVE")
  local pvpId = ModeShift.Utils:MakeProfileId(specName .. " PVP", specId, "PVP")

  if not ModeShift.Database:GetProfile(pveId) then
    self:CreateProfile({
      id = pveId,
      name = specName .. " PVE",
      description = "Perfil PVE de ejemplo para la spec actual.",
      order = 10,
      classFile = classFile,
      specId = specId,
      specName = specName,
      modeType = "PVE",
      equipment = { enabled = true, setName = specName .. " PVE" },
      talents = { enabled = true, configName = specName .. " PVE", autoApply = true },
      addons = { enabled = true, enable = {}, disable = {} },
      cvars = { enabled = false, values = {} },
    })
    local profile = ModeShift.Database:GetProfile(pveId)
    self:CaptureCurrentAddons(profile)
    self:SaveProfile(profile)
  end

  if not ModeShift.Database:GetProfile(pvpId) then
    self:CreateProfile({
      id = pvpId,
      name = specName .. " PVP",
      description = "Perfil PVP de ejemplo para la spec actual.",
      order = 20,
      classFile = classFile,
      specId = specId,
      specName = specName,
      modeType = "PVP",
      equipment = { enabled = true, setName = specName .. " PVP" },
      talents = { enabled = true, configName = specName .. " PVP", autoApply = true },
      addons = { enabled = true, enable = {}, disable = {} },
      cvars = { enabled = false, values = {} },
    })
    local profile = ModeShift.Database:GetProfile(pvpId)
    self:CaptureCurrentAddons(profile)
    self:SaveProfile(profile)
  end
end

function ProfileManager:GetProfile(profileId)
  local profile = ModeShift.Database:GetProfile(profileId)
  if profile then
    return normalizeProfile(profile)
  end
  return nil
end

function ProfileManager:GetProfilesForCurrentCharacter()
  local profiles = {}
  local classFile = ModeShift:GetClassFile()

  for _, profile in pairs(ModeShift.Database:GetProfiles()) do
    normalizeProfile(profile)
    local classMatches = not profile.classFile or not classFile or profile.classFile == classFile
    if profile.enabled ~= false and classMatches then
      table.insert(profiles, profile)
    end
  end

  table.sort(profiles, function(a, b)
    if (a.specId or 0) == (b.specId or 0) then
      return (a.order or 0) < (b.order or 0)
    end
    return (a.specId or 0) < (b.specId or 0)
  end)

  return profiles
end

function ProfileManager:GetEnabledProfilesBySpec()
  local grouped = {}
  for _, profile in ipairs(self:GetProfilesForCurrentCharacter()) do
    local specKey = profile.specId or 0
    grouped[specKey] = grouped[specKey] or {
      specId = profile.specId,
      specName = profile.specName or "Sin spec",
      profiles = {},
    }
    table.insert(grouped[specKey].profiles, profile)
  end
  return grouped
end

function ProfileManager:GetCurrentOrPreferredProfile()
  local activeProfileId = ModeShift.Database:GetActiveProfileId()
  if activeProfileId and self:GetProfile(activeProfileId) then
    return self:GetProfile(activeProfileId)
  end

  local specId = ModeShift:GetCurrentSpecId()
  local preferred = ModeShift.Database:GetPreferredProfileForSpec(specId)
  if preferred and self:GetProfile(preferred) then
    return self:GetProfile(preferred)
  end

  local profiles = self:GetProfilesForCurrentCharacter()
  return profiles[1]
end

function ProfileManager:ListProfiles()
  local profiles = self:GetProfilesForCurrentCharacter()
  local activeProfileId = ModeShift.Database:GetActiveProfileId()

  if #profiles == 0 then
    ModeShift:Print("no hay perfiles. Usa /ms create para crear ejemplos.")
    return
  end

  ModeShift:Print("perfiles:")
  for _, profile in ipairs(profiles) do
    local marker = profile.id == activeProfileId and "*" or "-"
    ModeShift:Print(string.format("%s %s [%s/%s] id=%s", marker, profile.name or profile.id, profile.specName or profile.specId or "sin spec", profile.modeType or "CUSTOM", profile.id))
  end
end

ModeShift:RegisterModule("ProfileManager", ProfileManager)
