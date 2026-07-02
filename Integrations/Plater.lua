local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "Plater",
  displayName = "Plater",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("Plater")
  end,
  getProfiles = function()
    local addon = _G.Plater
    if addon and addon.db then
      local profiles = ModeShift.Integrations:GetProfilesFromAceDB(addon.db)
      if #profiles > 0 then
        return profiles
      end
    end
    return ModeShift.Integrations:GetProfilesFromDB(_G.PlaterDB)
  end,
  getCurrentProfile = function()
    local addon = _G.Plater
    if addon and addon.db then
      return ModeShift.Integrations:GetCurrentProfileFromAceDB(addon.db)
    end
    return ModeShift.Integrations:GetCurrentProfileFromDB(_G.PlaterDB)
  end,
  applyProfile = function(profileName)
    local addon = _G.Plater
    if addon and addon.db then
      return ModeShift.Integrations:ApplyAceDBProfile(addon.db, profileName)
    end
    return false, "Plater no expone su base de perfiles"
  end,
})
