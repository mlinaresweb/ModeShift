local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "Bartender4",
  displayName = "Bartender4",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("Bartender4")
  end,
  getProfiles = function()
    local addon = _G.Bartender4
    if addon and addon.db then
      local profiles = ModeShift.Integrations:GetProfilesFromAceDB(addon.db)
      if #profiles > 0 then
        return profiles
      end
    end
    return ModeShift.Integrations:GetProfilesFromDB(_G.Bartender4DB)
  end,
  applyProfile = function(profileName)
    local addon = _G.Bartender4
    if addon and addon.db then
      return ModeShift.Integrations:ApplyAceDBProfile(addon.db, profileName)
    end
    return false, "Bartender4 no expone su base de perfiles"
  end,
})
