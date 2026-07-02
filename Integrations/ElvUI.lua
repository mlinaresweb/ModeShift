local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "ElvUI",
  displayName = "ElvUI",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("ElvUI")
  end,
  getProfiles = function()
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.data then
      local profiles = ModeShift.Integrations:GetProfilesFromAceDB(E.data)
      if #profiles > 0 then
        return profiles
      end
    end
    return ModeShift.Integrations:GetProfilesFromDB(_G.ElvDB)
  end,
  getCurrentProfile = function()
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.data then
      return ModeShift.Integrations:GetCurrentProfileFromAceDB(E.data)
    end
    return ModeShift.Integrations:GetCurrentProfileFromDB(_G.ElvDB)
  end,
  applyProfile = function(profileName)
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.data then
      return ModeShift.Integrations:ApplyAceDBProfile(E.data, profileName)
    end
    return false, "ElvUI no expone su base de perfiles"
  end,
})
