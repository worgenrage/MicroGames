local addonName, addon = ...

addon.name = addonName

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event ~= "ADDON_LOADED" or loadedAddonName ~= addonName then
        return
    end

    addon.UI.Create()

    SLASH_MICROGAMES1 = "/mg"
    SLASH_MICROGAMES2 = "/microgames"
    SlashCmdList.MICROGAMES = function()
        addon.UI.Toggle()
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
