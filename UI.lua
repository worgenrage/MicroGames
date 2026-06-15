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

local frame
local tabs = {}
local pages = {}
local rosterRows = {}
local controlRewardButtons = {}
local rewardButtons = {}
local rewardRows = {}
local rosterPage = 1
local rewardButtonPage = 1
local rewardSettingsPage = 1
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
local rewardButtonPageText
local rewardSettingsPageText
local rewardEditBox
local startGameButton
local stopGameButton
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
    SetButtonEnabled(rosterStartButton, not session.active)
    SetButtonEnabled(rosterSendButton, not session.active)
    SetButtonEnabled(rosterStopButton, not session.active)
    SetButtonEnabled(rosterResetButton, not session.active)

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
        SetButtonEnabled(rerollButton, round > 0 and count > 0)
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

    if rewardButtonPageText then
        rewardButtonPageText:SetText("Rewards " .. tostring(rewardButtonPage) .. " / " .. tostring(totalPages))
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

local function RefreshAll()
    UpdateSummary()
    RefreshRoster()
    RefreshRewardButtons()
    RefreshRewardSettings()

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

    CreateButton(page, "Round Roll", 0, -78, 410, 42, function()
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

    rewardButtonPageText = CreateValue(page, 46, -413, 130)

    CreateButton(page, ">", 176, -410, 34, 20, function()
        rewardButtonPage = rewardButtonPage + 1
        RefreshRewardButtons()
    end)

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

    rewardButtonPageText = CreateValue(page, 152, -158, 130)

    CreateButton(page, "Next Rewards", 286, -154, 124, 24, function()
        rewardButtonPage = rewardButtonPage + 1
        RefreshRewardButtons()
    end)

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

    tabs[4] = CreateFrame("Button", "MicroGamesTabSettings", frame, "CharacterFrameTabButtonTemplate")
    tabs[4]:SetPoint("LEFT", tabs[3], "RIGHT", -14, 0)
    tabs[4]:SetText("Settings")
    tabs[4].pageName = "settings"
    tabs[4]:SetScript("OnClick", function()
        ShowPage("settings")
    end)

    PanelTemplates_SetNumTabs(frame, 4)
    ShowPage("control")

    return frame
end
