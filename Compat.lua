local addonName, addon = ...

addon.name = addonName
addon.Compat = addon.Compat or {}
addon.isForever = addon.isForever == true

local Compat = addon.Compat

function Compat.IsForever()
    return addon.isForever == true
end

function Compat.IsSecretValue(value)
    if type(issecretvalue) ~= "function" then
        return false
    end

    local ok, isSecret = pcall(issecretvalue, value)

    return ok and isSecret == true
end

function Compat.IsChatMessagingLockedDown()
    if not C_ChatInfo or not C_ChatInfo.InChatMessagingLockdown then
        return false
    end

    local ok, lockedDown = pcall(C_ChatInfo.InChatMessagingLockdown)

    return ok and lockedDown == true
end
