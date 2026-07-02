local ModeShift = _G.ModeShift

local AddonProfileManager = {}

function AddonProfileManager:GetSupportedIntegrations()
  if not ModeShift.Integrations then
    return {}
  end
  return ModeShift.Integrations:GetAll()
end

function AddonProfileManager:GetAvailableProfiles(addonName)
  local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
  if not integration or type(integration.getProfiles) ~= "function" then
    return {}
  end

  local ok, profiles = ModeShift:SafeCall("getProfiles", integration.getProfiles)
  if ok and type(profiles) == "table" then
    table.sort(profiles)
    return profiles
  end

  return {}
end

function AddonProfileManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local addonProfiles = profile and profile.addonProfiles or nil

  if not addonProfiles or not addonProfiles.enabled then
    table.insert(result.skipped, "Perfiles internos de addons desactivados")
    return result
  end

  for addonName, entry in pairs(addonProfiles.entries or {}) do
    if type(entry) == "table" and entry.enabled and entry.profileName and entry.profileName ~= "" then
      local integration = ModeShift.Integrations and ModeShift.Integrations:Get(addonName)
      if not integration then
        table.insert(result.warnings, "Sin integracion para " .. tostring(addonName))
      elseif integration.isAvailable and not integration.isAvailable() then
        table.insert(result.warnings, tostring(integration.displayName or addonName) .. " no esta cargado")
      elseif type(integration.applyProfile) ~= "function" then
        table.insert(result.warnings, tostring(integration.displayName or addonName) .. " no puede cambiar perfil aun")
      else
        local ok, appliedOrErr, extraErr = ModeShift:SafeCall("applyProfile", integration.applyProfile, entry.profileName)
        if ok and appliedOrErr ~= false then
          local name = integration.displayName or addonName
          table.insert(result.applied, "Perfil " .. name .. ": " .. entry.profileName)
        else
          result.success = false
          table.insert(result.warnings, tostring(integration.displayName or addonName) .. ": " .. tostring(extraErr or appliedOrErr or "no aplicado"))
        end
      end
    end
  end

  return result
end

ModeShift:RegisterModule("AddonProfileManager", AddonProfileManager)
