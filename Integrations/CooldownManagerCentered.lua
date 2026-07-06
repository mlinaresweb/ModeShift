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

local function cdmNamespace()
  return _G.CooldownManagerCentered and _G.CooldownManagerCentered.ns
end

local function cdmProfile()
  local ns = cdmNamespace()
  return ns and ns.db and ns.db.profile
end

local refreshCooldownManager

local function deepCopy(value)
  return ModeShift.Utils and ModeShift.Utils:DeepCopy(value) or value
end

local function startsWith(value, prefix)
  return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local rootStateKeys = {
  _tracker_filled_with_defaults = true,
  cooldownStyleSettings = true,
  tracker = true,
  tracker_count = true,
  tracker_enabled = true,
}

local rootStatePrefixes = {
  "cooldownManager_",
  "trinketRacialTracker_",
}

local function isCdmRootStateKey(key)
  if rootStateKeys[key] then
    return true
  end

  for _, prefix in ipairs(rootStatePrefixes) do
    if startsWith(key, prefix) then
      return true
    end
  end

  return false
end

local trackerConfigKeys = {
  point = true,
  x = true,
  y = true,
  scale = true,
  alpha = true,
  strata = true,
  iconSize = true,
  iconPadding = true,
  orientation = true,
  showGCD = true,
  rangeIndicator = true,
  requireResource = true,
  showStacks = true,
  anchoredToTracker1 = true,
  anchoredToTracker1Spacing = true,
  lockHorizontal = true,
}

local function copyTrackerConfig(source)
  local copy = {}
  if type(source) ~= "table" then
    return copy
  end

  for key in pairs(trackerConfigKeys) do
    local value = source[key]
    if type(value) ~= "table" and value ~= nil then
      copy[key] = value
    end
  end

  return copy
end

local trackerAnchorByOrientation = {
  ["Horizontal Right"] = "LEFT",
  ["Horizontal Center"] = "CENTER",
  ["Horizontal Left"] = "RIGHT",
  ["Vertical Down"] = "TOP",
  ["Vertical Up"] = "BOTTOM",
}

local trackerRelativeFactors = {
  LEFT = { x = 0, y = -0.5 },
  RIGHT = { x = -1, y = -0.5 },
  TOP = { x = -0.5, y = -1 },
  BOTTOM = { x = -0.5, y = 0 },
  CENTER = { x = -0.5, y = -0.5 },
}

local function syncTrackerConfigFromFrame(db, index)
  if type(db) ~= "table" then
    return
  end

  local editMode = db.editMode
  if type(editMode) ~= "table" then
    return
  end

  local key = "tracker" .. index
  local config = editMode[key]
  local frame = _G["CMCTracker" .. index]
  if type(config) ~= "table" or not frame or not frame.GetCenter or not frame.GetSize then
    return
  end

  if frame.GetScale then
    local scale = frame:GetScale()
    if scale then
      config.scale = scale
    end
  end
  if frame.GetAlpha then
    local alpha = frame:GetAlpha()
    if alpha then
      config.alpha = alpha
    end
  end
  if frame.GetFrameStrata then
    local strata = frame:GetFrameStrata()
    if strata then
      config.strata = strata
    end
  end

  if config.anchoredToTracker1 then
    return
  end

  local centerX, centerY = frame:GetCenter()
  local frameWidth, frameHeight = frame:GetSize()
  if not centerX or not centerY or not frameWidth or not frameHeight or not UIParent or not UIParent.GetSize then
    return
  end

  local screenWidth, screenHeight = UIParent:GetSize()
  local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
  local uiParentScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
  local effectiveScale = frameScale / uiParentScale
  if effectiveScale and effectiveScale > 0 then
    screenWidth = screenWidth / effectiveScale
    screenHeight = screenHeight / effectiveScale
  end

  local anchorPrimary = trackerAnchorByOrientation[config.orientation or "Horizontal Right"] or "LEFT"
  local factor = trackerRelativeFactors[anchorPrimary] or trackerRelativeFactors.CENTER
  local x, y

  if anchorPrimary == "LEFT" then
    x = centerX - frameWidth / 2
    y = centerY + (screenHeight * factor.y)
  elseif anchorPrimary == "RIGHT" then
    x = centerX + frameWidth / 2 - screenWidth
    y = centerY + (screenHeight * factor.y)
  elseif anchorPrimary == "TOP" then
    x = centerX + (screenWidth * factor.x)
    y = centerY + frameHeight / 2 - screenHeight
  elseif anchorPrimary == "BOTTOM" then
    x = centerX + (screenWidth * factor.x)
    y = centerY - frameHeight / 2
  else
    x = centerX - screenWidth / 2
    y = centerY - screenHeight / 2
  end

  config.point = anchorPrimary
  config.x = x
  config.y = y
