local ModeShift = _G.ModeShift

ModeShift.Constants = {
  DB_VERSION = 1,

  MODE_TYPES = {
    PVE = "PVE",
    PVP = "PVP",
    RAID = "RAID",
    MYTHIC_PLUS = "MYTHIC_PLUS",
    ARENA = "ARENA",
    BLITZ = "BLITZ",
    FARMING = "FARMING",
    CUSTOM = "CUSTOM",
  },

  DEFAULT_ICON = "Interface\\AddOns\\ModeShift\\Media\\ModeShiftIcon",

  DEFAULT_SETTINGS = {
    minimapButton = true,
    minimapAngle = 225,
    addonCompartment = true,
    confirmBeforeApply = false,
    autoApplyPendingAfterCombat = true,
    showReloadPopup = true,
    debug = false,
    locale = "auto",
  },
}
