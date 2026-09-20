local addonName, addon = ...

addon.name = addonName
addon.Compat = addon.Compat or {}
addon.isForever = addon.isForever == true

local Compat = addon.Compat

function Compat.IsForever()
    return addon.isForever == true
end

function Compat.RegisterAddonMessagePrefix(prefix)
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix then
        return false
    end

    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)

    if not ok then
        return false
    end

    -- Older clients return a boolean; Forever returns an enum (0 is truthy).
    if type(result) == "boolean" then
        return result
    end

    local results = Enum and Enum.RegisterAddonMessagePrefixResult
    if results then
        return result == results.Success or result == results.DuplicatePrefix
    end

    return result == 0 or result == 1
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
