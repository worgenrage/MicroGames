local addonName, addon = ...

addon.name = addonName
addon.UI = addon.UI or {}

local API = addon.API
local UI = addon.UI

local FRAME_WIDTH = 460
local FRAME_HEIGHT = 640
local ROWS_PER_PAGE = 12
local REWARD_BUTTONS_PER_PAGE = 6
local REWARD_ROWS_PER_PAGE = 6
local HISTORY_ROWS_PER_PAGE = 5
local HISTORY_ROUND_ROWS_PER_PAGE = 6

local frame
local tabs = {}
local pages = {}
local rosterRows = {}
local controlRewardButtons = {}
local rewardButtons = {}
local rewardRows = {}
local historyRows = {}
local historyRoundRows = {}
local rosterPage = 1
local rewardButtonPage = 1
local rewardSettingsPage = 1
local historyPage = 1
local historyRoundPage = 1
local selectedHistoryIndex = nil
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
local rosterPageText
local controlRewardButtonPageText
local rewardsRewardButtonPageText
local rewardSettingsPageText
local historyPageText
local historyDetailText
local historyRoundPageText
local rewardEditBox
local resetAllConfirmText
local resetAllConfirmButton
local startGameButton
local stopGameButton
local roundRollButton
local rosterStartButton
local rosterSendButton
local rosterStopButton
local rosterResetButton
local rerollButton

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

local function SetRosterStatus(text)
    if rosterStatusText then
        rosterStatusText:SetText(text)
    end
end

