local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "BigWigs",
  displayName = "BigWigs",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("BigWigs")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetProfilesFromDB(_G.BigWigs3DB)
  end,
  applyProfile = function()
    return false, "BigWigs no expone aun una API segura conocida para cambiar perfil"
  end,
})
