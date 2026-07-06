local ModeShift = _G.ModeShift

local optionMethods = {
  "GetDesigns",
  "GetDesignList",
  "GetLayouts",
  "GetLayoutList",
  "GetLoadouts",
  "GetPresets",
  "GetConfigurations",
  "GetConfigs",
  "GetOptions",
}

local currentMethods = {
  "GetCurrentDesign",
  "GetActiveDesign",
  "GetSelectedDesign",
  "GetCurrentLayout",
  "GetActiveLayout",
  "GetSelectedLayout",
  "GetCurrentPreset",
  "GetActivePreset",
  "GetSelectedPreset",
  "GetCurrentConfig",
  "GetActiveConfig",
  "GetSelectedConfig",
}

local applyMethods = {
  "SetDesign",
  "SelectDesign",
  "ApplyDesign",
  "SetLayout",
  "SelectLayout",
  "ApplyLayout",
  "SetPreset",
  "SelectPreset",
  "ApplyPreset",
  "SetConfig",
  "SelectConfig",
  "ApplyConfig",
}

local nameKeys = {
  name = true,
  text = true,
  label = true,
  title = true,
  displayName = true,
  designName = true,
  layoutName = true,
  presetName = true,
  configName = true,
}

local function addName(out, seen, value)
  if type(value) ~= "string" and type(value) ~= "number" then
    return
  end

  local name = tostring(value)
  local lower = name:lower()
  if name == "" or name:sub(1, 1) == "+" or lower == "importar" or lower:find("copiar", 1, true) or lower:find("introducir", 1, true) or lower:find("tiempos de", 1, true) or lower:find("no se", 1, true) or seen[name] then
    return
  end

  seen[name] = true
  table.insert(out, name)
end

local function frameLooksCooldownRelated(frame)
  if not frame or not frame.GetName then
    return false
  end

  local current = frame
  for _ = 1, 4 do
    if not current then
      return false
    end
    local name = current:GetName()
    if type(name) == "string" then
      local lower = name:lower()
      if lower:find("cooldown", 1, true) or lower:find("cooldownviewer", 1, true) then
        return true
      end
    end
    current = current.GetParent and current:GetParent() or nil
  end

  return false
end

local function collectVisibleFrameTexts(out, seen)
  if type(EnumerateFrames) ~= "function" then
    return
  end

  local frame = EnumerateFrames()
  local checked = 0
  while frame and checked < 5000 do
    checked = checked + 1
    if frame.IsShown and frame:IsShown() and frameLooksCooldownRelated(frame) then
      if frame.GetText then
        addName(out, seen, frame:GetText())
      end
      if frame.GetFontString then
        local fontString = frame:GetFontString()
        if fontString and fontString.GetText then
          addName(out, seen, fontString:GetText())
        end
      end
    end
    frame = EnumerateFrames(frame)
  end
end

local function frameText(frame)
  if not frame then
    return nil
  end

  if frame.GetText then
    local text = frame:GetText()
    if type(text) == "string" and text ~= "" then
      return text
    end
  end

  if frame.GetFontString then
    local fontString = frame:GetFontString()
    if fontString and fontString.GetText then
      local text = fontString:GetText()
      if type(text) == "string" and text ~= "" then
        return text
      end
    end
  end

  return nil
end

local function clickVisibleDesign(optionName)
  if type(EnumerateFrames) ~= "function" then
    return false
  end

  local frame = EnumerateFrames()
  local checked = 0
  while frame and checked < 5000 do
    checked = checked + 1
    if frame.IsShown and frame:IsShown() and frameLooksCooldownRelated(frame) and frameText(frame) == optionName then
      if frame.Click and (not frame.IsEnabled or frame:IsEnabled()) then
        frame:Click()
        return true
      end
      local parent = frame.GetParent and frame:GetParent() or nil
      if parent and parent.Click and (not parent.IsEnabled or parent:IsEnabled()) then
        parent:Click()
        return true
      end
    end
    frame = EnumerateFrames(frame)
  end

  return false
end

local function collectNames(value, out, seen, depth)
  if type(value) ~= "table" or depth > 4 or #out >= 80 then
    return
  end

  for key, entry in pairs(value) do
    if type(entry) == "string" or type(entry) == "number" then
      addName(out, seen, entry)
    elseif type(entry) == "table" then
      if type(key) == "string" and key ~= "" and (entry.spellIDs or entry.spells or entry.cooldowns or entry.categories or entry.rules) then
        addName(out, seen, key)
      end
      for nameKey in pairs(nameKeys) do
        addName(out, seen, entry[nameKey])
      end
      collectNames(entry, out, seen, depth + 1)
    elseif type(key) == "string" and type(entry) == "boolean" then
      addName(out, seen, key)
    end
  end
