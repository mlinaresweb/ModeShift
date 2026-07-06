local ModeShift = _G.ModeShift

local AddonProfileManager = {
  profileCache = {},
  currentCache = {},
  optionCache = {},
  currentOptionCache = {},
}

local function cacheKey(addonName, deepScan)
  return tostring(addonName or "") .. "|" .. (deepScan and "deep" or "light")
end

local function copyList(source)
  local copy = {}
  for index, value in ipairs(source or {}) do
    copy[index] = value
  end
  return copy
end

function AddonProfileManager:GetSupportedIntegrations()
  if not ModeShift.Integrations then
    return {}
  end
  return ModeShift.Integrations:GetAll()
end

function AddonProfileManager:ClearCache(addonName)
  if addonName then
    self.profileCache[cacheKey(addonName, false)] = nil
    self.profileCache[cacheKey(addonName, true)] = nil
    self.currentCache[cacheKey(addonName, false)] = nil
    self.currentCache[cacheKey(addonName, true)] = nil
    self.optionCache[cacheKey(addonName, false)] = nil
    self.optionCache[cacheKey(addonName, true)] = nil
    self.currentOptionCache[cacheKey(addonName, false)] = nil
    self.currentOptionCache[cacheKey(addonName, true)] = nil
  else
    self.profileCache = {}
    self.currentCache = {}
    self.optionCache = {}
    self.currentOptionCache = {}
  end
end

function AddonProfileManager:ClearCurrentCache(addonName)
  if addonName then
    self.currentCache[cacheKey(addonName, false)] = nil
    self.currentCache[cacheKey(addonName, true)] = nil
    self.currentOptionCache[cacheKey(addonName, false)] = nil
    self.currentOptionCache[cacheKey(addonName, true)] = nil
  else
    self.currentCache = {}
    self.currentOptionCache = {}
  end
end

function AddonProfileManager:GetAvailableProfiles(addonName, deepScan)
  local key = cacheKey(addonName, deepScan)
  if self.profileCache[key] then
    return copyList(self.profileCache[key])
  end

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if integration and type(integration.getProfiles) == "function" then
    local ok, profiles = ModeShift:SafeCall("getProfiles", integration.getProfiles)
    if ok and type(profiles) == "table" and #profiles > 0 then
      table.sort(profiles)
      self.profileCache[key] = copyList(profiles)
      return copyList(profiles)
    end
  end

  if ModeShift.Integrations then
    local profiles = ModeShift.Integrations:GetGenericProfiles(addonName, deepScan)
    table.sort(profiles)
    self.profileCache[key] = copyList(profiles)
    return profiles
  end

  return {}
end

function AddonProfileManager:GetCurrentProfile(addonName, deepScan)
  local key = cacheKey(addonName, deepScan)
  if self.currentCache[key] ~= nil then
    return self.currentCache[key] or nil
  end

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if integration and type(integration.getCurrentProfile) == "function" then
    local ok, profileName = ModeShift:SafeCall("getCurrentProfile", integration.getCurrentProfile)
    if ok and profileName then
      self.currentCache[key] = tostring(profileName)
      return tostring(profileName)
    end
  end

  if ModeShift.Integrations then
    local profileName = ModeShift.Integrations:GetGenericCurrentProfile(addonName, deepScan)
    self.currentCache[key] = profileName or false
    return profileName
  end

  return nil
end

function AddonProfileManager:GetAvailableOptions(addonName, deepScan)
  local key = cacheKey(addonName, deepScan)
  if self.optionCache[key] then
    return copyList(self.optionCache[key])
  end

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if integration and type(integration.getOptions) == "function" then
    local ok, options = ModeShift:SafeCall("getOptions", integration.getOptions)
    if ok and type(options) == "table" then
      table.sort(options)
      self.optionCache[key] = copyList(options)
      return copyList(options)
    end
  end

  if ModeShift.Integrations then
    local options = ModeShift.Integrations:GetGenericOptions(addonName, deepScan)
    table.sort(options)
    self.optionCache[key] = copyList(options)
    return options
  end

  return {}
end

function AddonProfileManager:GetCurrentOption(addonName, deepScan)
  local key = cacheKey(addonName, deepScan)
  if self.currentOptionCache[key] ~= nil then
    return self.currentOptionCache[key] or nil
  end

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if integration and type(integration.getCurrentOption) == "function" then
    local ok, optionName = ModeShift:SafeCall("getCurrentOption", integration.getCurrentOption)
    if ok and optionName then
      self.currentOptionCache[key] = tostring(optionName)
      return tostring(optionName)
    end
  end

  if ModeShift.Integrations then
    local optionName = ModeShift.Integrations:GetGenericCurrentOption(addonName, deepScan)
    self.currentOptionCache[key] = optionName or false
    return optionName
  end

  return nil
