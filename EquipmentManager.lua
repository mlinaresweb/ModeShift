local ModeShift = _G.ModeShift

local EquipmentManager = {}

function EquipmentManager:GetEquipmentSets()
  local sets = {}

  if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetInfo then
    local ok, ids = ModeShift:SafeCall("GetEquipmentSetIDs", C_EquipmentSet.GetEquipmentSetIDs)
    if ok and type(ids) == "table" then
      for _, setId in ipairs(ids) do
        local infoOk, name, icon, setID = ModeShift:SafeCall("GetEquipmentSetInfo", C_EquipmentSet.GetEquipmentSetInfo, setId)
        if infoOk and name then
          table.insert(sets, { id = setID or setId, name = name, icon = icon })
        end
      end
    end
  elseif GetNumEquipmentSets and GetEquipmentSetInfo then
    for index = 1, GetNumEquipmentSets() do
      local ok, name, icon = ModeShift:SafeCall("GetEquipmentSetInfo", GetEquipmentSetInfo, index)
      if ok and name then
        table.insert(sets, { id = index, name = name, icon = icon })
      end
    end
  end

  return sets
end

function EquipmentManager:FindSet(equipment)
  equipment = equipment or {}
  local sets = self:GetEquipmentSets()

  if equipment.setId then
    for _, set in ipairs(sets) do
      if set.id == equipment.setId then
        return set
      end
    end
  end

  if equipment.setName then
    local wanted = string.lower(equipment.setName)
    for _, set in ipairs(sets) do
      if set.name and string.lower(set.name) == wanted then
        return set
      end
    end
  end

  return nil
end

function EquipmentManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local equipment = profile and profile.equipment or nil

  if not equipment or not equipment.enabled then
    table.insert(result.skipped, "Equipo desactivado")
    return result
  end

  if ModeShift:IsInCombat() then
    result.success = false
    table.insert(result.warnings, "No se puede cambiar equipo en combate")
    return result
  end

  local set = self:FindSet(equipment)
  if not set then
    table.insert(result.warnings, "No encuentro el set de equipo \"" .. tostring(equipment.setName or equipment.setId or "?") .. "\"")
    return result
  end

  local ok, err
  if C_EquipmentSet and C_EquipmentSet.UseEquipmentSet then
    ok, err = ModeShift:SafeCall("UseEquipmentSet", C_EquipmentSet.UseEquipmentSet, set.id)
  elseif UseEquipmentSet then
    ok, err = ModeShift:SafeCall("UseEquipmentSet", UseEquipmentSet, set.name)
  else
    table.insert(result.warnings, "La API de sets de equipo no esta disponible")
    return result
  end

  if ok then
    result.message = "Equipo: " .. set.name
    table.insert(result.applied, result.message)
  else
    result.success = false
    table.insert(result.errors, "No se pudo aplicar equipo: " .. tostring(err))
  end

  return result
end

ModeShift:RegisterModule("EquipmentManager", EquipmentManager)