end

local function namespaces()
  return {
    _G.C_CooldownViewer,
    _G.C_CooldownViewerSettings,
    _G.CooldownViewerSettings,
    _G.CooldownViewerManager,
    _G.CooldownManager,
    _G.CooldownManagerCentered,
  }
end

local function profileApi()
  return _G.CooldownManagerCentered and _G.CooldownManagerCentered.ns and _G.CooldownManagerCentered.ns.ProfileAPI
end

local function refreshCooldownManager()
  local addon = _G.CooldownManagerCentered
  local ns = addon and addon.ns
  if ns and ns.API and type(ns.API.RefreshCooldownManager) == "function" then
    ModeShift:SafeCall("CMC RefreshCooldownManager", ns.API.RefreshCooldownManager, ns.API)
  end
  if ns and ns.CooldownManager and type(ns.CooldownManager.ForceRefreshAll) == "function" then
    ModeShift:SafeCall("CMC ForceRefreshAll", ns.CooldownManager.ForceRefreshAll)
  end
end

local function ensureCooldownViewerSettings()
  if _G.CooldownViewerSettings then
    return true
  end

  if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
    ModeShift:SafeCall("Load Blizzard_CooldownViewer", C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
  elseif LoadAddOn then
    ModeShift:SafeCall("Load Blizzard_CooldownViewer", LoadAddOn, "Blizzard_CooldownViewer")
  end

  return _G.CooldownViewerSettings ~= nil
end

local function cooldownLayoutManager()
  if not ensureCooldownViewerSettings() then
    return nil
  end

  if _G.CooldownViewerSettings and type(_G.CooldownViewerSettings.GetLayoutManager) == "function" then
    local ok, manager = ModeShift:SafeCall("CDM GetLayoutManager", _G.CooldownViewerSettings.GetLayoutManager, _G.CooldownViewerSettings)
    if ok and manager then
      return manager
    end
  end

  return nil
end

local function isBlizzardEditModeLayoutName(name)
  local lower = tostring(name or ""):lower()
  local asciiOnly = lower:gsub("[^%a]", "")
  return lower == "modern"
    or lower == "classic"
    or lower == "moderno"
    or lower == "clasico"
    or asciiOnly == "clsico"
end

local function cooldownLayoutName(layout)
  if not layout then
    return nil
  end

  if type(CooldownManagerLayout_GetName) == "function" then
    local ok, name = ModeShift:SafeCall("CDM Layout GetName", CooldownManagerLayout_GetName, layout)
    if ok and name and name ~= "" then
      return tostring(name)
    end
  end

  if type(layout) == "table" then
    if layout.layoutName then
      return tostring(layout.layoutName)
    end
    if layout.name then
      return tostring(layout.name)
    end
    if type(layout.GetName) == "function" then
      local ok, name = ModeShift:SafeCall("CDM layout:GetName", layout.GetName, layout)
      if ok and name and name ~= "" then
        return tostring(name)
      end
    end
  end

  return nil
end

local function cooldownLayoutID(layout)
  if not layout then
    return nil
  end

  if type(CooldownManagerLayout_GetID) == "function" then
    local ok, id = ModeShift:SafeCall("CDM Layout GetID", CooldownManagerLayout_GetID, layout)
    if ok and id then
      return id
    end
  end

  if type(layout) == "table" then
    return layout.id or layout.layoutID or layout.layoutId or layout.ID
  end

  return nil
end

local function addCooldownLayout(out, seen, layout)
  local name = cooldownLayoutName(layout)
  if not name or name == "" or isBlizzardEditModeLayoutName(name) or seen[name] then
    return
  end

  seen[name] = {
    name = name,
    id = cooldownLayoutID(layout),
    layout = layout,
  }
  table.insert(out, name)
end

local function collectCooldownLayoutsFromValue(out, seen, value, depth)
  if depth > 4 or type(value) ~= "table" then
    return
  end

  addCooldownLayout(out, seen, value)
  for _, child in pairs(value) do
    if type(child) == "table" then
      collectCooldownLayoutsFromValue(out, seen, child, depth + 1)
    end
  end
end

local function getCooldownLayoutMap()
  local manager = cooldownLayoutManager()
  local out = {}
  local seen = {}
  if not manager then
    return out, seen
  end

  local modes = { false }
  if Enum and Enum.CDMLayoutMode and Enum.CDMLayoutMode.AccessOnly then
    table.insert(modes, Enum.CDMLayoutMode.AccessOnly)
  end

  local methods = {
    "GetLayouts",
    "GetAllLayouts",
    "GetLayoutsForCurrentSpec",
    "GetCustomLayouts",
  }

  for _, methodName in ipairs(methods) do
    if type(manager[methodName]) == "function" then
      for _, mode in ipairs(modes) do
        local ok, value
        if mode == false then
          ok, value = ModeShift:SafeCall("CDM " .. methodName, manager[methodName], manager)
        else
          ok, value = ModeShift:SafeCall("CDM " .. methodName, manager[methodName], manager, mode)
        end
        if ok then
          collectCooldownLayoutsFromValue(out, seen, value, 1)
        end
      end
    end
  end

  if type(manager.GetLayout) == "function" then
    for id = 1, 120 do
      local ok, layout = ModeShift:SafeCall("CDM GetLayout", manager.GetLayout, manager, id)
      if ok and layout then
        addCooldownLayout(out, seen, layout)
      end
    end
  end

  table.sort(out)
  return out, seen
end

local function getCooldownLayouts()
  local layouts = getCooldownLayoutMap()
  return layouts
end

local function getCurrentCooldownLayout()
  local manager = cooldownLayoutManager()
  if not manager then
    return nil
  end

  local modes = { false }
  if Enum and Enum.CDMLayoutMode and Enum.CDMLayoutMode.AccessOnly then
    table.insert(modes, Enum.CDMLayoutMode.AccessOnly)
  end

  if type(manager.GetActiveLayout) == "function" then
    for _, mode in ipairs(modes) do
      local ok, layout
      if mode == false then
        ok, layout = ModeShift:SafeCall("CDM GetActiveLayout", manager.GetActiveLayout, manager)
      else
        ok, layout = ModeShift:SafeCall("CDM GetActiveLayout", manager.GetActiveLayout, manager, mode)
      end
      if ok and layout then
        local name = cooldownLayoutName(layout)
        if name and not isBlizzardEditModeLayoutName(name) then
          return name
        end
      end
    end
  end

  if type(manager.GetActiveLayoutID) == "function" and type(manager.GetLayout) == "function" then
    local ok, id = ModeShift:SafeCall("CDM GetActiveLayoutID", manager.GetActiveLayoutID, manager)
    if ok and id then
      local layoutOk, layout = ModeShift:SafeCall("CDM GetLayout active", manager.GetLayout, manager, id)
      if layoutOk and layout then
        local name = cooldownLayoutName(layout)
        if name and not isBlizzardEditModeLayoutName(name) then
          return name
        end
      end
    end
  end

  return nil
end

local function findCooldownLayoutByName(manager, optionName)
  if not manager then
    return nil
  end

  local specTag = nil
  if type(manager.GetCurrentSpecTag) == "function" then
    local ok, tag = ModeShift:SafeCall("CDM GetCurrentSpecTag", manager.GetCurrentSpecTag, manager)
    if ok then
      specTag = tag
    end
  end

  if type(manager.GetLayoutByName) == "function" then
    local ok, layout = ModeShift:SafeCall("CDM GetLayoutByName spec", manager.GetLayoutByName, manager, optionName, specTag)
    if ok and layout then
      return layout
    end
    ok, layout = ModeShift:SafeCall("CDM GetLayoutByName all", manager.GetLayoutByName, manager, optionName)
    if ok and layout then
      return layout
    end
  end

  local _, map = getCooldownLayoutMap()
  local target = tostring(optionName or ""):lower()
  for name, entry in pairs(map) do
    if tostring(name):lower() == target then
      return entry.layout, entry.id
    end
  end

  return nil
end

local function applyCooldownLayout(optionName)
  if InCombatLockdown and InCombatLockdown() then
    return false, "no se puede cambiar diseno de CDM en combate"
  end

  local manager = cooldownLayoutManager()
  if not manager then
    return false, "no encuentro CooldownViewerSettings"
  end

  local layout, layoutID = findCooldownLayoutByName(manager, optionName)
  if not layout then
    return false, "no encuentro el diseno " .. tostring(optionName)
  end
  layoutID = layoutID or cooldownLayoutID(layout)

  if type(manager.SetActiveLayout) == "function" then
    local applied, err = ModeShift:SafeCall("CDM SetActiveLayout", manager.SetActiveLayout, manager, layout)
    if not applied then
      return false, err
    end
  elseif layoutID and type(manager.SetActiveLayoutByID) == "function" then
    local applied, err = ModeShift:SafeCall("CDM SetActiveLayoutByID", manager.SetActiveLayoutByID, manager, layoutID)
    if not applied then
      return false, err
    end
  else
    return false, "CDM no permite activar este diseno"
  end

  if type(manager.SaveLayouts) == "function" then
    ModeShift:SafeCall("CDM SaveLayouts", manager.SaveLayouts, manager)
  end
  refreshCooldownManager()
  return true
end

local function callNamespaceMethod(namespace, methodName, ...)
  local ok, value = ModeShift:SafeCall("Cooldown " .. methodName, namespace[methodName], namespace, ...)
  if ok then
    return true, value
  end

  return ModeShift:SafeCall("Cooldown " .. methodName, namespace[methodName], ...)
end

local function getDesignsFromRuntime()
  local out = {}
  local seen = {}

  for _, namespace in ipairs(namespaces()) do
    if type(namespace) == "table" then
      for _, methodName in ipairs(optionMethods) do
        if type(namespace[methodName]) == "function" then
          local ok, value = callNamespaceMethod(namespace, methodName)
          if ok then
            collectNames(value, out, seen, 1)
          end
        end
      end
      collectNames(namespace.designs, out, seen, 1)
      collectNames(namespace.layouts, out, seen, 1)
      collectNames(namespace.presets, out, seen, 1)
      collectNames(namespace.configs, out, seen, 1)
    end
  end

  if _G.CooldownViewerSettings and type(_G.CooldownViewerSettings.GetCurrentDataProvider) == "function" then
    local ok, provider = ModeShift:SafeCall("Cooldown provider", _G.CooldownViewerSettings.GetCurrentDataProvider, _G.CooldownViewerSettings)
    if ok and type(provider) == "table" then
      collectNames(provider, out, seen, 1)
    end
  end

  collectVisibleFrameTexts(out, seen)

  table.sort(out)
  return out
end

local function getCurrentDesignFromRuntime()
  for _, namespace in ipairs(namespaces()) do
    if type(namespace) == "table" then
      for _, methodName in ipairs(currentMethods) do
        if type(namespace[methodName]) == "function" then
          local ok, value = callNamespaceMethod(namespace, methodName)
          if ok and (type(value) == "string" or type(value) == "number") then
            return tostring(value)
          elseif ok and type(value) == "table" then
            for nameKey in pairs(nameKeys) do
              if value[nameKey] then
                return tostring(value[nameKey])
              end
            end
          end
        end
      end
    end
  end

  return nil
end

local function applyDesignRuntime(optionName)
  for _, namespace in ipairs(namespaces()) do
    if type(namespace) == "table" then
      for _, methodName in ipairs(applyMethods) do
        if type(namespace[methodName]) == "function" then
          local ok, resultOrErr = callNamespaceMethod(namespace, methodName, optionName)
          if ok and resultOrErr ~= false then
            return true
          end
        end
      end
    end
  end

  if clickVisibleDesign(optionName) then
    return true
  end

  return false, "no encuentro el diseno " .. tostring(optionName)
end

ModeShift.Integrations:Register({
  addonName = "CooldownManagerCentered",
  displayName = "Cooldown Manager",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("CooldownManagerCentered")
  end,
  getProfiles = function()
    local api = profileApi()
    if api and type(api.GetProfiles) == "function" then
      local ok, profiles = ModeShift:SafeCall("CMC GetProfiles", api.GetProfiles, api)
      if ok and type(profiles) == "table" then
        table.sort(profiles)
        return profiles
      end
    end
    return ModeShift.Integrations:GetGenericProfiles("CooldownManagerCentered", true)
  end,
  getCurrentProfile = function()
    local api = profileApi()
    if api and type(api.GetCurrentProfile) == "function" then
      local ok, profileName = ModeShift:SafeCall("CMC GetCurrentProfile", api.GetCurrentProfile, api)
      if ok and profileName then
        return tostring(profileName)
      end
    end
    return ModeShift.Integrations:GetGenericCurrentProfile("CooldownManagerCentered", true)
  end,
  applyProfile = function(profileName)
    local api = profileApi()
    if api and type(api.SetProfile) == "function" then
      local ok, err = ModeShift:SafeCall("CMC SetProfile", api.SetProfile, api, profileName)
      if ok then
        return true
      end
      return false, err
    end
    return ModeShift.Integrations:ApplyGenericProfile("CooldownManagerCentered", profileName)
  end,
  getOptions = function()
    return getCooldownLayouts()
  end,
  getCurrentOption = function()
    return getCurrentCooldownLayout()
  end,
  applyOption = function(optionName)
    return applyCooldownLayout(optionName)
  end,
})
