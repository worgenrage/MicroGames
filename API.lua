local addonName, addon = ...

addon.name = addonName
addon.API = addon.API or {}

local API = addon.API

local SESSION_MODE_SINGLE = "single"
local SESSION_MODE_MULTI_COORDINATOR = "multi_coordinator"
local SESSION_MODE_MULTI_ASSISTANT = "multi_assistant"
local numbersByName = {}
local namesByNumber = {}
local assignedCount = 0
local assignmentActive = false
local currentRound = 0
local pendingRollRound = nil
local pendingRollMax = nil
local lastWinnerRound = nil
local lastWinnerNumber = nil
local lastWinnerName = nil
local lastInvalidRollRound = nil
local lastInvalidRollNumber = nil
local lastInvalidRollName = nil
local lastInvalidRollReason = nil
local IsSnapshotPlayerOnline
local NamesMatch
local BuildNumberMessage
local SendWhisper
local SendMultiRaidWhisper
local SendRaidMessage
local SetLastWinner
local SetLastInvalidRoll
local RecordMultiRaidRollResult
local UpdateMultiRaidWinnerVerification
local EnsureMultiRaidActiveHistorySession
local RecordMultiRaidSessionRound
local QueueNumberWhisper
local QueueMultiRaidWhisper
local HandleMultiRaidRollResult
local StartChatQueueTicker
local StartAddonQueueTicker
local ResumePausedSendQueues
local defaultRewardTemplates = {
    "10 GOLD!",
    "20 GOLD!",
    "KROLL BLADE BOSS"
}
local eventFrame = CreateFrame("Frame")
local ADDON_MESSAGE_PREFIX = "MicroGames"
local MONITORING_PAYLOAD_LIMIT = 255
local MONITORING_LOG_LIMIT = 8
local MONITORING_LIVE_INTERVAL = 1
local MONITORING_REWARD_LIMIT = 4
local MONITORING_REWARD_TEXT_LIMIT = 16
local REWARD_TEMPLATE_TEXT_LIMIT = 80
local MULTI_RAID_LOG_LIMIT = 8
local MULTI_RAID_MAX_ASSISTANTS = 4
local CHAT_SEND_INTERVAL = 1.25
local ADDON_SEND_INTERVAL = 1
local monitoringLog = {}
local monitoringLastSnapshot = nil
local monitoringObservedSender = nil
local monitoringBroadcastEnabled = false
local monitoringBroadcastTicker = nil
local monitoringPrefixRegistered = false
local chatSendQueue = {
    items = {},
    total = 0,
    sent = 0,
    failed = 0,
    active = false,
    paused = false,
    pauseReason = nil,
    label = nil,
    ticker = nil
}
local addonSendQueue = {
    items = {},
    total = 0,
    sent = 0,
    failed = 0,
    active = false,
    paused = false,
    pauseReason = nil,
    label = nil,
    ticker = nil
}
local gmMoveState = {
    status = "required",
    message = "Move GM to last spot before recording raid.",
    targetGroup = nil,
    targetName = nil,
    requestedAt = nil,
    verifiedAt = nil
}

local function EnsureSettings()
    if type(MicroGamesDB) ~= "table" then
        MicroGamesDB = {}
    end

    if type(MicroGamesDB.numberWhisperText) ~= "string" or MicroGamesDB.numberWhisperText == "" then
        MicroGamesDB.numberWhisperText = "Your MG number is: XX"
    end

    if type(MicroGamesDB.roundRollDelay) ~= "number" or MicroGamesDB.roundRollDelay < 0 then
        MicroGamesDB.roundRollDelay = 2
    end

    if type(MicroGamesDB.rollCountdownSoundEnabled) ~= "boolean" then
        MicroGamesDB.rollCountdownSoundEnabled = false
    end

    if MicroGamesDB.sessionMode ~= SESSION_MODE_MULTI_COORDINATOR
        and MicroGamesDB.sessionMode ~= SESSION_MODE_MULTI_ASSISTANT
    then
        MicroGamesDB.sessionMode = SESSION_MODE_SINGLE
    end

    return MicroGamesDB
end

local function CopyDefaultRewardTemplates()
    local templates = {}

    for index = 1, #defaultRewardTemplates do
        templates[index] = defaultRewardTemplates[index]
    end

    return templates
end

local function EnsureRewardTemplates()
    local settings = EnsureSettings()

    if type(settings.rewardTemplates) ~= "table" or #settings.rewardTemplates == 0 then
        settings.rewardTemplates = CopyDefaultRewardTemplates()
    end

    return settings.rewardTemplates
end

local function EnsureHistory()
    local settings = EnsureSettings()

    if type(settings.history) ~= "table" then
        settings.history = {}
    end

    return settings.history
end

local function EnsureMultiRaidState()
    local settings = EnsureSettings()

    if type(settings.multiRaid) ~= "table" then
        settings.multiRaid = {}
    end

    if type(settings.multiRaid.assistants) ~= "table" then
        settings.multiRaid.assistants = {}
    end

    if type(settings.multiRaid.log) ~= "table" then
        settings.multiRaid.log = {}
    end

    if type(settings.multiRaid.seenMessages) ~= "table" then
        settings.multiRaid.seenMessages = {}
    end

    if type(settings.multiRaid.localRoster) ~= "table" then
        settings.multiRaid.localRoster = {}
    end

    if type(settings.multiRaid.rosterBuffers) ~= "table" then
        settings.multiRaid.rosterBuffers = {}
    end

    if type(settings.multiRaid.rosterVersion) ~= "number" then
        settings.multiRaid.rosterVersion = 0
    end

    if type(settings.multiRaid.nextSeq) ~= "number" or settings.multiRaid.nextSeq < 1 then
        settings.multiRaid.nextSeq = 1
    end

    return settings.multiRaid
end

local function GetTimestamp()
    return date("%Y-%m-%d %H:%M:%S")
end

local function TrimText(text)
    if type(text) ~= "string" then
        return ""
    end

    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")

    return text
end

local function NormalizePlayerName(name)
    local text = TrimText(name)

    text = string.gsub(text, "[|~\n\r]", "")

    return text
end

local function SanitizeProtocolValue(value, maxLength)
    local text = tostring(value or "")

    text = string.gsub(text, "[|~\n\r]", " ")

    if type(maxLength) == "number" and maxLength > 0 and string.len(text) > maxLength then
        text = string.sub(text, 1, maxLength)
    end

    return text
end

local function SanitizeChatText(value)
    local text = tostring(value or "")

    text = string.gsub(text, "[\n\r]", " ")
    text = string.gsub(text, "|", " ")

    if string.len(text) > 255 then
        text = string.sub(text, 1, 255)
    end

    return text
end

local function GetLocalPlayerName()
    local name, realm

    if UnitFullName then
        name, realm = UnitFullName("player")
    else
        name = UnitName("player")
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name or "-"
end

local function AddMultiRaidLog(message)
    local state = EnsureMultiRaidState()

    table.insert(state.log, 1, {
        at = GetTimestamp(),
        message = tostring(message or "-")
    })

    while #state.log > MULTI_RAID_LOG_LIMIT do
        table.remove(state.log)
    end
end

local function RefreshUI()
    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function GetSendAddonMessageReason(result)
    local addonResult = Enum and Enum.SendAddonMessageResult

    if result == false then
        return "SEND_FAILED"
    end

    if result == true or result == nil then
        return nil
    end

    if addonResult then
        if result == addonResult.Success then
            return nil
        elseif result == addonResult.InvalidPrefix then
            return "INVALID_PREFIX"
        elseif result == addonResult.InvalidMessage then
            return "INVALID_MESSAGE"
        elseif result == addonResult.AddonMessageThrottle then
            return "ADDON_MESSAGE_THROTTLE"
        elseif result == addonResult.InvalidChatType then
            return "INVALID_CHAT_TYPE"
        elseif result == addonResult.NotInGroup then
            return "NOT_IN_GROUP"
        elseif result == addonResult.TargetRequired then
            return "TARGET_REQUIRED"
        elseif result == addonResult.InvalidChannel then
            return "INVALID_CHANNEL"
        elseif result == addonResult.ChannelThrottle then
            return "CHANNEL_THROTTLE"
        elseif result == addonResult.GeneralError then
            return "GENERAL_ERROR"
        elseif addonResult.NotInGuild and result == addonResult.NotInGuild then
            return "NOT_IN_GUILD"
        elseif addonResult.AddOnMessageLockdown and result == addonResult.AddOnMessageLockdown then
            return "ADDON_MESSAGE_LOCKDOWN"
        elseif result == addonResult.TargetOffline then
            return "TARGET_OFFLINE"
        end
    elseif result == 0 then
        return nil
    elseif result == 3 then
        return "ADDON_MESSAGE_THROTTLE"
    elseif result == 11 then
        return "ADDON_MESSAGE_LOCKDOWN"
    elseif result == 12 then
        return "TARGET_OFFLINE"
    end

    return "SEND_RESULT_" .. tostring(result)
end

local function GetCurrentRaidRosterEntries(excludedName)
    local entries = {}
    local numMembers = GetNumGroupMembers()

    if not IsInRaid or not IsInRaid() then
        return entries
    end

    for raidIndex = 1, numMembers do
        local name = GetRaidRosterInfo(raidIndex)

        if name and not NamesMatch(name, excludedName) then
            entries[#entries + 1] = {
                name = name
            }
        end
    end

    return entries
end

local function MarkAssistantRosterStale()
    local state = EnsureMultiRaidState()

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.localRosterStatus == "recorded" or state.localRosterStatus == "sent" then
        state.localRosterStatus = "stale"
        AddMultiRaidLog("Local raid roster changed. Re-record before sending.")

        if state.acceptedCoordinator and state.sessionId then
            SendMultiRaidWhisper("ROSTER_STALE", state.acceptedCoordinator, state.sessionId, state.assistantRaidId)
        end

        if addon.UI and addon.UI.Refresh then
            addon.UI.Refresh()
        end
    end
end

local function NextMultiRaidSeq()
    local state = EnsureMultiRaidState()
    local seq = state.nextSeq

    state.nextSeq = seq + 1

    return seq
end

local function GenerateMultiRaidSessionId()
    return "MG-" .. tostring(random(1000, 9999))
end

local function EnsureCoordinatorSession()
    local state = EnsureMultiRaidState()

    if type(state.sessionId) ~= "string" or state.sessionId == "" then
        state.sessionId = GenerateMultiRaidSessionId()
    end

    state.coordinator = GetLocalPlayerName()

    return state
end

