local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "OmniBar",
  displayName = "OmniBar",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("OmniBar")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetProfilesFromDB(_G.OmniBarDB)
  end,
  applyProfile = function()
    return false, "OmniBar no expone aun una API segura conocida para cambiar perfil"
  end,
})
