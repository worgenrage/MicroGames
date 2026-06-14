local addonName, addon = ...

addon.name = addonName
addon.UI = addon.UI or {}

local API = addon.API
local UI = addon.UI

local FRAME_WIDTH = 460
local FRAME_HEIGHT = 620
local ROWS_PER_PAGE = 12
local REWARD_BUTTONS_PER_PAGE = 6
local REWARD_ROWS_PER_PAGE = 6

local frame
local tabs = {}
local pages = {}
local rosterRows = {}
local rewardButtons = {}
local rewardRows = {}
local rosterPage = 1
local rewardButtonPage = 1
local rewardSettingsPage = 1
local statusText
local activeText
local countText
local roundText
local previousRoundText
local nextRoundText
local rollText
local winnerText
local winnerMessageText
local whisperEditBox
local whisperPreviewText
local delayEditBox
local rosterPageText
local rewardButtonPageText
local rewardSettingsPageText
local rewardEditBox

local function SetStatus(text)
    if statusText then
        statusText:SetText(text)
    end
end

local function UpdateSummary()
    local count = API.CountRaidNumbers()
    local round = API.GetCurrentRound()
    local previousRoundMessage = API.BuildPreviousRoundMessage()
    local rollCommand = API.BuildRollCommand()
    local nextRoundMessage = API.BuildRoundMessage(round + 1)
    local winnerMessage = API.BuildWinnerMessage()

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

    if winnerText then
        winnerText:SetText(API.BuildLastWinnerText())
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

    if rewardButtonPage > totalPages then
        rewardButtonPage = totalPages
    end

    startIndex = ((rewardButtonPage - 1) * REWARD_BUTTONS_PER_PAGE) + 1

    for buttonIndex = 1, REWARD_BUTTONS_PER_PAGE do
        local rewardIndex = startIndex + buttonIndex - 1
        local text = templates[rewardIndex]
        local button = rewardButtons[buttonIndex]

        if text then
            button.rewardIndex = rewardIndex
            button:SetText(text)
            button:Show()
        else
            button.rewardIndex = nil
            button:Hide()
        end
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
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -72)
    page:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 44)

    countText = CreateValue(page, 0, 0, 240)
    activeText = CreateValue(page, 0, -22, 240)
    roundText = CreateValue(page, 0, -44, 240)
    previousRoundText = CreateValue(page, 0, -66, 320)
    nextRoundText = CreateValue(page, 0, -88, 320)
    rollText = CreateValue(page, 0, -110, 240)
    winnerText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    winnerText:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -140)
    winnerText:SetWidth(410)
    winnerText:SetJustifyH("LEFT")
    winnerMessageText = CreateValue(page, 0, -166, 410)

    CreateButton(page, "Start Numbering", 0, -202, 132, 26, function()
        local count = API.StartRaidNumbering()
        rosterPage = 1
        SetStatus("Numbering started. Recorded " .. tostring(count) .. " players.")
        RefreshAll()
    end)

    CreateButton(page, "Send Numbers", 144, -202, 132, 26, function()
        local sentCount = API.SendNumbers()
        SetStatus("Sent number whispers: " .. tostring(sentCount))
        RefreshAll()
    end)

    CreateButton(page, "Round Roll", 288, -202, 132, 26, function()
        local ok, result = API.RoundRoll()

        if ok then
            SetStatus("Round " .. tostring(result) .. " announced. Roll pending.")
        else
            SetStatus("Cannot roll: " .. tostring(result))
        end

        RefreshAll()
    end)

    CreateButton(page, "Say Winner", 0, -240, 104, 24, function()
        if API.SendWinnerSay() then
            SetStatus("Winner message sent in say.")
        else
            SetStatus("No winner to announce.")
        end
    end)

    CreateButton(page, "Whisper Winner", 116, -240, 128, 24, function()
        if API.SendWinnerWhisper() then
            SetStatus("Winner message whispered.")
        else
            SetStatus("No winner to whisper.")
        end
    end)

    CreateLabel(page, "Reward yell templates", 0, -278)

    for i = 1, REWARD_BUTTONS_PER_PAGE do
        local column = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local button = CreateButton(page, "Reward", column * 210, -302 - (row * 28), 198, 24, function(self)
            if self.rewardIndex and API.SendRewardYell(self.rewardIndex) then
                SetStatus("Reward yelled.")
            else
                SetStatus("No winner or reward template selected.")
            end
        end)

        rewardButtons[i] = button
    end

    CreateButton(page, "Prev Rewards", 0, -390, 104, 22, function()
        if rewardButtonPage > 1 then
            rewardButtonPage = rewardButtonPage - 1
        end

        RefreshRewardButtons()
    end)

    rewardButtonPageText = CreateValue(page, 128, -393, 150)

    CreateButton(page, "Next Rewards", 304, -390, 116, 22, function()
        rewardButtonPage = rewardButtonPage + 1
        RefreshRewardButtons()
    end)

    CreateButton(page, "Stop", 0, -428, 92, 24, function()
        API.StopRaidNumbering()
        SetStatus("Numbering stopped. Recorded data kept.")
        RefreshAll()
    end)

    CreateButton(page, "Reset", 104, -428, 92, 24, function()
        API.ResetRaidNumbering()
        rosterPage = 1
        SetStatus("Numbering and rounds reset.")
        RefreshAll()
    end)

    CreateButton(page, "Reset Rounds", 208, -428, 116, 24, function()
        API.ResetRounds()
        SetStatus("Rounds reset.")
        RefreshAll()
    end)

    statusText = CreateValue(page, 0, -470, 410)
    statusText:SetText("Ready.")

    return page
end

local function CreateRosterPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -72)
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
                SetStatus("Sent number to " .. parentRow.nameValue .. ".")
            else
                SetStatus("No recorded number for this player.")
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

    return page
end

local function CreateSettingsPage(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, -72)
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

    CreateLabel(page, "Reward yell templates", 0, -214)
    rewardEditBox = CreateEditBox(page, 0, -242, 292, 24)

    CreateButton(page, "Add Reward", 306, -242, 104, 24, function()
        if API.AddRewardTemplate(rewardEditBox:GetText()) then
            SetStatus("Reward template added.")
        else
            SetStatus("Enter reward text first.")
        end

        RefreshAll()
    end)

    for i = 1, REWARD_ROWS_PER_PAGE do
        local row = CreateFrame("Frame", nil, page)
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -282 - ((i - 1) * 26))
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

    CreateButton(page, "Previous", 0, -448, 92, 24, function()
        if rewardSettingsPage > 1 then
            rewardSettingsPage = rewardSettingsPage - 1
        end

        RefreshRewardSettings()
    end)

    rewardSettingsPageText = CreateValue(page, 132, -452, 150)

    CreateButton(page, "Next", 318, -448, 92, 24, function()
        rewardSettingsPage = rewardSettingsPage + 1
        RefreshRewardSettings()
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
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
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
    pages.settings = CreateSettingsPage(frame)

    tabs[1] = CreateFrame("Button", "MicroGamesTabControl", frame, "CharacterFrameTabButtonTemplate")
    tabs[1]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 12, 2)
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

    tabs[3] = CreateFrame("Button", "MicroGamesTabSettings", frame, "CharacterFrameTabButtonTemplate")
    tabs[3]:SetPoint("LEFT", tabs[2], "RIGHT", -14, 0)
    tabs[3]:SetText("Settings")
    tabs[3].pageName = "settings"
    tabs[3]:SetScript("OnClick", function()
        ShowPage("settings")
    end)

    PanelTemplates_SetNumTabs(frame, 3)
    ShowPage("control")

    frame:Hide()

    return frame
end
