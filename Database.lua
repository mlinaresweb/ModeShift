local ModeShift = _G.ModeShift

local Database = {}

local function defaults()
  return {
    version = ModeShift.Constants.DB_VERSION,
    globalSettings = ModeShift.Utils:DeepCopy(ModeShift.Constants.DEFAULT_SETTINGS),
    profiles = {},
    characters = {},
  }
end

function Database:Initialize()
  _G.ModeShiftDB = ModeShift.Utils:CopyDefaults(_G.ModeShiftDB, defaults())
  _G.ModeShiftCharDB = ModeShift.Utils:CopyDefaults(_G.ModeShiftCharDB, {
    activeProfileId = nil,
    lastAppliedProfileId = nil,
    pendingProfileId = nil,
    requiresReload = false,
  })

  self.db = _G.ModeShiftDB
  self.char = _G.ModeShiftCharDB
  self:Migrate()
  self:EnsureCharacter()
end

function Database:Migrate()
  self.db.version = self.db.version or 1
  self.db.globalSettings = ModeShift.Utils:CopyDefaults(self.db.globalSettings, ModeShift.Constants.DEFAULT_SETTINGS)
  self.db.profiles = self.db.profiles or {}
  self.db.characters = self.db.characters or {}
end

function Database:GetDB()
  if not self.db then
    self:Initialize()
  end
  return self.db
end

function Database:GetCharDB()
  if not self.char then
    self:Initialize()
  end
  return self.char
end

function Database:EnsureCharacter()
  local db = self:GetDB()
  local key = ModeShift:GetPlayerKey()
  db.characters[key] = ModeShift.Utils:CopyDefaults(db.characters[key], {
    activeProfileId = nil,
    lastAppliedProfileId = nil,
    preferredProfileBySpec = {},
  })

  return db.characters[key]
end

function Database:GetCharacter()
  return self:EnsureCharacter()
end

function Database:GetGlobalSetting(key)
  local db = self:GetDB()
  if db.globalSettings[key] == nil then
    return ModeShift.Constants.DEFAULT_SETTINGS[key]
  end
  return db.globalSettings[key]
end

function Database:SetGlobalSetting(key, value)
  local db = self:GetDB()
  db.globalSettings[key] = value
end

function Database:GetProfile(profileId)
  if not profileId then
    return nil
  end
  return self:GetDB().profiles[profileId]
end

function Database:SaveProfile(profile)
  if type(profile) ~= "table" or not profile.id then
    return nil
  end

  self:GetDB().profiles[profile.id] = profile
  return profile
end

function Database:DeleteProfile(profileId)
  self:GetDB().profiles[profileId] = nil
end

function Database:GetProfiles()
  return self:GetDB().profiles
end

function Database:SetActiveProfileId(profileId)
  local character = self:GetCharacter()
  local char = self:GetCharDB()
  character.activeProfileId = profileId
  char.activeProfileId = profileId
end

function Database:GetActiveProfileId()
  return self:GetCharDB().activeProfileId or self:GetCharacter().activeProfileId
end

function Database:SetLastAppliedProfileId(profileId)
  local character = self:GetCharacter()
  local char = self:GetCharDB()
  character.lastAppliedProfileId = profileId
  char.lastAppliedProfileId = profileId
end

function Database:GetLastAppliedProfileId()
  return self:GetCharDB().lastAppliedProfileId or self:GetCharacter().lastAppliedProfileId
end

function Database:SetPendingProfileId(profileId)
  self:GetCharDB().pendingProfileId = profileId
end

function Database:GetPendingProfileId()
  return self:GetCharDB().pendingProfileId
end

function Database:SetRequiresReload(value)
  self:GetCharDB().requiresReload = value and true or false
end

function Database:GetRequiresReload()
  return self:GetCharDB().requiresReload == true
end

function Database:SetPreferredProfileForSpec(specId, profileId)
  if not specId then
    return
  end
  self:GetCharacter().preferredProfileBySpec[specId] = profileId
end

function Database:GetPreferredProfileForSpec(specId)
  if not specId then
    return nil
  end
  return self:GetCharacter().preferredProfileBySpec[specId]
end

ModeShift:RegisterModule("Database", Database)