end

function AddonProfileManager:CanShowOptionPicker(addonName)
  local normalized = tostring(addonName or ""):lower()
  if normalized:find("cooldownmanager", 1, true) then
    return true
  end

  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  return integration and type(integration.getOptions) == "function"
end

function AddonProfileManager:CanShowProfilePicker(addonName)
  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if integration and type(integration.getProfiles) == "function" then
    local profiles = self:GetAvailableProfiles(addonName, false)
    if #profiles > 0 then
      return true
    end
    local currentProfile = self:GetCurrentProfile(addonName, false)
    return currentProfile ~= nil
  end

  if #self:GetAvailableProfiles(addonName, false) > 0 then
    return true
  end

  local currentProfile = self:GetCurrentProfile(addonName, false)
  if currentProfile ~= nil then
    return true
  end

  return false
end

function AddonProfileManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local addonProfiles = profile and profile.addonProfiles or nil

  if not addonProfiles or not addonProfiles.enabled then
    table.insert(result.skipped, "Perfiles internos de addons desactivados")
    return result
  end

  for addonName, entry in pairs(addonProfiles.entries or {}) do
    if type(entry) == "table" and entry.enabled then
      local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
      if integration and integration.isAvailable and not integration.isAvailable() then
        table.insert(result.warnings, tostring(integration.displayName or addonName) .. " no esta cargado")
      end

      if entry.profileName and entry.profileName ~= "" then
        if not integration then
          local ok, appliedOrErr, extraErr = ModeShift:SafeCall("applyGenericProfile", ModeShift.Integrations.ApplyGenericProfile, ModeShift.Integrations, addonName, entry.profileName)
          if ok and appliedOrErr ~= false then
            table.insert(result.applied, "Perfil " .. tostring(addonName) .. ": " .. entry.profileName)
            if extraErr then
              result.requiresReload = true
              table.insert(result.warnings, tostring(addonName) .. ": " .. tostring(extraErr))
            end
          else
            result.success = false
            table.insert(result.warnings, tostring(addonName) .. ": " .. tostring(extraErr or appliedOrErr or "no aplicado"))
          end
        elseif type(integration.applyProfile) ~= "function" then
          table.insert(result.warnings, tostring(integration.displayName or addonName) .. " no puede cambiar perfil aun")
        else
          local ok, appliedOrErr, extraErr = ModeShift:SafeCall("applyProfile", integration.applyProfile, entry.profileName)
          if ok and appliedOrErr ~= false then
            local name = integration.displayName or addonName
            table.insert(result.applied, "Perfil " .. name .. ": " .. entry.profileName)
            if extraErr then
              result.requiresReload = true
              table.insert(result.warnings, tostring(name) .. ": " .. tostring(extraErr))
            end
          else
            result.success = false
            table.insert(result.warnings, tostring(integration.displayName or addonName) .. ": " .. tostring(extraErr or appliedOrErr or "no aplicado"))
          end
        end
      end

      if entry.optionName and entry.optionName ~= "" then
        if integration and type(integration.applyOption) == "function" then
          local ok, appliedOrErr, extraErr = ModeShift:SafeCall("applyOption", integration.applyOption, entry.optionName)
          if ok and appliedOrErr ~= false then
            table.insert(result.applied, "Config " .. tostring(integration.displayName or addonName) .. ": " .. entry.optionName)
            if extraErr then
              result.requiresReload = true
              table.insert(result.warnings, tostring(integration.displayName or addonName) .. " config: " .. tostring(extraErr))
            end
          else
            result.success = false
            table.insert(result.warnings, tostring(integration.displayName or addonName) .. " config: " .. tostring(extraErr or appliedOrErr or "no aplicada"))
          end
        elseif ModeShift.Integrations then
          local ok, appliedOrErr, extraErr = ModeShift:SafeCall("applyGenericOption", ModeShift.Integrations.ApplyGenericOption, ModeShift.Integrations, addonName, entry.optionName)
          if ok and appliedOrErr ~= false then
            table.insert(result.applied, "Config " .. tostring(addonName) .. ": " .. entry.optionName)
            if extraErr then
              result.requiresReload = true
              table.insert(result.warnings, tostring(addonName) .. " config: " .. tostring(extraErr))
            end
          else
            result.success = false
            table.insert(result.warnings, tostring(addonName) .. " config: " .. tostring(extraErr or appliedOrErr or "no aplicada"))
          end
        end
      end
    end
  end

  return result
end

function AddonProfileManager:OnEvent(event)
  if event == "ADDON_LOADED" then
    self:ClearCache()
  end
end

ModeShift:RegisterModule("AddonProfileManager", AddonProfileManager)
