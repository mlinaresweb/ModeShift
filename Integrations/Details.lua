local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "Details",
  displayName = "Details!",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("Details")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetProfilesFromDB(_G.DetailsDataStorage)
  end,
  applyProfile = function()
    return false, "Details no se aplica aun de forma segura desde ModeShift"
  end,
})
