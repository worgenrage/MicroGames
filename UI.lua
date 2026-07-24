local addonName, addon = ...

addon.name = addonName
addon.UI = addon.UI or {}

local API = addon.API
local UI = addon.UI

local FRAME_WIDTH = 540
local FRAME_HEIGHT = 640
local COLLAPSED_FRAME_WIDTH = 220
local COLLAPSED_FRAME_HEIGHT = 72
local ROWS_PER_PAGE = 12
local REWARD_BUTTONS_PER_PAGE = 6
local REWARD_ROWS_PER_PAGE = 6
local HISTORY_ROWS_PER_PAGE = 5
local HISTORY_ROUND_ROWS_PER_PAGE = 6
local MONITORING_ROWS = 8

local frame
local collapseButton
local modeDropdown
local modeStatusText
local tradeEventFrame
local tabs = {}
local pages = {}
local rosterRows = {}
local controlRewardButtons = {}
local rewardButtons = {}
local rewardRows = {}
local historyRows = {}
local historyRoundRows = {}
local monitoringRows = {}
local multiAssistantRows = {}
local multiLogRows = {}
local rosterPage = 1
local rewardButtonPage = 1
local rewardSettingsPage = 1
local historyPage = 1
local historyRoundPage = 1
local selectedHistoryIndex = nil
local currentPageName = "control"
local collapsed = false
local collapsedForTrade = false
local statusText
local rosterStatusText
local activeText
local countText
local gameSessionText
local roundText
local previousRoundText
local nextRoundText
local rollText
local winnerPanel
local winnerText
local winnerNameText
local winnerMessageText
local whisperEditBox
local whisperPreviewText
local delayEditBox
local countdownSoundCheckBox
local rosterPageText
local controlRewardButtonPageText
local rewardsRewardButtonPageText
local rewardSettingsPageText
local historyPageText
local historyDetailText
local historyRoundPageText
local monitoringSummaryText
local monitoringLocalText
local monitoringStatusText
local monitoringLiveButton
local rewardEditBox
local resetAllConfirmText
local resetAllConfirmButton
local startGameButton
local stopGameButton
local roundRollButton
local rosterGMMoveButton
local rosterStartButton
local rosterSendButton
local rosterResetButton
local rerollButton
local multiCoordinatorFrame
local multiAssistantFrame
local assistantNameEditBox
local multiCoordinatorSummaryText
local multiAssistantSummaryText
local multiSetupStatusText
local multiAddAssistantButton
local multiCoordinatorClearButton
local multiRequestRostersButton
local multiRecordCoordinatorButton
local multiAssignNumbersButton
local multiSendNumbersButton
local multiStartButton
local multiStopButton
local multiAcceptButton
local multiRejectButton
local multiAssistantClearButton
local multiRecordLocalButton
local multiSendRosterButton

local function SetButtonEnabled(button, enabled)
    if not button then
        return
    end

    if enabled then
        button:Enable()
        button:SetAlpha(1)
    else
        button:Disable()
        button:SetAlpha(0.45)
    end
end

local function SetStatus(text)
    if statusText then
        statusText:SetText(text)
    end
end

local function RefreshModeControl()
    local mode = API.GetSessionMode()
    local locked = not API.CanChangeSessionMode()

    if modeDropdown then
        UIDropDownMenu_SetText(modeDropdown, API.GetSessionModeLabel(mode))

        if locked then
            UIDropDownMenu_DisableDropDown(modeDropdown)
        else
            UIDropDownMenu_EnableDropDown(modeDropdown)
        end
    end

    if modeStatusText then
        if locked then
            modeStatusText:SetText("Mode locked")
            modeStatusText:SetTextColor(1, 0.82, 0)
        else
            modeStatusText:SetText("")
        end
    end
end

local function IsSingleRaidMode()
    return API.GetSessionMode() == "single"
end

local function IsMultiCoordinatorMode()
    return API.GetSessionMode() == "multi_coordinator"
end

local function SetRosterStatus(text)
    if rosterStatusText then
        rosterStatusText:SetText(text)
    end
end

local function SetMultiSetupStatus(text)
    if multiSetupStatusText then
        multiSetupStatusText:SetText(text)
    end
end

local function BuildMultiLogText(entry)
    return tostring(entry.at or "-") .. " | " .. tostring(entry.message or "-")
end