local function UpdateSummary()
    local count = API.CountRaidNumbers()
    local round = API.GetCurrentRound()
    local previousRoundMessage = API.BuildPreviousRoundMessage()
    local rollCommand = API.BuildRollCommand()
    local nextRoundMessage = API.BuildRoundMessage(round + 1)
    local winner = API.GetLastWinner()
    local winnerMessage = API.BuildWinnerMessage()
    local session = API.GetGameSessionSummary()
    local canModifyRoster = API.CanModifyRoster()

    if activeText then
        if API.HasRaidNumbers() then
            activeText:SetText("Numbering state: Active")
        else
            activeText:SetText("Numbering state: Inactive")
        end
    end

    if countText then
        countText:SetText("Recorded players: " .. tostring(count))
    end

    if gameSessionText then
        if session.active then
            gameSessionText:SetText("EVENT STARTED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(count))
            gameSessionText:SetTextColor(0.2, 1, 0.2)
        else
            gameSessionText:SetText("EVENT STOPPED - ROUND " .. tostring(round) .. " - MEMBERS " .. tostring(count))
            gameSessionText:SetTextColor(1, 0.82, 0)
        end
    end

    SetButtonEnabled(startGameButton, not session.active)
    SetButtonEnabled(stopGameButton, session.active)
    SetButtonEnabled(rosterStartButton, canModifyRoster)
    SetButtonEnabled(rosterSendButton, canModifyRoster)
    SetButtonEnabled(rosterStopButton, canModifyRoster)
    SetButtonEnabled(rosterResetButton, canModifyRoster)
    SetButtonEnabled(roundRollButton, count > 0 and not API.HasPendingRoll())

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
        rollText:SetText("Next roll range: " .. (rollCommand or "-"))
    end

    if rerollButton then
        rerollButton:SetText(API.BuildRerollButtonText())
        SetButtonEnabled(rerollButton, round > 0 and count > 0 and not API.HasPendingRoll())
    end

    if winnerText then
        if winner then
            winnerText:SetText("Winner number: #" .. tostring(winner.number))
            winnerText:SetTextColor(1, 0.86, 0)
        else
            winnerText:SetText("Winner number: -")
            winnerText:SetTextColor(1, 0.86, 0)
        end
    end

    if winnerNameText then
        if winner and winner.name then
            winnerNameText:SetText("Winner name: " .. tostring(winner.name))
            winnerNameText:SetTextColor(0.2, 1, 0.2)
        else
            winnerNameText:SetText("Winner name: -")
            winnerNameText:SetTextColor(0.2, 1, 0.2)
        end
    end

    if winnerPanel and winnerPanel.background then
        if winner then
            winnerPanel.background:SetColorTexture(0.08, 0.22, 0.08, 0.82)
        else
            winnerPanel.background:SetColorTexture(0.12, 0.12, 0.12, 0.65)
        end
    end

    if winnerMessageText then
        winnerMessageText:SetText("Winner message: " .. (winnerMessage or "-"))
    end

    if whisperPreviewText then
        whisperPreviewText:SetText("Preview: " .. tostring(API.BuildNumberWhisperMessage(12)))
    end
end

local function RefreshRoster()
    local entries = API.GetRaidNumberEntries()
    local totalPages = math.max(1, math.ceil(#entries / ROWS_PER_PAGE))

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

    return "#" .. tostring(index) .. "  " .. tostring(startedAt) .. " - rounds " .. tostring(rounds) .. " - players " .. tostring(players) .. " - stopped " .. tostring(stoppedAt)
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

    lines[#lines + 1] = "Session #" .. tostring(index)
    lines[#lines + 1] = "Started: " .. tostring(session.startedAt or "-")
    lines[#lines + 1] = "Stopped: " .. tostring(session.stoppedAt or "-")
    lines[#lines + 1] = "Players: " .. tostring(session.finalAssignedCount or session.assignedCount or 0)
    lines[#lines + 1] = "Rounds: " .. tostring(session.totalRounds or session.currentRound or #rounds)
    lines[#lines + 1] = "Final winner: #" .. tostring(winnerNumber) .. " - " .. tostring(winnerName)
    lines[#lines + 1] = "Rewards sent: " .. tostring(#rewards)

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
        local line = rewardText .. " @" .. sentAt

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
    local rewardText = "-"

    if type(rewards) == "table" and #rewards > 0 then
        rewardText = table.concat(rewards, "; ")
    end

    return "R" .. tostring(roundNumber) .. " | " .. tostring(rolledAt) .. " | #" .. tostring(rollNumber) .. " " .. tostring(winnerName) .. " | " .. rewardText
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

    if not selectedHistoryIndex and #history > 0 then
        selectedHistoryIndex = #history
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

local function RefreshAll()
    UpdateSummary()
    RefreshRoster()
    RefreshRewardButtons()
    RefreshRewardSettings()
    RefreshHistory()

    if whisperEditBox then
        whisperEditBox:SetText(API.GetNumberWhisperText())
    end

    if delayEditBox then
        delayEditBox:SetText(tostring(API.GetRoundRollDelay()))
    end

    if rewardEditBox then
        rewardEditBox:SetText("")
    end
end

local function ShowPage(pageName)
    local index

    for name, page in pairs(pages) do
        if name == pageName then
            page:Show()
        else
            page:Hide()
        end
    end

    for i = 1, #tabs do
        if tabs[i].pageName == pageName then
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
        local ok, result = API.RoundRoll()

        if ok then
            SetStatus("Round " .. tostring(result) .. " announced. Roll pending.")
        else
            SetStatus("Cannot roll: " .. tostring(result))
        end

        RefreshAll()
    end)

    rerollButton = CreateButton(page, API.BuildRerollButtonText(), 126, -124, 158, 22, function()
        local ok, result = API.RerollCurrentRound()

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
        if API.SendWinnerSay() then
            SetStatus("Winner message sent in say.")
        else
            SetStatus("No winner to announce.")
        end
    end)

    CreateButton(page, "Whisper Winner", 116, -260, 128, 24, function()
        if API.SendWinnerWhisper() then
            SetStatus("Winner message whispered.")
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
            if self.rewardIndex and API.SendRewardYell(self.rewardIndex) then
                SetStatus("Reward yelled.")
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

            if parentRow.nameValue and API.SendNumberWhisperToName(parentRow.nameValue) then
                SetRosterStatus("Sent number to " .. parentRow.nameValue .. ".")
            else
                SetRosterStatus("No recorded number for this player.")
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

    CreateLabel(page, "Roster setup", 0, -382)

    rosterStartButton = CreateButton(page, "Start", 0, -406, 76, 22, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Roster is locked while a game session is active.")
            return
        end

        local count = API.StartRaidNumbering()
        rosterPage = 1
        SetRosterStatus("Numbering started. Recorded " .. tostring(count) .. " players.")
        RefreshAll()
    end)

    rosterSendButton = CreateButton(page, "Send #", 84, -406, 76, 22, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Roster is locked while a game session is active.")
            return
        end

        local sentCount = API.SendNumbers()
        SetRosterStatus("Sent number whispers: " .. tostring(sentCount))
        RefreshAll()
    end)

    rosterStopButton = CreateButton(page, "Stop", 168, -406, 64, 22, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Roster is locked while a game session is active.")
            return
        end

        API.StopRaidNumbering()
        SetRosterStatus("Numbering stopped. Recorded data kept.")
        RefreshAll()
    end)

    rosterResetButton = CreateButton(page, "Reset", 240, -406, 70, 22, function()
        if not API.CanModifyRoster() then
            SetRosterStatus("Roster is locked while a game session is active.")
            return
        end

        API.ResetRaidNumbering()
        rosterPage = 1
        SetRosterStatus("Numbering and rounds reset.")
        RefreshAll()
    end)

    CreateButton(page, "Rounds 0", 318, -406, 92, 22, function()
        API.ResetRounds()
        SetRosterStatus("Rounds reset.")
        RefreshAll()
    end)

    rosterStatusText = CreateValue(page, 0, -448, 410)
    rosterStatusText:SetText("Roster ready.")

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
            if self.rewardIndex and API.SendRewardYell(self.rewardIndex) then
                SetStatus("Reward yelled.")
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

    CreateLabel(page, "Round rewards", 0, -344)

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

    CreateSeparator(page, -220)

    CreateLabel(page, "Danger zone", 0, -230)

    CreateButton(page, "RESET ALL", 0, -258, 120, 24, function()
        if resetAllConfirmText then
            resetAllConfirmText:Show()
        end

        if resetAllConfirmButton then
            resetAllConfirmButton:Show()
        end

        SetStatus("Reset confirmation required.")
    end)

    resetAllConfirmText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    resetAllConfirmText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -296)
    resetAllConfirmText:SetWidth(410)
    resetAllConfirmText:SetJustifyH("LEFT")
    resetAllConfirmText:SetText("WARNING: This permanently deletes ALL MicroGames SavedVariables data, including history, active session, roster, rewards, settings, and round data. Are you sure?")
    resetAllConfirmText:SetTextColor(1, 0.12, 0.12)
    resetAllConfirmText:Hide()

    resetAllConfirmButton = CreateButton(page, "YES, DELETE ALL DATA", 0, -348, 190, 26, function()
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
    RefreshAll()
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
    RefreshAll()
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

    pages.control = CreateControlPage(frame)
    pages.roster = CreateRosterPage(frame)
    pages.rewards = CreateRewardsPage(frame)
    pages.history = CreateHistoryPage(frame)
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
    tabs[2]:SetText("Roster")
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

    tabs[5] = CreateFrame("Button", "MicroGamesTabSettings", frame, "CharacterFrameTabButtonTemplate")
    tabs[5]:SetPoint("LEFT", tabs[4], "RIGHT", -14, 0)
    tabs[5]:SetText("Settings")
    tabs[5].pageName = "settings"
    tabs[5]:SetScript("OnClick", function()
        ShowPage("settings")
    end)

    PanelTemplates_SetNumTabs(frame, 5)
    ShowPage("control")

    return frame
end
