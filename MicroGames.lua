local addonName, addon = ...

addon.name = addonName

local function PrintLoadedMessage()
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("MicroGames loaded. Type /mg or /microgames to open.")
    end
end

local eventFrame = CreateFrame("Frame")

SLASH_MICROGAMES1 = "/mg"
SLASH_MICROGAMES2 = "/microgames"
SlashCmdList.MICROGAMES = function()
    if addon.UI and addon.UI.Toggle then
        addon.UI.Toggle()
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self)
    PrintLoadedMessage()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
