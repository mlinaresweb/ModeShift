local ModeShift = _G.ModeShift

local SlashCommands = {}

local function split(input)
  local parts = {}
  for value in string.gmatch(input or "", "%S+") do
    table.insert(parts, value)
  end
  return parts
end

local function joinArgs(args, startIndex)
  local values = {}
  for index = startIndex, #args do
    table.insert(values, args[index])
  end
  return table.concat(values, " ")
end

local function removeValue(list, value)
  for index = #list, 1, -1 do
    if list[index] == value then
      table.remove(list, index)
    end
  end
end

local function addUnique(list, value)
  for _, current in ipairs(list) do
    if current == value then
      return
    end
  end
  table.insert(list, value)
end

function SlashCommands:Register()
  SLASH_MODESHIFT1 = "/modeshift"
  SLASH_MODESHIFT2 = "/ms"
  SlashCmdList.MODESHIFT = function(message)
    self:Handle(message)
  end
end

function SlashCommands:Handle(message)
  local args = split(message)
  local command = string.lower(args[1] or "config")

  if command == "config" or command == "" then
    ModeShift:OpenConfig()
  elseif command == "apply" then
    local profileId = args[2]
    if not profileId then
      ModeShift:Print("uso: /ms apply <profileId>")
      return
    end
    ModeShift.ApplyEngine:ApplyProfile(profileId, { source = "slash" })
  elseif command == "current" then
    local profileId = ModeShift.Database:GetActiveProfileId()
    local profile = profileId and ModeShift.ProfileManager:GetProfile(profileId)
    if profile then
      ModeShift:Print("perfil actual: " .. (profile.name or profile.id) .. " (" .. profile.id .. ")")
    else
      ModeShift:Print("no hay perfil activo.")
    end
  elseif command == "reload" then
    ModeShift.Database:SetRequiresReload(false)
    ReloadUI()
  elseif command == "debug" then
    local current = ModeShift.Database:GetGlobalSetting("debug")
    ModeShift.Database:SetGlobalSetting("debug", not current)
    ModeShift:Print("debug " .. (not current and "activado" or "desactivado") .. ".")
  elseif command == "create" then
    ModeShift.ProfileManager:EnsureExampleProfiles()
    ModeShift:RefreshConfig()
    ModeShift:Print("perfiles de ejemplo creados para la spec actual.")
  elseif command == "list" then
    ModeShift.ProfileManager:ListProfiles()
  elseif command == "set" then
    self:HandleSet(args)
  elseif command == "addon" then
    self:HandleAddon(args)
  elseif command == "addons" then
    self:HandleAddons()
  elseif command == "reapply" then
    ModeShift.ApplyEngine:ReapplyCurrentProfile()
  elseif command == "quick" then
    ModeShift.QuickMenu:Open(nil, { forceMenu = true })
  else
    self:Help()
  end
end

function SlashCommands:HandleSet(args)
  local field = string.lower(args[2] or "")
  local profileId = args[3]
  local value = joinArgs(args, 4)
  local profile = profileId and ModeShift.ProfileManager:GetProfile(profileId)

  if not profile or value == "" then
    ModeShift:Print("uso: /ms set equipment|talents <profileId> <nombre>")
    return
  end

  if field == "equipment" or field == "gear" then
    profile.equipment.enabled = true
    profile.equipment.setName = value
    profile.equipment.setId = nil
    ModeShift.Database:SaveProfile(profile)
    ModeShift:Print("equipo de " .. profile.id .. " = " .. value)
  elseif field == "talents" or field == "talent" then
    profile.talents.enabled = true
    profile.talents.configName = value
    profile.talents.configId = nil
    ModeShift.Database:SaveProfile(profile)
    ModeShift:Print("talentos de " .. profile.id .. " = " .. value)
  else
    ModeShift:Print("uso: /ms set equipment|talents <profileId> <nombre>")
  end
end

function SlashCommands:HandleAddon(args)
  local profileId = args[2]
  local action = string.lower(args[3] or "")
  local addonName = args[4]
  local profile = profileId and ModeShift.ProfileManager:GetProfile(profileId)

  if not profile or not addonName or addonName == "" then
    ModeShift:Print("uso: /ms addon <profileId> enable|disable|ignore <addonName>")
    return
  end

  profile.addons.enabled = true
  profile.addons.enable = ModeShift.Utils:SafeArray(profile.addons.enable)
  profile.addons.disable = ModeShift.Utils:SafeArray(profile.addons.disable)

  if action == "enable" then
    removeValue(profile.addons.disable, addonName)
    addUnique(profile.addons.enable, addonName)
    ModeShift.Database:SaveProfile(profile)
    ModeShift:Print(addonName .. " se activara en " .. profile.id)
  elseif action == "disable" then
    removeValue(profile.addons.enable, addonName)
    addUnique(profile.addons.disable, addonName)
    ModeShift.Database:SaveProfile(profile)
    ModeShift:Print(addonName .. " se desactivara en " .. profile.id)
  elseif action == "ignore" then
    removeValue(profile.addons.enable, addonName)
    removeValue(profile.addons.disable, addonName)
    ModeShift.Database:SaveProfile(profile)
    ModeShift:Print(addonName .. " queda ignorado en " .. profile.id)
  else
    ModeShift:Print("uso: /ms addon <profileId> enable|disable|ignore <addonName>")
  end
end

function SlashCommands:HandleAddons()
  if not ModeShift.AddonManager then
    ModeShift:Print("AddonManager no esta disponible.")
    return
  end

  local addons = ModeShift.AddonManager:GetInstalledAddons()
  ModeShift:Print("addons instalados: " .. tostring(#addons))
  for index, addon in ipairs(addons) do
    if index > 20 then
      ModeShift:Print("usa el nombre del addon con /ms addon <profileId> enable|disable <addonName>")
      return
    end
    ModeShift:Print((addon.enabled and "[on] " or "[off] ") .. addon.name)
  end
end

function SlashCommands:Help()
  ModeShift:Print("comandos:")
  ModeShift:Print("/ms config - abrir configuracion")
  ModeShift:Print("/ms list - listar perfiles")
  ModeShift:Print("/ms apply <profileId> - aplicar perfil")
  ModeShift:Print("/ms current - ver perfil actual")
  ModeShift:Print("/ms create - crear perfiles de ejemplo")
  ModeShift:Print("/ms set equipment <profileId> <nombre> - asignar set")
  ModeShift:Print("/ms set talents <profileId> <nombre> - asignar loadout")
  ModeShift:Print("/ms addon <profileId> enable|disable|ignore <addonName> - configurar addon")
  ModeShift:Print("/ms addons - listar addons instalados")
  ModeShift:Print("/ms reload - recargar interfaz")
  ModeShift:Print("/ms debug - alternar debug")
end

ModeShift:RegisterModule("SlashCommands", SlashCommands)
