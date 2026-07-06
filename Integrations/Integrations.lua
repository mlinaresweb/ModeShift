local ModeShift = _G.ModeShift

local Integrations = {
  registry = {},
  order = {},
}

local function addonApi()
  return C_AddOns or {}
end

local function splitCSV(value)
  local list = {}
  if type(value) ~= "string" then
    return list
  end

  for item in string.gmatch(value, "([^,]+)") do
    item = ModeShift.Utils:Trim(item)
    if item ~= "" then
      table.insert(list, item)
    end
  end

  return list
end

local function normalizeName(value)
  return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function stripWowColors(value)
  value = tostring(value or "")
  value = value:gsub("|c%x%x%x%x%x%x%x%x", "")
  value = value:gsub("|r", "")
  value = value:gsub("|A:[^|]+|a", "")
  return value
end

local function acronym(value)
  value = stripWowColors(value)
  local letters = {}
  for letter in value:gmatch("%u") do
    table.insert(letters, letter:lower())
  end
  if #letters >= 2 then
    return table.concat(letters)
  end
  return nil
end

local function addUnique(list, seen, value)
  if value == nil then
    return
  end

  local name = tostring(value)
  if name == "" or seen[name] then
    return
  end

  seen[name] = true
  table.insert(list, name)
end

local function looksLikeProfileMap(value)
  if type(value) ~= "table" then
    return false
  end

  local found = 0
  for key, entry in pairs(value) do
    if type(key) == "string" and key ~= "" and type(entry) == "table" then
      found = found + 1
      if found >= 1 then
        return true
      end
    end
  end

  return false
end

local profileContainerKeys = {
  profiles = true,
  Profiles = true,
  profileData = true,
  ProfileData = true,
  profileDataByName = true,
  profileSettings = true,
  profileDB = true,
}

local currentProfileKeys = {
  currentProfile = true,
  CurrentProfile = true,
  activeProfile = true,
  ActiveProfile = true,
  selectedProfile = true,
  SelectedProfile = true,
  profileName = true,
  ProfileName = true,
}

local function addNamesFromProfileArray(value, out, seen)
  if type(value) ~= "table" then
    return false
  end

  local found = false
  for _, entry in ipairs(value) do
    if type(entry) == "table" and (entry.name or entry.profileName or entry.profile) then
      addUnique(out, seen, entry.name or entry.profileName or entry.profile)
      found = true
    elseif type(entry) == "string" or type(entry) == "number" then
      addUnique(out, seen, entry)
      found = true
    end
  end

  return found
end

local function collectProfileNames(source, out, seen, depth, state)
  if type(source) ~= "table" or depth > 4 then
    return
  end

  state.nodes = (state.nodes or 0) + 1
  if state.nodes > 260 or #out >= 120 then
    return
  end

  addNamesFromProfileArray(source.ProfileData, out, seen)
  addNamesFromProfileArray(source.profileData, out, seen)

  if type(source.profileKeys) == "table" then
    for _, profileName in pairs(source.profileKeys) do
      if type(profileName) == "string" or type(profileName) == "number" then
        addUnique(out, seen, profileName)
      end
    end
  end

  for key, value in pairs(source) do
    if type(key) == "string" and type(value) == "table" then
      local normalized = normalizeName(key)
      if profileContainerKeys[key] or normalized == "profiles" or normalized:find("profiles", 1, true) then
        if addNamesFromProfileArray(value, out, seen) then
          -- handled array-style profile data
        elseif looksLikeProfileMap(value) then
          for profileName in pairs(value) do
            if type(profileName) == "string" or type(profileName) == "number" then
              addUnique(out, seen, profileName)
            end
          end
        end
      elseif depth < 4 then
        collectProfileNames(value, out, seen, depth + 1, state)
      end
    end
  end
end

function Integrations:IsAddonLoaded(addonName)
  local api = addonApi()
  if api.IsAddOnLoaded then
    local ok, loaded = ModeShift:SafeCall("IsAddOnLoaded", api.IsAddOnLoaded, addonName)
    return ok and loaded
  end
  if IsAddOnLoaded then
    local ok, loaded = ModeShift:SafeCall("IsAddOnLoaded", IsAddOnLoaded, addonName)
    return ok and loaded
  end
  return false
