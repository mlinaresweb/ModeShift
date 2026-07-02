local ModeShift = _G.ModeShift

local QuickMenu = {}

local function addButton(root, text, callback)
  if root.CreateButton then
    root:CreateButton(text, callback)
  elseif root.CreateTitle then
    root:CreateTitle(text)
  end
end

local function profileReloadHint(profile)
  local addons = profile and profile.addons
  if addons and addons.enabled and (#ModeShift.Utils:SafeArray(addons.enable) > 0 or #ModeShift.Utils:SafeArray(addons.disable) > 0) then
    return " [reload]"
  end
  return ""
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
    if options.forceMenu then
      ModeShift:Print("no hay perfiles. Usa /ms create para crear ejemplos.")
    elseif ModeShift.ProfileManager then
      ModeShift.ProfileManager:EnsureExampleProfiles()
      ModeShift:Print("he creado perfiles de ejemplo. Usa /ms list para verlos.")
    end
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
      local currentSpecId = ModeShift:GetCurrentSpecId()
      local preferred = ModeShift.Database:GetPreferredProfileForSpec(currentSpecId)
      local grouped = ModeShift.ProfileManager:GetEnabledProfilesBySpec()
      local groupCount = 0
      for _ in pairs(grouped) do
        groupCount = groupCount + 1
      end

      if groupCount <= 1 then
        for _, profile in ipairs(profiles) do
          local prefix = profile.id == activeProfileId and "* " or ""
          local suffix = profile.id == preferred and " (recomendado)" or ""
          addButton(root, prefix .. (profile.name or profile.id) .. suffix .. profileReloadHint(profile), function()
            ModeShift.ApplyEngine:ApplyProfile(profile.id, { source = "quick-menu" })
          end)
        end
      else
        for _, group in pairs(grouped) do
          local submenu = root:CreateButton(group.specName or tostring(group.specId or "Sin spec"))
          for _, profile in ipairs(group.profiles) do
            local prefix = profile.id == activeProfileId and "* " or ""
            local suffix = profile.id == preferred and " (recomendado)" or ""
            submenu:CreateButton(prefix .. (profile.name or profile.id) .. suffix .. profileReloadHint(profile), function()
              ModeShift.ApplyEngine:ApplyProfile(profile.id, { source = "quick-menu" })
            end)
          end
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
