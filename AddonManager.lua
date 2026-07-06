local ModeShift = _G.ModeShift

local AddonManager = {
  installedCache = nil,
}

local function addonApi()
  return C_AddOns or {}
end

local function getAddOnInfo(addonName)
  local api = addonApi()
  if api.GetAddOnInfo then
    return ModeShift:SafeCall("GetAddOnInfo", api.GetAddOnInfo, addonName)
  end
  if GetAddOnInfo then
    return ModeShift:SafeCall("GetAddOnInfo", GetAddOnInfo, addonName)
  end
  return false, nil
end

function AddonManager:IsInstalled(addonName)
  if not addonName or addonName == "" then
    return false
  end

  local ok, nameOrTitle = getAddOnInfo(addonName)
  return ok and nameOrTitle ~= nil
end

function AddonManager:IsEnabled(addonName)
  local api = addonApi()
  local character = UnitName and UnitName("player") or nil

  if api.GetAddOnEnableState then
    local ok, state = ModeShift:SafeCall("GetAddOnEnableState", api.GetAddOnEnableState, addonName, character)
    if (not ok or state == nil) and character then
      ok, state = ModeShift:SafeCall("GetAddOnEnableState", api.GetAddOnEnableState, character, addonName)
    end
    if ok and state ~= nil then
      if Enum and Enum.AddOnEnableState then
        return state == Enum.AddOnEnableState.All or state == Enum.AddOnEnableState.Character
      end
      return state and state > 0
    end
  end

  if GetAddOnEnableState then
    local ok, state = ModeShift:SafeCall("GetAddOnEnableState", GetAddOnEnableState, character, addonName)
    if (not ok or state == nil) then
      ok, state = ModeShift:SafeCall("GetAddOnEnableState", GetAddOnEnableState, addonName, character)
    end
    if ok and state ~= nil then
      return state and state > 0
    end
  end

  return false
end

function AddonManager:SetEnabled(addonName, enabled)
  if addonName == ModeShift.addonName and not enabled then
    return false, "ModeShift no puede desactivarse a si mismo"
  end

  local api = addonApi()
  local character = UnitName and UnitName("player") or nil

  if enabled then
    if api.EnableAddOn then
      local ok, err = ModeShift:SafeCall("EnableAddOn", api.EnableAddOn, addonName, character)
      self:ClearInstalledCache()
      return ok, err
    end
    if EnableAddOn then
      local ok, err = ModeShift:SafeCall("EnableAddOn", EnableAddOn, addonName, character)
      self:ClearInstalledCache()
      return ok, err
    end
  else
    if api.DisableAddOn then
      local ok, err = ModeShift:SafeCall("DisableAddOn", api.DisableAddOn, addonName, character)
      self:ClearInstalledCache()
      return ok, err
    end
    if DisableAddOn then
      local ok, err = ModeShift:SafeCall("DisableAddOn", DisableAddOn, addonName, character)
      self:ClearInstalledCache()
      return ok, err
    end
  end

  return false, "La API de addons no esta disponible"
end

function AddonManager:ClearInstalledCache()
  self.installedCache = nil
end

local function copyAddonList(source)
  local copy = {}
  for index, addon in ipairs(source or {}) do
    copy[index] = {
      name = addon.name,
      title = addon.title,
      enabled = addon.enabled,
    }
  end
  return copy
end

function AddonManager:SetProfileAddonState(profile, addonName, shouldLoad)
  if type(profile) ~= "table" or not addonName or addonName == "" then
    return
  end

  profile.addons = ModeShift.Utils:CopyDefaults(profile.addons, { enabled = true, enable = {}, disable = {} })
  profile.addons.enabled = true
  profile.addons.enable = ModeShift.Utils:SafeArray(profile.addons.enable)
  profile.addons.disable = ModeShift.Utils:SafeArray(profile.addons.disable)

  for index = #profile.addons.enable, 1, -1 do
    if profile.addons.enable[index] == addonName then
      table.remove(profile.addons.enable, index)
    end
  end
  for index = #profile.addons.disable, 1, -1 do
    if profile.addons.disable[index] == addonName then
      table.remove(profile.addons.disable, index)
    end
  end

  if addonName == ModeShift.addonName then
    shouldLoad = true
  end

  if shouldLoad then
    table.insert(profile.addons.enable, addonName)
  else
    table.insert(profile.addons.disable, addonName)
  end
