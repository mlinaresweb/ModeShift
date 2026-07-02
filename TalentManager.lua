local ModeShift = _G.ModeShift

local TalentManager = {}

function TalentManager:GetTalentLoadouts(specId)
  local loadouts = {}
  specId = specId or ModeShift:GetCurrentSpecId()

  if C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
    local ok, configIds = ModeShift:SafeCall("GetConfigIDsBySpecID", C_ClassTalents.GetConfigIDsBySpecID, specId)
    if ok and type(configIds) == "table" then
      for _, configId in ipairs(configIds) do
        local name
        if C_Traits and C_Traits.GetConfigInfo then
          local infoOk, info = ModeShift:SafeCall("GetConfigInfo", C_Traits.GetConfigInfo, configId)
          if infoOk and type(info) == "table" then
            name = info.name
          end
        end
        table.insert(loadouts, { id = configId, name = name or tostring(configId), specId = specId })
      end
    end
  end

  return loadouts
end

function TalentManager:FindLoadout(talents, specId)
  talents = talents or {}
  local loadouts = self:GetTalentLoadouts(specId)

  if talents.configId then
    for _, loadout in ipairs(loadouts) do
      if loadout.id == talents.configId then
        return loadout
      end
    end
  end

  if talents.configName then
    local wanted = string.lower(talents.configName)
    for _, loadout in ipairs(loadouts) do
      if loadout.name and string.lower(loadout.name) == wanted then
        return loadout
      end
    end
  end

  return nil
end

function TalentManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local talents = profile and profile.talents or nil

  if not talents or not talents.enabled then
    table.insert(result.skipped, "Talentos desactivados")
    return result
  end

  if ModeShift:IsInCombat() then
    result.success = false
    table.insert(result.warnings, "No se pueden cambiar talentos en combate")
    return result
  end

  local currentSpecId = ModeShift:GetCurrentSpecId()
  if profile.specId and currentSpecId and profile.specId ~= currentSpecId then
    table.insert(result.warnings, "El loadout de talentos pertenece a otra spec")
    return result
  end

  if not (C_ClassTalents and C_ClassTalents.LoadConfig) then
    table.insert(result.warnings, "La API de loadouts de talentos no esta disponible")
    return result
  end

  local loadout = self:FindLoadout(talents, currentSpecId)
  if not loadout then
    table.insert(result.warnings, "No encuentro el loadout \"" .. tostring(talents.configName or talents.configId or "?") .. "\"")
    return result
  end

  local ok, err = ModeShift:SafeCall("LoadConfig", C_ClassTalents.LoadConfig, loadout.id, talents.autoApply ~= false)
  if ok then
    result.message = "Talentos: " .. (loadout.name or loadout.id)
    table.insert(result.applied, result.message)
  else
    result.success = false
    table.insert(result.errors, "No se pudo aplicar talentos: " .. tostring(err))
  end

  return result
end

ModeShift:RegisterModule("TalentManager", TalentManager)