end

local function syncTrackersFromVisibleFrames(db)
  local count = tonumber(db and db.tracker_count) or 10
  if count < 1 then
    count = 10
  elseif count > 10 then
    count = 10
  end

  for index = 1, count do
    syncTrackerConfigFromFrame(db, index)
  end
end

local function getTrackerExtraState()
  local db = cdmProfile()
  if not db then
    return nil
  end

  syncTrackersFromVisibleFrames(db)

  local state = {
    version = 2,
    db = {},
    tracker_enabled = db.tracker_enabled and true or false,
    tracker_count = db.tracker_count,
    editMode = {},
  }

  for key, value in pairs(db) do
    if isCdmRootStateKey(key) then
      state.db[key] = deepCopy(value)
    end
  end

  local editMode = db.editMode or {}
  local count = tonumber(db.tracker_count) or 0
  if count < 1 then
    count = 10
  end

  if type(editMode) == "table" then
    state.editMode = deepCopy(editMode)
  end

  -- Compatibility with older captured states that only knew about trackers.
  for index = 1, count do
    local key = "tracker" .. index
    if type(editMode[key]) == "table" and type(state.editMode[key]) ~= "table" then
      state.editMode[key] = copyTrackerConfig(editMode[key])
    end
  end

  if next(state.db) == nil and next(state.editMode) == nil and not state.tracker_enabled then
    return nil
  end

  return state
end

local function refreshTrackerState(ns, db)
  if ns.TrackerDB and type(ns.TrackerDB.InitializeDB) == "function" then
    ModeShift:SafeCall("CMC TrackerDB InitializeDB", ns.TrackerDB.InitializeDB)
  end
  if ns.TrackerItemsData and type(ns.TrackerItemsData.InvalidateOwnedItemsCache) == "function" then
    ModeShift:SafeCall("CMC Tracker InvalidateOwnedItemsCache", ns.TrackerItemsData.InvalidateOwnedItemsCache, ns.TrackerItemsData)
  end
  if ns.TrackerItemViewer then
    if db.tracker_enabled and type(ns.TrackerItemViewer.Initialize) == "function" then
      ModeShift:SafeCall("CMC Tracker Initialize", ns.TrackerItemViewer.Initialize, ns.TrackerItemViewer)
    end
    if type(ns.TrackerItemViewer.EnsureTrackers) == "function" then
      ModeShift:SafeCall("CMC Tracker EnsureTrackers", ns.TrackerItemViewer.EnsureTrackers, ns.TrackerItemViewer)
    end
    if type(ns.TrackerItemViewer.ReconcileTrackerCount) == "function" then
      ModeShift:SafeCall("CMC Tracker ReconcileTrackerCount", ns.TrackerItemViewer.ReconcileTrackerCount, ns.TrackerItemViewer)
    end
    if type(ns.TrackerItemViewer.RefreshItemViewerFrames) == "function" then
      ModeShift:SafeCall("CMC Tracker RefreshItemViewerFrames", ns.TrackerItemViewer.RefreshItemViewerFrames, ns.TrackerItemViewer)
    end
    if type(ns.TrackerItemViewer.RefreshStyling) == "function" then
      ModeShift:SafeCall("CMC Tracker RefreshStyling", ns.TrackerItemViewer.RefreshStyling, ns.TrackerItemViewer)
    end
    if type(ns.TrackerItemViewer.RefreshUsabilityTints) == "function" then
      ModeShift:SafeCall("CMC Tracker RefreshUsabilityTints", ns.TrackerItemViewer.RefreshUsabilityTints, ns.TrackerItemViewer)
    end
  end
