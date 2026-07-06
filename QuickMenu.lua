local ModeShift = _G.ModeShift

local QuickMenu = {}

local function addButton(root, text, callback)
  if root.CreateButton then
    root:CreateButton(text, callback)
  elseif root.CreateTitle then
    root:CreateTitle(text)
  end
end

local function addTitle(root, text)
  if root.CreateTitle then
    root:CreateTitle(text)
  elseif root.CreateButton then
    root:CreateButton(text, function() end)
  end
end

local function selectedProfileText(profile)
  return "|cffff4a35" .. tostring(profile.name or profile.id or "Perfil") .. " (actual)|r"
end

local TYPE_ORDER = {
  PVP = 10,
  ARENA = 20,
  BLITZ = 30,
  PVE = 40,
  MYTHIC_PLUS = 50,
  RAID = 60,
  FARMING = 70,
  CUSTOM = 100,
}

local TYPE_LABELS = {
  MYTHIC_PLUS = "M+",
  CUSTOM = "Custom",
}

local function modeTypeLabel(modeType)
  modeType = modeType or "CUSTOM"
  return TYPE_LABELS[modeType] or modeType
end

local function sortProfiles(left, right)
  local leftOrder = left.order or 0
  local rightOrder = right.order or 0
  if leftOrder == rightOrder then
    return tostring(left.name or left.id) < tostring(right.name or right.id)
  end
  return leftOrder < rightOrder
end

local function sortTypeGroups(left, right)
  local leftOrder = TYPE_ORDER[left.modeType] or 999
  local rightOrder = TYPE_ORDER[right.modeType] or 999
  if leftOrder == rightOrder then
    return tostring(left.modeType) < tostring(right.modeType)
  end
  return leftOrder < rightOrder
end

local function buildTypeGroups(profiles)
  local map = {}
  local groups = {}

  for _, profile in ipairs(profiles or {}) do
    local modeType = profile.modeType or "CUSTOM"
    local group = map[modeType]
    if not group then
      group = { modeType = modeType, profiles = {} }
      map[modeType] = group
      table.insert(groups, group)
    end
    table.insert(group.profiles, profile)
  end

  table.sort(groups, sortTypeGroups)
  for _, group in ipairs(groups) do
    table.sort(group.profiles, sortProfiles)
  end

  return groups
end

local function addProfileButton(root, profile, activeProfileId)
  local profileValue = profile
  local name = profile.id == activeProfileId and selectedProfileText(profile) or (profile.name or profile.id)
  addButton(root, name, function()
    ModeShift.ApplyEngine:ApplyProfile(profileValue.id, { source = "quick-menu" })
  end)
end

local function addTypedProfileGroups(root, profiles, activeProfileId)
  local typeGroups = buildTypeGroups(profiles)

  for index, typeGroup in ipairs(typeGroups) do
    if index > 1 and root.CreateDivider then
      root:CreateDivider()
    end
    addTitle(root, modeTypeLabel(typeGroup.modeType))
    for _, profile in ipairs(typeGroup.profiles) do
      addProfileButton(root, profile, activeProfileId)
    end
  end
end

function QuickMenu:GetProfiles()
  if not ModeShift.ProfileManager then
    return {}
  end
  return ModeShift.ProfileManager:GetProfilesForCurrentCharacter()
end

function QuickMenu:GetToggleProfile(profiles)
  if #profiles ~= 2 then
    return nil
  end

  local activeProfileId = ModeShift.Database:GetActiveProfileId()
  if profiles[1].id == activeProfileId then
    return profiles[2]
  end
  return profiles[1]
end

function QuickMenu:Open(anchor, options)
  options = options or {}
  local profiles = self:GetProfiles()

  if #profiles == 0 then
    ModeShift:Print("no hay perfiles. Abre la configuracion y pulsa Nuevo, o usa /ms create si quieres ejemplos.")
    return
  end

  if not options.forceMenu then
    if #profiles == 1 then
      ModeShift.ApplyEngine:ApplyProfile(profiles[1].id, { source = "quick" })
      return
    end

    local toggleProfile = self:GetToggleProfile(profiles)
    if toggleProfile then
      ModeShift.ApplyEngine:ApplyProfile(toggleProfile.id, { source = "quick-toggle" })
      return
    end
  end

  if MenuUtil and MenuUtil.CreateContextMenu and anchor then
    MenuUtil.CreateContextMenu(anchor, function(_, root)
      local activeProfileId = ModeShift.Database:GetActiveProfileId()
      local grouped = ModeShift.ProfileManager:GetEnabledProfilesBySpec()
      local groupCount = 0
      for _ in pairs(grouped) do
        groupCount = groupCount + 1
      end

      if groupCount <= 1 then
        addTypedProfileGroups(root, profiles, activeProfileId)
      else
        local specGroups = {}
        for _, group in pairs(grouped) do
          table.insert(specGroups, group)
        end
        table.sort(specGroups, function(left, right)
          return tostring(left.specName or left.specId or "") < tostring(right.specName or right.specId or "")
        end)

        for _, group in ipairs(specGroups) do
          local submenu = root:CreateButton(group.specName or tostring(group.specId or "Sin spec"))
          addTypedProfileGroups(submenu, group.profiles, activeProfileId)
        end
      end

      if root.CreateDivider then
        root:CreateDivider()
      end
      addButton(root, "Reaplicar perfil actual", function()
        ModeShift.ApplyEngine:ReapplyCurrentProfile()
      end)
      addButton(root, "Abrir configuracion", function()
        ModeShift:OpenConfig()
      end)
      if ModeShift.Database:GetPendingProfileId() then
        addButton(root, "Aplicar perfil pendiente", function()
          local pending = ModeShift.Database:GetPendingProfileId()
          ModeShift.Database:SetPendingProfileId(nil)
          ModeShift.ApplyEngine:ApplyProfile(pending, { fromPending = true })
        end)
      end
      if ModeShift.Database:GetRequiresReload() then
        addButton(root, "Recargar interfaz", function()
          ModeShift.Database:SetRequiresReload(false)
          ReloadUI()
        end)
      end
    end)
    return
  end

  ModeShift:Print("menu rapido:")
  for _, profile in ipairs(profiles) do
    ModeShift:Print("/ms apply " .. profile.id .. " - " .. (profile.name or profile.id))
  end
end

ModeShift:RegisterModule("QuickMenu", QuickMenu)
