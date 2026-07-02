local ModeShift = _G.ModeShift

local EditModeManager = {}

local function addLayout(layouts, candidate, fallbackIndex)
  if type(candidate) ~= "table" then
    return
  end

  local name = candidate.layoutName or candidate.name or candidate.displayName
  local id = candidate.layoutIndex or candidate.layoutId or candidate.id or fallbackIndex
  if name or id then
    table.insert(layouts, {
      id = id,
      name = name or tostring(id),
    })
  end
end

local function collectLayouts(layouts, value)
  if type(value) ~= "table" then
    return
  end

  if value.layouts then
    collectLayouts(layouts, value.layouts)
    return
  end

  if value.layoutName or value.name or value.displayName then
    addLayout(layouts, value)
    return
  end

  for index, candidate in pairs(value) do
    addLayout(layouts, candidate, index)
  end
end

function EditModeManager:GetLayouts()
  local layouts = {}

  if C_EditMode and C_EditMode.GetLayouts then
    local ok, result1, result2, result3 = ModeShift:SafeCall("GetLayouts", C_EditMode.GetLayouts)
    if ok then
      collectLayouts(layouts, result1)
      collectLayouts(layouts, result2)
      collectLayouts(layouts, result3)
    end
  end

  table.sort(layouts, function(a, b)
    return tostring(a.name or "") < tostring(b.name or "")
  end)

  return layouts
end

function EditModeManager:FindLayout(editMode)
  editMode = editMode or {}
  local layouts = self:GetLayouts()

  if editMode.layoutId then
    for _, layout in ipairs(layouts) do
      if layout.id == editMode.layoutId then
        return layout
      end
    end
  end

  if editMode.layoutName then
    local wanted = string.lower(editMode.layoutName)
    for _, layout in ipairs(layouts) do
      if layout.name and string.lower(layout.name) == wanted then
        return layout
      end
    end
  end

  return nil
end

function EditModeManager:Apply(profile)
  local result = ModeShift.Utils:Result(true)
  local editMode = profile and profile.editMode or nil

  if not editMode or not editMode.enabled then
    table.insert(result.skipped, "Edit Mode desactivado")
    return result
  end

  if ModeShift:IsInCombat() then
    result.success = false
    table.insert(result.warnings, "No se puede cambiar Edit Mode en combate")
    return result
  end

  if not (C_EditMode and C_EditMode.SetActiveLayout) then
    table.insert(result.warnings, "La API de Edit Mode no esta disponible")
    return result
  end

  local layout = self:FindLayout(editMode)
  if not layout then
    table.insert(result.warnings, "No encuentro el layout de Edit Mode \"" .. tostring(editMode.layoutName or editMode.layoutId or "?") .. "\"")
    return result
  end

  local ok, err = ModeShift:SafeCall("SetActiveLayout", C_EditMode.SetActiveLayout, layout.id)
  if ok then
    result.message = "Layout UI: " .. layout.name
    table.insert(result.applied, result.message)
  else
    result.success = false
    table.insert(result.errors, "No se pudo aplicar layout UI: " .. tostring(err))
  end

  return result
end

ModeShift:RegisterModule("EditModeManager", EditModeManager)
