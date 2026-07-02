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

  local source = db.profiles
  if type(source) ~= "table" and type(db.global) == "table" then
    source = db.global.profiles
  end

  if type(source) == "table" then
    for profileName in pairs(source) do
      table.insert(profiles, tostring(profileName))
    end
  end

  table.sort(profiles)
  return profiles
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
  local addonObject = _G[addonName] or self:GetAceAddon(addonName)
  if type(addonObject) == "table" and type(addonObject.db) == "table" then
    return addonObject.db, "AceDB"
  end

  local savedVariables = splitCSV(self:GetAddonMetadata(addonName, "SavedVariables"))
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

function Integrations:GetGenericProfiles(addonName)
  local source = self:GetGenericProfileSource(addonName)
  if not source then
    return {}
  end
  return self:GetProfilesFromAceDB(source)
end

function Integrations:ApplyGenericProfile(addonName, profileName)
  local source, sourceName = self:GetGenericProfileSource(addonName)
  if not source then
    return false, "No encuentro perfiles compatibles"
  end

  if type(source.SetProfile) == "function" then
    return self:ApplyAceDBProfile(source, profileName)
  end

  return false, "Perfil detectado en " .. tostring(sourceName) .. ", pero el addon no expone cambio seguro"
end

ModeShift:RegisterModule("Integrations", Integrations)
