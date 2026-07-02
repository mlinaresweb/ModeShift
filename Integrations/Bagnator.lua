local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "Bagnator",
  displayName = "Bagnator",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("Bagnator")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetGenericProfiles("Bagnator")
  end,
  getCurrentProfile = function()
    return ModeShift.Integrations:GetGenericCurrentProfile("Bagnator")
  end,
  applyProfile = function(profileName)
    return ModeShift.Integrations:ApplyGenericProfile("Bagnator", profileName)
  end,
})
