local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "Baganator",
  displayName = "Baganator",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("Baganator")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetGenericProfiles("Baganator")
  end,
  getCurrentProfile = function()
    return ModeShift.Integrations:GetGenericCurrentProfile("Baganator")
  end,
  applyProfile = function(profileName)
    return ModeShift.Integrations:ApplyGenericProfile("Baganator", profileName)
  end,
})