local function SplitPayload(payload)
    local fields = {}
    local startIndex = 1
    local separatorIndex

    if type(payload) ~= "string" then
        return fields
    end

    while true do
        separatorIndex = string.find(payload, "|", startIndex, true)

        if not separatorIndex then
            fields[#fields + 1] = string.sub(payload, startIndex)
            break
        end

        fields[#fields + 1] = string.sub(payload, startIndex, separatorIndex - 1)
        startIndex = separatorIndex + 1
    end

    return fields
end

local function BuildMultiRaidPayload(messageType, sessionId, source, target, raidId, seq, value1, value2)
    return table.concat({
        "mr1",
        SanitizeProtocolValue(messageType, 24),
        SanitizeProtocolValue(sessionId, 16),
        SanitizeProtocolValue(source, 48),
        SanitizeProtocolValue(target, 48),
        tostring(raidId or "-"),
        tostring(seq or 0),
        SanitizeProtocolValue(value1 or "-", 48),
        SanitizeProtocolValue(value2 or "-", 120)
    }, "|")
end

local function DecodeMultiRaidPayload(payload)
    local fields = SplitPayload(payload)

    if fields[1] ~= "mr1" then
        return nil
    end

    return {
        messageType = fields[2] or "-",
        sessionId = fields[3] or "-",
        source = fields[4] or "-",
        target = fields[5] or "-",
        raidId = tonumber(fields[6]),
        seq = tonumber(fields[7]) or 0,
        value1 = fields[8],
        value2 = fields[9]
    }
end

SendMultiRaidWhisper = function(messageType, target, sessionId, raidId, value1, value2)
    local source = GetLocalPlayerName()
    local seq = NextMultiRaidSeq()
    local payload = BuildMultiRaidPayload(messageType, sessionId, source, target, raidId, seq, value1, value2)
    local result

    if not monitoringPrefixRegistered then
        return false, "PREFIX_NOT_REGISTERED"
    end

    if string.len(payload) > MONITORING_PAYLOAD_LIMIT then
        return false, "PAYLOAD_TOO_LONG"
    end

    result = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, payload, "WHISPER", target)

    local reason = GetSendAddonMessageReason(result)

    if reason then
        return false, reason
    end

    return true, seq
end

local function SanitizeMonitoringValue(value, maxLength)
    local text = tostring(value or "")

    text = string.gsub(text, "[|~\n\r]", " ")

    if type(maxLength) == "number" and maxLength > 0 and string.len(text) > maxLength then
        text = string.sub(text, 1, maxLength)
    end

    return text
end

local function BuildMonitoringRewardText()
    local rewards = EnsureRewardTemplates()
    local rewardText = {}
    local limit = math.min(#rewards, MONITORING_REWARD_LIMIT)

    for index = 1, limit do
        rewardText[#rewardText + 1] = SanitizeMonitoringValue(rewards[index], MONITORING_REWARD_TEXT_LIMIT)
    end

    return tostring(#rewards), table.concat(rewardText, "~")
end

local function SplitMonitoringRewards(text)
    local rewards = {}
    local startIndex = 1
    local separatorIndex

    if type(text) ~= "string" or text == "" then
        return rewards
    end

    while true do
        separatorIndex = string.find(text, "~", startIndex, true)

        if not separatorIndex then
            rewards[#rewards + 1] = string.sub(text, startIndex)
            break
        end

        rewards[#rewards + 1] = string.sub(text, startIndex, separatorIndex - 1)
        startIndex = separatorIndex + 1
    end

    return rewards
end

local function AddMonitoringLogEntry(entry)
    table.insert(monitoringLog, 1, entry)

    while #monitoringLog > MONITORING_LOG_LIMIT do
        table.remove(monitoringLog)
    end
end

local function SplitMonitoringPayload(payload)
    local fields = {}
    local startIndex = 1
    local separatorIndex

    if type(payload) ~= "string" then
        return fields
    end

    while true do
        separatorIndex = string.find(payload, "|", startIndex, true)

        if not separatorIndex then
            fields[#fields + 1] = string.sub(payload, startIndex)
            break
        end

        fields[#fields + 1] = string.sub(payload, startIndex, separatorIndex - 1)
        startIndex = separatorIndex + 1
    end

    return fields
end

local function BuildMonitoringSnapshot(eventName)
    local session = EnsureSettings().activeSession
    local sessionActive = type(session) == "table" and session.status == "active"
    local rewardCount, rewardText = BuildMonitoringRewardText()

    return {
        event = SanitizeMonitoringValue(eventName or "STATE", 24),
        sentAt = GetTimestamp(),
        sender = SanitizeMonitoringValue(UnitName("player") or "-", 40),
        session = sessionActive and "active" or "inactive",
        round = tostring(currentRound or 0),
        players = tostring(assignedCount or 0),
        pending = pendingRollRound and tostring(pendingRollRound) or "-",
        winnerNumber = lastWinnerNumber and tostring(lastWinnerNumber) or "-",
        winnerName = SanitizeMonitoringValue(lastWinnerName or "-", 40),
        rewardCount = rewardCount,
        rewards = rewardText
    }
end

local function EncodeMonitoringSnapshot(snapshot)
    return table.concat({
        "v1",
        snapshot.event,
        snapshot.sentAt,
        snapshot.sender,
        snapshot.session,
        snapshot.round,
        snapshot.players,
        snapshot.pending,
        snapshot.winnerNumber,
        snapshot.winnerName,
        snapshot.rewardCount,
        snapshot.rewards
    }, "|")
end

local function DecodeMonitoringSnapshot(payload)
    local fields = SplitMonitoringPayload(payload)

    if fields[1] ~= "v1" then
        return nil
    end

    return {
        event = fields[2] or "-",
        sentAt = fields[3] or "-",
        sender = fields[4] or "-",
        session = fields[5] or "-",
        round = fields[6] or "-",
        players = fields[7] or "-",
        pending = fields[8] or "-",
        winnerNumber = fields[9] or "-",
        winnerName = fields[10] or "-",
        rewardCount = fields[11] or "0",
        rewards = SplitMonitoringRewards(fields[12])
    }
end

local function GetMonitoringBroadcastChannel()
    if IsInRaid and IsInRaid() then
        return "RAID"
    end

    if IsInGroup and IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function HandleMonitoringMessage(payload, sender)
    local snapshot = DecodeMonitoringSnapshot(payload)
    local sanitizedSender

    if not snapshot then
        return
    end

    sanitizedSender = SanitizeMonitoringValue(sender or snapshot.sender or "-")

    if monitoringObservedSender and monitoringObservedSender ~= sanitizedSender then
        return
    end

    snapshot.receivedAt = GetTimestamp()
    snapshot.sender = sanitizedSender
    monitoringLastSnapshot = snapshot
    monitoringObservedSender = sanitizedSender

    AddMonitoringLogEntry({
        receivedAt = snapshot.receivedAt,
        sender = snapshot.sender,
        event = snapshot.event,
        round = snapshot.round,
        players = snapshot.players,
        pending = snapshot.pending,
        winnerName = snapshot.winnerName
    })

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function FindAssistantBySender(state, sender)
    local normalizedSender = NormalizePlayerName(sender)

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.senderName == normalizedSender or assistant.targetName == normalizedSender then
            return assistant
        end
    end

    return nil
end

local function HandleMultiRaidInvite(message, sender)
    local state = EnsureMultiRaidState()

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if message.target ~= GetLocalPlayerName()
        and message.target ~= UnitName("player")
        and message.target ~= "-"
    then
        return
    end

    if state.acceptedCoordinator and state.sessionId and state.acceptedCoordinator ~= sender then
        AddMultiRaidLog("Ignored invite from " .. tostring(sender) .. "; already locked to " .. tostring(state.acceptedCoordinator) .. ".")
        return
    end

    state.pendingInvite = {
        sessionId = message.sessionId,
        coordinator = sender,
        raidId = message.raidId,
        seq = message.seq,
        receivedAt = GetTimestamp()
    }

    AddMultiRaidLog("Invite received from " .. tostring(sender) .. " for " .. tostring(message.sessionId) .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidAccept(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    if message.sessionId ~= state.sessionId then
        AddMultiRaidLog("Ignored ACCEPT from " .. tostring(sender) .. " for wrong session.")
        return
    end

    assistant = FindAssistantBySender(state, sender)

    if not assistant then
        AddMultiRaidLog("Ignored ACCEPT from unknown assistant " .. tostring(sender) .. ".")
        return
    end

    assistant.senderName = NormalizePlayerName(sender)
    assistant.status = "accepted"
    assistant.acceptedAt = GetTimestamp()
    AddMultiRaidLog("Assistant accepted: " .. tostring(assistant.senderName) .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidReject(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    if message.sessionId ~= state.sessionId then
        return
    end

    assistant = FindAssistantBySender(state, sender)

    if not assistant then
        return
    end

    assistant.senderName = NormalizePlayerName(sender)
    assistant.status = "rejected"
    assistant.rejectedAt = GetTimestamp()
    AddMultiRaidLog("Assistant rejected: " .. tostring(assistant.senderName) .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidVerifyWinner(message, sender)
    local state = EnsureMultiRaidState()
    local winnerName = message.value2
    local online
    local responseType

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored winner verify from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    online = IsSnapshotPlayerOnline(winnerName)
    responseType = online and "WINNER_ONLINE" or "WINNER_OFFLINE"
    SendMultiRaidWhisper(responseType, sender, message.sessionId, state.assistantRaidId, message.value1, winnerName)
    AddMultiRaidLog("Winner verify: #" .. tostring(message.value1 or "-")
        .. " " .. tostring(winnerName or "-")
        .. " is " .. (online and "online" or "offline") .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidWinnerStatus(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    if message.sessionId ~= state.sessionId then
        return
    end

    assistant = FindAssistantBySender(state, sender)

    if not assistant or assistant.status ~= "accepted" then
        AddMultiRaidLog("Ignored winner status from unknown assistant " .. tostring(sender) .. ".")
        return
    end

    assistant.lastWinnerVerifyAt = GetTimestamp()
    assistant.lastWinnerVerifyNumber = message.value1
    assistant.lastWinnerVerifyName = message.value2
    assistant.lastWinnerVerifyStatus = message.messageType

    AddMultiRaidLog("Winner verify from " .. tostring(sender)
        .. ": #" .. tostring(message.value1 or "-")
        .. " " .. tostring(message.value2 or "-")
        .. " " .. tostring(message.messageType) .. ".")

    if message.messageType == "WINNER_OFFLINE" then
        SetLastInvalidRoll(currentRound, tonumber(message.value1), message.value2, "OFFLINE")
        RecordMultiRaidRollResult(currentRound, tonumber(message.value1), {
            name = message.value2,
            raidId = assistant.raidId,
            assistantName = assistant.senderName or assistant.targetName
        }, true, "OFFLINE")
        API.RelayMultiRaidMessage("Offline winner #" .. tostring(message.value1 or "-")
            .. " " .. tostring(message.value2 or "-")
            .. ". Roll again.")
    elseif message.messageType == "WINNER_ONLINE" then
        UpdateMultiRaidWinnerVerification(currentRound, tonumber(message.value1), message.value2, assistant.raidId, "ASSISTANT_ONLINE")
        API.RelayMultiRaidMessage("Winner confirmed: #" .. tostring(message.value1 or "-")
            .. " " .. tostring(message.value2 or "-")
            .. " - Raid " .. tostring(assistant.raidId or "-"))
    end

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function GetRosterAssistant(state, sender, message)
    local assistant = FindAssistantBySender(state, sender)

    if not assistant then
        return nil
    end

    if message.sessionId ~= state.sessionId then
        return nil
    end

    return assistant
end

local function HandleMultiRaidRosterRequest(message, sender)
    local state = EnsureMultiRaidState()

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored roster request from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    state.lastRosterRequestedAt = GetTimestamp()
    AddMultiRaidLog("Coordinator requested local roster.")

    if state.localRosterStatus == "stale" then
        SendMultiRaidWhisper("ROSTER_STALE", sender, state.sessionId, state.assistantRaidId)
    elseif #state.localRoster == 0 then
        SendMultiRaidWhisper("ROSTER_NOT_READY", sender, state.sessionId, state.assistantRaidId, "NOT_RECORDED")
    end

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidRosterNotReady(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    assistant = GetRosterAssistant(state, sender, message)

    if not assistant then
        return
    end

    assistant.rosterStatus = "not_ready"
    assistant.rosterReason = message.value1 or "-"
    assistant.lastRosterAt = GetTimestamp()
    AddMultiRaidLog("Roster not ready from " .. tostring(sender) .. ": " .. tostring(assistant.rosterReason) .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidRosterStale(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    assistant = GetRosterAssistant(state, sender, message)

    if not assistant then
        return
    end

    assistant.rosterStatus = "stale"
    assistant.lastRosterAt = GetTimestamp()
    AddMultiRaidLog("Roster stale from " .. tostring(sender) .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidRosterBegin(message, sender)
    local state = EnsureMultiRaidState()
    local assistant
    local key

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    assistant = GetRosterAssistant(state, sender, message)

    if not assistant then
        AddMultiRaidLog("Ignored roster from unknown assistant " .. tostring(sender) .. ".")
        return
    end

    key = tostring(sender) .. "|" .. tostring(message.sessionId) .. "|" .. tostring(message.raidId or "-")
    state.rosterBuffers[key] = {
        sender = sender,
        raidId = message.raidId,
        expectedCount = tonumber(message.value1) or 0,
        rosterVersion = tonumber(message.value2) or 0,
        rows = {}
    }
    assistant.rosterStatus = "receiving"
    assistant.expectedCount = tonumber(message.value1) or 0
    AddMultiRaidLog("Roster receiving from " .. tostring(sender) .. " (" .. tostring(assistant.expectedCount) .. ").")
end

local function HandleMultiRaidRosterRow(message, sender)
    local state = EnsureMultiRaidState()
    local key
    local buffer
    local rowIndex

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    key = tostring(sender) .. "|" .. tostring(message.sessionId) .. "|" .. tostring(message.raidId or "-")
    buffer = state.rosterBuffers[key]

    if type(buffer) ~= "table" then
        return
    end

    rowIndex = tonumber(message.value1)

    if rowIndex and message.value2 and message.value2 ~= "-" then
        buffer.rows[rowIndex] = {
            name = message.value2
        }
    end
end

local function HandleMultiRaidRosterEnd(message, sender)
    local state = EnsureMultiRaidState()
    local assistant
    local key
    local buffer
    local roster = {}

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    assistant = GetRosterAssistant(state, sender, message)

    if not assistant then
        return
    end

    key = tostring(sender) .. "|" .. tostring(message.sessionId) .. "|" .. tostring(message.raidId or "-")
    buffer = state.rosterBuffers[key]

    if type(buffer) ~= "table" then
        return
    end

    for index = 1, buffer.expectedCount do
        if buffer.rows[index] and buffer.rows[index].name then
            roster[#roster + 1] = {
                name = buffer.rows[index].name
            }
        end
    end

    assistant.roster = roster
    assistant.eligibleCount = #roster
    assistant.rosterVersion = buffer.rosterVersion
    assistant.rosterStatus = "received"
    assistant.lastRosterAt = GetTimestamp()
    state.rosterBuffers[key] = nil
    AddMultiRaidLog("Roster received from " .. tostring(sender) .. ": " .. tostring(#roster) .. " eligible.")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidAssignBegin(message, sender)
    local state = EnsureMultiRaidState()
    local rangeText = message.value1 or "-"
    local startNumber, endNumber = string.match(rangeText, "^(%d+)%-(%d+)$")

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored assignment from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    state.assignmentBuffer = {}
    state.assignedRangeStart = tonumber(startNumber)
    state.assignedRangeEnd = tonumber(endNumber)
    state.assignmentExpectedCount = tonumber(message.value2) or 0
    state.assignmentStatus = "receiving"
    AddMultiRaidLog("Assignment receiving: " .. tostring(rangeText) .. ".")
end

local function HandleMultiRaidAssignRow(message, sender)
    local state = EnsureMultiRaidState()
    local number = tonumber(message.value1)

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        return
    end

    if type(state.assignmentBuffer) ~= "table" then
        return
    end

    if number and message.value2 and message.value2 ~= "-" then
        state.assignmentBuffer[#state.assignmentBuffer + 1] = {
            number = number,
            name = message.value2
        }
    end
end

local function HandleMultiRaidAssignEnd(message, sender)
    local state = EnsureMultiRaidState()
    local byName = {}
    local byNumber = {}

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        return
    end

    if type(state.assignmentBuffer) ~= "table" then
        return
    end

    for index = 1, #state.assignmentBuffer do
        local entry = state.assignmentBuffer[index]

        byName[entry.name] = entry.number
        byNumber[entry.number] = entry.name
    end

    state.assignedRoster = state.assignmentBuffer
    state.assignedNumbersByName = byName
    state.assignedNamesByNumber = byNumber
    state.assignmentBuffer = nil
    state.assignmentStatus = "received"
    state.assignmentReceivedAt = GetTimestamp()
    AddMultiRaidLog("Assignment received: " .. tostring(#state.assignedRoster) .. " players.")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidRelayRaid(message, sender)
    local state = EnsureMultiRaidState()
    local relayText = message.value2

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored relay from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    if not relayText or relayText == "-" then
        return
    end

    SendRaidMessage(relayText)
    AddMultiRaidLog("Relayed to RAID: " .. tostring(relayText))

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function SendAssistantNumberWhispers()
    local state = EnsureMultiRaidState()
    local roster = state.assignedRoster or {}
    local queuedCount = 0

    if #roster <= 0 or state.assignmentStatus ~= "received" then
        return false, "ASSIGNMENT_REQUIRED"
    end

    if chatSendQueue.active or #chatSendQueue.items > 0 then
        return false, "SEND_QUEUE_ACTIVE"
    end

    ResetChatQueue("Assistant number whispers", function(sent, failed)
        state.numberWhisperStatus = failed > 0 and "failed" or "sent"
        state.numberWhisperSentAt = GetTimestamp()
        state.numberWhisperSentCount = sent
        state.numberWhisperFailedCount = failed

        if failed > 0 then
            SendMultiRaidWhisper("NUMBERS_FAILED", state.acceptedCoordinator, state.sessionId, state.assistantRaidId, tostring(failed))
            AddMultiRaidLog("Number whispers completed with failures: " .. tostring(failed) .. ".")
        else
            SendMultiRaidWhisper("NUMBERS_SENT", state.acceptedCoordinator, state.sessionId, state.assistantRaidId, tostring(sent))
            AddMultiRaidLog("Number whispers sent: " .. tostring(sent) .. ".")
        end
    end)

    for index = 1, #roster do
        local entry = roster[index]

        if entry and entry.name and entry.number then
            QueueNumberWhisper(entry.name, BuildNumberMessage(entry.number), "Assistant number whispers")
            queuedCount = queuedCount + 1
        end
    end

    state.numberWhisperStatus = "sending"
    state.numberWhisperQueuedAt = GetTimestamp()
    state.numberWhisperQueuedCount = queuedCount
    AddMultiRaidLog("Number whispers queued: " .. tostring(queuedCount) .. ".")

    return true, queuedCount
end

local function HandleMultiRaidSendNumbers(message, sender)
    local state = EnsureMultiRaidState()
    local ok, result

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored number send request from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    ok, result = SendAssistantNumberWhispers()

    if not ok then
        SendMultiRaidWhisper("NUMBERS_FAILED", sender, state.sessionId, state.assistantRaidId, tostring(result))
        AddMultiRaidLog("Number whispers failed: " .. tostring(result) .. ".")
    end

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidNumbersStatus(message, sender)
    local state = EnsureMultiRaidState()
    local assistant

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return
    end

    if message.sessionId ~= state.sessionId then
        return
    end

    assistant = FindAssistantBySender(state, sender)

    if not assistant or assistant.status ~= "accepted" then
        return
    end

    if message.messageType == "NUMBERS_SENT" then
        assistant.numberWhisperStatus = "sent"
        assistant.numberWhisperSentCount = tonumber(message.value1) or 0
        assistant.numberWhisperSentAt = GetTimestamp()
        AddMultiRaidLog("Numbers sent by " .. tostring(sender) .. ": " .. tostring(assistant.numberWhisperSentCount) .. ".")
    else
        assistant.numberWhisperStatus = "failed"
        assistant.numberWhisperError = message.value1 or "-"
        AddMultiRaidLog("Numbers failed by " .. tostring(sender) .. ": " .. tostring(assistant.numberWhisperError) .. ".")
    end

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidGameStart(message, sender)
    local state = EnsureMultiRaidState()

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored game start from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    state.gameStatus = "active"
    state.startedAt = GetTimestamp()
    state.totalAssigned = tonumber(message.value1) or state.totalAssigned
    AddMultiRaidLog("Multi game started by Coordinator. Total players: " .. tostring(state.totalAssigned or "-") .. ".")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidGameStop(message, sender)
    local state = EnsureMultiRaidState()

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return
    end

    if state.acceptedCoordinator ~= sender or state.sessionId ~= message.sessionId then
        AddMultiRaidLog("Ignored game stop from unauthorized sender " .. tostring(sender) .. ".")
        return
    end

    state.gameStatus = "stopped"
    state.stoppedAt = GetTimestamp()
    AddMultiRaidLog("Multi game stopped by Coordinator.")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

local function HandleMultiRaidMessage(payload, sender)
    local message = DecodeMultiRaidPayload(payload)
    local normalizedSender = NormalizePlayerName(sender)
    local state
    local seenKey

    if not message then
        return false
    end

    state = EnsureMultiRaidState()
    seenKey = tostring(normalizedSender) .. "|" .. tostring(message.sessionId) .. "|" .. tostring(message.seq)

    if state.seenMessages[seenKey] then
        return true
    end

    state.seenMessages[seenKey] = true

    if message.messageType == "INVITE" then
        HandleMultiRaidInvite(message, normalizedSender)
    elseif message.messageType == "ACCEPT" then
        HandleMultiRaidAccept(message, normalizedSender)
    elseif message.messageType == "REJECT" then
        HandleMultiRaidReject(message, normalizedSender)
    elseif message.messageType == "VERIFY_WINNER" then
        HandleMultiRaidVerifyWinner(message, normalizedSender)
    elseif message.messageType == "WINNER_ONLINE" or message.messageType == "WINNER_OFFLINE" then
        HandleMultiRaidWinnerStatus(message, normalizedSender)
    elseif message.messageType == "ROSTER_REQUEST" then
        HandleMultiRaidRosterRequest(message, normalizedSender)
    elseif message.messageType == "ROSTER_NOT_READY" then
        HandleMultiRaidRosterNotReady(message, normalizedSender)
    elseif message.messageType == "ROSTER_STALE" then
        HandleMultiRaidRosterStale(message, normalizedSender)
    elseif message.messageType == "ROSTER_BEGIN" then
        HandleMultiRaidRosterBegin(message, normalizedSender)
    elseif message.messageType == "ROSTER_ROW" then
        HandleMultiRaidRosterRow(message, normalizedSender)
    elseif message.messageType == "ROSTER_END" then
        HandleMultiRaidRosterEnd(message, normalizedSender)
    elseif message.messageType == "ASSIGN_BEGIN" then
        HandleMultiRaidAssignBegin(message, normalizedSender)
    elseif message.messageType == "ASSIGN_ROW" then
        HandleMultiRaidAssignRow(message, normalizedSender)
    elseif message.messageType == "ASSIGN_END" then
        HandleMultiRaidAssignEnd(message, normalizedSender)
    elseif message.messageType == "RELAY_RAID" then
        HandleMultiRaidRelayRaid(message, normalizedSender)
    elseif message.messageType == "SEND_NUMBERS" then
        HandleMultiRaidSendNumbers(message, normalizedSender)
    elseif message.messageType == "NUMBERS_SENT" or message.messageType == "NUMBERS_FAILED" then
        HandleMultiRaidNumbersStatus(message, normalizedSender)
    elseif message.messageType == "GAME_START" then
        HandleMultiRaidGameStart(message, normalizedSender)
    elseif message.messageType == "GAME_STOP" then
        HandleMultiRaidGameStop(message, normalizedSender)
    end

    return true
end

local function SendMonitoringState(eventName)
    local channel = GetMonitoringBroadcastChannel()
    local snapshot
    local payload
    local result

    if not channel then
        return false, "NO_GROUP"
    end

    if not monitoringPrefixRegistered then
        return false, "PREFIX_NOT_REGISTERED"
    end

    snapshot = BuildMonitoringSnapshot(eventName)
    payload = EncodeMonitoringSnapshot(snapshot)

    if string.len(payload) > MONITORING_PAYLOAD_LIMIT then
        return false, "PAYLOAD_TOO_LONG"
    end

    result = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, payload, channel)

    local reason = GetSendAddonMessageReason(result)

    if reason then
        return false, reason
    end

    return true, channel
end

local function BroadcastMonitoringState(eventName)
    if not monitoringBroadcastEnabled then
        return false, "LIVE_DISABLED"
    end

    return SendMonitoringState(eventName)
end

local function StopMonitoringTicker()
    if monitoringBroadcastTicker and monitoringBroadcastTicker.Cancel then
        monitoringBroadcastTicker:Cancel()
    end

    monitoringBroadcastTicker = nil
end

local function StartMonitoringTicker()
    StopMonitoringTicker()

    if not C_Timer or not C_Timer.NewTicker then
        return false, "TIMER_UNAVAILABLE"
    end

    monitoringBroadcastTicker = C_Timer.NewTicker(MONITORING_LIVE_INTERVAL, function()
        BroadcastMonitoringState("LIVE")
    end)

    return true, "LIVE_STARTED"
end

local function GetRosterSnapshot()
    local roster = {}

    for number = 1, assignedCount do
        local name = namesByNumber[number]

        if name then
            roster[#roster + 1] = {
                number = number,
                name = name
            }
        end
    end

    return roster
end

local function RestoreRosterSnapshot(roster)
    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0

    if type(roster) ~= "table" then
        return
    end

    for index = 1, #roster do
        local entry = roster[index]

        if entry and entry.name and entry.number then
            namesByNumber[entry.number] = entry.name
            numbersByName[entry.name] = entry.number

            if entry.number > assignedCount then
                assignedCount = entry.number
            end
        end
    end
end

local function PersistActiveSessionState()
    local session = EnsureSettings().activeSession

    if type(session) ~= "table" then
        return nil
    end

    session.roster = GetRosterSnapshot()
    session.assignedCount = assignedCount
    session.currentRound = currentRound
    session.lastWinnerRound = lastWinnerRound
    session.lastWinnerNumber = lastWinnerNumber
    session.lastWinnerName = lastWinnerName
    session.lastInvalidRollRound = lastInvalidRollRound
    session.lastInvalidRollNumber = lastInvalidRollNumber
    session.lastInvalidRollName = lastInvalidRollName
    session.lastInvalidRollReason = lastInvalidRollReason
    session.pendingRollRound = nil
    session.pendingRollMax = nil

    return session
end

local function RestoreActiveSessionState()
    local session = EnsureSettings().activeSession

    if type(session) ~= "table" or session.status ~= "active" then
        return false
    end

    RestoreRosterSnapshot(session.roster)
    assignmentActive = assignedCount > 0
    currentRound = session.currentRound or 0
    pendingRollRound = nil
    pendingRollMax = nil
    session.pendingRollRound = nil
    session.pendingRollMax = nil
    lastWinnerRound = session.lastWinnerRound
    lastWinnerNumber = session.lastWinnerNumber
    lastWinnerName = session.lastWinnerName
    lastInvalidRollRound = session.lastInvalidRollRound
    lastInvalidRollNumber = session.lastInvalidRollNumber
    lastInvalidRollName = session.lastInvalidRollName
    lastInvalidRollReason = session.lastInvalidRollReason

    return true
end

local function RecordSessionRound(roundNumber, rollMax)
    local session = EnsureSettings().activeSession

    if type(session) ~= "table" then
        return
    end

    if type(session.rounds) ~= "table" then
        session.rounds = {}
    end

    session.rounds[#session.rounds + 1] = {
        round = roundNumber,
        announcedAt = GetTimestamp(),
        rollMin = 1,
        rollMax = rollMax or assignedCount
    }
end

local function RecordSessionRollResult(roundNumber, rollNumber, winnerName, invalid, invalidReason)
    local session = EnsureSettings().activeSession
    local rounds
    local roundEntry
    local rolledAt

    if type(session) ~= "table" or type(session.rounds) ~= "table" then
        return
    end

    rounds = session.rounds

    for index = #rounds, 1, -1 do
        if rounds[index].round == roundNumber then
            roundEntry = rounds[index]
            rolledAt = GetTimestamp()

            if invalid then
                roundEntry.invalidRollNumber = rollNumber
                roundEntry.invalidWinnerName = winnerName
                roundEntry.invalidReason = invalidReason
                roundEntry.invalidAt = rolledAt
            else
                roundEntry.rollNumber = rollNumber
                roundEntry.winnerName = winnerName
                roundEntry.rolledAt = rolledAt
                roundEntry.invalidRollNumber = nil
                roundEntry.invalidWinnerName = nil
                roundEntry.invalidReason = nil
                roundEntry.invalidAt = nil
            end

            if type(roundEntry.rolls) ~= "table" then
                roundEntry.rolls = {}
            end

            roundEntry.rolls[#roundEntry.rolls + 1] = {
                rollNumber = rollNumber,
                winnerName = winnerName,
                rolledAt = rolledAt,
                reroll = #roundEntry.rolls > 0,
                invalid = invalid and true or false,
                invalidReason = invalidReason
            }

            return
        end
    end
end

local function RecordSessionReward(rewardText, message)
    local session = EnsureSettings().activeSession
    local multiState = EnsureMultiRaidState()
    local multiSession = multiState.activeSession

    if type(session) ~= "table" and type(multiSession) == "table" and multiSession.status == "active" then
        session = multiSession
    end

    if type(session) ~= "table" then
        return
    end

    if type(session.rewards) ~= "table" then
        session.rewards = {}
    end

    session.rewards[#session.rewards + 1] = {
        round = lastWinnerRound,
        winnerNumber = lastWinnerNumber,
        winnerName = lastWinnerName,
        reward = rewardText,
        message = message,
        sentAt = GetTimestamp()
    }
end

local function CopyRosterList(roster)
    local copy = {}

    if type(roster) ~= "table" then
        return copy
    end

    for index = 1, #roster do
        local entry = roster[index]

        if type(entry) == "table" then
            copy[#copy + 1] = {
                name = entry.name,
                number = entry.number,
                raidId = entry.raidId,
                assistantName = entry.assistantName
            }
        end
    end

    return copy
end

local function CopyRaidRanges(ranges)
    local copy = {}

    if type(ranges) ~= "table" then
        return copy
    end

    for raidId, range in pairs(ranges) do
        if type(range) == "table" then
            copy[raidId] = {
                raidId = range.raidId,
                rangeStart = range.rangeStart,
                rangeEnd = range.rangeEnd,
                eligibleCount = range.eligibleCount,
                assistantName = range.assistantName
            }
        end
    end

    return copy
end

local function BuildMultiRaidAssistantSnapshot(state)
    local assistants = {}

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        assistants[index] = {
            raidId = assistant.raidId,
            targetName = assistant.targetName,
            senderName = assistant.senderName,
            status = assistant.status,
            rosterStatus = assistant.rosterStatus,
            eligibleCount = assistant.eligibleCount,
            rangeStart = assistant.rangeStart,
            rangeEnd = assistant.rangeEnd
        }
    end

    return assistants
end

EnsureMultiRaidActiveHistorySession = function(state)
    local session = state.activeSession

    if type(session) ~= "table" or session.status ~= "active" then
        session = {
            sessionType = "multi",
            status = "active",
            sessionId = state.sessionId,
            coordinator = state.coordinator,
            startedAt = state.startedAt or GetTimestamp(),
            assignedCount = state.totalAssigned or 0,
            roster = CopyRosterList(state.globalAssignments),
            coordinatorRoster = CopyRosterList(state.coordinatorRoster),
            raidRanges = CopyRaidRanges(state.raidRanges),
            assistants = BuildMultiRaidAssistantSnapshot(state),
            currentRound = currentRound,
            rounds = {},
            rewards = {}
        }
        state.activeSession = session
    end

    return session
end

RecordMultiRaidSessionRound = function(state, roundNumber, rollMax)
    local session = EnsureMultiRaidActiveHistorySession(state)

    if type(session.rounds) ~= "table" then
        session.rounds = {}
    end

    session.currentRound = roundNumber
    session.rounds[#session.rounds + 1] = {
        round = roundNumber,
        announcedAt = GetTimestamp(),
        rollMin = 1,
        rollMax = rollMax or state.totalAssigned or 0,
        sessionType = "multi"
    }
end

RecordMultiRaidRollResult = function(roundNumber, rollNumber, winner, invalid, invalidReason, verifyStatus)
    local state = EnsureMultiRaidState()
    local session = state.activeSession
    local rounds
    local roundEntry
    local rolledAt

    if type(session) ~= "table" or type(session.rounds) ~= "table" then
        return
    end

    rounds = session.rounds

    for index = #rounds, 1, -1 do
        if rounds[index].round == roundNumber then
            roundEntry = rounds[index]
            rolledAt = GetTimestamp()

            if invalid then
                roundEntry.invalidRollNumber = rollNumber
                roundEntry.invalidWinnerName = winner and winner.name or "-"
                roundEntry.invalidWinnerRaidId = winner and winner.raidId or nil
                roundEntry.invalidReason = invalidReason
                roundEntry.invalidAt = rolledAt
            else
                roundEntry.rollNumber = rollNumber
                roundEntry.winnerName = winner and winner.name or "-"
                roundEntry.winnerRaidId = winner and winner.raidId or nil
                roundEntry.winnerAssistantName = winner and winner.assistantName or nil
                roundEntry.verifyStatus = verifyStatus
                roundEntry.rolledAt = rolledAt
                roundEntry.invalidRollNumber = nil
                roundEntry.invalidWinnerName = nil
                roundEntry.invalidWinnerRaidId = nil
                roundEntry.invalidReason = nil
                roundEntry.invalidAt = nil
            end

            if type(roundEntry.rolls) ~= "table" then
                roundEntry.rolls = {}
            end

            roundEntry.rolls[#roundEntry.rolls + 1] = {
                rollNumber = rollNumber,
                winnerName = winner and winner.name or "-",
                winnerRaidId = winner and winner.raidId or nil,
                rolledAt = rolledAt,
                reroll = #roundEntry.rolls > 0,
                invalid = invalid and true or false,
                invalidReason = invalidReason,
                verifyStatus = verifyStatus
            }

            return
        end
    end
end

UpdateMultiRaidWinnerVerification = function(roundNumber, winnerNumber, winnerName, raidId, verifyStatus)
    local state = EnsureMultiRaidState()
    local session = state.activeSession

    if type(session) ~= "table" or type(session.rounds) ~= "table" then
        return
    end

    for index = #session.rounds, 1, -1 do
        local roundEntry = session.rounds[index]

        if roundEntry.round == roundNumber and roundEntry.rollNumber == winnerNumber then
            roundEntry.verifyStatus = verifyStatus
            roundEntry.winnerName = winnerName or roundEntry.winnerName
            roundEntry.winnerRaidId = raidId or roundEntry.winnerRaidId
            roundEntry.verifyAt = GetTimestamp()
            return
        end
    end
end

BuildNumberMessage = function(number)
    local numberText = tostring(number)
    local text = API.GetNumberWhisperText()
    local message, replacements = string.gsub(text, "XX", numberText)

    if replacements == 0 then
        message = text .. " " .. numberText
    end

    return message
end

local function IsChatMessagingLockedDown()
    local ok, lockedDown

    if not C_ChatInfo or not C_ChatInfo.InChatMessagingLockdown then
        return false
    end

    ok, lockedDown = pcall(C_ChatInfo.InChatMessagingLockdown)

    return ok and lockedDown == true
end

local function SendVisibleChatMessage(message, chatType, target)
    local ok

    if IsChatMessagingLockedDown() then
        return false, "CHAT_MESSAGE_LOCKDOWN"
    end

    if not C_ChatInfo or not C_ChatInfo.SendChatMessage then
        return false, "CHAT_API_UNAVAILABLE"
    end

    ok = pcall(C_ChatInfo.SendChatMessage, SanitizeChatText(message), chatType, nil, target)

    if not ok then
        return false, "SEND_FAILED"
    end

    return true
end

SendWhisper = function(message, name)
    return SendVisibleChatMessage(message, "WHISPER", name)
end

SendRaidMessage = function(message)
    return SendVisibleChatMessage(message, "RAID")
end

local function SendRaidWarningMessage(message)
    return SendVisibleChatMessage(message, "RAID_WARNING")
end

local function SendSayMessage(message)
    return SendVisibleChatMessage(message, "SAY")
end

local function SendYellMessage(message)
    return SendVisibleChatMessage(message, "YELL")
end

local function ClearQueuePause(queue)
    queue.paused = false
    queue.pauseReason = nil
end

local function StopQueueTicker(queue)
    if queue.ticker and queue.ticker.Cancel then
        queue.ticker:Cancel()
    end

    queue.ticker = nil
    queue.active = false
end

local function PauseQueue(queue, reason)
    StopQueueTicker(queue)
    queue.paused = true
    queue.pauseReason = reason
end

local function FinishChatQueue()
    local onComplete = chatSendQueue.onComplete
    local label = chatSendQueue.label
    local sent = chatSendQueue.sent
    local failed = chatSendQueue.failed

    StopQueueTicker(chatSendQueue)
    ClearQueuePause(chatSendQueue)
    chatSendQueue.label = label
    chatSendQueue.onComplete = nil
    chatSendQueue.completedAt = GetTimestamp()

    if onComplete then
        onComplete(sent, failed)
    end

    RefreshUI()
end

StartChatQueueTicker = function()
    if chatSendQueue.ticker then
        return
    end

    if IsChatMessagingLockedDown() then
        PauseQueue(chatSendQueue, "CHAT_MESSAGE_LOCKDOWN")
        RefreshUI()
        return
    end

    ClearQueuePause(chatSendQueue)
    chatSendQueue.active = true
    chatSendQueue.ticker = C_Timer.NewTicker(CHAT_SEND_INTERVAL, function()
        local item = table.remove(chatSendQueue.items, 1)
        local ok, reason

        if not item then
            FinishChatQueue()
            return
        end

        ok, reason = SendWhisper(item.message, item.target)

        if ok then
            chatSendQueue.sent = chatSendQueue.sent + 1

            if item.onSent then
                item.onSent(item)
            end
        elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
            table.insert(chatSendQueue.items, 1, item)
            PauseQueue(chatSendQueue, reason)
        else
            chatSendQueue.failed = chatSendQueue.failed + 1

            if item.onFailed then
                item.onFailed(item, reason or "SEND_FAILED")
            end
        end

        RefreshUI()
    end)
end

QueueNumberWhisper = function(target, message, label, onSent, onFailed)
    chatSendQueue.items[#chatSendQueue.items + 1] = {
        target = target,
        message = message,
        onSent = onSent,
        onFailed = onFailed
    }
    chatSendQueue.total = chatSendQueue.total + 1
    chatSendQueue.label = label or chatSendQueue.label or "Number whispers"
    chatSendQueue.completedAt = nil

    StartChatQueueTicker()
    RefreshUI()

    return true, #chatSendQueue.items
end

local function ResetChatQueue(label, onComplete)
    StopQueueTicker(chatSendQueue)
    chatSendQueue.items = {}
    chatSendQueue.total = 0
    chatSendQueue.sent = 0
    chatSendQueue.failed = 0
    ClearQueuePause(chatSendQueue)
    chatSendQueue.label = label
    chatSendQueue.onComplete = onComplete
    chatSendQueue.completedAt = nil
end

local function FinishAddonQueue()
    StopQueueTicker(addonSendQueue)
    ClearQueuePause(addonSendQueue)
    addonSendQueue.completedAt = GetTimestamp()
    RefreshUI()
end

StartAddonQueueTicker = function()
    if addonSendQueue.ticker then
        return
    end

    if IsChatMessagingLockedDown() then
        PauseQueue(addonSendQueue, "ADDON_MESSAGE_LOCKDOWN")
        RefreshUI()
        return
    end

    ClearQueuePause(addonSendQueue)
    addonSendQueue.active = true
    addonSendQueue.ticker = C_Timer.NewTicker(ADDON_SEND_INTERVAL, function()
        local item = table.remove(addonSendQueue.items, 1)
        local ok, result

        if not item then
            FinishAddonQueue()
            return
        end

        ok, result = SendMultiRaidWhisper(
            item.messageType,
            item.target,
            item.sessionId,
            item.raidId,
            item.value1,
            item.value2
        )

        if ok then
            addonSendQueue.sent = addonSendQueue.sent + 1

            if item.onSent then
                item.onSent(item)
            end
        elseif result == "ADDON_MESSAGE_LOCKDOWN" then
            table.insert(addonSendQueue.items, 1, item)
            PauseQueue(addonSendQueue, result)
        elseif result == "ADDON_MESSAGE_THROTTLE" or result == "CHANNEL_THROTTLE" then
            item.retryCount = (item.retryCount or 0) + 1

            if item.retryCount <= 10 then
                table.insert(addonSendQueue.items, 1, item)
            else
                addonSendQueue.failed = addonSendQueue.failed + 1

                if item.onFailed then
                    item.onFailed(item, result)
                end
            end
        else
            addonSendQueue.failed = addonSendQueue.failed + 1

            if item.onFailed then
                item.onFailed(item, result)
            end
        end

        RefreshUI()
    end)
end

ResumePausedSendQueues = function()
    if IsChatMessagingLockedDown() then
        return
    end

    if chatSendQueue.paused and #chatSendQueue.items > 0 then
        ClearQueuePause(chatSendQueue)
        StartChatQueueTicker()
    end

    if addonSendQueue.paused and #addonSendQueue.items > 0 then
        ClearQueuePause(addonSendQueue)
        StartAddonQueueTicker()
    end

    RefreshUI()
end

QueueMultiRaidWhisper = function(messageType, target, sessionId, raidId, value1, value2, label, onSent, onFailed)
    addonSendQueue.items[#addonSendQueue.items + 1] = {
        messageType = messageType,
        target = target,
        sessionId = sessionId,
        raidId = raidId,
        value1 = value1,
        value2 = value2,
        onSent = onSent,
        onFailed = onFailed
    }
    addonSendQueue.total = addonSendQueue.total + 1
    addonSendQueue.label = label or addonSendQueue.label or "Addon messages"
    addonSendQueue.completedAt = nil

    StartAddonQueueTicker()
    RefreshUI()

    return true, #addonSendQueue.items
end

local function ScheduleRollCountdown(roundNumber, rollMax, delay)
    local maxCountdown = math.min(3, math.floor(delay or 0))

    if not API.GetRollCountdownSoundEnabled() or maxCountdown <= 0 then
        return
    end

    for countdown = maxCountdown, 1, -1 do
        C_Timer.After(delay - countdown, function()
            if pendingRollRound == roundNumber and pendingRollMax == rollMax then
                SendRaidWarningMessage("Rolling in " .. tostring(countdown) .. "...")
            end
        end)
    end
end

local function ParseRollMessage(message)
    local roller, roll, minimum, maximum = string.match(message, "^(.-) rolls (%d+) %((%d+)%-(%d+)%)")

    if not roll then
        return nil
    end

    return roller, tonumber(roll), tonumber(minimum), tonumber(maximum)
end

SetLastWinner = function(roundNumber, number)
    lastWinnerRound = roundNumber
    lastWinnerNumber = number
    lastWinnerName = namesByNumber[number]
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil
end

SetLastInvalidRoll = function(roundNumber, number, name, reason)
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = roundNumber
    lastInvalidRollNumber = number
    lastInvalidRollName = name
    lastInvalidRollReason = reason
end

NamesMatch = function(left, right)
    if not left or not right then
        return false
    end

    if left == right then
        return true
    end

    if Ambiguate then
        return Ambiguate(left, "short") == Ambiguate(right, "short")
            or Ambiguate(left, "none") == Ambiguate(right, "none")
    end

    return false
end

IsSnapshotPlayerOnline = function(name)
    local numMembers = GetNumGroupMembers()

    if not name or name == "" then
        return false
    end

    for raidIndex = 1, numMembers do
        local rosterName, _, _, _, _, _, _, online = GetRaidRosterInfo(raidIndex)

        if NamesMatch(rosterName, name) then
            return online and true or false
        end
    end

    return false
end

local function SetGMMoveState(status, message, targetGroup, targetName)
    gmMoveState.status = status
    gmMoveState.message = message
    gmMoveState.targetGroup = targetGroup
    gmMoveState.targetName = targetName

    if status == "moving" then
        gmMoveState.requestedAt = GetTimestamp()
        gmMoveState.verifiedAt = nil
    elseif status == "ready" then
        gmMoveState.verifiedAt = GetTimestamp()
    elseif status == "required" or status == "failed" then
        gmMoveState.verifiedAt = nil
    end
end

local function FindLiveRaidLayout()
    local entries = {}
    local gmName = GetLocalPlayerName()
    local gmIndex = nil
    local gmSubgroup = nil
    local targetGroup = nil
    local targetMember = nil

    if not IsInRaid or not IsInRaid() then
        return nil, "NOT_IN_RAID"
    end

    for raidIndex = 1, MAX_RAID_MEMBERS do
        local name, rank, subgroup, _, _, _, _, online = GetRaidRosterInfo(raidIndex)

        if name and subgroup then
            local entry = {
                index = raidIndex,
                name = name,
                rank = rank,
                subgroup = subgroup,
                online = online and true or false
            }

            entries[#entries + 1] = entry

            if NamesMatch(name, gmName) then
                gmIndex = raidIndex
                gmSubgroup = subgroup
            end

            if not targetGroup or subgroup > targetGroup then
                targetGroup = subgroup
                targetMember = entry
            elseif subgroup == targetGroup and (not targetMember or raidIndex > targetMember.index) then
                targetMember = entry
            end
        end
    end

    if #entries <= 0 then
        return nil, "RAID_ROSTER_UNAVAILABLE"
    end

    if not gmIndex then
        return nil, "PLAYER_NOT_FOUND"
    end

    return {
        entries = entries,
        gmName = gmName,
        gmIndex = gmIndex,
        gmSubgroup = gmSubgroup,
        targetGroup = targetGroup,
        targetMember = targetMember
    }
end

local function VerifyPendingGMMove()
    local layout
    local reason

    if gmMoveState.status ~= "moving" then
        return false
    end

    layout, reason = FindLiveRaidLayout()

    if not layout then
        SetGMMoveState("failed", "Cannot verify GM move: " .. tostring(reason) .. ".")
        return false
    end

    if layout.gmSubgroup == gmMoveState.targetGroup then
        SetGMMoveState("ready", "GM moved to subgroup " .. tostring(layout.gmSubgroup) .. ". Record Raid is now available.", layout.gmSubgroup)
        return true
    end

    SetGMMoveState("failed", "GM move was not applied. Try again before recording raid.", gmMoveState.targetGroup)
    return false
end

local function MarkGMMoveRequiredAfterRosterChange()
    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        return
    end

    if assignmentActive or API.HasActiveGameSession() then
        return
    end

    if gmMoveState.status == "ready" then
        SetGMMoveState("required", "Raid roster changed. Move GM again before recording raid.")
    end
end

local function HandleSystemMessage(message)
    local roller, roll, minimum, maximum
    local playerName
    local winnerName

    if not pendingRollRound then
        return
    end

    roller, roll, minimum, maximum = ParseRollMessage(message)

    if not roll or minimum ~= 1 or maximum ~= pendingRollMax then
        return
    end

    playerName = UnitName("player")

    if roller ~= playerName then
        return
    end

    if API.GetSessionMode() == SESSION_MODE_MULTI_COORDINATOR then
        HandleMultiRaidRollResult(pendingRollRound, roll, pendingRollMax)
        pendingRollRound = nil
        pendingRollMax = nil

        if addon.UI and addon.UI.Refresh then
            addon.UI.Refresh()
        end

        return
    end

    winnerName = namesByNumber[roll]

    if not IsSnapshotPlayerOnline(winnerName) then
        SetLastInvalidRoll(pendingRollRound, roll, winnerName, "OFFLINE")
        RecordSessionRollResult(pendingRollRound, roll, winnerName, true, "OFFLINE")
        pendingRollRound = nil
        pendingRollMax = nil
        PersistActiveSessionState()
        BroadcastMonitoringState("ROLL_INVALID_OFFLINE")

        if addon.UI and addon.UI.Refresh then
            addon.UI.Refresh()
        end

        return
    end

    SetLastWinner(pendingRollRound, roll)
    RecordSessionRollResult(pendingRollRound, roll, lastWinnerName, false)
    pendingRollRound = nil
    pendingRollMax = nil
    PersistActiveSessionState()
    BroadcastMonitoringState("ROLL_RESULT")

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    monitoringPrefixRegistered = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX) ~= false
end
eventFrame:SetScript("OnEvent", function(self, event, message, payload, channel, sender)
    if event == "CHAT_MSG_SYSTEM" and message then
        HandleSystemMessage(message)
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        ResumePausedSendQueues()
    elseif event == "GROUP_ROSTER_UPDATE" then
        MarkAssistantRosterStale()
        if not VerifyPendingGMMove() then
            MarkGMMoveRequiredAfterRosterChange()
        end

        if addon.UI and addon.UI.Refresh then
            addon.UI.Refresh()
        end
    elseif event == "CHAT_MSG_ADDON" and message == ADDON_MESSAGE_PREFIX then
        if not HandleMultiRaidMessage(payload, sender) then
            HandleMonitoringMessage(payload, sender)
        end
    end
end)

function API.GetGMMoveView()
    return {
        status = gmMoveState.status,
        message = gmMoveState.message,
        targetGroup = gmMoveState.targetGroup,
        targetName = gmMoveState.targetName,
        requestedAt = gmMoveState.requestedAt,
        verifiedAt = gmMoveState.verifiedAt,
        ready = gmMoveState.status == "ready"
    }
end

function API.IsGMMoveReady()
    return gmMoveState.status == "ready"
end

function API.CanRecordRaid()
    return API.GetSessionMode() == SESSION_MODE_SINGLE
        and API.CanModifyRoster()
        and API.IsGMMoveReady()
end

function API.MoveGMToLastSpot()
    local layout
    local reason
    local target

    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        SetGMMoveState("failed", "Cannot move GM: Single Raid mode required.")
        return false, "MULTI_RAID_NOT_READY"
    end

    if not API.CanModifyRoster() then
        SetGMMoveState("failed", "Cannot move GM: setup is locked.")
        return false, "ROSTER_LOCKED"
    end

    if InCombatLockdown and InCombatLockdown() then
        SetGMMoveState("failed", "Cannot move GM: combat lockdown.")
        return false, "COMBAT_LOCKDOWN"
    end

    if not SwapRaidSubgroup then
        SetGMMoveState("failed", "Cannot move GM: raid swap API unavailable.")
        return false, "RAID_SWAP_UNAVAILABLE"
    end

    if not (UnitIsGroupLeader and UnitIsGroupLeader("player"))
        and not (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        and not (UnitIsRaidOfficer and UnitIsRaidOfficer("player"))
        and not (IsRaidLeader and IsRaidLeader())
        and not (IsRaidOfficer and IsRaidOfficer())
    then
        SetGMMoveState("failed", "Cannot move GM: raid leader or assistant required.")
        return false, "RAID_PERMISSION_REQUIRED"
    end

    layout, reason = FindLiveRaidLayout()

    if not layout then
        SetGMMoveState("failed", "Cannot move GM: " .. tostring(reason) .. ".")
        return false, reason
    end

    target = layout.targetMember

    if not target then
        SetGMMoveState("failed", "Cannot move GM: target member not found.")
        return false, "TARGET_MEMBER_NOT_FOUND"
    end

    if layout.gmSubgroup == layout.targetGroup then
        if layout.gmIndex == target.index then
            SetGMMoveState("ready", "GM already appears last in subgroup " .. tostring(layout.targetGroup) .. ". Record Raid is now available.", layout.targetGroup)
            return true, "GM_ALREADY_LAST", layout.targetGroup
        end

        SetGMMoveState("ready", "GM is already in the last used subgroup " .. tostring(layout.targetGroup) .. ". Record Raid is now available.", layout.targetGroup)
        return true, "GM_ALREADY_LAST_GROUP", layout.targetGroup
    end

    SetGMMoveState("moving", "Swapping GM with " .. tostring(target.name) .. " in subgroup " .. tostring(layout.targetGroup) .. "...", layout.targetGroup, target.name)
    SwapRaidSubgroup(layout.gmIndex, target.index)

    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if gmMoveState.status == "moving" then
                VerifyPendingGMMove()

                if addon.UI and addon.UI.Refresh then
                    addon.UI.Refresh()
                end
            end
        end)
    end

    return true, "GM_MOVE_STARTED", layout.targetGroup
end

function API.StartRaidNumbering()
    local nextNumber = 1
    local entries

    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        return 0, "MULTI_RAID_NOT_READY"
    end

    if not API.CanModifyRoster() then
        return 0, "ROSTER_LOCKED"
    end

    if not API.IsGMMoveReady() then
        return 0, "GM_MOVE_REQUIRED"
    end

    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0

    entries = GetCurrentRaidRosterEntries(GetLocalPlayerName())

    for index = 1, #entries do
        local entry = entries[index]

        if entry.name then
            numbersByName[entry.name] = nextNumber
            namesByNumber[nextNumber] = entry.name
            assignedCount = nextNumber
            nextNumber = nextNumber + 1
        end
    end

    assignmentActive = assignedCount > 0
    PersistActiveSessionState()
    BroadcastMonitoringState("ROSTER_RECORDED")

    return assignedCount
end

function API.StopRaidNumbering()
    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        return false, "MULTI_RAID_NOT_READY"
    end

    if not API.CanModifyRoster() then
        return false, "ROSTER_LOCKED"
    end

    assignmentActive = false
    SetGMMoveState("required", "Move GM to last spot before recording raid.")

    return true, "ROSTER_STOPPED"
end

function API.ResetRaidNumbering()
    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        return false, "MULTI_RAID_NOT_READY"
    end

    if not API.CanModifyRoster() then
        return false, "ROSTER_LOCKED"
    end

    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0
    assignmentActive = false
    currentRound = 0
    pendingRollRound = nil
    pendingRollMax = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil
    SetGMMoveState("required", "Move GM to last spot before recording raid.")
    PersistActiveSessionState()
    BroadcastMonitoringState("ROSTER_CLEARED")

    return true, "ROSTER_CLEARED"
end

function API.ResetAllData()
    StopMonitoringTicker()
    monitoringBroadcastEnabled = false
    monitoringLastSnapshot = nil
    monitoringObservedSender = nil
    monitoringLog = {}
    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0
    assignmentActive = false
    currentRound = 0
    pendingRollRound = nil
    pendingRollMax = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil
    SetGMMoveState("required", "Move GM to last spot before recording raid.")
    MicroGamesDB = {}
    EnsureSettings()
    EnsureRewardTemplates()
    EnsureHistory()
    BroadcastMonitoringState("RESET_ALL")

    return true
end

function API.HasRaidNumbers()
    return assignmentActive
end

function API.GetRaidNumberByName(name)
    if not name then
        return nil
    end

    return numbersByName[name]
end

function API.GetRaidNameByNumber(number)
    if not number then
        return nil
    end

    return namesByNumber[number]
end

function API.CountRaidNumbers()
    return assignedCount
end

function API.GetRaidNumberEntries()
    local entries = {}

    for number = 1, assignedCount do
        local name = namesByNumber[number]

        if name then
            entries[#entries + 1] = {
                number = number,
                name = name
            }
        end
    end

    return entries
end

function API.SetNumberWhisperText(text)
    local settings = EnsureSettings()

    if type(text) ~= "string" or text == "" then
        settings.numberWhisperText = "Your MG number is: XX"
        return settings.numberWhisperText
    end

    settings.numberWhisperText = text

    return settings.numberWhisperText
end

function API.GetNumberWhisperText()
    return EnsureSettings().numberWhisperText
end

function API.BuildNumberWhisperMessage(number)
    if not number then
        return nil
    end

    return BuildNumberMessage(number)
end

function API.SendNumberWhisperToName(name)
    local number = API.GetRaidNumberByName(name)

    if not assignmentActive or not number then
        return false
    end

    return SendWhisper(BuildNumberMessage(number), name)
end

function API.SendNumbers()
    local queuedCount = 0

    if not assignmentActive then
        return false, "NO_ACTIVE_NUMBERING"
    end

    if chatSendQueue.active or #chatSendQueue.items > 0 then
        return false, "SEND_QUEUE_ACTIVE"
    end

    ResetChatQueue("Single Raid number whispers")

    for number = 1, assignedCount do
        local name = namesByNumber[number]

        if name then
            QueueNumberWhisper(name, BuildNumberMessage(number), "Single Raid number whispers")
            queuedCount = queuedCount + 1
        end
    end

    return true, queuedCount
end

function API.GetCurrentRound()
    return currentRound
end

function API.HasPendingRoll()
    return pendingRollRound ~= nil
end

function API.HasInvalidRollPending()
    return lastInvalidRollRound ~= nil and lastInvalidRollRound == currentRound and not lastWinnerNumber
end

function API.GetPreviousRound()
    if currentRound <= 1 then
        return nil
    end

    return currentRound - 1
end

function API.ResetRounds()
    local session

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    currentRound = 0
    pendingRollMax = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil

    session = EnsureSettings().activeSession

    if type(session) == "table" and session.status == "active" then
        session.rounds = {}
        session.rewards = {}
    end

    PersistActiveSessionState()

    return true, "ROUNDS_RESET"
end

function API.SetRoundRollDelay(seconds)
    local settings = EnsureSettings()

    if type(seconds) ~= "number" or seconds < 0 then
        settings.roundRollDelay = 2
        return settings.roundRollDelay
    end

    settings.roundRollDelay = seconds

    return settings.roundRollDelay
end

function API.GetRoundRollDelay()
    return EnsureSettings().roundRollDelay
end

function API.GetSessionMode()
    return EnsureSettings().sessionMode
end

function API.GetSessionModeLabel(mode)
    mode = mode or API.GetSessionMode()

    if mode == SESSION_MODE_MULTI_COORDINATOR then
        return "Multi Raid - Coordinator"
    end

    if mode == SESSION_MODE_MULTI_ASSISTANT then
        return "Multi Raid - Assistant"
    end

    return "Single Raid"
end

function API.GetSessionModeOptions()
    return {
        {
            value = SESSION_MODE_SINGLE,
            label = "Single Raid"
        },
        {
            value = SESSION_MODE_MULTI_COORDINATOR,
            label = "Multi Raid - Coordinator"
        },
        {
            value = SESSION_MODE_MULTI_ASSISTANT,
            label = "Multi Raid - Assistant"
        }
    }
end

function API.CanChangeSessionMode()
    return not API.HasActiveGameSession()
        and EnsureMultiRaidState().gameStatus ~= "active"
        and not API.HasPendingRoll()
end

function API.SetSessionMode(mode)
    local settings = EnsureSettings()

    if mode ~= SESSION_MODE_SINGLE
        and mode ~= SESSION_MODE_MULTI_COORDINATOR
        and mode ~= SESSION_MODE_MULTI_ASSISTANT
    then
        return false, "INVALID_SESSION_MODE"
    end

    if not API.CanChangeSessionMode() then
        return false, "SESSION_MODE_LOCKED"
    end

    settings.sessionMode = mode

    return true, mode
end

function API.GetMultiRaidView()
    local state = EnsureMultiRaidState()
    local assistants = {}
    local log = {}

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        assistants[index] = {
            raidId = assistant.raidId,
            targetName = assistant.targetName,
            senderName = assistant.senderName,
            status = assistant.status,
            rosterStatus = assistant.rosterStatus,
            rosterReason = assistant.rosterReason,
            eligibleCount = assistant.eligibleCount,
            expectedCount = assistant.expectedCount,
            rosterVersion = assistant.rosterVersion,
            lastRosterAt = assistant.lastRosterAt,
            rangeStart = assistant.rangeStart,
            rangeEnd = assistant.rangeEnd,
            assignmentStatus = assistant.assignmentStatus,
            assignmentSentAt = assistant.assignmentSentAt,
            invitedAt = assistant.invitedAt,
            acceptedAt = assistant.acceptedAt,
            rejectedAt = assistant.rejectedAt,
            lastSeq = assistant.lastSeq,
            numberWhisperStatus = assistant.numberWhisperStatus,
            numberWhisperSentCount = assistant.numberWhisperSentCount,
            numberWhisperSentAt = assistant.numberWhisperSentAt,
            numberWhisperError = assistant.numberWhisperError,
            lastWinnerVerifyAt = assistant.lastWinnerVerifyAt,
            lastWinnerVerifyNumber = assistant.lastWinnerVerifyNumber,
            lastWinnerVerifyName = assistant.lastWinnerVerifyName,
            lastWinnerVerifyStatus = assistant.lastWinnerVerifyStatus
        }
    end

    for index = 1, #state.log do
        log[index] = state.log[index]
    end

    return {
        mode = API.GetSessionMode(),
        sessionId = state.sessionId,
        coordinator = state.coordinator,
        acceptedCoordinator = state.acceptedCoordinator,
        assistantRaidId = state.assistantRaidId,
        coordinatorRoster = state.coordinatorRoster,
        coordinatorRosterStatus = state.coordinatorRosterStatus,
        coordinatorRosterRecordedAt = state.coordinatorRosterRecordedAt,
        raidRanges = state.raidRanges,
        totalAssigned = state.totalAssigned,
        assignmentsStatus = state.assignmentsStatus,
        assignedAt = state.assignedAt,
        localRoster = state.localRoster,
        localRosterStatus = state.localRosterStatus,
        localRosterVersion = state.rosterVersion,
        localRosterRecordedAt = state.localRosterRecordedAt,
        localRosterSentAt = state.localRosterSentAt,
        assignedRoster = state.assignedRoster,
        assignedRangeStart = state.assignedRangeStart,
        assignedRangeEnd = state.assignedRangeEnd,
        assignmentStatus = state.assignmentStatus,
        assignmentReceivedAt = state.assignmentReceivedAt,
        numberWhisperStatus = state.numberWhisperStatus,
        numberWhisperSentCount = state.numberWhisperSentCount,
        numberWhisperSentAt = state.numberWhisperSentAt,
        gameStatus = state.gameStatus,
        startedAt = state.startedAt,
        stoppedAt = state.stoppedAt,
        lastRosterRequestedAt = state.lastRosterRequestedAt,
        pendingInvite = state.pendingInvite,
        assistants = assistants,
        log = log
    }
end

function API.GetSendQueueView()
    return {
        chat = {
            active = chatSendQueue.active,
            label = chatSendQueue.label,
            total = chatSendQueue.total,
            sent = chatSendQueue.sent,
            failed = chatSendQueue.failed,
            pending = #chatSendQueue.items,
            completedAt = chatSendQueue.completedAt,
            paused = chatSendQueue.paused,
            pauseReason = chatSendQueue.pauseReason
        },
        addon = {
            active = addonSendQueue.active,
            label = addonSendQueue.label,
            total = addonSendQueue.total,
            sent = addonSendQueue.sent,
            failed = addonSendQueue.failed,
            pending = #addonSendQueue.items,
            completedAt = addonSendQueue.completedAt,
            paused = addonSendQueue.paused,
            pauseReason = addonSendQueue.pauseReason
        }
    }
end

function API.CancelSendQueues()
    StopQueueTicker(chatSendQueue)
    StopQueueTicker(addonSendQueue)
    chatSendQueue.items = {}
    addonSendQueue.items = {}
    chatSendQueue.active = false
    addonSendQueue.active = false
    ClearQueuePause(chatSendQueue)
    ClearQueuePause(addonSendQueue)
    RefreshUI()

    return true, "SEND_QUEUES_CANCELLED"
end

function API.AddMultiRaidAssistant(name)
    local state
    local targetName = NormalizePlayerName(name)
    local assistant
    local ok, result

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if targetName == "" then
        return false, "ASSISTANT_NAME_REQUIRED"
    end

    state = EnsureCoordinatorSession()

    if API.HasActiveGameSession() or state.gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    if #state.assistants >= MULTI_RAID_MAX_ASSISTANTS then
        return false, "ASSISTANT_LIMIT_REACHED"
    end

    for index = 1, #state.assistants do
        if state.assistants[index].targetName == targetName or state.assistants[index].senderName == targetName then
            return false, "ASSISTANT_ALREADY_ADDED"
        end
    end

    assistant = {
        raidId = #state.assistants + 2,
        targetName = targetName,
        status = "invited",
        rosterStatus = "not_ready",
        invitedAt = GetTimestamp()
    }

    state.assistants[#state.assistants + 1] = assistant
    ok, result = SendMultiRaidWhisper("INVITE", targetName, state.sessionId, assistant.raidId)

    if ok then
        assistant.lastSeq = result
        AddMultiRaidLog("Invite sent to " .. targetName .. " as Raid " .. tostring(assistant.raidId) .. ".")
        return true, "INVITE_SENT"
    end

    assistant.status = "send_failed"
    AddMultiRaidLog("Invite failed for " .. targetName .. ": " .. tostring(result) .. ".")

    return false, result
end

function API.AcceptMultiRaidInvite()
    local state = EnsureMultiRaidState()
    local invite = state.pendingInvite
    local ok, result

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return false, "NOT_ASSISTANT_MODE"
    end

    if type(invite) ~= "table" then
        return false, "NO_PENDING_INVITE"
    end

    ok, result = SendMultiRaidWhisper("ACCEPT", invite.coordinator, invite.sessionId, invite.raidId)

    if not ok then
        AddMultiRaidLog("Accept failed: " .. tostring(result) .. ".")
        return false, result
    end

    state.sessionId = invite.sessionId
    state.acceptedCoordinator = invite.coordinator
    state.assistantRaidId = invite.raidId
    state.pendingInvite = nil
    AddMultiRaidLog("Accepted coordinator " .. tostring(state.acceptedCoordinator) .. ".")

    return true, "INVITE_ACCEPTED"
end

function API.RejectMultiRaidInvite()
    local state = EnsureMultiRaidState()
    local invite = state.pendingInvite
    local ok, result

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return false, "NOT_ASSISTANT_MODE"
    end

    if type(invite) ~= "table" then
        return false, "NO_PENDING_INVITE"
    end

    ok, result = SendMultiRaidWhisper("REJECT", invite.coordinator, invite.sessionId, invite.raidId)

    if not ok then
        AddMultiRaidLog("Reject failed: " .. tostring(result) .. ".")
        return false, result
    end

    AddMultiRaidLog("Rejected coordinator " .. tostring(invite.coordinator) .. ".")
    state.pendingInvite = nil

    return true, "INVITE_REJECTED"
end

function API.ClearMultiRaidSession()
    local settings = EnsureSettings()

    if API.HasActiveGameSession() or EnsureMultiRaidState().gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    settings.multiRaid = {}
    EnsureMultiRaidState()

    return true, "MULTI_RAID_CLEARED"
end

function API.RecordMultiRaidCoordinatorRoster()
    local state = EnsureCoordinatorSession()
    local entries

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if state.gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    if not IsInRaid or not IsInRaid() then
        state.coordinatorRosterStatus = "not_ready"
        AddMultiRaidLog("Cannot record Coordinator roster: not in raid.")
        return false, "NO_RAID"
    end

    entries = GetCurrentRaidRosterEntries(GetLocalPlayerName())

    if #entries <= 0 then
        state.coordinatorRoster = {}
        state.coordinatorRosterStatus = "not_ready"
        AddMultiRaidLog("Cannot record Coordinator roster: no eligible players.")
        return false, "NO_ELIGIBLE_PLAYERS"
    end

    state.coordinatorRoster = entries
    state.coordinatorRosterStatus = "recorded"
    state.coordinatorRosterRecordedAt = GetTimestamp()
    state.assignmentsStatus = nil
    AddMultiRaidLog("Coordinator roster recorded: " .. tostring(#entries) .. " eligible.")

    return true, #entries
end

local function AddGlobalAssignment(state, number, name, raidId, assistantName)
    state.globalAssignments[#state.globalAssignments + 1] = {
        number = number,
        name = name,
        raidId = raidId,
        assistantName = assistantName
    }
    state.globalNamesByNumber[number] = {
        name = name,
        raidId = raidId,
        assistantName = assistantName
    }
    state.globalNumbersByName[name] = number
end

local function SendAssistantAssignment(state, assistant)
    local target = assistant.senderName or assistant.targetName
    local roster = assistant.roster or {}
    local rangeText

    if not assistant.rangeStart or not assistant.rangeEnd then
        return false, "ASSISTANT_NOT_ASSIGNED"
    end

    rangeText = tostring(assistant.rangeStart) .. "-" .. tostring(assistant.rangeEnd)
    QueueMultiRaidWhisper("ASSIGN_BEGIN", target, state.sessionId, assistant.raidId, rangeText, tostring(#roster), "Assistant assignments")

    for index = 1, #roster do
        local number = assistant.rangeStart + index - 1

        QueueMultiRaidWhisper("ASSIGN_ROW", target, state.sessionId, assistant.raidId, tostring(number), roster[index].name, "Assistant assignments")
    end

    QueueMultiRaidWhisper("ASSIGN_END", target, state.sessionId, assistant.raidId, rangeText, tostring(#roster), "Assistant assignments", function()
        assistant.assignmentStatus = "sent"
        assistant.assignmentSentAt = GetTimestamp()
        AddMultiRaidLog("Assignment sent to " .. tostring(target) .. ".")
    end, function(item, reason)
        assistant.assignmentStatus = "send_failed"
        assistant.assignmentError = reason
        AddMultiRaidLog("Assignment send failed for " .. tostring(target) .. ": " .. tostring(reason) .. ".")
    end)

    assistant.assignmentStatus = "queued"
    assistant.assignmentQueuedAt = GetTimestamp()

    return true, "ASSIGN_QUEUED"
end

function API.AssignMultiRaidGlobalNumbers()
    local state = EnsureCoordinatorSession()
    local nextNumber = 1
    local coordinatorRoster = state.coordinatorRoster or {}
    local sentCount = 0
    local lastError = nil

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if state.gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    if addonSendQueue.active or #addonSendQueue.items > 0 then
        return false, "SEND_QUEUE_ACTIVE"
    end

    if #coordinatorRoster <= 0 then
        return false, "COORDINATOR_ROSTER_REQUIRED"
    end

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted" and assistant.rosterStatus ~= "received" then
            return false, "ASSISTANT_ROSTER_REQUIRED"
        end
    end

    state.globalAssignments = {}
    state.globalNamesByNumber = {}
    state.globalNumbersByName = {}
    state.raidRanges = {}
    StopQueueTicker(addonSendQueue)
    addonSendQueue.items = {}
    addonSendQueue.total = 0
    addonSendQueue.sent = 0
    addonSendQueue.failed = 0
    ClearQueuePause(addonSendQueue)
    addonSendQueue.label = "Assistant assignments"
    addonSendQueue.completedAt = nil

    state.raidRanges[1] = {
        raidId = 1,
        rangeStart = nextNumber,
        eligibleCount = #coordinatorRoster,
        assistantName = GetLocalPlayerName()
    }

    for index = 1, #coordinatorRoster do
        AddGlobalAssignment(state, nextNumber, coordinatorRoster[index].name, 1, GetLocalPlayerName())
        nextNumber = nextNumber + 1
    end

    state.raidRanges[1].rangeEnd = nextNumber - 1

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]
        local roster = assistant.roster or {}

        if assistant.status == "accepted" then
            assistant.rangeStart = nextNumber
            assistant.eligibleCount = #roster

            for rosterIndex = 1, #roster do
                AddGlobalAssignment(state, nextNumber, roster[rosterIndex].name, assistant.raidId, assistant.senderName or assistant.targetName)
                nextNumber = nextNumber + 1
            end

            assistant.rangeEnd = nextNumber - 1
            state.raidRanges[assistant.raidId] = {
                raidId = assistant.raidId,
                rangeStart = assistant.rangeStart,
                rangeEnd = assistant.rangeEnd,
                eligibleCount = #roster,
                assistantName = assistant.senderName or assistant.targetName
            }

            local ok, result = SendAssistantAssignment(state, assistant)

            if ok then
                sentCount = sentCount + 1
            else
                assistant.assignmentStatus = "send_failed"
                lastError = result
            end
        end
    end

    state.totalAssigned = nextNumber - 1
    state.assignmentsStatus = "assigned"
    state.assignedAt = GetTimestamp()
    AddMultiRaidLog("Global numbers assigned: " .. tostring(state.totalAssigned) .. " total; assignments sent: " .. tostring(sentCount) .. ".")

    if state.totalAssigned <= 0 then
        return false, "NO_ASSIGNMENTS"
    end

    if lastError then
        return false, lastError
    end

    return true, state.totalAssigned
end

function API.RecordMultiRaidLocalRoster()
    local state = EnsureMultiRaidState()
    local entries

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return false, "NOT_ASSISTANT_MODE"
    end

    if state.gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    if not IsInRaid or not IsInRaid() then
        state.localRosterStatus = "not_ready"
        AddMultiRaidLog("Cannot record local roster: not in raid.")
        return false, "NO_RAID"
    end

    entries = GetCurrentRaidRosterEntries(GetLocalPlayerName())

    if #entries <= 0 then
        state.localRoster = {}
        state.localRosterStatus = "not_ready"
        AddMultiRaidLog("Cannot record local roster: no eligible players.")
        return false, "NO_ELIGIBLE_PLAYERS"
    end

    state.rosterVersion = (state.rosterVersion or 0) + 1
    state.localRoster = entries
    state.localRosterStatus = "recorded"
    state.localRosterRecordedAt = GetTimestamp()
    state.localRosterSentAt = nil
    AddMultiRaidLog("Local roster recorded: " .. tostring(#entries) .. " eligible.")

    return true, #entries
end

function API.SendMultiRaidRoster()
    local state = EnsureMultiRaidState()
    local target = state.acceptedCoordinator
    local roster = state.localRoster or {}

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_ASSISTANT then
        return false, "NOT_ASSISTANT_MODE"
    end

    if state.gameStatus == "active" or API.HasPendingRoll() then
        return false, "SESSION_MODE_LOCKED"
    end

    if not target or not state.sessionId then
        return false, "NO_ACCEPTED_COORDINATOR"
    end

    if state.localRosterStatus == "stale" then
        SendMultiRaidWhisper("ROSTER_STALE", target, state.sessionId, state.assistantRaidId)
        return false, "ROSTER_STALE"
    end

    if #roster <= 0 then
        SendMultiRaidWhisper("ROSTER_NOT_READY", target, state.sessionId, state.assistantRaidId, "NOT_RECORDED")
        return false, "ROSTER_NOT_RECORDED"
    end

    if addonSendQueue.active or #addonSendQueue.items > 0 then
        return false, "SEND_QUEUE_ACTIVE"
    end

    StopQueueTicker(addonSendQueue)
    addonSendQueue.items = {}
    addonSendQueue.total = 0
    addonSendQueue.sent = 0
    addonSendQueue.failed = 0
    ClearQueuePause(addonSendQueue)
    addonSendQueue.label = "Assistant roster"
    addonSendQueue.completedAt = nil

    QueueMultiRaidWhisper("ROSTER_BEGIN", target, state.sessionId, state.assistantRaidId, tostring(#roster), tostring(state.rosterVersion or 0), "Assistant roster")

    for index = 1, #roster do
        QueueMultiRaidWhisper("ROSTER_ROW", target, state.sessionId, state.assistantRaidId, tostring(index), roster[index].name, "Assistant roster")
    end

    QueueMultiRaidWhisper("ROSTER_END", target, state.sessionId, state.assistantRaidId, tostring(#roster), tostring(state.rosterVersion or 0), "Assistant roster", function()
        state.localRosterStatus = "sent"
        state.localRosterSentAt = GetTimestamp()
        AddMultiRaidLog("Local roster sent: " .. tostring(#roster) .. " eligible.")
    end, function(item, reason)
        state.localRosterStatus = "send_failed"
        state.localRosterError = reason
        AddMultiRaidLog("Roster send failed: " .. tostring(reason) .. ".")
    end)

    state.localRosterStatus = "sending"
    state.localRosterQueuedAt = GetTimestamp()
    AddMultiRaidLog("Local roster queued: " .. tostring(#roster) .. " eligible.")

    return true, #roster
end

function API.RequestMultiRaidRosters()
    local state = EnsureMultiRaidState()
    local sentCount = 0
    local lastError = nil

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    EnsureCoordinatorSession()

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted" then
            local target = assistant.senderName or assistant.targetName
            local ok, result = SendMultiRaidWhisper("ROSTER_REQUEST", target, state.sessionId, assistant.raidId)

            if ok then
                assistant.rosterStatus = "requested"
                assistant.lastRosterRequestAt = GetTimestamp()
                sentCount = sentCount + 1
            else
                lastError = result
            end
        end
    end

    AddMultiRaidLog("Roster requests sent: " .. tostring(sentCount) .. ".")

    if sentCount > 0 then
        return true, sentCount
    end

    return false, lastError or "NO_ACCEPTED_ASSISTANTS"
end

function API.RequestMultiRaidWinnerVerification(assistantName, winnerNumber, winnerName, raidId)
    local state = EnsureMultiRaidState()
    local assistant = FindAssistantBySender(state, assistantName)
    local target
    local ok, result

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if not assistant or assistant.status ~= "accepted" then
        return false, "ASSISTANT_NOT_ACCEPTED"
    end

    target = assistant.senderName or assistant.targetName
    ok, result = SendMultiRaidWhisper(
        "VERIFY_WINNER",
        target,
        state.sessionId,
        raidId or assistant.raidId,
        tostring(winnerNumber or "-"),
        winnerName or "-"
    )

    if ok then
        AddMultiRaidLog("Winner verify requested from " .. tostring(target)
            .. " for #" .. tostring(winnerNumber or "-")
            .. " " .. tostring(winnerName or "-") .. ".")
        return true, "VERIFY_SENT"
    end

    AddMultiRaidLog("Winner verify request failed: " .. tostring(result) .. ".")

    return false, result
end

function API.RelayMultiRaidMessage(message, targetRaidId)
    local state = EnsureMultiRaidState()
    local sentCount = 0
    local lastError = nil

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if type(message) ~= "string" or message == "" then
        return false, "MESSAGE_REQUIRED"
    end

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted"
            and (not targetRaidId or assistant.raidId == targetRaidId)
        then
            local target = assistant.senderName or assistant.targetName
            local ok, result = SendMultiRaidWhisper("RELAY_RAID", target, state.sessionId, assistant.raidId, "RAID", message)

            if ok then
                sentCount = sentCount + 1
            else
                lastError = result
            end
        end
    end

    AddMultiRaidLog("Relay sent to assistants: " .. tostring(sentCount) .. " | " .. tostring(message))

    if sentCount > 0 then
        return true, sentCount
    end

    return false, lastError or "NO_ACCEPTED_ASSISTANTS"
end

function API.SendMultiRaidNumbers()
    local state = EnsureMultiRaidState()
    local queuedCount = 0
    local assistantCommandCount = 0
    local lastError = nil
    local hasLocalWhispers = false

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if state.assignmentsStatus ~= "assigned" or type(state.globalAssignments) ~= "table" then
        return false, "GLOBAL_ASSIGNMENTS_REQUIRED"
    end

    for index = 1, #state.globalAssignments do
        local entry = state.globalAssignments[index]

        if entry and entry.raidId == 1 and entry.name and entry.number then
            hasLocalWhispers = true
            break
        end
    end

    if hasLocalWhispers then
        if chatSendQueue.active or #chatSendQueue.items > 0 then
            return false, "SEND_QUEUE_ACTIVE"
        end

        ResetChatQueue("Coordinator number whispers", function(sent, failed)
            state.numberWhisperStatus = failed > 0 and "failed" or "sent"
            state.numberWhisperSentAt = GetTimestamp()
            state.numberWhisperSentCount = sent
            state.numberWhisperFailedCount = failed
            AddMultiRaidLog("Coordinator local number whispers completed: " .. tostring(sent) .. " sent, " .. tostring(failed) .. " failed.")
        end)
    end

    for index = 1, #state.globalAssignments do
        local entry = state.globalAssignments[index]

        if entry and entry.raidId == 1 and entry.name and entry.number then
            QueueNumberWhisper(entry.name, BuildNumberMessage(entry.number), "Coordinator number whispers")
            queuedCount = queuedCount + 1
        end
    end

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted" then
            local target = assistant.senderName or assistant.targetName
            local ok, result = SendMultiRaidWhisper("SEND_NUMBERS", target, state.sessionId, assistant.raidId)

            if ok then
                assistant.numberWhisperStatus = "requested"
                assistant.numberWhisperRequestedAt = GetTimestamp()
                assistantCommandCount = assistantCommandCount + 1
            else
                assistant.numberWhisperStatus = "send_failed"
                assistant.numberWhisperError = result
                lastError = result
            end
        end
    end

    state.numberWhisperStatus = queuedCount > 0 and "sending" or "requested"
    state.numberWhisperQueuedAt = GetTimestamp()
    state.numberWhisperQueuedCount = queuedCount
    AddMultiRaidLog("Number whisper dispatch: local " .. tostring(queuedCount)
        .. ", assistants " .. tostring(assistantCommandCount) .. ".")

    if lastError then
        return false, lastError
    end

    return true, queuedCount + assistantCommandCount
end

function API.StartMultiRaidGameSession()
    local state = EnsureCoordinatorSession()
    local sentCount = 0
    local lastError = nil

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if state.gameStatus == "active" then
        return false, "ACTIVE_MULTI_SESSION_EXISTS"
    end

    if state.assignmentsStatus ~= "assigned" or (state.totalAssigned or 0) <= 0 then
        return false, "GLOBAL_ASSIGNMENTS_REQUIRED"
    end

    currentRound = 0
    pendingRollRound = nil
    pendingRollMax = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil
    state.gameStatus = "active"
    state.startedAt = GetTimestamp()
    state.stoppedAt = nil
    state.activeSession = nil
    EnsureMultiRaidActiveHistorySession(state)

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted" then
            local target = assistant.senderName or assistant.targetName
            local ok, result = SendMultiRaidWhisper("GAME_START", target, state.sessionId, assistant.raidId, tostring(state.totalAssigned or 0))

            if ok then
                sentCount = sentCount + 1
            else
                lastError = result
            end
        end
    end

    SendRaidMessage("Multi raid game started. Players: " .. tostring(state.totalAssigned or 0))
    API.RelayMultiRaidMessage("Multi raid game started. Players: " .. tostring(state.totalAssigned or 0))
    AddMultiRaidLog("Multi game started. Assistant notifications: " .. tostring(sentCount) .. ".")

    if lastError then
        return false, lastError
    end

    return true, state.totalAssigned or 0
end

function API.StopMultiRaidGameSession()
    local state = EnsureMultiRaidState()
    local sentCount = 0
    local lastError = nil

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if state.gameStatus ~= "active" then
        return false, "NO_ACTIVE_MULTI_SESSION"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    state.gameStatus = "stopped"
    state.stoppedAt = GetTimestamp()

    if type(state.activeSession) == "table" then
        local history = EnsureHistory()

        state.activeSession.status = "stopped"
        state.activeSession.stoppedAt = state.stoppedAt
        state.activeSession.totalRounds = currentRound
        state.activeSession.finalAssignedCount = state.totalAssigned or 0
        state.activeSession.finalWinnerRound = lastWinnerRound
        state.activeSession.finalWinnerNumber = lastWinnerNumber
        state.activeSession.finalWinnerName = lastWinnerName
        state.activeSession.finalInvalidRollRound = lastInvalidRollRound
        state.activeSession.finalInvalidRollNumber = lastInvalidRollNumber
        state.activeSession.finalInvalidRollName = lastInvalidRollName
        state.activeSession.finalInvalidRollReason = lastInvalidRollReason
        state.activeSession.assistants = BuildMultiRaidAssistantSnapshot(state)
        history[#history + 1] = state.activeSession
        state.activeSession = nil
    end

    for index = 1, #state.assistants do
        local assistant = state.assistants[index]

        if assistant.status == "accepted" then
            local target = assistant.senderName or assistant.targetName
            local ok, result = SendMultiRaidWhisper("GAME_STOP", target, state.sessionId, assistant.raidId)

            if ok then
                sentCount = sentCount + 1
            else
                lastError = result
            end
        end
    end

    SendRaidMessage("Multi raid game stopped.")
    API.RelayMultiRaidMessage("Multi raid game stopped.")
    AddMultiRaidLog("Multi game stopped. Assistant notifications: " .. tostring(sentCount) .. ".")

    if lastError then
        return false, lastError
    end

    return true, "MULTI_GAME_STOPPED"
end

local function ResolveMultiRaidWinner(number)
    local state = EnsureMultiRaidState()
    local entry

    if type(state.globalNamesByNumber) ~= "table" then
        return nil
    end

    entry = state.globalNamesByNumber[number]

    if type(entry) ~= "table" then
        return nil
    end

    return entry
end

HandleMultiRaidRollResult = function(roundNumber, roll, rollMax)
    local winner = ResolveMultiRaidWinner(roll)
    local resultMessage = "Coordinator rolled " .. tostring(roll) .. " (1-" .. tostring(rollMax) .. ")"

    API.RelayMultiRaidMessage(resultMessage)

    if not winner then
        SetLastInvalidRoll(roundNumber, roll, "-", "NO_GLOBAL_ASSIGNMENT")
        RecordMultiRaidRollResult(roundNumber, roll, nil, true, "NO_GLOBAL_ASSIGNMENT")
        API.RelayMultiRaidMessage("Invalid roll #" .. tostring(roll) .. ": no global assignment. Roll again.")
        return
    end

    if winner.raidId == 1 then
        if not IsSnapshotPlayerOnline(winner.name) then
            SetLastInvalidRoll(roundNumber, roll, winner.name, "OFFLINE")
            RecordMultiRaidRollResult(roundNumber, roll, winner, true, "OFFLINE")
            API.RelayMultiRaidMessage("Offline winner #" .. tostring(roll) .. " " .. tostring(winner.name) .. ". Roll again.")
            return
        end

        SetLastWinner(roundNumber, roll)
        lastWinnerName = winner.name
        RecordMultiRaidRollResult(roundNumber, roll, winner, false, nil, "LOCAL_ONLINE")
        API.RelayMultiRaidMessage("Winner: #" .. tostring(roll) .. " " .. tostring(winner.name) .. " - Raid 1")
        return
    end

    SetLastWinner(roundNumber, roll)
    lastWinnerName = winner.name
    RecordMultiRaidRollResult(roundNumber, roll, winner, false, nil, "PENDING_ASSISTANT_VERIFY")
    API.RelayMultiRaidMessage("Winner pending verify: #" .. tostring(roll) .. " " .. tostring(winner.name) .. " - Raid " .. tostring(winner.raidId))
    API.RequestMultiRaidWinnerVerification(winner.assistantName, roll, winner.name, winner.raidId)
end

function API.MultiRaidRoundRoll()
    local state = EnsureMultiRaidState()
    local delay = API.GetRoundRollDelay()
    local rollRound
    local rollMax = state.totalAssigned or 0

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if rollMax <= 0 or state.assignmentsStatus ~= "assigned" then
        return false, "GLOBAL_ASSIGNMENTS_REQUIRED"
    end

    if state.gameStatus ~= "active" then
        return false, "NO_ACTIVE_MULTI_SESSION"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    if API.HasInvalidRollPending() then
        return false, "INVALID_ROLL_NEEDS_REROLL"
    end

    currentRound = currentRound + 1
    pendingRollRound = currentRound
    pendingRollMax = rollMax
    rollRound = currentRound
    SendRaidMessage(API.BuildRoundMessage(currentRound))
    API.RelayMultiRaidMessage(API.BuildRoundMessage(currentRound))
    API.RelayMultiRaidMessage("Rolling 1-" .. tostring(rollMax) .. "...")
    RecordMultiRaidSessionRound(state, currentRound, rollMax)
    AddMultiRaidLog("Multi round roll pending: ROUND " .. tostring(rollRound) .. " 1-" .. tostring(rollMax) .. ".")

    C_Timer.After(delay, function()
        if pendingRollRound == rollRound and pendingRollMax == rollMax then
            RandomRoll(1, rollMax)
        end
    end)

    C_Timer.After(delay + 10, function()
        if pendingRollRound == rollRound then
            pendingRollRound = nil
            pendingRollMax = nil
            API.RelayMultiRaidMessage("Roll timed out for ROUND " .. tostring(rollRound) .. ".")

            if addon.UI and addon.UI.Refresh then
                addon.UI.Refresh()
            end
        end
    end)

    return true, currentRound
end

function API.MultiRaidRerollCurrentRound()
    local state = EnsureMultiRaidState()
    local delay = API.GetRoundRollDelay()
    local rerollRound = currentRound
    local rollMax = state.totalAssigned or 0

    if API.GetSessionMode() ~= SESSION_MODE_MULTI_COORDINATOR then
        return false, "NOT_COORDINATOR_MODE"
    end

    if rollMax <= 0 or state.assignmentsStatus ~= "assigned" then
        return false, "GLOBAL_ASSIGNMENTS_REQUIRED"
    end

    if state.gameStatus ~= "active" then
        return false, "NO_ACTIVE_MULTI_SESSION"
    end

    if rerollRound <= 0 then
        return false, "NO_CURRENT_ROUND"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    pendingRollRound = rerollRound
    pendingRollMax = rollMax
    API.RelayMultiRaidMessage("Rerolling ROUND " .. tostring(rerollRound) .. " 1-" .. tostring(rollMax) .. "...")
    AddMultiRaidLog("Multi reroll pending: ROUND " .. tostring(rerollRound) .. " 1-" .. tostring(rollMax) .. ".")

    C_Timer.After(delay, function()
        if pendingRollRound == rerollRound and pendingRollMax == rollMax then
            RandomRoll(1, rollMax)
        end
    end)

    C_Timer.After(delay + 10, function()
        if pendingRollRound == rerollRound then
            pendingRollRound = nil
            pendingRollMax = nil
            API.RelayMultiRaidMessage("Reroll timed out for ROUND " .. tostring(rerollRound) .. ".")

            if addon.UI and addon.UI.Refresh then
                addon.UI.Refresh()
            end
        end
    end)

    return true, rerollRound
end

function API.SetRollCountdownSoundEnabled(enabled)
    local settings = EnsureSettings()

    settings.rollCountdownSoundEnabled = enabled and true or false

    return settings.rollCountdownSoundEnabled
end

function API.GetRollCountdownSoundEnabled()
    return EnsureSettings().rollCountdownSoundEnabled
end

function API.TestRollCountdownSound()
    local sent, reason

    if not API.GetRollCountdownSoundEnabled() then
        return false, "ROLL_COUNTDOWN_SOUND_DISABLED"
    end

    sent, reason = SendRaidWarningMessage("MicroGames roll countdown sound test.")

    if not sent then
        return false, reason
    end

    return true, "ROLL_COUNTDOWN_SOUND_TEST_SENT"
end

function API.BroadcastMonitoringState()
    return SendMonitoringState("MANUAL")
end

function API.StartMonitoringBroadcast()
    local ok, result

    if not API.HasActiveGameSession() then
        return false, "NO_ACTIVE_SESSION"
    end

    if not GetMonitoringBroadcastChannel() then
        return false, "NO_GROUP"
    end

    monitoringBroadcastEnabled = true
    ok, result = StartMonitoringTicker()

    if not ok then
        monitoringBroadcastEnabled = false
        return false, result
    end

    SendMonitoringState("LIVE_START")

    return true, "LIVE_STARTED"
end

function API.StopMonitoringBroadcast()
    SendMonitoringState("LIVE_STOP")
    monitoringBroadcastEnabled = false
    StopMonitoringTicker()

    return true, "LIVE_STOPPED"
end

function API.GetMonitoringBroadcastEnabled()
    return monitoringBroadcastEnabled
end

function API.ClearMonitoringLog()
    monitoringLog = {}
    monitoringLastSnapshot = nil
    monitoringObservedSender = nil
end

function API.GetMonitoringView()
    local logCopy = {}
    local channel = GetMonitoringBroadcastChannel()

    for index = 1, #monitoringLog do
        logCopy[index] = monitoringLog[index]
    end

    return {
        lastSnapshot = monitoringLastSnapshot,
        log = logCopy,
        channel = channel or "-",
        liveEnabled = monitoringBroadcastEnabled,
        liveInterval = MONITORING_LIVE_INTERVAL,
        observedSender = monitoringObservedSender,
        gameActive = API.HasActiveGameSession(),
        localState = BuildMonitoringSnapshot("LOCAL")
    }
end

function API.BuildRoundMessage(roundNumber)
    if not roundNumber then
        return nil
    end

    return "ROUND " .. tostring(roundNumber)
end

function API.BuildPreviousRoundMessage()
    return API.BuildRoundMessage(API.GetPreviousRound())
end

function API.BuildRollCommand()
    if assignedCount <= 0 then
        return nil
    end

    return "/roll 1-" .. tostring(assignedCount)
end

function API.BuildRerollButtonText()
    if currentRound <= 0 then
        return "Roll again"
    end

    return "Roll again for " .. tostring(API.BuildRoundMessage(currentRound))
end

function API.GetLastWinner()
    if not lastWinnerNumber then
        return nil
    end

    return {
        round = lastWinnerRound,
        number = lastWinnerNumber,
        name = lastWinnerName
    }
end

function API.GetLastInvalidRoll()
    if not lastInvalidRollNumber then
        return nil
    end

    return {
        round = lastInvalidRollRound,
        number = lastInvalidRollNumber,
        name = lastInvalidRollName,
        reason = lastInvalidRollReason
    }
end

function API.BuildLastWinnerText()
    if not lastWinnerNumber then
        if lastInvalidRollNumber then
            return "Invalid roll: #" .. tostring(lastInvalidRollNumber)
                .. " - " .. tostring(lastInvalidRollName or "-")
                .. " (" .. tostring(lastInvalidRollReason or "INVALID") .. ")"
        end

        return "Winner: -"
    end

    return "Winner: #" .. tostring(lastWinnerNumber) .. " - " .. tostring(lastWinnerName or "-")
end

function API.BuildWinnerMessage()
    if not lastWinnerRound then
        return nil
    end

    return "You win ROUND " .. tostring(lastWinnerRound) .. " come closer! :)"
end

function API.SendWinnerSay()
    local message = API.BuildWinnerMessage()

    if not message then
        return false
    end

    return SendSayMessage(message)
end

function API.SendWinnerWhisper()
    local message = API.BuildWinnerMessage()

    if not message or not lastWinnerName then
        return false
    end

    return SendWhisper(message, lastWinnerName)
end

function API.GetRewardTemplates()
    local templates = {}
    local savedTemplates = EnsureRewardTemplates()

    for index = 1, #savedTemplates do
        templates[index] = savedTemplates[index]
    end

    return templates
end

function API.AddRewardTemplate(text)
    local savedTemplates = EnsureRewardTemplates()

    if type(text) ~= "string" or text == "" then
        return false
    end

    if string.len(text) > REWARD_TEMPLATE_TEXT_LIMIT then
        text = string.sub(text, 1, REWARD_TEMPLATE_TEXT_LIMIT)
    end

    savedTemplates[#savedTemplates + 1] = text
    BroadcastMonitoringState("REWARD_TEMPLATE_ADDED")

    return true
end

function API.RemoveRewardTemplate(index)
    local savedTemplates = EnsureRewardTemplates()

    if type(index) ~= "number" or index < 1 or index > #savedTemplates then
        return false
    end

    table.remove(savedTemplates, index)
    BroadcastMonitoringState("REWARD_TEMPLATE_REMOVED")

    return true
end

function API.BuildRewardYellMessage(rewardText)
    if type(rewardText) ~= "string" or rewardText == "" then
        return nil
    end

    if lastWinnerName and lastWinnerRound then
        return "[" .. tostring(lastWinnerName) .. "]: " .. rewardText
    end

    if lastWinnerName then
        return "[" .. tostring(lastWinnerName) .. "]: " .. rewardText
    end

    return "Reward: " .. rewardText
end

function API.SendRewardYell(index)
    local savedTemplates = EnsureRewardTemplates()
    local rewardText = savedTemplates[index]
    local message
    local sent, reason

    if not rewardText or not lastWinnerNumber then
        return false
    end

    message = API.BuildRewardYellMessage(rewardText)

    if not message then
        return false
    end

    sent, reason = SendYellMessage(message)

    if not sent then
        return false, reason
    end

    RecordSessionReward(rewardText, message)
    PersistActiveSessionState()
    BroadcastMonitoringState("REWARD_SENT")

    return true
end

function API.StartGameSession()
    local settings = EnsureSettings()
    local session

    if API.GetSessionMode() ~= SESSION_MODE_SINGLE then
        return false, "MULTI_RAID_NOT_READY"
    end

    if type(settings.activeSession) == "table" and settings.activeSession.status == "active" then
        RestoreActiveSessionState()
        return false, "ACTIVE_SESSION_EXISTS"
    end

    if not assignmentActive and not API.IsGMMoveReady() then
        return false, "GM_MOVE_REQUIRED"
    end

    if not assignmentActive or assignedCount <= 0 then
        API.StartRaidNumbering()
    end

    if assignedCount <= 0 then
        return false, "NO_RAID_NUMBERS"
    end

    session = {
        status = "active",
        startedAt = GetTimestamp(),
        assignedCount = assignedCount,
        roster = GetRosterSnapshot(),
        currentRound = currentRound,
        rounds = {},
        rewards = {}
    }

    settings.activeSession = session
    PersistActiveSessionState()
    BroadcastMonitoringState("GAME_STARTED")

    return true, "GAME_STARTED"
end

function API.StopGameSession()
    local settings = EnsureSettings()
    local session = settings.activeSession
    local history

    if type(session) ~= "table" or session.status ~= "active" then
        return false, "NO_ACTIVE_SESSION"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    PersistActiveSessionState()

    session.status = "stopped"
    session.stoppedAt = GetTimestamp()
    session.totalRounds = currentRound
    session.finalAssignedCount = assignedCount
    session.finalWinnerRound = lastWinnerRound
    session.finalWinnerNumber = lastWinnerNumber
    session.finalWinnerName = lastWinnerName
    session.finalInvalidRollRound = lastInvalidRollRound
    session.finalInvalidRollNumber = lastInvalidRollNumber
    session.finalInvalidRollName = lastInvalidRollName
    session.finalInvalidRollReason = lastInvalidRollReason
    BroadcastMonitoringState("GAME_STOPPED")
    API.StopMonitoringBroadcast()

    history = EnsureHistory()
    history[#history + 1] = session
    settings.activeSession = nil
    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0
    assignmentActive = false
    currentRound = 0
    pendingRollRound = nil
    pendingRollMax = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
    lastInvalidRollRound = nil
    lastInvalidRollNumber = nil
    lastInvalidRollName = nil
    lastInvalidRollReason = nil
    SetGMMoveState("required", "Move GM to last spot before recording raid.")

    return true, "GAME_STOPPED"
end

function API.HasActiveGameSession()
    local session = EnsureSettings().activeSession

    return type(session) == "table" and session.status == "active"
end

function API.CanModifyRoster()
    return not API.HasActiveGameSession() and not API.HasPendingRoll()
end

function API.GetGameSessionSummary()
    local session = EnsureSettings().activeSession

    if type(session) ~= "table" or session.status ~= "active" then
        return {
            active = false
        }
    end

    return {
        active = true,
        startedAt = session.startedAt,
        assignedCount = session.assignedCount or assignedCount,
        currentRound = session.currentRound or currentRound
    }
end

function API.GetGameHistory()
    local history = EnsureHistory()
    local copy = {}

    for index = 1, #history do
        copy[index] = history[index]
    end

    return copy
end

function API.RoundRoll()
    local delay = API.GetRoundRollDelay()
    local rollRound
    local rollMax

    if not API.HasActiveGameSession() then
        return false, "NO_ACTIVE_SESSION"
    end

    if assignedCount <= 0 then
        return false, "NO_RAID_NUMBERS"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    if API.HasInvalidRollPending() then
        return false, "INVALID_ROLL_NEEDS_REROLL"
    end

    currentRound = currentRound + 1
    pendingRollRound = currentRound
    rollRound = currentRound
    rollMax = assignedCount
    pendingRollMax = rollMax
    RecordSessionRound(currentRound, rollMax)
    PersistActiveSessionState()

    SendRaidMessage(API.BuildRoundMessage(currentRound))
    ScheduleRollCountdown(rollRound, rollMax, delay)
    BroadcastMonitoringState("ROUND_ROLL")

    C_Timer.After(delay, function()
        if pendingRollRound == rollRound and pendingRollMax == rollMax then
            RandomRoll(1, rollMax)
        end
    end)

    C_Timer.After(delay + 10, function()
        if pendingRollRound == rollRound then
            pendingRollRound = nil
            pendingRollMax = nil
            PersistActiveSessionState()
            BroadcastMonitoringState("ROLL_TIMEOUT")

            if addon.UI and addon.UI.Refresh then
                addon.UI.Refresh()
            end
        end
    end)

    return true, currentRound
end

function API.RerollCurrentRound()
    local delay = API.GetRoundRollDelay()
    local rerollRound = currentRound
    local rollMax = assignedCount

    if not API.HasActiveGameSession() then
        return false, "NO_ACTIVE_SESSION"
    end

    if assignedCount <= 0 then
        return false, "NO_RAID_NUMBERS"
    end

    if rerollRound <= 0 then
        return false, "NO_CURRENT_ROUND"
    end

    if pendingRollRound then
        return false, "ROLL_PENDING"
    end

    pendingRollRound = rerollRound
    pendingRollMax = rollMax
    PersistActiveSessionState()
    ScheduleRollCountdown(rerollRound, rollMax, delay)
    BroadcastMonitoringState("REROLL")

    C_Timer.After(delay, function()
        if pendingRollRound == rerollRound and pendingRollMax == rollMax then
            RandomRoll(1, rollMax)
        end
    end)

    C_Timer.After(delay + 10, function()
        if pendingRollRound == rerollRound then
            pendingRollRound = nil
            pendingRollMax = nil
            PersistActiveSessionState()
            BroadcastMonitoringState("ROLL_TIMEOUT")

            if addon.UI and addon.UI.Refresh then
                addon.UI.Refresh()
            end
        end
    end)

    return true, rerollRound
end

API.AssignRaidNumbers = API.StartRaidNumbering
API.ClearRaidNumbers = API.ResetRaidNumbering
API.GetAssignedRaidCount = API.CountRaidNumbers
API.SendNumberWhispers = API.SendNumbers

RestoreActiveSessionState()
