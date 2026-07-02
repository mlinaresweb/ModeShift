local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "OmniCD",
  displayName = "OmniCD",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("OmniCD")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetProfilesFromDB(_G.OmniCDDB)
  end,
  applyProfile = function()
    return false, "OmniCD no expone aun una API segura conocida para cambiar perfil"
  end,
})