end

function Integrations:IsAddonInstalled(addonName)
  if ModeShift.AddonManager then
    return ModeShift.AddonManager:IsInstalled(addonName)
  end
  return false
end

function Integrations:Register(integration)
  if type(integration) ~= "table" or not integration.addonName then
    return
  end

  integration.displayName = integration.displayName or integration.addonName
  self.registry[integration.addonName] = integration
  table.insert(self.order, integration.addonName)
end

function Integrations:Get(addonName)
  return self.registry[addonName]
end

function Integrations:GetAll()
  local list = {}
  for _, addonName in ipairs(self.order) do
    if self.registry[addonName] then
      table.insert(list, self.registry[addonName])
    end
  end
  return list
end

function Integrations:GetAddonMetadata(addonName, field)
  local api = addonApi()
  if api.GetAddOnMetadata then
    local ok, value = ModeShift:SafeCall("GetAddOnMetadata", api.GetAddOnMetadata, addonName, field)
    if ok then
      return value
    end
  end
  if GetAddOnMetadata then
    local ok, value = ModeShift:SafeCall("GetAddOnMetadata", GetAddOnMetadata, addonName, field)
    if ok then
      return value
    end
  end
  return nil
end

function Integrations:GetProfilesFromDB(db)
  local profiles = {}
  if type(db) ~= "table" then
    return profiles
  end

  local seen = {}

  local source = db.profiles
  if type(source) ~= "table" and type(db.global) == "table" then
    source = db.global.profiles
  end
  if type(source) ~= "table" and type(db.profile) == "table" then
    source = db.profile.profiles
  end

  if type(source) == "table" then
    for profileName in pairs(source) do
      addUnique(profiles, seen, profileName)
    end
  end

  collectProfileNames(db, profiles, seen, 1, { nodes = 0 })

  table.sort(profiles)
  return profiles
end

function Integrations:GetCurrentProfileFromDB(db)
  if type(db) ~= "table" then
    return nil
  end

  if type(db.profileKeys) == "table" then
    local key = ModeShift:GetPlayerKey()
    if db.profileKeys[key] then
      return tostring(db.profileKeys[key])
    end

    local playerName = UnitName and UnitName("player") or nil
    local realmName = GetRealmName and GetRealmName() or nil
    if playerName and db.profileKeys[playerName] then
      return tostring(db.profileKeys[playerName])
    end
    if playerName and realmName then
      local compactRealm = tostring(realmName):gsub("%s+", "")
      local candidates = {
        playerName .. " - " .. realmName,
        playerName .. "-" .. realmName,
        compactRealm .. "-" .. playerName,
      }
      for _, candidate in ipairs(candidates) do
        if db.profileKeys[candidate] then
          return tostring(db.profileKeys[candidate])
        end
      end
    end
  end

  if type(db.global) == "table" and db.global.currentProfile then
    return tostring(db.global.currentProfile)
  end

  for key in pairs(currentProfileKeys) do
    if db[key] ~= nil then
      return tostring(db[key])
    end
  end

  return nil
end

local function addCandidate(candidates, seen, candidate)
  if type(candidate) ~= "table" or seen[candidate] then
    return
  end

  seen[candidate] = true
  table.insert(candidates, candidate)
end

local function objectHasProfileCapabilities(candidate)
  if type(candidate) ~= "table" then
    return false
  end

  if type(candidate.GetProfiles) == "function"
    or type(candidate.GetProfileNames) == "function"
    or type(candidate.GetCurrentProfile) == "function"
    or type(candidate.GetActiveProfile) == "function"
    or type(candidate.SetProfile) == "function"
    or type(candidate.SwitchProfile) == "function"
    or type(candidate.ChangeProfile) == "function"
    or type(candidate.ApplyProfile) == "function"
    or type(candidate.ProfileData) == "table"
  then
    return true
  end

  return false
end

