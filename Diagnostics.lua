local ModeShift = _G.ModeShift

local Diagnostics = {}

function Diagnostics:GetClientInfo()
  local version, build, date, toc = GetBuildInfo()
  return {
    version = version,
    build = build,
    date = date,
    toc = toc,
  }
end

function Diagnostics:PrintSummary()
  local info = self:GetClientInfo()
  ModeShift:Print("diagnostico:")
  ModeShift:Print("cliente " .. tostring(info.version or "?") .. " build " .. tostring(info.build or "?") .. " interface " .. tostring(info.toc or "?"))

  local profiles = ModeShift.ProfileManager and ModeShift.ProfileManager:GetProfilesForCurrentCharacter() or {}
  ModeShift:Print("perfiles ModeShift: " .. tostring(#profiles))

  local supported = 0
  local detected = 0
  local addons = ModeShift.AddonManager and ModeShift.AddonManager:GetInstalledAddons() or {}
  for _, addon in ipairs(addons) do
    local profilesForAddon = ModeShift.AddonProfileManager and ModeShift.AddonProfileManager:GetAvailableProfiles(addon.name) or {}
    if ModeShift.Integrations and ModeShift.Integrations:Get(addon.name) then
      supported = supported + 1
    end
    if #profilesForAddon > 0 then
      detected = detected + 1
    end
  end

  ModeShift:Print("addons instalados: " .. tostring(#addons))
  ModeShift:Print("integraciones conocidas cargadas: " .. tostring(supported))
  ModeShift:Print("addons con perfiles detectados: " .. tostring(detected))
end

ModeShift:RegisterModule("Diagnostics", Diagnostics)
