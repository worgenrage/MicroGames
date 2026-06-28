local addonName, addon = ...

addon.name = addonName
addon.API = addon.API or {}

local API = addon.API

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
local defaultRewardTemplates = {
    "10 GOLD!",
    "20 GOLD!",
    "KROLL BLADE BOSS"
}
local eventFrame = CreateFrame("Frame")
local ADDON_MESSAGE_PREFIX = "MicroGames"
local MONITORING_LOG_LIMIT = 8
local MONITORING_LIVE_INTERVAL = 1
local MONITORING_REWARD_LIMIT = 6
local monitoringLog = {}
local monitoringLastSnapshot = nil
local monitoringObservedSender = nil
local monitoringBroadcastEnabled = false
local monitoringBroadcastTicker = nil
local monitoringPrefixRegistered = false

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

local function GetTimestamp()
    return date("%Y-%m-%d %H:%M:%S")
end

local function SanitizeMonitoringValue(value)
    local text = tostring(value or "")

    text = string.gsub(text, "[|~\n\r]", " ")

    return text
end

local function BuildMonitoringRewardText()
    local rewards = EnsureRewardTemplates()
    local rewardText = {}
    local limit = math.min(#rewards, MONITORING_REWARD_LIMIT)

    for index = 1, limit do
        rewardText[#rewardText + 1] = SanitizeMonitoringValue(rewards[index])
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
        event = SanitizeMonitoringValue(eventName or "STATE"),
        sentAt = GetTimestamp(),
        sender = SanitizeMonitoringValue(UnitName("player") or "-"),
        session = sessionActive and "active" or "inactive",
        round = tostring(currentRound or 0),
        players = tostring(assignedCount or 0),
        pending = pendingRollRound and tostring(pendingRollRound) or "-",
        winnerNumber = lastWinnerNumber and tostring(lastWinnerNumber) or "-",
        winnerName = SanitizeMonitoringValue(lastWinnerName or "-"),
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

local function SendMonitoringState(eventName)
    local channel = GetMonitoringBroadcastChannel()
    local snapshot
    local result

    if not channel then
        return false, "NO_GROUP"
    end

    if not monitoringPrefixRegistered then
        return false, "PREFIX_NOT_REGISTERED"
    end

    snapshot = BuildMonitoringSnapshot(eventName)
    result = C_ChatInfo.SendAddonMessage(ADDON_MESSAGE_PREFIX, EncodeMonitoringSnapshot(snapshot), channel)

    if result == false then
        return false, "SEND_FAILED"
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

local function RecordSessionRollResult(roundNumber, rollNumber, winnerName)
    local session = EnsureSettings().activeSession
    local rounds
    local roundEntry

    if type(session) ~= "table" or type(session.rounds) ~= "table" then
        return
    end

    rounds = session.rounds

    for index = #rounds, 1, -1 do
        if rounds[index].round == roundNumber then
            roundEntry = rounds[index]
            roundEntry.rollNumber = rollNumber
            roundEntry.winnerName = winnerName
            roundEntry.rolledAt = GetTimestamp()

            if type(roundEntry.rolls) ~= "table" then
                roundEntry.rolls = {}
            end

            roundEntry.rolls[#roundEntry.rolls + 1] = {
                rollNumber = rollNumber,
                winnerName = winnerName,
                rolledAt = roundEntry.rolledAt,
                reroll = #roundEntry.rolls > 0
            }

            return
        end
    end
end

local function RecordSessionReward(rewardText, message)
    local session = EnsureSettings().activeSession

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

local function BuildNumberMessage(number)
    local numberText = tostring(number)
    local text = API.GetNumberWhisperText()
    local message, replacements = string.gsub(text, "XX", numberText)

    if replacements == 0 then
        message = text .. " " .. numberText
    end

    return message
end

local function SendWhisper(message, name)
    C_ChatInfo.SendChatMessage(message, "WHISPER", nil, name)
end

local function SendRaidMessage(message)
    C_ChatInfo.SendChatMessage(message, "RAID")
end

local function SendRaidWarningMessage(message)
    C_ChatInfo.SendChatMessage(message, "RAID_WARNING")
end

local function SendSayMessage(message)
    C_ChatInfo.SendChatMessage(message, "SAY")
end

local function SendYellMessage(message)
    C_ChatInfo.SendChatMessage(message, "YELL")
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

local function SetLastWinner(roundNumber, number)
    lastWinnerRound = roundNumber
    lastWinnerNumber = number
    lastWinnerName = namesByNumber[number]
end

local function HandleSystemMessage(message)
    local roller, roll, minimum, maximum
    local playerName

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

    SetLastWinner(pendingRollRound, roll)
    RecordSessionRollResult(pendingRollRound, roll, lastWinnerName)
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
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    monitoringPrefixRegistered = C_ChatInfo.RegisterAddonMessagePrefix(ADDON_MESSAGE_PREFIX) ~= false
end
eventFrame:SetScript("OnEvent", function(self, event, message, payload, channel, sender)
    if event == "CHAT_MSG_SYSTEM" and message then
        HandleSystemMessage(message)
    elseif event == "CHAT_MSG_ADDON" and message == ADDON_MESSAGE_PREFIX then
        HandleMonitoringMessage(payload, sender)
    end
end)

function API.StartRaidNumbering()
    local nextNumber = 1
    local numMembers = GetNumGroupMembers()

    numbersByName = {}
    namesByNumber = {}
    assignedCount = 0

    for raidIndex = 1, numMembers do
        local name = GetRaidRosterInfo(raidIndex)

        if name then
            numbersByName[name] = nextNumber
            namesByNumber[nextNumber] = name
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
    assignmentActive = false
end

function API.ResetRaidNumbering()
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
    PersistActiveSessionState()
    BroadcastMonitoringState("ROSTER_CLEARED")
end

function API.ResetAllData()
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

    SendWhisper(BuildNumberMessage(number), name)

    return true
end

function API.SendNumbers()
    local sentCount = 0

    if not assignmentActive then
        return 0
    end

    for number = 1, assignedCount do
        local name = namesByNumber[number]

        if name then
            SendWhisper(BuildNumberMessage(number), name)
            sentCount = sentCount + 1
        end
    end

    return sentCount
end

function API.GetCurrentRound()
    return currentRound
end

function API.HasPendingRoll()
    return pendingRollRound ~= nil
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

function API.SetRollCountdownSoundEnabled(enabled)
    local settings = EnsureSettings()

    settings.rollCountdownSoundEnabled = enabled and true or false

    return settings.rollCountdownSoundEnabled
end

function API.GetRollCountdownSoundEnabled()
    return EnsureSettings().rollCountdownSoundEnabled
end

function API.TestRollCountdownSound()
    if not API.GetRollCountdownSoundEnabled() then
        return false, "ROLL_COUNTDOWN_SOUND_DISABLED"
    end

    SendRaidWarningMessage("MicroGames roll countdown sound test.")

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

function API.BuildLastWinnerText()
    if not lastWinnerNumber then
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

    SendSayMessage(message)

    return true
end

function API.SendWinnerWhisper()
    local message = API.BuildWinnerMessage()

    if not message or not lastWinnerName then
        return false
    end

    SendWhisper(message, lastWinnerName)

    return true
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

    if not rewardText or not lastWinnerNumber then
        return false
    end

    message = API.BuildRewardYellMessage(rewardText)

    if not message then
        return false
    end

    SendYellMessage(message)
    RecordSessionReward(rewardText, message)
    PersistActiveSessionState()
    BroadcastMonitoringState("REWARD_SENT")

    return true
end

function API.StartGameSession()
    local settings = EnsureSettings()
    local session

    if type(settings.activeSession) == "table" and settings.activeSession.status == "active" then
        RestoreActiveSessionState()
        return false, "ACTIVE_SESSION_EXISTS"
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