function Integrations:GetGenericProfileObjects(addonName)
  local aliases = {}
  aliases[normalizeName(addonName)] = true

  local title = self:GetAddonMetadata(addonName, "Title")
  if title then
    aliases[normalizeName(stripWowColors(title))] = true
  end

  local addonAcronym = acronym(addonName)
  if addonAcronym then
    aliases[addonAcronym] = true
  end

  local titleAcronym = acronym(title or "")
  if titleAcronym then
    aliases[titleAcronym] = true
  end

  local candidates = {}
  local seen = {}
  addCandidate(candidates, seen, _G[addonName])
  addCandidate(candidates, seen, self:GetAceAddon(addonName))
  if addonAcronym then
    addCandidate(candidates, seen, _G[addonAcronym])
    addCandidate(candidates, seen, _G[string.upper(addonAcronym)])
  end
  if titleAcronym then
    addCandidate(candidates, seen, _G[titleAcronym])
    addCandidate(candidates, seen, _G[string.upper(titleAcronym)])
  end

  for variableName in pairs(aliases) do
    addCandidate(candidates, seen, _G[variableName])
    addCandidate(candidates, seen, _G[string.upper(variableName)])
  end

  return candidates
end

function Integrations:GetProfilesFromObject(object)
  local profiles = {}
  local seen = {}

  if type(object) ~= "table" then
    return profiles
  end

  local methods = { "GetProfiles", "GetProfileNames" }
  for _, methodName in ipairs(methods) do
    if type(object[methodName]) == "function" then
      local ok, result = ModeShift:SafeCall(methodName, object[methodName], object)
      if ok and type(result) == "table" then
        for _, profileName in pairs(result) do
          addUnique(profiles, seen, profileName)
        end
      end
    end
  end

  addNamesFromProfileArray(object.ProfileData, profiles, seen)
  addNamesFromProfileArray(object.profileData, profiles, seen)
  collectProfileNames(object, profiles, seen, 1, { nodes = 0 })
  table.sort(profiles)
  return profiles
end

function Integrations:GetCurrentProfileFromObject(object)
  if type(object) ~= "table" then
    return nil
  end

  local methods = { "GetCurrentProfile", "GetActiveProfile", "GetSelectedProfile", "CurrentProfile" }
  for _, methodName in ipairs(methods) do
    if type(object[methodName]) == "function" then
      local ok, result = ModeShift:SafeCall(methodName, object[methodName], object)
      if ok and result then
        return tostring(result)
      end
    end
  end

  return self:GetCurrentProfileFromDB(object)
end

function Integrations:GetProfilesFromAceDB(dbObject)
  if type(dbObject) ~= "table" then
    return {}
  end

  if type(dbObject.GetProfiles) == "function" then
    local ok, profiles = ModeShift:SafeCall("GetProfiles", dbObject.GetProfiles, dbObject)
    if ok and type(profiles) == "table" then
      table.sort(profiles)
      return profiles
    end
  end

  return self:GetProfilesFromDB(dbObject.sv or dbObject)
end

local optionKeys = {
  layouts = true,
  layout = true,
  designs = true,
  design = true,
  configs = true,
  config = true,
  presets = true,
  preset = true,
  displays = true,
  display = true,
  overlays = true,
  overlay = true,
}

local currentOptionKeys = {
  currentLayout = true,
  activeLayout = true,
  selectedLayout = true,
  layout = true,
  currentConfig = true,
  activeConfig = true,
  selectedConfig = true,
  currentDesign = true,
  activeDesign = true,
  selectedDesign = true,
  currentPreset = true,
  activePreset = true,
  selectedPreset = true,
}

local function collectNamesFromTable(source, out, depth)
  if type(source) ~= "table" or depth > 3 then
    return
  end

  for key, value in pairs(source) do
    if type(key) == "string" and type(value) == "table" and optionKeys[key] then
      for name in pairs(value) do
        if type(name) == "string" or type(name) == "number" then
          out[tostring(name)] = true
        end
      end
    elseif type(value) == "table" then
      collectNamesFromTable(value, out, depth + 1)
    end
  end
end

