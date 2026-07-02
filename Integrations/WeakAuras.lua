local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "WeakAuras",
  displayName = "WeakAuras",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("WeakAuras")
  end,
  getProfiles = function()
    return {}
  end,
  applyProfile = function()
    return false, "WeakAuras no usa perfiles globales compatibles con este selector"
  end,
})
