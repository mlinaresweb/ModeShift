local ModeShift = _G.ModeShift

local Integrations = {
  registry = {},
  order = {},
}

local function addonApi()
  return C_AddOns or {}
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

ModeShift:RegisterModule("Integrations", Integrations)