end

function AddonManager:ShouldLoadInProfile(profile, addon)
  local addonName = type(addon) == "table" and addon.name or addon
  local addons = profile and profile.addons or nil

  if addonName == ModeShift.addonName then
    return true
  end

  if not addons then
    return false
  end

  for _, name in ipairs(ModeShift.Utils:SafeArray(addons.enable)) do
    if name == addonName then
      return true
    end
  end
  return false
end

local function buildAddonState(profile)
  local state = {}
  local addons = profile and profile.addons or nil
  if not addons or not addons.enabled then
    return state
  end

  for _, addonName in ipairs(ModeShift.Utils:SafeArray(addons.enable)) do
    state[addonName] = true
  end

  return state
end

function AddonManager:ProfilesHaveDifferentAddonState(leftProfile, rightProfile)
  if not leftProfile or not rightProfile then
    return false
  end

  local leftAddons = leftProfile.addons
  local rightAddons = rightProfile.addons
  if not (leftAddons and leftAddons.enabled and rightAddons and rightAddons.enabled) then
    return false
  end

  local leftState = buildAddonState(leftProfile)
  local rightState = buildAddonState(rightProfile)

  for addonName, enabled in pairs(leftState) do
    if rightState[addonName] ~= enabled then
      return true
    end
  end

  for addonName, enabled in pairs(rightState) do
    if leftState[addonName] ~= enabled then
      return true
    end
  end

  return false
end

function AddonManager:GetInstalledAddons(forceRefresh)
  if self.installedCache and not forceRefresh then
    return copyAddonList(self.installedCache)
  end

  local addons = {}
  local api = addonApi()
  local count = 0

  if api.GetNumAddOns then
    local ok, value = ModeShift:SafeCall("GetNumAddOns", api.GetNumAddOns)
    count = ok and value or 0
  elseif GetNumAddOns then
    count = GetNumAddOns()
  end

  for index = 1, count do
    local ok, name, title = getAddOnInfo(index)
    if ok and name and name ~= ModeShift.addonName then
      table.insert(addons, { name = name, title = title or name, enabled = self:IsEnabled(name) })
    end
  end

  self.installedCache = copyAddonList(addons)
  return addons
end

function AddonManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local addons = profile and profile.addons or nil

  if not addons or not addons.enabled then
    table.insert(result.skipped, "Addons desactivados")
    return result
  end

  local changed = {}
  local installed = self:GetInstalledAddons(true)
  for _, addon in ipairs(installed) do
    local shouldLoad = self:ShouldLoadInProfile(profile, addon)
    if shouldLoad then
      if not self:IsEnabled(addon.name) then
        local ok, err = self:SetEnabled(addon.name, true)
        if ok then
          table.insert(changed, "+" .. addon.name)
        else
          result.success = false
          table.insert(result.errors, "No se pudo activar " .. addon.name .. ": " .. tostring(err))
        end
      end
    else
      if self:IsEnabled(addon.name) then
        local ok, err = self:SetEnabled(addon.name, false)
        if ok then
          table.insert(changed, "-" .. addon.name)
        else
          result.success = false
          table.insert(result.errors, "No se pudo desactivar " .. addon.name .. ": " .. tostring(err))
        end
      end
    end
  end

  if #changed > 0 then
    result.requiresReload = true
    result.message = "Addons modificados: " .. table.concat(changed, ", ")
    table.insert(result.applied, result.message)
  else
    result.message = "Addons sin cambios"
  end

  return result
end

function AddonManager:OnEvent(event)
  if event == "ADDON_LOADED" then
    self:ClearInstalledCache()
  end
end

ModeShift:RegisterModule("AddonManager", AddonManager)
