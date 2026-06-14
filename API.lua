local addonName, addon = ...

addon.name = addonName
addon.API = addon.API or {}

local API = addon.API

local numbersByName = {}
local namesByNumber = {}
local assignedCount = 0
local assignmentActive = false
local currentRound = 0
local roundRollDelay = 2
local pendingRollRound = nil
local lastWinnerRound = nil
local lastWinnerNumber = nil
local lastWinnerName = nil
local numberWhisperText = "Your MG number is: XX"
local eventFrame = CreateFrame("Frame")

local function BuildNumberMessage(number)
    local numberText = tostring(number)
    local message, replacements = string.gsub(numberWhisperText, "XX", numberText)

    if replacements == 0 then
        message = numberWhisperText .. " " .. numberText
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

local function ParseRollMessage(message)
    local roll, minimum, maximum = string.match(message, "rolls (%d+) %((%d+)%-(%d+)%)")

    if not roll then
        return nil
    end

    return tonumber(roll), tonumber(minimum), tonumber(maximum)
end

local function SetLastWinner(roundNumber, number)
    lastWinnerRound = roundNumber
    lastWinnerNumber = number
    lastWinnerName = namesByNumber[number]
end

local function HandleSystemMessage(message)
    local roll, minimum, maximum

    if not pendingRollRound then
        return
    end

    roll, minimum, maximum = ParseRollMessage(message)

    if not roll or minimum ~= 1 or maximum ~= assignedCount then
        return
    end

    SetLastWinner(pendingRollRound, roll)
    pendingRollRound = nil

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

    assignmentActive = true

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
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
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
    if type(text) ~= "string" or text == "" then
        numberWhisperText = "Your MG number is: XX"
        return numberWhisperText
    end

    numberWhisperText = text

    return numberWhisperText
end

function API.GetNumberWhisperText()
    return numberWhisperText
end

function API.BuildNumberWhisperMessage(number)
    if not number then
        return nil
    end

    return BuildNumberMessage(number)
end

function API.SendNumberWhisperToName(name)
    local number = API.GetRaidNumberByName(name)

    if not number then
        return false
    end

    SendWhisper(BuildNumberMessage(number), name)

    return true
end

function API.SendNumbers()
    local sentCount = 0

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

function API.GetPreviousRound()
    if currentRound <= 1 then
        return nil
    end

    return currentRound - 1
end

function API.ResetRounds()
    currentRound = 0
    pendingRollRound = nil
    lastWinnerRound = nil
    lastWinnerNumber = nil
    lastWinnerName = nil
end

function API.SetRoundRollDelay(seconds)
    if type(seconds) ~= "number" or seconds < 0 then
        roundRollDelay = 2
        return roundRollDelay
    end

    roundRollDelay = seconds

    return roundRollDelay
end

function API.GetRoundRollDelay()
    return roundRollDelay
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

function API.RoundRoll()
    if assignedCount <= 0 then
        return false, "NO_RAID_NUMBERS"
    end

    currentRound = currentRound + 1
    pendingRollRound = currentRound

    SendRaidMessage(API.BuildRoundMessage(currentRound))

    C_Timer.After(roundRollDelay, function()
        RandomRoll(1, assignedCount)
    end)

    return true, currentRound
end

API.AssignRaidNumbers = API.StartRaidNumbering
API.ClearRaidNumbers = API.ResetRaidNumbering
API.GetAssignedRaidCount = API.CountRaidNumbers
API.SendNumberWhispers = API.SendNumbers