local function BuildSendQueueStatusText()
    local view = API.GetSendQueueView()
    local chat = view.chat or {}
    local addonQueue = view.addon or {}
    local parts = {}

    if chat.active or chat.paused then
        parts[#parts + 1] = tostring(chat.label or "Chat")
            .. ": " .. tostring(chat.sent or 0)
            .. "/" .. tostring(chat.total or 0)
            .. " sent"

        if chat.paused then
            parts[#parts] = parts[#parts] .. " - paused by chat restrictions"
        end
    end

    if addonQueue.active or addonQueue.paused then
        parts[#parts + 1] = tostring(addonQueue.label or "Addon")
            .. ": " .. tostring(addonQueue.sent or 0)
            .. "/" .. tostring(addonQueue.total or 0)
            .. " sent"

        if addonQueue.paused then
            parts[#parts] = parts[#parts] .. " - paused by chat restrictions"
        end
    end

    if #parts <= 0 then
        return nil
    end

    return table.concat(parts, " | ")
end

local function RefreshMultiRaidSetup()
    local view = API.GetMultiRaidView()
    local assistants = view.assistants or {}
    local log = view.log or {}
    local queueView = API.GetSendQueueView()
    local chatQueueBusy = queueView.chat and (queueView.chat.active or queueView.chat.paused)
    local addonQueueBusy = queueView.addon and (queueView.addon.active or queueView.addon.paused)
    local gameActive = view.gameStatus == "active"
    local rollPending = API.HasPendingRoll()
    local acceptedCount = 0
    local allAcceptedRostersReady = true
    local localRosterReady = view.localRosterStatus == "recorded"
        or view.localRosterStatus == "send_failed"
        or view.localRosterStatus == "sent"

    for index = 1, #assistants do
        if assistants[index].status == "accepted" then
            acceptedCount = acceptedCount + 1

            if assistants[index].rosterStatus ~= "received" then
                allAcceptedRostersReady = false
            end
        end
    end

    if multiCoordinatorSummaryText then
        multiCoordinatorSummaryText:SetText("Session: " .. tostring(view.sessionId or "-")
            .. "\nCoordinator: " .. tostring(view.coordinator or "-")
            .. "\nGame: " .. tostring(view.gameStatus or "not started")
            .. "\nMain raid: " .. tostring(view.coordinatorRosterStatus or "not recorded")
            .. " | Eligible: " .. tostring(view.coordinatorRoster and #view.coordinatorRoster or 0)
            .. " | Total assigned: " .. tostring(view.totalAssigned or "-"))
    end

    for index = 1, #multiAssistantRows do
        local row = multiAssistantRows[index]
        local assistant = assistants[index]

        if assistant then
            local rosterText = assistant.rosterStatus or "not_ready"

            row:SetText("Raid " .. tostring(assistant.raidId or "-")
                .. " | " .. tostring(assistant.senderName or assistant.targetName or "-")
                .. " | " .. tostring(assistant.status or "-")
                .. " | " .. tostring(rosterText)
                .. " " .. tostring(assistant.eligibleCount or "-")
                .. " | " .. tostring(assistant.rangeStart or "-") .. "-" .. tostring(assistant.rangeEnd or "-")
                .. " | nums " .. tostring(assistant.numberWhisperStatus or "-"))
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end

    if multiAssistantSummaryText then
        if view.pendingInvite then
            multiAssistantSummaryText:SetText("Pending invite from: " .. tostring(view.pendingInvite.coordinator or "-")
                .. "\nSession: " .. tostring(view.pendingInvite.sessionId or "-")
                .. "\nAssigned raid: " .. tostring(view.pendingInvite.raidId or "-"))
        elseif view.acceptedCoordinator then
            multiAssistantSummaryText:SetText("Connected coordinator: " .. tostring(view.acceptedCoordinator)
                .. "\nSession: " .. tostring(view.sessionId or "-")
                .. "\nAssigned raid: " .. tostring(view.assistantRaidId or "-")
                .. "\nLocal roster: " .. tostring(view.localRosterStatus or "not recorded")
                .. " | Eligible: " .. tostring(view.localRoster and #view.localRoster or 0)
                .. "\nAssigned range: " .. tostring(view.assignedRangeStart or "-") .. "-" .. tostring(view.assignedRangeEnd or "-")
                .. " | Status: " .. tostring(view.assignmentStatus or "-")
                .. "\nGame: " .. tostring(view.gameStatus or "not started")
                .. " | Numbers: " .. tostring(view.numberWhisperStatus or "-"))
        else
            multiAssistantSummaryText:SetText("No pending Coordinator invite.\nSwitch to this mode, then ask the Coordinator to add your character name.")
        end
    end

    for index = 1, #multiLogRows do
        local row = multiLogRows[index]
        local entry = log[index]

        if entry then
            row:SetText(BuildMultiLogText(entry))
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end

    SetButtonEnabled(multiAddAssistantButton, not gameActive and not rollPending)
    SetButtonEnabled(multiCoordinatorClearButton, not gameActive and not rollPending)
    SetButtonEnabled(multiRequestRostersButton, acceptedCount > 0 and not gameActive and not rollPending)
    SetButtonEnabled(multiRecordCoordinatorButton, not gameActive and not rollPending)
    SetButtonEnabled(multiAssignNumbersButton,
        view.coordinatorRosterStatus == "recorded"
            and allAcceptedRostersReady
            and not gameActive
            and not rollPending
            and not addonQueueBusy)
    SetButtonEnabled(multiSendNumbersButton,
        view.assignmentsStatus == "assigned"
            and not gameActive
            and not rollPending
            and not chatQueueBusy
            and not addonQueueBusy)
    SetButtonEnabled(multiStartButton,
        view.assignmentsStatus == "assigned"
            and (view.totalAssigned or 0) > 0
            and not gameActive
            and not rollPending
            and not addonQueueBusy)
    SetButtonEnabled(multiStopButton, gameActive and not rollPending)

    SetButtonEnabled(multiAcceptButton, view.pendingInvite ~= nil and not gameActive)
    SetButtonEnabled(multiRejectButton, view.pendingInvite ~= nil and not gameActive)
    SetButtonEnabled(multiAssistantClearButton, not gameActive and not rollPending)
    SetButtonEnabled(multiRecordLocalButton, not gameActive and not rollPending)
    SetButtonEnabled(multiSendRosterButton,
        view.acceptedCoordinator ~= nil
            and localRosterReady
            and not gameActive
            and not rollPending
            and not addonQueueBusy)
end

local function UpdateSummary()
    local count = API.CountRaidNumbers()
    local round = API.GetCurrentRound()
    local previousRoundMessage = API.BuildPreviousRoundMessage()
    local rollCommand = API.BuildRollCommand()
    local nextRoundMessage = API.BuildRoundMessage(round + 1)
    local winner = API.GetLastWinner()
    local invalidRoll = API.GetLastInvalidRoll()
    local winnerMessage = API.BuildWinnerMessage()
    local session = API.GetGameSessionSummary()
    local canModifyRoster = API.CanModifyRoster()
    local singleRaidMode = IsSingleRaidMode()
    local multiCoordinatorMode = IsMultiCoordinatorMode()
    local invalidRollPending = API.HasInvalidRollPending()
    local multiView = API.GetMultiRaidView()
    local multiGameActive = multiView.gameStatus == "active"
    local sendQueueView = API.GetSendQueueView()
    local sendQueueActive = (sendQueueView.chat and (sendQueueView.chat.active or sendQueueView.chat.paused))
        or (sendQueueView.addon and (sendQueueView.addon.active or sendQueueView.addon.paused))
    local gmMoveView = API.GetGMMoveView()

    if activeText then
        if multiCoordinatorMode then
            activeText:SetText("Multi state: " .. tostring(multiView.gameStatus or "not started"))
        elseif API.HasRaidNumbers() then
            activeText:SetText("Numbering state: Active")
        else
            activeText:SetText("Numbering state: Inactive")
        end
    end

    if countText then
        if multiCoordinatorMode then
            countText:SetText("Global assigned players: " .. tostring(multiView.totalAssigned or 0))
        else
            countText:SetText("Recorded players: " .. tostring(count))
        end
    end

    if gameSessionText then
        if multiCoordinatorMode then
            if multiGameActive then
                gameSessionText:SetText("MULTI STARTED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(multiView.totalAssigned or 0))
                gameSessionText:SetTextColor(0.2, 1, 0.2)
            else
                gameSessionText:SetText("MULTI STOPPED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(multiView.totalAssigned or 0))
                gameSessionText:SetTextColor(1, 0.82, 0)
            end
        elseif session.active then
            gameSessionText:SetText("EVENT STARTED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(count))
            gameSessionText:SetTextColor(0.2, 1, 0.2)
        else
            gameSessionText:SetText("EVENT STOPPED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(count))
            gameSessionText:SetTextColor(1, 0.82, 0)
        end
    end

    SetButtonEnabled(startGameButton, singleRaidMode and not session.active)
    SetButtonEnabled(stopGameButton, session.active and not API.HasPendingRoll())
    SetButtonEnabled(rosterGMMoveButton, singleRaidMode and canModifyRoster and not API.HasRaidNumbers() and gmMoveView.status ~= "moving")
    SetButtonEnabled(rosterStartButton, singleRaidMode and API.CanRecordRaid())
    SetButtonEnabled(rosterSendButton, singleRaidMode and canModifyRoster and API.HasRaidNumbers() and count > 0 and not sendQueueActive)
    SetButtonEnabled(rosterResetButton, singleRaidMode and canModifyRoster)
    SetButtonEnabled(roundRollButton, (singleRaidMode and session.active and count > 0 and not API.HasPendingRoll() and not invalidRollPending)
        or (multiCoordinatorMode and multiGameActive and not API.HasPendingRoll() and not invalidRollPending))

    if rosterSendButton then
        rosterSendButton:SetText("Send Numbers (" .. tostring(count) .. ")")
    end

    if roundText then
        if round > 0 then
            roundText:SetText("Current round: " .. tostring(API.BuildRoundMessage(round)))
        else
            roundText:SetText("Current round: -")
        end
    end

    if previousRoundText then
        previousRoundText:SetText("Previous completed round: " .. (previousRoundMessage or "-"))
    end

    if nextRoundText then
        nextRoundText:SetText("Next round message: " .. tostring(nextRoundMessage))
    end

    if rollText then
        if multiCoordinatorMode and (multiView.totalAssigned or 0) > 0 then
            rollText:SetText("Next roll range: /roll 1-" .. tostring(multiView.totalAssigned))
        else
            rollText:SetText("Next roll range: " .. (rollCommand or "-"))
        end
    end

    if rerollButton then
        rerollButton:SetText(API.BuildRerollButtonText())
        SetButtonEnabled(rerollButton, (singleRaidMode and session.active and round > 0 and count > 0 and not API.HasPendingRoll())
            or (multiCoordinatorMode and multiGameActive and round > 0 and not API.HasPendingRoll()))
    end

    if winnerText then
        if winner then
            winnerText:SetText("Winner number: #" .. tostring(winner.number))
            winnerText:SetTextColor(1, 0.86, 0)
        elseif invalidRoll then
            winnerText:SetText("Invalid roll: #" .. tostring(invalidRoll.number))
            winnerText:SetTextColor(1, 0.35, 0.2)
        else
            winnerText:SetText("Winner number: -")
            winnerText:SetTextColor(1, 0.86, 0)
        end
    end

    if winnerNameText then
        if winner and winner.name then
            winnerNameText:SetText("Winner name: " .. tostring(winner.name))
            winnerNameText:SetTextColor(0.2, 1, 0.2)
        elseif invalidRoll then
            winnerNameText:SetText("Offline player: " .. tostring(invalidRoll.name or "-"))
            winnerNameText:SetTextColor(1, 0.35, 0.2)
        else
            winnerNameText:SetText("Winner name: -")
            winnerNameText:SetTextColor(0.2, 1, 0.2)
        end
    end

    if winnerPanel and winnerPanel.background then
        if winner then
            winnerPanel.background:SetColorTexture(0.08, 0.22, 0.08, 0.82)
        elseif invalidRoll then
            winnerPanel.background:SetColorTexture(0.28, 0.08, 0.04, 0.82)
        else
            winnerPanel.background:SetColorTexture(0.12, 0.12, 0.12, 0.65)
        end
    end

    if winnerMessageText then
        if invalidRoll then
            winnerMessageText:SetText("Offline winner. Roll again for this round.")
        elseif multiCoordinatorMode and multiView.manualWinnerCheck then
            winnerMessageText:SetText("Manual Assistant check required for Raid "
                .. tostring(multiView.manualWinnerCheck.raidId or "-") .. ".")
        else
            winnerMessageText:SetText("Winner message: " .. (winnerMessage or "-"))
        end
    end

    if whisperPreviewText then
        whisperPreviewText:SetText("Preview: " .. tostring(API.BuildNumberWhisperMessage(12)))
    end
end

local function RefreshRoster()
    local entries = API.GetRaidNumberEntries()
    local totalPages = math.max(1, math.ceil(#entries / ROWS_PER_PAGE))
    local mode = API.GetSessionMode()
    local queueText = BuildSendQueueStatusText()
    local sendQueueView = API.GetSendQueueView()
    local sendQueueActive = (sendQueueView.chat and (sendQueueView.chat.active or sendQueueView.chat.paused))
        or (sendQueueView.addon and (sendQueueView.addon.active or sendQueueView.addon.paused))
    local gmMoveView = API.GetGMMoveView()

    if multiCoordinatorFrame then
        if mode == "multi_coordinator" then
            multiCoordinatorFrame:Show()
        else
            multiCoordinatorFrame:Hide()
        end
    end

    if multiAssistantFrame then
        if mode == "multi_assistant" then
            multiAssistantFrame:Show()
        else
            multiAssistantFrame:Hide()
        end
    end

    RefreshMultiRaidSetup()

    if queueText then
        if mode == "single" then
            SetRosterStatus(queueText)
        else
            SetMultiSetupStatus(queueText)
        end
    elseif mode == "single" and not API.HasRaidNumbers() and gmMoveView.message then
        SetRosterStatus(gmMoveView.message)
    end

    if rosterPage > totalPages then
        rosterPage = totalPages
    end

    local startIndex = ((rosterPage - 1) * ROWS_PER_PAGE) + 1

    for rowIndex = 1, ROWS_PER_PAGE do
        local entry = entries[startIndex + rowIndex - 1]
        local row = rosterRows[rowIndex]

        if entry then
            row.nameValue = entry.name
            row.number:SetText(tostring(entry.number))
            row.name:SetText(entry.name)
            SetButtonEnabled(row.sendButton, API.CanModifyRoster() and API.HasRaidNumbers() and not sendQueueActive)
            row:Show()
        else
            row.nameValue = nil
            row:Hide()
        end
    end

    if rosterPageText then
        rosterPageText:SetText("Page " .. tostring(rosterPage) .. " / " .. tostring(totalPages))
    end
end

local function RefreshRewardButtons()
    local templates = API.GetRewardTemplates()
    local totalPages = math.max(1, math.ceil(#templates / REWARD_BUTTONS_PER_PAGE))
    local startIndex
    local function UpdateButton(button, rewardIndex, text)
        if not button then
            return
        end

        if text then
            button.rewardIndex = rewardIndex
            button:SetText(text)
            button:Show()
        else
            button.rewardIndex = nil
            button:Hide()
        end
    end

    if rewardButtonPage > totalPages then
        rewardButtonPage = totalPages
    end

    startIndex = ((rewardButtonPage - 1) * REWARD_BUTTONS_PER_PAGE) + 1

    for buttonIndex = 1, REWARD_BUTTONS_PER_PAGE do
        local rewardIndex = startIndex + buttonIndex - 1
        local text = templates[rewardIndex]
        UpdateButton(controlRewardButtons[buttonIndex], rewardIndex, text)
        UpdateButton(rewardButtons[buttonIndex], rewardIndex, text)
    end

    if controlRewardButtonPageText then
        controlRewardButtonPageText:SetText("Rewards " .. tostring(rewardButtonPage) .. " / " .. tostring(totalPages))
    end

    if rewardsRewardButtonPageText then
        rewardsRewardButtonPageText:SetText("Rewards " .. tostring(rewardButtonPage) .. " / " .. tostring(totalPages))
    end
end

local function RefreshRewardSettings()
    local templates = API.GetRewardTemplates()
    local totalPages = math.max(1, math.ceil(#templates / REWARD_ROWS_PER_PAGE))
    local startIndex

    if rewardSettingsPage > totalPages then
        rewardSettingsPage = totalPages
    end

    startIndex = ((rewardSettingsPage - 1) * REWARD_ROWS_PER_PAGE) + 1

    for rowIndex = 1, REWARD_ROWS_PER_PAGE do
        local rewardIndex = startIndex + rowIndex - 1
        local text = templates[rewardIndex]
        local row = rewardRows[rowIndex]

        if text then
            row.rewardIndex = rewardIndex
            row.text:SetText(text)
            row:Show()
        else
            row.rewardIndex = nil
            row:Hide()
        end
    end

    if rewardSettingsPageText then
        rewardSettingsPageText:SetText("Page " .. tostring(rewardSettingsPage) .. " / " .. tostring(totalPages))
    end
end

local function BuildHistoryRowText(session, index)
    local startedAt = session.startedAt or "-"
    local stoppedAt = session.stoppedAt or "-"
    local rounds = session.totalRounds or session.currentRound or 0
    local players = session.finalAssignedCount or session.assignedCount or 0
    local sessionType = session.sessionType == "multi" and "Multi" or "Single"

    return "#" .. tostring(index) .. "  " .. sessionType .. "  " .. tostring(startedAt)
        .. " - rounds " .. tostring(rounds)
        .. " - players " .. tostring(players)
        .. " - stopped " .. tostring(stoppedAt)
end

local function HistoryColor(text, color)
    return "|cff" .. color .. tostring(text) .. "|r"
end

local function CompactTime(timestamp)
    local timeText

    if type(timestamp) ~= "string" then
        return "-"
    end

    timeText = string.match(timestamp, "%d%d%d%d%-%d%d%-%d%d (%d%d:%d%d:%d%d)")

    return timeText or timestamp
end

local function BuildHistoryDetailText(session, index)
    local lines = {}
    local rounds = session.rounds or {}
    local rewards = session.rewards or {}
    local winnerName = session.finalWinnerName or "-"
    local winnerNumber = session.finalWinnerNumber or "-"
    local sessionType = session.sessionType == "multi" and "Multi Raid" or "Single Raid"

    lines[#lines + 1] = "Session #" .. tostring(index) .. " - " .. sessionType
    lines[#lines + 1] = "Started: " .. tostring(session.startedAt or "-")
    lines[#lines + 1] = "Stopped: " .. tostring(session.stoppedAt or "-")
    lines[#lines + 1] = "Players: " .. tostring(session.finalAssignedCount or session.assignedCount or 0)
    lines[#lines + 1] = "Rounds: " .. tostring(session.totalRounds or session.currentRound or #rounds)
    lines[#lines + 1] = "Final winner: #" .. tostring(winnerNumber) .. " - " .. tostring(winnerName)
    lines[#lines + 1] = "Rewards sent: " .. tostring(#rewards)

    if session.sessionType == "multi" then
        local ranges = session.raidRanges or {}
        local rangeText = {}

        lines[#lines + 1] = "Multi session: " .. tostring(session.sessionId or "-")
        lines[#lines + 1] = "Coordinator: " .. tostring(session.coordinator or "-")

        for raidId, range in pairs(ranges) do
            if type(range) == "table" then
                rangeText[#rangeText + 1] = "R" .. tostring(raidId)
                    .. " " .. tostring(range.rangeStart or "-")
                    .. "-" .. tostring(range.rangeEnd or "-")
                    .. " (" .. tostring(range.eligibleCount or 0) .. ")"
            end
        end

        if #rangeText > 0 then
            lines[#lines + 1] = "Raid ranges: " .. table.concat(rangeText, "; ")
        end
    end

    return table.concat(lines, "\n")
end

local function BuildRewardsByRound(session)
    local rewards = session.rewards or {}
    local rewardsByRound = {}

    for index = 1, #rewards do
        local reward = rewards[index]
        local roundNumber = reward.round or 0
        local rewardText = tostring(reward.reward or "-")
        local sentAt = CompactTime(reward.sentAt)
        local line = HistoryColor(rewardText, "9cff9c") .. " at " .. sentAt

        if type(rewardsByRound[roundNumber]) ~= "table" then
            rewardsByRound[roundNumber] = {}
        end

        rewardsByRound[roundNumber][#rewardsByRound[roundNumber] + 1] = line
    end

    return rewardsByRound
end

local function BuildRoundHistoryText(round, rewardsByRound)
    local rollNumber = round.rollNumber or "-"
    local winnerName = round.winnerName or "-"
    local rolledAt = CompactTime(round.rolledAt or round.announcedAt)
    local roundNumber = round.round or "?"
    local rewards = rewardsByRound[round.round or 0]
    local rewardText = "Reward: -"
    local invalidText = nil
    local winnerRaidText = ""
    local verifyText = ""

    if type(rewards) == "table" and #rewards > 0 then
        rewardText = "Reward: " .. table.concat(rewards, "; ")
    end

    if round.winnerRaidId then
        winnerRaidText = " R" .. tostring(round.winnerRaidId)
    end

    if round.verifyStatus then
        verifyText = " | " .. tostring(round.verifyStatus)
    end

    if round.invalidRollNumber then
        invalidText = " | Invalid #" .. tostring(round.invalidRollNumber)
            .. " " .. HistoryColor(round.invalidWinnerName or "-", "ff8060")
            .. (round.invalidWinnerRaidId and (" R" .. tostring(round.invalidWinnerRaidId)) or "")
            .. " (" .. tostring(round.invalidReason or "INVALID") .. ")"
    end

    return "R" .. tostring(roundNumber)
        .. " | " .. tostring(rolledAt)
        .. " | #" .. tostring(rollNumber)
        .. " " .. HistoryColor(winnerName, "80ff80")
        .. winnerRaidText
        .. verifyText
        .. (invalidText or "")
        .. " | " .. rewardText
end

local function RefreshHistoryRounds(session)
    local rounds = {}
    local rewardsByRound = {}
    local totalPages
    local startIndex

    if type(session) == "table" then
        rounds = session.rounds or {}
        rewardsByRound = BuildRewardsByRound(session)
    end

    totalPages = math.max(1, math.ceil(#rounds / HISTORY_ROUND_ROWS_PER_PAGE))

    if historyRoundPage > totalPages then
        historyRoundPage = totalPages
    end

    startIndex = ((historyRoundPage - 1) * HISTORY_ROUND_ROWS_PER_PAGE) + 1

    for rowIndex = 1, HISTORY_ROUND_ROWS_PER_PAGE do
        local round = rounds[startIndex + rowIndex - 1]
        local row = historyRoundRows[rowIndex]

        if row then
            if round then
                row.text:SetText(BuildRoundHistoryText(round, rewardsByRound))
                row:Show()
            else
                row:Hide()
            end
        end
    end

    if historyRoundPageText then
        historyRoundPageText:SetText("Rounds " .. tostring(historyRoundPage) .. " / " .. tostring(totalPages))
    end
end

local function RefreshHistory()
    local history = API.GetGameHistory()
    local totalPages = math.max(1, math.ceil(#history / HISTORY_ROWS_PER_PAGE))
    local startIndex

    if historyPage > totalPages then
        historyPage = totalPages
    end

    if selectedHistoryIndex and selectedHistoryIndex > #history then
        selectedHistoryIndex = nil
    end

    if not selectedHistoryIndex and #history > 0 then
        selectedHistoryIndex = #history
        historyPage = math.ceil(selectedHistoryIndex / HISTORY_ROWS_PER_PAGE)
        historyRoundPage = 1
    end

    startIndex = ((historyPage - 1) * HISTORY_ROWS_PER_PAGE) + 1

    for rowIndex = 1, HISTORY_ROWS_PER_PAGE do
        local historyIndex = startIndex + rowIndex - 1
        local session = history[historyIndex]
        local row = historyRows[rowIndex]

        if row then
            if session then
                row.historyIndex = historyIndex
                row.text:SetText(BuildHistoryRowText(session, historyIndex))
                row:Show()
            else
                row.historyIndex = nil
                row:Hide()
            end
        end
    end

    if historyPageText then
        historyPageText:SetText("Page " .. tostring(historyPage) .. " / " .. tostring(totalPages))
    end

    if historyDetailText then
        if selectedHistoryIndex and history[selectedHistoryIndex] then
            historyDetailText:SetText(BuildHistoryDetailText(history[selectedHistoryIndex], selectedHistoryIndex))
            RefreshHistoryRounds(history[selectedHistoryIndex])
        else
            historyDetailText:SetText("No completed sessions yet.")
            RefreshHistoryRounds(nil)
        end
    end
end

local function BuildMonitoringSnapshotText(snapshot)
    local lines = {}
    local rewardLines = {}

    if type(snapshot) ~= "table" then
        return "No live remote monitoring data received."
    end

    lines[#lines + 1] = "Source: " .. tostring(snapshot.sender or "-")
    lines[#lines + 1] = "Event: " .. tostring(snapshot.event or "-") .. " at " .. tostring(snapshot.sentAt or "-")
    lines[#lines + 1] = "Session: " .. tostring(snapshot.session or "-") .. " | Round: " .. tostring(snapshot.round or "-") .. " | Players: " .. tostring(snapshot.players or "-")
    lines[#lines + 1] = "Pending roll: " .. tostring(snapshot.pending or "-")
    lines[#lines + 1] = "Winner: #" .. tostring(snapshot.winnerNumber or "-") .. " - " .. tostring(snapshot.winnerName or "-")
    lines[#lines + 1] = "Received: " .. tostring(snapshot.receivedAt or "-")

    if type(snapshot.rewards) == "table" and #snapshot.rewards > 0 then
        for index = 1, #snapshot.rewards do
            rewardLines[#rewardLines + 1] = tostring(index) .. ". " .. tostring(snapshot.rewards[index])
        end

        lines[#lines + 1] = "Rewards (" .. tostring(snapshot.rewardCount or #snapshot.rewards) .. "): " .. table.concat(rewardLines, " | ")
    else
        lines[#lines + 1] = "Rewards: -"
    end

    return table.concat(lines, "\n")
end

local function BuildMonitoringLocalText(view)
    local localState = view.localState or {}

    return "Broadcast channel: " .. tostring(view.channel or "-")
        .. "\nLocal role: " .. (view.liveEnabled and "GM broadcaster" or "Observer")
        .. " | Observed GM: " .. tostring(view.observedSender or "-")
        .. "\nGame session: " .. (view.gameActive and "STARTED" or "STOPPED")
        .. "\nLive broadcast: " .. (view.liveEnabled and "ON" or "OFF")
        .. " | Interval: " .. tostring(view.liveInterval or "-") .. "s"
        .. "\nLocal session: " .. tostring(localState.session or "-")
        .. " | Round: " .. tostring(localState.round or "-")
        .. " | Players: " .. tostring(localState.players or "-")
        .. "\nLocal pending: " .. tostring(localState.pending or "-")
        .. " | Winner: #" .. tostring(localState.winnerNumber or "-")
        .. " - " .. tostring(localState.winnerName or "-")
end

local function BuildMonitoringLogText(entry)
    return tostring(entry.receivedAt or "-")
        .. " | " .. tostring(entry.sender or "-")
        .. " | " .. tostring(entry.event or "-")
        .. " | R" .. tostring(entry.round or "-")
        .. " | P" .. tostring(entry.players or "-")
        .. " | Pending " .. tostring(entry.pending or "-")
        .. " | " .. tostring(entry.winnerName or "-")
end

local function RefreshMonitoring()
    local view = API.GetMonitoringView()
    local log = view.log or {}

    if monitoringSummaryText then
        monitoringSummaryText:SetText(BuildMonitoringSnapshotText(view.lastSnapshot))
    end

    if monitoringLocalText then
        monitoringLocalText:SetText(BuildMonitoringLocalText(view))
    end

    if monitoringLiveButton then
        monitoringLiveButton:SetText(view.liveEnabled and "Stop GM Live" or "Start GM Live")
        SetButtonEnabled(monitoringLiveButton, view.liveEnabled or view.gameActive)
    end

    for rowIndex = 1, MONITORING_ROWS do
        local row = monitoringRows[rowIndex]
        local entry = log[rowIndex]

        if row then
            if entry then
                row.text:SetText(BuildMonitoringLogText(entry))
                row:Show()
            else
                row:Hide()
            end
        end
    end
end

local function RefreshAll()
    RefreshModeControl()
    UpdateSummary()
    RefreshRoster()
    RefreshRewardButtons()
    RefreshRewardSettings()
    RefreshHistory()
    RefreshMonitoring()

    if whisperEditBox then
        whisperEditBox:SetText(API.GetNumberWhisperText())
    end

    if delayEditBox then
        delayEditBox:SetText(tostring(API.GetRoundRollDelay()))
    end

    if countdownSoundCheckBox then
        countdownSoundCheckBox:SetChecked(API.GetRollCountdownSoundEnabled())
    end

    if rewardEditBox then
        rewardEditBox:SetText("")
    end
end

local function InitializeModeDropdown(self)
    local options = API.GetSessionModeOptions()

    for index = 1, #options do
        local option = options[index]
        local info = UIDropDownMenu_CreateInfo()

        info.text = option.label
        info.value = option.value
        info.checked = option.value == API.GetSessionMode()
        info.func = function(button)
            local ok, result = API.SetSessionMode(button.value)

            if ok then
                currentPageName = "control"
                SetStatus("Mode set to " .. API.GetSessionModeLabel(button.value) .. ".")
            elseif result == "SESSION_MODE_LOCKED" then
                SetStatus("Cannot change mode while a session or roll is active.")
            else
                SetStatus("Cannot change mode: " .. tostring(result))
            end

            RefreshAll()
        end

        UIDropDownMenu_AddButton(info)
    end
end

local function SetCollapsed(value)
    local tab

    if not frame then
        return
    end

    collapsed = value and true or false

    if collapsed then
        frame:SetSize(COLLAPSED_FRAME_WIDTH, COLLAPSED_FRAME_HEIGHT)

        for _, page in pairs(pages) do
            page:Hide()
        end

        for index = 1, #tabs do
            tabs[index]:Hide()
        end

        if frame.title then
            frame.title:SetText("MicroGames")
        end

        if collapseButton then
            collapseButton:SetText("Max")
        end

        if modeDropdown then
            modeDropdown:Hide()
        end

        if modeStatusText then
            modeStatusText:Hide()
        end

        return
    end

    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)

    if modeDropdown then
        modeDropdown:Show()
    end

    if modeStatusText then
        modeStatusText:Show()
    end

    for index = 1, #tabs do
        tabs[index]:Show()
    end

    for name, page in pairs(pages) do
        if name == currentPageName then
            page:Show()
        else
            page:Hide()
        end
    end

    for index = 1, #tabs do
        tab = tabs[index]

        if tab.pageName == currentPageName then
            PanelTemplates_SelectTab(tab)
            PanelTemplates_SetTab(frame, index)
        else
            PanelTemplates_DeselectTab(tab)
        end
    end

    if frame.title then
        frame.title:SetText("MicroGames")
    end

    if collapseButton then
        collapseButton:SetText("Min")
    end

    RefreshAll()
end

local function ShowPage(pageName)
    local index

    currentPageName = pageName or currentPageName

    if collapsed then
        return
    end

    for name, page in pairs(pages) do
        if name == currentPageName then
            page:Show()
        else
            page:Hide()
        end
    end

    for i = 1, #tabs do
        if tabs[i].pageName == currentPageName then
            index = i
            PanelTemplates_SelectTab(tabs[i])
        else
            PanelTemplates_DeselectTab(tabs[i])
        end
    end

    if index then
        PanelTemplates_SetTab(frame, index)
    end

    RefreshAll()
end

local function CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateValue(parent, x, y, width)
    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    value:SetWidth(width)
    value:SetJustifyH("LEFT")
    return value
end

local function CreateSeparator(parent, y, width)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    line:SetSize(width or 410, 2)
    line:SetColorTexture(0.74, 0.74, 0.70, 0.72)
    return line
end

local function CreateButton(parent, text, x, y, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetSize(width, height)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateEditBox(parent, x, y, width, height)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    editBox:SetSize(width, height)
    editBox:SetAutoFocus(false)
    return editBox
end

local function CreateCheckBox(parent, text, x, y, onClick)
    local checkBox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkBox:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    checkBox:SetSize(24, 24)
    checkBox.text = checkBox:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    checkBox.text:SetPoint("LEFT", checkBox, "RIGHT", 4, 0)
    checkBox.text:SetText(text)
    checkBox:SetScript("OnClick", onClick)
    return checkBox
end

local function CreateControlPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    roundText = CreateValue(page, 0, 0, 190)
    previousRoundText = CreateValue(page, 210, 0, 200)
    nextRoundText = CreateValue(page, 0, -22, 250)
    rollText = CreateValue(page, 260, -22, 150)
    countText = CreateValue(page, 0, -44, 160)
    activeText = CreateValue(page, 180, -44, 180)

    CreateSeparator(page, -66)

    roundRollButton = CreateButton(page, "Round Roll", 0, -78, 410, 42, function()
        local ok, result

        if IsMultiCoordinatorMode() then
            ok, result = API.MultiRaidRoundRoll()
        else
            ok, result = API.RoundRoll()
        end

        if ok then
            SetStatus("Round " .. tostring(result) .. " announced. Roll pending.")
        elseif type(result) == "string" and string.find(result, "ROUND_ANNOUNCEMENT_FAILED_", 1, true) == 1 then
            SetStatus("WARNING: ROUND announcement was not sent. Roll cancelled. Check raid chat permissions or restrictions.")
        else
            SetStatus("Cannot roll: " .. tostring(result))
        end

        RefreshAll()
    end)

    rerollButton = CreateButton(page, API.BuildRerollButtonText(), 126, -124, 158, 22, function()
        local ok, result

        if IsMultiCoordinatorMode() then
            ok, result = API.MultiRaidRerollCurrentRound()
        else
            ok, result = API.RerollCurrentRound()
        end

        if ok then
            SetStatus("Reroll pending for ROUND " .. tostring(result) .. ".")
        else
            SetStatus("Cannot reroll: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateSeparator(page, -146)

    winnerPanel = CreateFrame("Frame", nil, page)
    winnerPanel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -154)
    winnerPanel:SetSize(410, 92)
    winnerPanel.background = winnerPanel:CreateTexture(nil, "BACKGROUND")
    winnerPanel.background:SetAllPoints(winnerPanel)
    winnerPanel.background:SetColorTexture(0.12, 0.12, 0.12, 0.65)

    winnerText = winnerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    winnerText:SetPoint("TOPLEFT", winnerPanel, "TOPLEFT", 10, -10)
    winnerText:SetWidth(410)
    winnerText:SetJustifyH("LEFT")
    winnerNameText = winnerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    winnerNameText:SetPoint("TOPLEFT", winnerPanel, "TOPLEFT", 10, -34)
    winnerNameText:SetWidth(390)
    winnerNameText:SetJustifyH("LEFT")
    winnerMessageText = winnerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    winnerMessageText:SetPoint("TOPLEFT", winnerPanel, "TOPLEFT", 10, -62)
    winnerMessageText:SetWidth(390)
    winnerMessageText:SetJustifyH("LEFT")

    CreateButton(page, "Say Winner", 0, -260, 104, 24, function()
        local ok, reason = API.SendWinnerSay()

        if ok then
            SetStatus("Winner message sent in say.")
        elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
            SetStatus("Chat messaging is temporarily restricted.")
        else
            SetStatus("No winner to announce.")
        end
    end)

    CreateButton(page, "Whisper Winner", 116, -260, 128, 24, function()
        local ok, reason = API.SendWinnerWhisper()

        if ok then
            SetStatus("Winner message whispered.")
        elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
            SetStatus("Chat messaging is temporarily restricted.")
        else
            SetStatus("No winner to whisper.")
        end
    end)

    CreateSeparator(page, -288)

    CreateLabel(page, "Reward yells", 0, -298)

    for i = 1, REWARD_BUTTONS_PER_PAGE do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local button = CreateButton(page, "Reward", column * 210, -322 - (row * 28), 198, 22, function(self)
            local ok, reason = API.SendRewardYell(self.rewardIndex)

            if ok then
                SetStatus("Reward yelled.")
            elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
                SetStatus("Chat messaging is temporarily restricted.")
            else
                SetStatus("No winner or reward template selected.")
            end
        end)

        controlRewardButtons[i] = button
    end

    CreateButton(page, "<", 0, -410, 34, 20, function()
        if rewardButtonPage > 1 then
            rewardButtonPage = rewardButtonPage - 1
        end

        RefreshRewardButtons()
    end)

    controlRewardButtonPageText = CreateValue(page, 46, -413, 130)

    CreateButton(page, ">", 176, -410, 34, 20, function()
        rewardButtonPage = rewardButtonPage + 1
        RefreshRewardButtons()
    end)

    CreateSeparator(page, -438)

    CreateLabel(page, "GAME CONTROL", 0, -446)
    gameSessionText = CreateValue(page, 130, -446, 280)

    startGameButton = CreateButton(page, "START GAME", 0, -470, 160, 28, function()
        local ok, result = API.StartGameSession()

        if ok then
            SetStatus("Game session active: " .. tostring(result))
        else
            SetStatus("Cannot start game: " .. tostring(result))
        end

        RefreshAll()
    end)

    stopGameButton = CreateButton(page, "STOP GAME", 176, -470, 160, 28, function()
        local ok, result = API.StopGameSession()

        if ok then
            SetStatus("Game session saved: " .. tostring(result))
        else
            SetStatus("Cannot stop game: " .. tostring(result))
        end

        RefreshAll()
    end)

    statusText = CreateValue(page, 0, -508, 410)
    statusText:SetText("Ready.")

    return page
end

local function CreateRosterPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    CreateLabel(page, "#", 0, 0)
    CreateLabel(page, "Name", 54, 0)

    CreateSeparator(page, -18)

    for i = 1, ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -24 - ((i - 1) * 24))
        row:SetSize(410, 22)

        row.number = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.number:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.number:SetWidth(40)
        row.number:SetJustifyH("LEFT")

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("LEFT", row, "LEFT", 54, 0)
        row.name:SetWidth(230)
        row.name:SetJustifyH("LEFT")

        row.sendButton = CreateButton(row, "Send", 322, -1, 76, 20, function(self)
            local parentRow = self:GetParent()
            local ok, reason = API.SendNumberWhisperToName(parentRow.nameValue)

            if ok then
                SetRosterStatus("Sent number to " .. parentRow.nameValue .. ".")
            elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
                SetRosterStatus("Chat messaging is temporarily restricted.")
            else
                SetRosterStatus("Record the raid before sending MG number whispers.")
            end
        end)

        rosterRows[i] = row
    end

    CreateButton(page, "Previous", 0, -334, 92, 24, function()
        if rosterPage > 1 then
            rosterPage = rosterPage - 1
        end

        RefreshRoster()
    end)

    CreateButton(page, "Next", 318, -334, 92, 24, function()
        rosterPage = rosterPage + 1
        RefreshRoster()
    end)

    rosterPageText = CreateValue(page, 132, -338, 150)

    CreateSeparator(page, -372)

    CreateLabel(page, "Setup", 0, -382)

    rosterGMMoveButton = CreateButton(page, "Move GM to Last Spot", 0, -406, 176, 24, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Setup is locked while a game session is active or a roll is pending.")
            return
        end

        local ok, result, targetGroup = API.MoveGMToLastSpot()
        local view = API.GetGMMoveView()

        if ok then
            SetRosterStatus(view.message or ("GM move started for subgroup " .. tostring(targetGroup or "-") .. "."))
        else
            SetRosterStatus(view.message or ("Cannot move GM: " .. tostring(result)))
        end

        RefreshAll()
    end)

    rosterStartButton = CreateButton(page, "Record Raid", 192, -406, 126, 24, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Setup is locked while a game session is active or a roll is pending.")
            return
        end

        if not API.CanRecordRaid() then
            local view = API.GetGMMoveView()

            SetRosterStatus(view.message or "Move GM to last spot before recording raid.")
            return
        end

        local count, reason = API.StartRaidNumbering()
        rosterPage = 1

        if count > 0 then
            SetRosterStatus("Raid recorded. Players: " .. tostring(count) .. ".")
        elseif reason == "GM_MOVE_REQUIRED" then
            SetRosterStatus("Move GM to last spot before recording raid.")
        else
            SetRosterStatus("No raid members recorded. Join a raid first.")
        end

        RefreshAll()
    end)

    rosterResetButton = CreateButton(page, "Clear Raid", 318, -406, 92, 24, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Setup is locked while a game session is active or a roll is pending.")
            return
        end

        API.ResetRaidNumbering()
        rosterPage = 1
        SetRosterStatus("Recorded raid and rounds cleared.")
        RefreshAll()
    end)

    rosterSendButton = CreateButton(page, "Send Numbers (0)", 0, -434, 176, 24, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Setup is locked while a game session is active or a roll is pending.")
            return
        end

        if not API.HasRaidNumbers() or API.CountRaidNumbers() <= 0 then
            SetRosterStatus("Record the raid before sending MG number whispers.")
            return
        end

        local ok, result = API.SendNumbers()

        if ok then
            SetRosterStatus("Queued MG number whispers: " .. tostring(result))
        elseif result == "SEND_QUEUE_ACTIVE" then
            SetRosterStatus("Number whispers are already sending.")
        else
            SetRosterStatus("Cannot send MG number whispers: " .. tostring(result))
        end

        RefreshAll()
    end)

    rosterStatusText = CreateValue(page, 0, -472, 410)
    rosterStatusText:SetText("Setup ready.")

    multiCoordinatorFrame = CreateFrame("Frame", nil, page)
    multiCoordinatorFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    multiCoordinatorFrame:SetSize(410, 506)
    multiCoordinatorFrame.background = multiCoordinatorFrame:CreateTexture(nil, "BACKGROUND")
    multiCoordinatorFrame.background:SetAllPoints(multiCoordinatorFrame)
    multiCoordinatorFrame.background:SetColorTexture(0.07, 0.07, 0.07, 0.96)
    multiCoordinatorFrame:Hide()

    CreateLabel(multiCoordinatorFrame, "Multi Raid Coordinator", 0, 0)
    multiCoordinatorSummaryText = CreateValue(multiCoordinatorFrame, 0, -28, 410)
    multiCoordinatorSummaryText:SetHeight(58)
    multiCoordinatorSummaryText:SetJustifyV("TOP")

    CreateSeparator(multiCoordinatorFrame, -92)
    CreateLabel(multiCoordinatorFrame, "Assistant character name", 0, -104)
    assistantNameEditBox = CreateEditBox(multiCoordinatorFrame, 0, -132, 258, 24)
    multiAddAssistantButton = CreateButton(multiCoordinatorFrame, "Add Assistant", 272, -132, 126, 24, function()
        local ok, result = API.AddMultiRaidAssistant(assistantNameEditBox:GetText())

        if ok then
            assistantNameEditBox:SetText("")
            SetMultiSetupStatus("Assistant invite sent.")
        elseif result == "ASSISTANT_NAME_REQUIRED" then
            SetMultiSetupStatus("Enter an assistant character name.")
        else
            SetMultiSetupStatus("Assistant invite failed: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateSeparator(multiCoordinatorFrame, -172)
    CreateLabel(multiCoordinatorFrame, "Assistants", 0, -184)

    for i = 1, 5 do
        local row = CreateValue(multiCoordinatorFrame, 0, -210 - ((i - 1) * 24), 410)
        multiAssistantRows[i] = row
    end

    multiCoordinatorClearButton = CreateButton(multiCoordinatorFrame, "Clear Multi", 0, -344, 112, 24, function()
        local ok, result = API.ClearMultiRaidSession()

        if ok then
            SetMultiSetupStatus("Multi-raid session cleared.")
        else
            SetMultiSetupStatus("Cannot clear multi-raid session: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiRequestRostersButton = CreateButton(multiCoordinatorFrame, "Request Rosters", 128, -344, 132, 24, function()
        local ok, result = API.RequestMultiRaidRosters()

        if ok then
            SetMultiSetupStatus("Roster requests sent: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Roster request failed: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiRecordCoordinatorButton = CreateButton(multiCoordinatorFrame, "Record Main Raid", 276, -344, 126, 24, function()
        local ok, result = API.RecordMultiRaidCoordinatorRoster()

        if ok then
            SetMultiSetupStatus("Main raid recorded: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Cannot record main raid: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiAssignNumbersButton = CreateButton(multiCoordinatorFrame, "Assign Numbers", 0, -378, 132, 24, function()
        local ok, result = API.AssignMultiRaidGlobalNumbers()

        if ok then
            SetMultiSetupStatus("Global numbers assigned; assistant sync queued: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Cannot assign numbers: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiSendNumbersButton = CreateButton(multiCoordinatorFrame, "Send Numbers", 148, -378, 112, 24, function()
        local ok, result = API.SendMultiRaidNumbers()

        if ok then
            SetMultiSetupStatus("Number dispatch queued: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Cannot send numbers: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiStartButton = CreateButton(multiCoordinatorFrame, "Start Multi", 276, -378, 126, 24, function()
        local ok, result, warning = API.StartMultiRaidGameSession()

        if ok then
            if warning then
                SetMultiSetupStatus("WARNING: Multi game started, but an Assistant notification failed: " .. tostring(warning))
            else
                SetMultiSetupStatus("Multi game started: " .. tostring(result) .. " players.")
            end
        else
            SetMultiSetupStatus("Cannot start multi game: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiStopButton = CreateButton(multiCoordinatorFrame, "Stop Multi", 0, -412, 112, 24, function()
        local ok, result, warning = API.StopMultiRaidGameSession()

        if ok then
            if warning then
                SetMultiSetupStatus("WARNING: Multi game stopped, but an Assistant notification failed: " .. tostring(warning))
            else
                SetMultiSetupStatus("Multi game stopped.")
            end
        else
            SetMultiSetupStatus("Cannot stop multi game: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiAssistantFrame = CreateFrame("Frame", nil, page)
    multiAssistantFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    multiAssistantFrame:SetSize(410, 506)
    multiAssistantFrame.background = multiAssistantFrame:CreateTexture(nil, "BACKGROUND")
    multiAssistantFrame.background:SetAllPoints(multiAssistantFrame)
    multiAssistantFrame.background:SetColorTexture(0.07, 0.07, 0.07, 0.96)
    multiAssistantFrame:Hide()

    CreateLabel(multiAssistantFrame, "Multi Raid Assistant", 0, 0)
    multiAssistantSummaryText = CreateValue(multiAssistantFrame, 0, -28, 410)
    multiAssistantSummaryText:SetHeight(78)
    multiAssistantSummaryText:SetJustifyV("TOP")

    multiAcceptButton = CreateButton(multiAssistantFrame, "Accept", 0, -124, 92, 24, function()
        local ok, result = API.AcceptMultiRaidInvite()

        if ok then
            SetMultiSetupStatus("Coordinator invite accepted.")
        else
            SetMultiSetupStatus("Cannot accept invite: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiRejectButton = CreateButton(multiAssistantFrame, "Reject", 108, -124, 92, 24, function()
        local ok, result = API.RejectMultiRaidInvite()

        if ok then
            SetMultiSetupStatus("Coordinator invite rejected.")
        else
            SetMultiSetupStatus("Cannot reject invite: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiAssistantClearButton = CreateButton(multiAssistantFrame, "Clear Multi", 216, -124, 112, 24, function()
        local ok, result = API.ClearMultiRaidSession()

        if ok then
            SetMultiSetupStatus("Multi-raid session cleared.")
        else
            SetMultiSetupStatus("Cannot clear multi-raid session: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiRecordLocalButton = CreateButton(multiAssistantFrame, "Record Local Raid", 0, -162, 136, 24, function()
        local ok, result = API.RecordMultiRaidLocalRoster()

        if ok then
            SetMultiSetupStatus("Local roster recorded: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Cannot record local roster: " .. tostring(result))
        end

        RefreshAll()
    end)

    multiSendRosterButton = CreateButton(multiAssistantFrame, "Send Roster", 152, -162, 112, 24, function()
        local ok, result = API.SendMultiRaidRoster()

        if ok then
            SetMultiSetupStatus("Local roster queued: " .. tostring(result) .. ".")
        else
            SetMultiSetupStatus("Cannot send roster: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateSeparator(multiAssistantFrame, -208)
    CreateLabel(multiAssistantFrame, "Auth log", 0, -220)

    for i = 1, 6 do
        local row = CreateValue(multiAssistantFrame, 0, -246 - ((i - 1) * 22), 410)
        multiLogRows[i] = row
    end

    multiSetupStatusText = CreateValue(page, 0, -486, 410)
    multiSetupStatusText:SetText("")

    return page
end

local function CreateRewardsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    CreateLabel(page, "Winner reward yells", 0, 0)
    CreateValue(page, 0, -24, 410):SetText("Press a reward button after a winner is detected.")

    CreateSeparator(page, -44)

    for i = 1, REWARD_BUTTONS_PER_PAGE do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local button = CreateButton(page, "Reward", column * 210, -58 - (row * 30), 198, 24, function(self)
            local ok, reason = API.SendRewardYell(self.rewardIndex)

            if ok then
                SetStatus("Reward yelled.")
            elseif reason == "CHAT_MESSAGE_LOCKDOWN" then
                SetStatus("Chat messaging is temporarily restricted.")
            else
                SetStatus("No winner or reward template selected.")
            end
        end)

        rewardButtons[i] = button
    end

    CreateButton(page, "Previous Rewards", 0, -154, 132, 24, function()
        if rewardButtonPage > 1 then
            rewardButtonPage = rewardButtonPage - 1
        end

        RefreshRewardButtons()
    end)

    rewardsRewardButtonPageText = CreateValue(page, 152, -158, 130)

    CreateButton(page, "Next Rewards", 286, -154, 124, 24, function()
        rewardButtonPage = rewardButtonPage + 1
        RefreshRewardButtons()
    end)

    CreateSeparator(page, -198)

    CreateLabel(page, "Add reward template", 0, -210)
    rewardEditBox = CreateEditBox(page, 0, -238, 292, 24)

    CreateButton(page, "Add Reward", 306, -238, 104, 24, function()
        if API.AddRewardTemplate(rewardEditBox:GetText()) then
            SetStatus("Reward template added.")
        else
            SetStatus("Enter reward text first.")
        end

        RefreshAll()
    end)

    CreateLabel(page, "Saved reward templates", 0, -282)

    CreateSeparator(page, -300)

    for i = 1, REWARD_ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -310 - ((i - 1) * 26))
        row:SetSize(410, 24)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetWidth(292)
        row.text:SetJustifyH("LEFT")

        row.removeButton = CreateButton(row, "Remove", 318, -1, 82, 20, function(self)
            local parentRow = self:GetParent()

            if parentRow.rewardIndex and API.RemoveRewardTemplate(parentRow.rewardIndex) then
                SetStatus("Reward template removed.")
            else
                SetStatus("No reward template selected.")
            end

            RefreshAll()
        end)

        rewardRows[i] = row
    end

    CreateButton(page, "Previous", 0, -474, 92, 24, function()
        if rewardSettingsPage > 1 then
            rewardSettingsPage = rewardSettingsPage - 1
        end

        RefreshRewardSettings()
    end)

    rewardSettingsPageText = CreateValue(page, 132, -478, 150)

    CreateButton(page, "Next", 318, -474, 92, 24, function()
        rewardSettingsPage = rewardSettingsPage + 1
        RefreshRewardSettings()
    end)

    return page
end

local function CreateHistoryPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    CreateLabel(page, "Completed sessions", 0, 0)

    CreateSeparator(page, -18)

    for i = 1, HISTORY_ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28 - ((i - 1) * 28))
        row:SetSize(410, 24)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetWidth(320)
        row.text:SetJustifyH("LEFT")

        row.viewButton = CreateButton(row, "View", 334, -1, 66, 20, function(self)
            local parentRow = self:GetParent()

            selectedHistoryIndex = parentRow.historyIndex
            historyRoundPage = 1
            RefreshHistory()
        end)

        historyRows[i] = row
    end

    CreateButton(page, "Previous", 0, -176, 92, 24, function()
        if historyPage > 1 then
            historyPage = historyPage - 1
        end

        RefreshHistory()
    end)

    historyPageText = CreateValue(page, 132, -180, 150)

    CreateButton(page, "Next", 318, -176, 92, 24, function()
        historyPage = historyPage + 1
        RefreshHistory()
    end)

    CreateSeparator(page, -210)

    CreateLabel(page, "Session details", 0, -220)

    historyDetailText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    historyDetailText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -244)
    historyDetailText:SetWidth(410)
    historyDetailText:SetJustifyH("LEFT")
    historyDetailText:SetJustifyV("TOP")

    CreateSeparator(page, -334)

    CreateLabel(page, "Round results and rewards", 0, -344)

    for i = 1, HISTORY_ROUND_ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -370 - ((i - 1) * 20))
        row:SetSize(410, 18)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetWidth(410)
        row.text:SetJustifyH("LEFT")

        historyRoundRows[i] = row
    end

    CreateButton(page, "<", 0, -482, 34, 20, function()
        if historyRoundPage > 1 then
            historyRoundPage = historyRoundPage - 1
        end

        RefreshHistory()
    end)

    historyRoundPageText = CreateValue(page, 46, -485, 130)

    CreateButton(page, ">", 176, -482, 34, 20, function()
        historyRoundPage = historyRoundPage + 1
        RefreshHistory()
    end)

    return page
end

local function CreateMonitoringPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    CreateLabel(page, "Live remote state", 0, 0)

    monitoringSummaryText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    monitoringSummaryText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -24)
    monitoringSummaryText:SetWidth(500)
    monitoringSummaryText:SetJustifyH("LEFT")
    monitoringSummaryText:SetJustifyV("TOP")

    CreateSeparator(page, -174, 500)

    CreateLabel(page, "Local debug state", 0, -184)

    monitoringLocalText = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    monitoringLocalText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -208)
    monitoringLocalText:SetWidth(500)
    monitoringLocalText:SetJustifyH("LEFT")
    monitoringLocalText:SetJustifyV("TOP")

    monitoringLiveButton = CreateButton(page, "Start GM Live", 0, -300, 122, 24, function()
        local ok
        local result

        if API.GetMonitoringBroadcastEnabled() then
            ok, result = API.StopMonitoringBroadcast()
        else
            ok, result = API.StartMonitoringBroadcast()
        end

        if ok then
            monitoringStatusText:SetText("Monitoring " .. tostring(result) .. ".")
        elseif result == "NO_ACTIVE_SESSION" then
            monitoringStatusText:SetText("Start the game before starting GM live.")
        elseif result == "NO_GROUP" then
            monitoringStatusText:SetText("Join a party or raid before starting live monitoring.")
        else
            monitoringStatusText:SetText("Monitoring failed: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateButton(page, "Send Update", 134, -300, 104, 24, function()
        local ok, result = API.BroadcastMonitoringState()

        if ok then
            monitoringStatusText:SetText("Monitoring update sent on " .. tostring(result) .. ".")
        elseif result == "NO_GROUP" then
            monitoringStatusText:SetText("Join a party or raid before sending an update.")
        else
            monitoringStatusText:SetText("Monitoring update failed: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateButton(page, "Clear GM", 250, -300, 82, 24, function()
        API.ClearMonitoringLog()
        monitoringStatusText:SetText("Observed GM and log cleared.")
        RefreshAll()
    end)

    monitoringStatusText = CreateValue(page, 344, -304, 156)

    CreateSeparator(page, -344, 500)

    CreateLabel(page, "Received events", 0, -354)

    for i = 1, MONITORING_ROWS do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -380 - ((i - 1) * 20))
        row:SetSize(500, 18)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.text:SetWidth(500)
        row.text:SetJustifyH("LEFT")

        monitoringRows[i] = row
    end

    return page
end

local function CreateSettingsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -92)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    CreateLabel(page, "Number whisper text", 0, 0)
    whisperEditBox = CreateEditBox(page, 0, -28, 410, 24)
    whisperEditBox:SetScript("OnEnterPressed", function(self)
        API.SetNumberWhisperText(self:GetText())
        self:ClearFocus()
        SetStatus("Whisper text saved.")
    end)

    CreateButton(page, "Save Text", 0, -64, 100, 24, function()
        API.SetNumberWhisperText(whisperEditBox:GetText())
        SetStatus("Whisper text saved.")
        RefreshAll()
    end)

    whisperPreviewText = CreateValue(page, 0, -98, 410)

    CreateSeparator(page, -128)

    CreateLabel(page, "Round roll delay seconds", 0, -138)
    delayEditBox = CreateEditBox(page, 0, -166, 80, 24)
    delayEditBox:SetNumeric(false)
    delayEditBox:SetScript("OnEnterPressed", function(self)
        API.SetRoundRollDelay(tonumber(self:GetText()))
        self:SetText(tostring(API.GetRoundRollDelay()))
        self:ClearFocus()
        SetStatus("Round delay saved.")
    end)

    CreateButton(page, "Save Delay", 96, -166, 104, 24, function()
        API.SetRoundRollDelay(tonumber(delayEditBox:GetText()))
        delayEditBox:SetText(tostring(API.GetRoundRollDelay()))
        SetStatus("Round delay saved.")
        RefreshAll()
    end)

    countdownSoundCheckBox = CreateCheckBox(page, "Roll Countdown Sound", 0, -204, function(self)
        API.SetRollCountdownSoundEnabled(self:GetChecked())
        SetStatus("Roll countdown sound " .. (self:GetChecked() and "enabled." or "disabled."))
        RefreshAll()
    end)

    CreateButton(page, "Test Sound", 220, -204, 104, 24, function()
        local ok, result = API.TestRollCountdownSound()

        if ok then
            SetStatus("Roll countdown sound test sent.")
        elseif result == "ROLL_COUNTDOWN_SOUND_DISABLED" then
            SetStatus("Enable Roll Countdown Sound before testing.")
        elseif result == "CHAT_MESSAGE_LOCKDOWN" then
            SetStatus("Chat messaging is temporarily restricted.")
        else
            SetStatus("Roll countdown sound test failed.")
        end
    end)

    CreateSeparator(page, -244)

    CreateLabel(page, "Danger zone", 0, -254)

    CreateButton(page, "RESET ALL", 0, -282, 120, 24, function()
        if resetAllConfirmText then
            resetAllConfirmText:Show()
        end

        if resetAllConfirmButton then
            resetAllConfirmButton:Show()
        end

        SetStatus("Reset confirmation required.")
    end)

    resetAllConfirmText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resetAllConfirmText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -320)
    resetAllConfirmText:SetWidth(410)
    resetAllConfirmText:SetJustifyH("LEFT")
    resetAllConfirmText:SetText("WARNING: This permanently deletes ALL MicroGames SavedVariables data, including history, active session, roster, rewards, settings, and round data. Are you sure?")
    resetAllConfirmText:SetTextColor(1, 0.12, 0.12)
    resetAllConfirmText:Hide()

    resetAllConfirmButton = CreateButton(page, "YES, DELETE ALL DATA", 0, -372, 190, 26, function()
        API.ResetAllData()
        rosterPage = 1
        rewardButtonPage = 1
        rewardSettingsPage = 1
        historyPage = 1
        historyRoundPage = 1
        selectedHistoryIndex = nil

        if resetAllConfirmText then
            resetAllConfirmText:Hide()
        end

        if resetAllConfirmButton then
            resetAllConfirmButton:Hide()
        end

        SetStatus("All MicroGames data reset.")
        RefreshAll()
    end)
    resetAllConfirmButton:Hide()

    return page
end

function UI.Show()
    if not frame then
        UI.Create()
    end

    frame:Show()

    if collapsed then
        SetCollapsed(false)
    else
        RefreshAll()
    end
end

function UI.Hide()
    if frame then
        frame:Hide()
    end
end

function UI.Toggle()
    if frame and frame:IsShown() then
        UI.Hide()
    else
        UI.Show()
    end
end

function UI.Refresh()
    if frame then
        RefreshAll()
    end
end

function UI.Create()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "MicroGamesFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function()
    end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 6, 0)
    frame.title:SetText("MicroGames")

    modeStatusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    modeStatusText:SetPoint("RIGHT", frame, "TOPRIGHT", -86, -14)
    modeStatusText:SetWidth(82)
    modeStatusText:SetJustifyH("RIGHT")

    modeDropdown = CreateFrame("Frame", "MicroGamesModeDropdown", frame, "UIDropDownMenuTemplate")
    modeDropdown:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -154, -3)
    UIDropDownMenu_SetWidth(modeDropdown, 158)
    UIDropDownMenu_Initialize(modeDropdown, InitializeModeDropdown)
    UIDropDownMenu_SetText(modeDropdown, API.GetSessionModeLabel())

    collapseButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    collapseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -4)
    collapseButton:SetSize(46, 20)
    collapseButton:SetText("Min")
    collapseButton:SetScript("OnClick", function()
        SetCollapsed(not collapsed)
    end)

    pages.control = CreateControlPage(frame)
    pages.roster = CreateRosterPage(frame)
    pages.rewards = CreateRewardsPage(frame)
    pages.history = CreateHistoryPage(frame)
    pages.monitoring = CreateMonitoringPage(frame)
    pages.settings = CreateSettingsPage(frame)

    tabs[1] = CreateFrame("Button", "MicroGamesTabControl", frame, "CharacterFrameTabButtonTemplate")
    tabs[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -34)
    tabs[1]:SetText("Control")
    tabs[1].pageName = "control"
    tabs[1]:SetScript("OnClick", function()
        ShowPage("control")
    end)

    tabs[2] = CreateFrame("Button", "MicroGamesTabRoster", frame, "CharacterFrameTabButtonTemplate")
    tabs[2]:SetPoint("LEFT", tabs[1], "RIGHT", -14, 0)
    tabs[2]:SetText("Setup")
    tabs[2].pageName = "roster"
    tabs[2]:SetScript("OnClick", function()
        ShowPage("roster")
    end)

    tabs[3] = CreateFrame("Button", "MicroGamesTabRewards", frame, "CharacterFrameTabButtonTemplate")
    tabs[3]:SetPoint("LEFT", tabs[2], "RIGHT", -14, 0)
    tabs[3]:SetText("Rewards")
    tabs[3].pageName = "rewards"
    tabs[3]:SetScript("OnClick", function()
        ShowPage("rewards")
    end)

    tabs[4] = CreateFrame("Button", "MicroGamesTabHistory", frame, "CharacterFrameTabButtonTemplate")
    tabs[4]:SetPoint("LEFT", tabs[3], "RIGHT", -14, 0)
    tabs[4]:SetText("History")
    tabs[4].pageName = "history"
    tabs[4]:SetScript("OnClick", function()
        ShowPage("history")
    end)

    tabs[5] = CreateFrame("Button", "MicroGamesTabMonitoring", frame, "CharacterFrameTabButtonTemplate")
    tabs[5]:SetPoint("LEFT", tabs[4], "RIGHT", -14, 0)
    tabs[5]:SetText("Monitoring")
    tabs[5].pageName = "monitoring"
    tabs[5]:SetScript("OnClick", function()
        ShowPage("monitoring")
    end)

    tabs[6] = CreateFrame("Button", "MicroGamesTabSettings", frame, "CharacterFrameTabButtonTemplate")
    tabs[6]:SetPoint("LEFT", tabs[5], "RIGHT", -14, 0)
    tabs[6]:SetText("Settings")
    tabs[6].pageName = "settings"
    tabs[6]:SetScript("OnClick", function()
        ShowPage("settings")
    end)

    PanelTemplates_SetNumTabs(frame, 6)
    ShowPage("control")

    tradeEventFrame = CreateFrame("Frame")
    tradeEventFrame:RegisterEvent("TRADE_SHOW")
    tradeEventFrame:RegisterEvent("TRADE_CLOSED")
    tradeEventFrame:SetScript("OnEvent", function(self, event)
        if event == "TRADE_SHOW" and frame and frame:IsShown() and not collapsed then
            collapsedForTrade = true
            SetCollapsed(true)
        elseif event == "TRADE_CLOSED" and collapsedForTrade then
            collapsedForTrade = false

            if frame and frame:IsShown() then
                SetCollapsed(false)
            end
        end
    end)

    return frame
end
