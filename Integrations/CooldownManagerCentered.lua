local ModeShift = _G.ModeShift

local optionMethods = {
  "GetDesigns",
  "GetDesignList",
  "GetLayouts",
  "GetLayoutList",
  "GetLoadouts",
  "GetProfiles",
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

  return ModeShift.Integrations:GetGenericCurrentOption("CooldownManagerCentered", true)
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

  return ModeShift.Integrations:ApplyGenericOption("CooldownManagerCentered", optionName)
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
    local api = profileApi()
    if api and type(api.GetProfiles) == "function" then
      local ok, profiles = ModeShift:SafeCall("CMC GetProfiles", api.GetProfiles, api)
      if ok and type(profiles) == "table" then
        table.sort(profiles)
        return profiles
      end
    end
    local options = getDesignsFromRuntime()
    if #options > 0 then
      return options
    end
    return ModeShift.Integrations:GetGenericOptions("CooldownManagerCentered", true)
  end,
  getCurrentOption = function()
    local api = profileApi()
    if api and type(api.GetCurrentProfile) == "function" then
      local ok, profileName = ModeShift:SafeCall("CMC GetCurrentProfile", api.GetCurrentProfile, api)
      if ok and profileName then
        return tostring(profileName)
      end
    end
    return getCurrentDesignFromRuntime()
  end,
  applyOption = function(optionName)
    local api = profileApi()
    if api and type(api.SetProfile) == "function" then
      local ok, err = ModeShift:SafeCall("CMC SetProfile", api.SetProfile, api, optionName)
      if ok then
        return true
      end
      return false, err
    end
    local applied, applyErr = applyDesignRuntime(optionName)
    if applied then
      return true
    end
    return false, applyErr or err
  end,
})
