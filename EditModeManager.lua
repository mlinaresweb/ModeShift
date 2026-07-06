local ModeShift = _G.ModeShift

local EditModeManager = {}

local function getLayoutInfo()
  if not (C_EditMode and C_EditMode.GetLayouts) then
    return nil
  end

  local ok, layoutInfo = ModeShift:SafeCall("GetLayouts", C_EditMode.GetLayouts)
  if ok and type(layoutInfo) == "table" then
    return layoutInfo
  end

  return nil
end

local function getLayoutName(candidate)
  if type(candidate) ~= "table" then
    return nil
  end

  return candidate.layoutName or candidate.name or candidate.displayName
end

local function namesEqual(left, right)
  if not left or not right then
    return false
  end

  return tostring(left):lower() == tostring(right):lower()
end

local function getBaseLayoutName(apiIndex)
  if apiIndex == 1 then
    return _G.LAYOUT_STYLE_MODERN or "Modern"
  elseif apiIndex == 2 then
    return _G.LAYOUT_STYLE_CLASSIC or "Classic"
  end

  return nil
end

local function addLayout(layouts, candidate, apiIndex, customIndex, activeIndex)
  local name = getLayoutName(candidate)
  local id = apiIndex
  if name or id then
    table.insert(layouts, {
      id = id,
      name = name or tostring(id),
      customIndex = customIndex,
      active = (activeIndex ~= nil and id == activeIndex) or (type(candidate) == "table" and (candidate.active or candidate.isActive or candidate.isCurrent or candidate.selected)),
      layout = candidate,
    })
  end
end

local function addBaseLayouts(layouts, activeIndex)
  addLayout(layouts, { layoutName = getBaseLayoutName(1) }, 1, nil, activeIndex)
  addLayout(layouts, { layoutName = getBaseLayoutName(2) }, 2, nil, activeIndex)
end

local function getCustomApiIndex(candidate, customIndex)
  if type(candidate) == "table" then
    local candidateIndex = candidate.layoutIndex or candidate.layoutId or candidate.id
    if type(candidateIndex) == "number" and candidateIndex >= 3 then
      return candidateIndex
    end
  end

  return customIndex + 2
end

local function collectCustomLayouts(layouts, value, activeIndex)
  if type(value) ~= "table" then
    return
  end

  if value.layouts then
    collectCustomLayouts(layouts, value.layouts, value.activeLayout or activeIndex)
    return
  end

  if getLayoutName(value) then
    local apiIndex = value.layoutIndex or value.layoutId or value.id
    addLayout(layouts, value, apiIndex, nil, activeIndex)
    return
  end

  for customIndex, candidate in ipairs(value) do
    addLayout(layouts, candidate, getCustomApiIndex(candidate, customIndex), customIndex, activeIndex)
  end
end

function EditModeManager:GetLayouts()
  local layouts = {}

  local layoutInfo = getLayoutInfo()
  if layoutInfo then
    addBaseLayouts(layouts, layoutInfo.activeLayout)
    collectCustomLayouts(layouts, layoutInfo.layouts or layoutInfo, layoutInfo.activeLayout)
  end

  table.sort(layouts, function(a, b)
    if a.id and b.id and a.id <= 2 and b.id > 2 then
      return true
    elseif a.id and b.id and a.id > 2 and b.id <= 2 then
      return false
    end

    return tostring(a.name or "") < tostring(b.name or "")
  end)

  return layouts
end

function EditModeManager:FindLayout(editMode)
  editMode = editMode or {}
  local layouts = self:GetLayouts()

  if editMode.layoutName then
    local wanted = string.lower(editMode.layoutName)
    for _, layout in ipairs(layouts) do
      if layout.name and string.lower(layout.name) == wanted then
        return layout
      end
    end
  end

  if editMode.layoutId then
    for _, layout in ipairs(layouts) do
      if tostring(layout.id) == tostring(editMode.layoutId) then
        return layout
      end
    end
  end

  return nil
end

function EditModeManager:GetCurrentLayout()
  local layoutInfo = getLayoutInfo()
  if layoutInfo and layoutInfo.activeLayout then
    local activeIndex = layoutInfo.activeLayout
    local activeLayout = nil
    local name = getBaseLayoutName(activeIndex)

    if not name and type(layoutInfo.layouts) == "table" then
      local customIndex = activeIndex - 2
      activeLayout = customIndex > 0 and layoutInfo.layouts[customIndex] or nil
      name = getLayoutName(activeLayout)
    end

    if name or activeIndex then
      return {
        id = activeIndex,
        name = name or tostring(activeIndex),
        customIndex = activeIndex > 2 and activeIndex - 2 or nil,
        active = true,
        layout = activeLayout,
      }
    end
  end

  local candidates = {}
  if C_EditMode then
    local methods = {
      "GetActiveLayout",
      "GetActiveLayoutInfo",
      "GetCurrentLayout",
      "GetCurrentLayoutInfo",
      "GetSelectedLayout",
      "GetSelectedLayoutInfo",
    }
    for _, methodName in ipairs(methods) do
      if type(C_EditMode[methodName]) == "function" then
        local ok, result1, result2 = ModeShift:SafeCall(methodName, C_EditMode[methodName])
        if ok then
          table.insert(candidates, result1)
          table.insert(candidates, result2)
        end
      end
    end
  end

  local layouts = self:GetLayouts()
  for _, candidate in ipairs(candidates) do
    if type(candidate) == "table" then
      local layout = self:FindLayout({
        layoutId = candidate.layoutIndex or candidate.layoutId or candidate.id,
        layoutName = candidate.layoutName or candidate.name or candidate.displayName,
      })
      if layout then
        return layout
      end
    elseif type(candidate) == "number" then
      for _, layout in ipairs(layouts) do
        if layout.id == candidate then
          return layout
        end
      end
    elseif type(candidate) == "string" then
      local wanted = candidate:lower()
      for _, layout in ipairs(layouts) do
        if layout.name and layout.name:lower() == wanted then
          return layout
        end
      end
    end
  end

  for _, layout in ipairs(layouts) do
    if layout.active then
      return layout
    end
  end

  return nil
end

function EditModeManager:ApplyLayoutByName(layoutName)
  if ModeShift:IsInCombat() then
    return false, "No se puede cambiar Edit Mode en combate"
  end

  if not (C_EditMode and C_EditMode.SetActiveLayout) then
    return false, "La API de Edit Mode no esta disponible"
  end

  local layout = self:FindLayout({ layoutName = layoutName })
  if not layout then
    return false, "No encuentro el layout " .. tostring(layoutName)
  end

  return self:SetActiveLayout(layout)
end

function EditModeManager:SetActiveLayout(layout)
  if not layout or not layout.id then
    return false, "Layout sin indice valido"
  end

  local ok, err = ModeShift:SafeCall("SetActiveLayout", C_EditMode.SetActiveLayout, layout.id)
  if not ok then
    return false, err
  end

  local current = self:GetCurrentLayout()
  if current and layout.name and not namesEqual(current.name, layout.name) then
    return false, "Blizzard dejo activo \"" .. tostring(current.name) .. "\" al intentar activar \"" .. tostring(layout.name) .. "\""
  end

  return true
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

  local ok, err = self:SetActiveLayout(layout)
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