local function findCurrentOption(source, depth)
  if type(source) ~= "table" or depth > 3 then
    return nil
  end

  for key, value in pairs(source) do
    if type(key) == "string" and currentOptionKeys[key] and (type(value) == "string" or type(value) == "number") then
      return tostring(value)
    elseif type(value) == "table" then
      local found = findCurrentOption(value, depth + 1)
      if found then
        return found
      end
    end
  end

  return nil
end

local function setCurrentOption(source, optionName, depth)
  if type(source) ~= "table" or depth > 3 then
    return false
  end

  for key, value in pairs(source) do
    if type(key) == "string" and currentOptionKeys[key] and (type(value) == "string" or type(value) == "number") then
      source[key] = optionName
      return true
    elseif type(value) == "table" and setCurrentOption(value, optionName, depth + 1) then
      return true
    end
  end

  return false
end

function Integrations:GetCurrentProfileFromAceDB(dbObject)
  if type(dbObject) ~= "table" then
    return nil
  end

  if type(dbObject.GetCurrentProfile) == "function" then
    local ok, profileName = ModeShift:SafeCall("GetCurrentProfile", dbObject.GetCurrentProfile, dbObject)
    if ok and profileName then
      return tostring(profileName)
    end
  end

  return self:GetCurrentProfileFromDB(dbObject.sv or dbObject)
end

function Integrations:ApplyAceDBProfile(dbObject, profileName)
  if type(dbObject) ~= "table" or type(dbObject.SetProfile) ~= "function" then
    return false, "El addon no expone SetProfile"
  end

  return ModeShift:SafeCall("SetProfile", dbObject.SetProfile, dbObject, profileName)
end

function Integrations:GetAceAddon(addonName)
  if type(LibStub) ~= "function" then
    return nil
  end

  local ok, aceAddon = ModeShift:SafeCall("LibStub AceAddon", LibStub, "AceAddon-3.0", true)
  if not ok or not aceAddon or type(aceAddon.GetAddon) ~= "function" then
    return nil
  end

  local addonOk, addon = ModeShift:SafeCall("AceAddon GetAddon", aceAddon.GetAddon, aceAddon, addonName, true)
  if addonOk then
    return addon
  end
  return nil
end

function Integrations:GetGenericProfileSource(addonName)
  for _, object in ipairs(self:GetGenericProfileObjects(addonName)) do
    if type(object.db) == "table" then
      return object.db, "AceDB"
    end
  end

  local addonObject = _G[addonName] or self:GetAceAddon(addonName)
  if type(addonObject) == "table" and type(addonObject.db) == "table" then
    return addonObject.db, "AceDB"
  end

  local savedVariables = splitCSV(self:GetAddonMetadata(addonName, "SavedVariables"))
  local perCharacter = splitCSV(self:GetAddonMetadata(addonName, "SavedVariablesPerCharacter"))
  for _, variableName in ipairs(perCharacter) do
    table.insert(savedVariables, variableName)
  end

  for _, variableName in ipairs(savedVariables) do
    local db = _G[variableName]
    local profiles = self:GetProfilesFromDB(db)
    if #profiles > 0 then
      return db, variableName
    end
  end

  local candidates = {
    addonName .. "DB",
    addonName .. "_DB",
    addonName .. "SavedVariables",
  }
  for _, variableName in ipairs(candidates) do
    local db = _G[variableName]
    local profiles = self:GetProfilesFromDB(db)
    if #profiles > 0 then
      return db, variableName
    end
  end

  return nil, nil
end

function Integrations:GetGenericDBSource(addonName)
  local source, sourceName = self:GetGenericProfileSource(addonName)
  if source then
    return source, sourceName
  end

  local savedVariables = splitCSV(self:GetAddonMetadata(addonName, "SavedVariables"))
  local perCharacter = splitCSV(self:GetAddonMetadata(addonName, "SavedVariablesPerCharacter"))
  for _, variableName in ipairs(perCharacter) do
    table.insert(savedVariables, variableName)
  end

  for _, variableName in ipairs(savedVariables) do
    if type(_G[variableName]) == "table" then
      return _G[variableName], variableName
    end
  end

  local candidates = {
    addonName .. "DB",
    addonName .. "_DB",
    addonName .. "SavedVariables",
  }
  for _, variableName in ipairs(candidates) do
    if type(_G[variableName]) == "table" then
      return _G[variableName], variableName
    end
  end

  return nil, nil
