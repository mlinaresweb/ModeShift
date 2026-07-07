local ModeShift = _G.ModeShift

local AddonManager = {
  installedCache = nil,
  dependencyCache = nil,
}

local function addonApi()
  return C_AddOns or {}
end

local function callVararg(fn, ...)
  local values = { pcall(fn, ...) }
  local ok = table.remove(values, 1)
  return ok, values
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

local function getAddOnMetadata(addonName, key)
  local api = addonApi()
  if api.GetAddOnMetadata then
    local ok, metadata = ModeShift:SafeCall("GetAddOnMetadata", api.GetAddOnMetadata, addonName, key)
    if ok then
      return metadata
    end
  end
  if GetAddOnMetadata then
    local ok, metadata = ModeShift:SafeCall("GetAddOnMetadata", GetAddOnMetadata, addonName, key)
    if ok then
      return metadata
    end
  end
  return nil
end

local function addUnique(list, value)
  if not value or value == "" then
    return
  end
  for _, current in ipairs(list) do
    if current == value then
      return
    end
  end
  table.insert(list, value)
end

local function addIconCandidate(list, value)
  if value == nil or value == "" then
    return
  end

  if type(value) == "number" then
    addUnique(list, value)
    return
  end

  if type(value) ~= "string" then
    return
  end

  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  if value == "" then
    return
  end

  local numeric = value:match("^%d+$")
  if numeric then
    addUnique(list, tonumber(numeric))
    return
  end

  value = value:gsub("/", "\\")
  addUnique(list, value)
end

local function splitMetadataList(value)
  local list = {}
  if type(value) ~= "string" then
    return list
  end
  for token in value:gmatch("[^,%s]+") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    addUnique(list, token)
  end
  return list
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

function AddonManager:IsLoaded(addonName)
  if not addonName or addonName == "" then
    return false
  end

  local api = addonApi()
  if api.IsAddOnLoaded then
    local ok, loaded = ModeShift:SafeCall("IsAddOnLoaded", api.IsAddOnLoaded, addonName)
    if ok then
      return loaded and true or false
    end
  end

  if IsAddOnLoaded then
    local ok, loaded = ModeShift:SafeCall("IsAddOnLoaded", IsAddOnLoaded, addonName)
    if ok then
      return loaded and true or false
    end
  end

  return false
end

function AddonManager:GetAddonIcon(addonName)
  local candidates = {}
  for _, key in ipairs({ "IconTexture", "Icon", "X-Icon", "X-IconTexture" }) do
    local icon = getAddOnMetadata(addonName, key)
    if icon and icon ~= "" then
      addIconCandidate(candidates, icon)
    end
  end

  for _, key in ipairs({ "IconAtlas", "X-IconAtlas" }) do
    local atlas = getAddOnMetadata(addonName, key)
    if atlas and atlas ~= "" then
      table.insert(candidates, { atlas = atlas })
    end
  end

  addIconCandidate(candidates, 134400)
  addIconCandidate(candidates, "Interface\\Icons\\INV_Misc_QuestionMark")
  addIconCandidate(candidates, "Interface\\Icons\\INV_Misc_QuestionMark.blp")
  return candidates
end

function AddonManager:IsLoadOnDemand(addonName)
  local api = addonApi()
  local value

  if api.GetAddOnMetadata then
    local ok, metadata = ModeShift:SafeCall("GetAddOnMetadata", api.GetAddOnMetadata, addonName, "LoadOnDemand")
    if ok then
      value = metadata
    end
  elseif GetAddOnMetadata then
    local ok, metadata = ModeShift:SafeCall("GetAddOnMetadata", GetAddOnMetadata, addonName, "LoadOnDemand")
    if ok then
      value = metadata
    end
  end

  value = value and tostring(value):lower() or nil
  return value == "1" or value == "true"
end

