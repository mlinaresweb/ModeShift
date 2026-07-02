local ModeShift = _G.ModeShift

local Utils = {}

function Utils:CopyDefaults(target, defaults)
  if type(target) ~= "table" then
    target = {}
  end

  if type(defaults) ~= "table" then
    return target
  end

  for key, value in pairs(defaults) do
    if type(value) == "table" then
      target[key] = self:CopyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end

  return target
end

function Utils:ShallowCopy(source)
  local copy = {}
  if type(source) ~= "table" then
    return copy
  end

  for key, value in pairs(source) do
    copy[key] = value
  end

  return copy
end

function Utils:DeepCopy(source)
  if type(source) ~= "table" then
    return source
  end

  local copy = {}
  for key, value in pairs(source) do
    copy[key] = self:DeepCopy(value)
  end

  return copy
end

function Utils:Trim(value)
  if type(value) ~= "string" then
    return ""
  end

  return value:match("^%s*(.-)%s*$")
end

function Utils:Slug(value)
  value = tostring(value or "profile"):lower()
  value = value:gsub("[^%w]+", "_")
  value = value:gsub("^_+", ""):gsub("_+$", "")
  if value == "" then
    value = "profile"
  end
  return value
end

function Utils:MakeProfileId(name, specId, modeType)
  local base = table.concat({
    "profile",
    specId or "nospec",
    modeType or "custom",
    self:Slug(name),
  }, "_")

  return base
end

function Utils:SafeArray(value)
  if type(value) == "table" then
    return value
  end

  return {}
end

function Utils:Result(success, message)
  return {
    success = success ~= false,
    requiresReload = false,
    message = message,
    warnings = {},
    errors = {},
    skipped = {},
    applied = {},
  }
end

function Utils:AddMessage(list, value)
  if type(list) == "table" and value then
    table.insert(list, tostring(value))
  end
end

function Utils:GetAddOnApi()
  return C_AddOns or {}
end

ModeShift:RegisterModule("Utils", Utils)