end

function Integrations:DeepFindGenericProfileSource(addonName)
  local source, sourceName = self:GetGenericDBSource(addonName)
  if source then
    return source, sourceName
  end

  local normalizedAddon = normalizeName(addonName)
  for variableName, db in pairs(_G) do
    if type(variableName) == "string" and type(db) == "table" then
      local normalizedVariable = normalizeName(variableName)
      if normalizedVariable:find(normalizedAddon, 1, true) then
        local profiles = self:GetProfilesFromDB(db)
        if #profiles > 0 then
          return db, variableName
        end
      end
    end
  end

  return nil, nil
end

function Integrations:DeepFindGenericDBSource(addonName)
  local source, sourceName = self:GetGenericDBSource(addonName)
  if source then
    return source, sourceName
  end

  local normalizedAddon = normalizeName(addonName)
  for variableName, db in pairs(_G) do
    if type(variableName) == "string" and type(db) == "table" then
      local normalizedVariable = normalizeName(variableName)
      if normalizedVariable:find(normalizedAddon, 1, true) then
        return db, variableName
      end
    end
  end

  return nil, nil
end

function Integrations:GetGenericProfiles(addonName, deepScan)
  local profiles = {}
  local seen = {}
  for _, object in ipairs(self:GetGenericProfileObjects(addonName)) do
    local objectProfiles = self:GetProfilesFromObject(object)
    for _, profileName in ipairs(objectProfiles) do
      addUnique(profiles, seen, profileName)
    end
  end

  local source = deepScan and self:DeepFindGenericProfileSource(addonName) or self:GetGenericProfileSource(addonName)
  if source then
    local dbProfiles = self:GetProfilesFromAceDB(source)
    for _, profileName in ipairs(dbProfiles) do
      addUnique(profiles, seen, profileName)
    end
  end

  table.sort(profiles)
  return profiles
end

function Integrations:GetGenericCurrentProfile(addonName, deepScan)
  for _, object in ipairs(self:GetGenericProfileObjects(addonName)) do
    local profileName = self:GetCurrentProfileFromObject(object)
    if profileName then
      return profileName
    end
  end

  local source = deepScan and self:DeepFindGenericProfileSource(addonName) or self:GetGenericProfileSource(addonName)
  if source then
    local profileName = self:GetCurrentProfileFromAceDB(source)
    if profileName then
      return profileName
    end
  end

  local perCharacter = splitCSV(self:GetAddonMetadata(addonName, "SavedVariablesPerCharacter"))
  for _, variableName in ipairs(perCharacter) do
    local normalized = normalizeName(variableName)
    local value = _G[variableName]
    if (normalized:find("profile", 1, true) or normalized:find("layout", 1, true))
      and (type(value) == "string" or type(value) == "number")
    then
      return tostring(value)
    end
  end

  return nil
end

function Integrations:GetGenericOptions(addonName, deepScan)
  local source = deepScan and self:DeepFindGenericDBSource(addonName) or self:GetGenericDBSource(addonName)
  local names = {}
  if source then
    collectNamesFromTable(source.sv or source, names, 1)
  end

  local list = {}
  for name in pairs(names) do
    table.insert(list, name)
  end
  table.sort(list)
  return list
end

function Integrations:GetGenericCurrentOption(addonName, deepScan)
  local source = deepScan and self:DeepFindGenericDBSource(addonName) or self:GetGenericDBSource(addonName)
  if not source then
    return nil
  end
  return findCurrentOption(source.sv or source, 1)
end

function Integrations:ApplyGenericOption(addonName, optionName)
  local addon = _G[addonName] or self:GetAceAddon(addonName)
  if type(addon) == "table" then
    local methods = {
      "SetLayout",
      "SetConfig",
      "SetPreset",
      "SetDesign",
      "ApplyLayout",
      "ApplyConfig",
      "ApplyPreset",
      "ApplyDesign",
    }
    for _, methodName in ipairs(methods) do
      if type(addon[methodName]) == "function" then
        return ModeShift:SafeCall(methodName, addon[methodName], addon, optionName)
      end
    end
  end

  local source = self:DeepFindGenericDBSource(addonName)
  local db = source and (source.sv or source) or nil
  if db and setCurrentOption(db, optionName, 1) then
    return true, "Config escrita en SavedVariables; puede requerir reload o reabrir la config del addon"
  end

  return false, "Opcion detectada, pero el addon no expone API segura para aplicarla"
