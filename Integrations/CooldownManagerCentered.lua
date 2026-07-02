local ModeShift = _G.ModeShift

ModeShift.Integrations:Register({
  addonName = "CooldownManagerCentered",
  displayName = "Cooldown Manager",
  isAvailable = function()
    return ModeShift.Integrations:IsAddonLoaded("CooldownManagerCentered")
  end,
  getProfiles = function()
    return ModeShift.Integrations:GetGenericProfiles("CooldownManagerCentered", true)
  end,
  getCurrentProfile = function()
    return ModeShift.Integrations:GetGenericCurrentProfile("CooldownManagerCentered", true)
  end,
  applyProfile = function(profileName)
    return ModeShift.Integrations:ApplyGenericProfile("CooldownManagerCentered", profileName)
  end,
  getOptions = function()
    return ModeShift.Integrations:GetGenericOptions("CooldownManagerCentered", true)
  end,
  getCurrentOption = function()
    return ModeShift.Integrations:GetGenericCurrentOption("CooldownManagerCentered", true)
  end,
  applyOption = function(optionName)
    return ModeShift.Integrations:ApplyGenericOption("CooldownManagerCentered", optionName)
  end,
})
