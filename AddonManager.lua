local ModeShift = _G.ModeShift

local AddonManager = {}

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
  local api = addonApi()
  local character = UnitName and UnitName("player") or nil

  if enabled then
    if api.EnableAddOn then
      return ModeShift:SafeCall("EnableAddOn", api.EnableAddOn, addonName, character)
    end
    if EnableAddOn then
      return ModeShift:SafeCall("EnableAddOn", EnableAddOn, addonName, character)
    end
  else
    if api.DisableAddOn then
      return ModeShift:SafeCall("DisableAddOn", api.DisableAddOn, addonName, character)
    end
    if DisableAddOn then
      return ModeShift:SafeCall("DisableAddOn", DisableAddOn, addonName, character)
    end
  end

  return false, "La API de addons no esta disponible"
end

function AddonManager:GetInstalledAddons()
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
    if ok and name then
      table.insert(addons, { name = name, title = title or name, enabled = self:IsEnabled(name) })
    end
  end

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

  for _, addonName in ipairs(ModeShift.Utils:SafeArray(addons.enable)) do
    if addonName and addonName ~= "" then
      if not self:IsInstalled(addonName) then
        table.insert(result.warnings, "Addon no instalado: " .. addonName)
      elseif self:IsEnabled(addonName) then
        table.insert(result.skipped, "Addon ya activo: " .. addonName)
      else
        local ok, err = self:SetEnabled(addonName, true)
        if ok then
          table.insert(changed, "+" .. addonName)
        else
          result.success = false
          table.insert(result.errors, "No se pudo activar " .. addonName .. ": " .. tostring(err))
        end
      end
    end
  end

  for _, addonName in ipairs(ModeShift.Utils:SafeArray(addons.disable)) do
    if addonName and addonName ~= "" then
      if not self:IsInstalled(addonName) then
        table.insert(result.warnings, "Addon no instalado: " .. addonName)
      elseif not self:IsEnabled(addonName) then
        table.insert(result.skipped, "Addon ya desactivado: " .. addonName)
      else
        local ok, err = self:SetEnabled(addonName, false)
        if ok then
          table.insert(changed, "-" .. addonName)
        else
          result.success = false
          table.insert(result.errors, "No se pudo desactivar " .. addonName .. ": " .. tostring(err))
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

ModeShift:RegisterModule("AddonManager", AddonManager)
