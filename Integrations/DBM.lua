local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "DBM-Core",
  displayName = "DBM",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("DBM-Core")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetProfilesFromDB(_G.DBM_AllSavedOptions)
  end,
  applyProfile = function()
    return false, "DBM no expone aun una API segura conocida para cambiar perfil"
  end,
})