end

function Integrations:ApplyProfileOnObject(object, profileName)
  if type(object) ~= "table" then
    return false, "Objeto no valido"
  end

  local methods = {
    { name = "SetProfile", passSelf = true },
    { name = "SwitchProfile", passSelf = true },
    { name = "ChangeProfile", passSelf = true },
    { name = "ApplyProfile", passSelf = false },
    { name = "ApplyProfile", passSelf = true },
    { name = "SelectProfile", passSelf = true },
    { name = "LoadProfile", passSelf = true },
  }

  for _, method in ipairs(methods) do
    local methodName = method.name
    if type(object[methodName]) == "function" then
      if method.passSelf then
        return ModeShift:SafeCall(methodName, object[methodName], object, profileName)
      end
      return ModeShift:SafeCall(methodName, object[methodName], profileName)
    end
  end

  return false, "El addon no expone metodo de cambio de perfil"
end

function Integrations:SetMetadataCurrentProfile(addonName, profileName)
  local variables = splitCSV(self:GetAddonMetadata(addonName, "SavedVariablesPerCharacter"))
  local savedVariables = splitCSV(self:GetAddonMetadata(addonName, "SavedVariables"))
  for _, variableName in ipairs(savedVariables) do
    table.insert(variables, variableName)
  end

  local changed = false
  for _, variableName in ipairs(variables) do
    local normalized = normalizeName(variableName)
    if normalized:find("profile", 1, true) or normalized:find("layout", 1, true) then
      local value = _G[variableName]
      if type(value) == "string" or type(value) == "number" or value == nil then
        _G[variableName] = profileName
        changed = true
      end
    end
  end

  return changed
end

function Integrations:ApplyGenericProfile(addonName, profileName)
  local available = self:GetGenericProfiles(addonName, true)
  local profileExistsInObjects = false
  for _, name in ipairs(available) do
    if name == profileName then
      profileExistsInObjects = true
      break
    end
  end

  for _, object in ipairs(self:GetGenericProfileObjects(addonName)) do
    if profileExistsInObjects then
      local ok, appliedOrErr, extraErr = self:ApplyProfileOnObject(object, profileName)
      if ok and appliedOrErr ~= false then
        return true, extraErr
      end
    end
  end

  local source, sourceName = self:DeepFindGenericProfileSource(addonName)
  if not source then
    return false, "No encuentro perfiles compatibles"
  end

  if type(source.SetProfile) == "function" then
    return self:ApplyAceDBProfile(source, profileName)
  end

  local db = source.sv or source
  local profiles = self:GetProfilesFromDB(db)
  local profileExists = false
  for _, name in ipairs(profiles) do
    if name == profileName then
      profileExists = true
      break
    end
  end

  if profileExists then
    if type(db.profileKeys) == "table" then
      db.profileKeys[ModeShift:GetPlayerKey()] = profileName
    end

    local wroteCurrentKey = false
    for key in pairs(currentProfileKeys) do
      if db[key] ~= nil then
        db[key] = profileName
        wroteCurrentKey = true
      end
    end

    if type(db.global) == "table" and db.global.currentProfile ~= nil then
      db.global.currentProfile = profileName
      wroteCurrentKey = true
    end

    if self:SetMetadataCurrentProfile(addonName, profileName) then
      wroteCurrentKey = true
    end

    if wroteCurrentKey or type(db.profileKeys) == "table" then
      return true, "Perfil escrito en " .. tostring(sourceName) .. "; puede requerir reload"
    end

    return true, "Perfil escrito en " .. tostring(sourceName) .. "; puede requerir reload"
  end

  return false, "Perfil detectado en " .. tostring(sourceName) .. ", pero el addon no expone cambio seguro"
end

ModeShift:RegisterModule("Integrations", Integrations)