function AddonManager:GetDependencies(addonName)
  local dependencies = {}
  if not addonName or addonName == "" then
    return dependencies
  end

  self.dependencyCache = self.dependencyCache or {}
  if self.dependencyCache[addonName] then
    local cached = {}
    for index, dependency in ipairs(self.dependencyCache[addonName]) do
      cached[index] = dependency
    end
    return cached
  end

  local api = addonApi()
  if api.GetAddOnDependencies then
    local ok, values = callVararg(api.GetAddOnDependencies, addonName)
    if ok then
      for _, value in ipairs(values) do
        if type(value) == "table" then
          for _, dependency in ipairs(value) do
            if dependency ~= addonName and self:IsInstalled(dependency) then
              addUnique(dependencies, dependency)
            end
          end
        elseif type(value) == "string" and value ~= addonName and self:IsInstalled(value) then
          addUnique(dependencies, value)
        end
      end
    end
  elseif GetAddOnDependencies then
    local ok, values = callVararg(GetAddOnDependencies, addonName)
    if ok then
      for _, value in ipairs(values) do
        if type(value) == "string" and value ~= addonName and self:IsInstalled(value) then
          addUnique(dependencies, value)
        end
      end
    end
  end

  for _, key in ipairs({ "Dependencies", "RequiredDeps", "RequiredDep" }) do
    for _, dependency in ipairs(splitMetadataList(getAddOnMetadata(addonName, key))) do
      if dependency ~= addonName and self:IsInstalled(dependency) then
        addUnique(dependencies, dependency)
      end
    end
  end

  self.dependencyCache[addonName] = {}
  for index, dependency in ipairs(dependencies) do
    self.dependencyCache[addonName][index] = dependency
  end

  return dependencies
end

function AddonManager:GetRequiredDependents(addonName)
  local dependents = {}
  if not addonName or addonName == "" then
    return dependents
  end

  for _, addon in ipairs(self:GetInstalledAddons()) do
    for _, dependency in ipairs(self:GetDependencies(addon.name)) do
      if dependency == addonName then
        addUnique(dependents, addon.name)
      end
    end
  end

  return dependents
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
  self.dependencyCache = nil
end

local function copyAddonList(source)
  local copy = {}
  for index, addon in ipairs(source or {}) do
    copy[index] = {
      name = addon.name,
      title = addon.title,
      icon = addon.icon,
      enabled = addon.enabled,
    }
  end
  return copy
end

function AddonManager:SetProfileAddonStateExact(profile, addonName, shouldLoad)
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

function AddonManager:SetProfileAddonState(profile, addonName, shouldLoad)
  if type(profile) ~= "table" or not addonName or addonName == "" then
    return
  end

  profile.addons = ModeShift.Utils:CopyDefaults(profile.addons, { enabled = true, enable = {}, disable = {} })
  profile.addons.enabled = true
  profile.addons.enable = ModeShift.Utils:SafeArray(profile.addons.enable)
  profile.addons.disable = ModeShift.Utils:SafeArray(profile.addons.disable)

  local visited = {}
  local function enableWithDependencies(name)
    if visited[name] then
      return
    end
    visited[name] = true
    self:SetProfileAddonStateExact(profile, name, true)
    for _, dependency in ipairs(self:GetDependencies(name)) do
      enableWithDependencies(dependency)
    end
  end

  local function disableWithDependents(name)
    if visited[name] then
      return
    end
    visited[name] = true
    self:SetProfileAddonStateExact(profile, name, false)
    for _, dependent in ipairs(self:GetRequiredDependents(name)) do
      disableWithDependents(dependent)
    end
  end

  if shouldLoad then
    enableWithDependencies(addonName)
  else
    disableWithDependents(addonName)
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

  local visited = {}
  local function enabledAddonRequires(name)
    if visited[name] then
      return false
    end
    visited[name] = true
    for _, dependency in ipairs(self:GetDependencies(name)) do
      if dependency == addonName or enabledAddonRequires(dependency) then
        return true
      end
    end
    return false
  end

  for _, name in ipairs(ModeShift.Utils:SafeArray(addons.enable)) do
    if enabledAddonRequires(name) then
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
      table.insert(addons, { name = name, title = title or name, icon = self:GetAddonIcon(name), enabled = self:IsEnabled(name) })
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
  local needsSessionReload = {}
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
      if addon.name ~= ModeShift.addonName and not self:IsLoadOnDemand(addon.name) and not self:IsLoaded(addon.name) then
        table.insert(needsSessionReload, addon.name)
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
      if addon.name ~= ModeShift.addonName and self:IsLoaded(addon.name) then
        table.insert(needsSessionReload, addon.name)
      end
    end
  end

  if #changed > 0 then
    result.requiresReload = true
    result.message = "Addons modificados: " .. table.concat(changed, ", ")
    table.insert(result.applied, result.message)
  elseif #needsSessionReload > 0 then
    result.requiresReload = true
    result.message = "Addons pendientes de cargar: " .. table.concat(needsSessionReload, ", ")
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