end

local function refreshViewerState(ns)
  refreshCooldownManager()

  if ns.StyledIcons and type(ns.StyledIcons.OnSettingChanged) == "function" then
    ModeShift:SafeCall("CMC StyledIcons OnSettingChanged", ns.StyledIcons.OnSettingChanged, ns.StyledIcons)
  elseif ns.StyledIcons and type(ns.StyledIcons.RefreshAll) == "function" then
    ModeShift:SafeCall("CMC StyledIcons RefreshAll", ns.StyledIcons.RefreshAll, ns.StyledIcons)
  end

  if ns.CooldownFont and type(ns.CooldownFont.RefreshAll) == "function" then
    ModeShift:SafeCall("CMC CooldownFont RefreshAll", ns.CooldownFont.RefreshAll, ns.CooldownFont)
  end
  if ns.Stacks and type(ns.Stacks.RefreshAll) == "function" then
    ModeShift:SafeCall("CMC Stacks RefreshAll", ns.Stacks.RefreshAll, ns.Stacks)
  end
  if ns.RangeCheck and type(ns.RangeCheck.RefreshAll) == "function" then
    ModeShift:SafeCall("CMC RangeCheck RefreshAll", ns.RangeCheck.RefreshAll, ns.RangeCheck)
  end
  if ns.BuffBarIconMode and type(ns.BuffBarIconMode.RefreshAll) == "function" then
    ModeShift:SafeCall("CMC BuffBarIconMode RefreshAll", ns.BuffBarIconMode.RefreshAll)
  end

  if ns.Keybinds and type(ns.Keybinds.OnSettingChanged) == "function" then
    ModeShift:SafeCall("CMC Keybinds OnSettingChanged", ns.Keybinds.OnSettingChanged, ns.Keybinds)
  end
  if ns.Assistant and type(ns.Assistant.OnSettingChanged) == "function" then
    ModeShift:SafeCall("CMC Assistant Essential", ns.Assistant.OnSettingChanged, ns.Assistant, "Essential")
    ModeShift:SafeCall("CMC Assistant Utility", ns.Assistant.OnSettingChanged, ns.Assistant, "Utility")
  end

  if C_Timer and type(C_Timer.After) == "function" then
    C_Timer.After(0.1, refreshCooldownManager)
  end
end

local function applyTrackerExtraState(state)
  if type(state) ~= "table" then
    return false, "estado de trackers invalido"
  end

  local ns = cdmNamespace()
  local db = cdmProfile()
  if not ns or not db then
    return false, "CooldownManagerCentered no esta listo"
  end

  if type(state.db) == "table" then
    for key, value in pairs(state.db) do
      if isCdmRootStateKey(key) then
        db[key] = deepCopy(value)
      end
    end
  end

  -- Older captures only had these values at the top level.
  if state.tracker_enabled ~= nil then
    db.tracker_enabled = state.tracker_enabled and true or false
  end
  if tonumber(state.tracker_count) then
    db.tracker_count = tonumber(state.tracker_count)
  end
  if type(state.tracker) == "table" then
    db.tracker = deepCopy(state.tracker)
  end
  if type(state.cooldownStyleSettings) == "table" then
    db.cooldownStyleSettings = deepCopy(state.cooldownStyleSettings)
  end

  db.editMode = db.editMode or {}
  if state.version == 2 and type(state.editMode) == "table" then
    db.editMode = deepCopy(state.editMode)
  else
    for key, config in pairs(state.editMode or {}) do
      if type(key) == "string" and key:match("^tracker%d+$") and type(config) == "table" then
        db.editMode[key] = db.editMode[key] or {}
        for configKey in pairs(trackerConfigKeys) do
          if config[configKey] ~= nil then
            db.editMode[key][configKey] = config[configKey]
          end
        end
      end
    end
  end

  refreshTrackerState(ns, db)
  refreshViewerState(ns)
  return true
end

function refreshCooldownManager()
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
  getExtraState = function()
    return getTrackerExtraState()
  end,
  applyExtraState = function(state)
    return applyTrackerExtraState(state)
  end,
})
