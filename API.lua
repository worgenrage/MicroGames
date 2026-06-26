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

local function SendSayMessage(message)
    C_ChatInfo.SendChatMessage(message, "SAY")
end

local function SendYellMessage(message)
    C_ChatInfo.SendChatMessage(message, "YELL")
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

    if addon.UI and addon.UI.Refresh then
        addon.UI.Refresh()
    end
end

eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:SetScript("OnEvent", function(self, event, message)
    if event == "CHAT_MSG_SYSTEM" and message then
        HandleSystemMessage(message)
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

    return true
end

function API.RemoveRewardTemplate(index)
    local savedTemplates = EnsureRewardTemplates()

    if type(index) ~= "number" or index < 1 or index > #savedTemplates then
        return false
    end

    table.remove(savedTemplates, index)

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
