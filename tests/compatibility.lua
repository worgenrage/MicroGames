-- Run from the repository root with Lua 5.1+ (not loaded by either TOC).
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function newClient(options)
    options = options or {}
    local client = { frames = {}, timers = {}, now = 0, chat = {}, comms = {}, rolls = 0, locked = false }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.MicroGamesDB = options.db or {}
    env.MAX_RAID_MEMBERS = 40
    env.date = function() return "2026-09-20 12:00:00" end
    env.random = function() return 1234 end
    env.UnitName = function() return "GM" end
    env.UnitFullName = function() return "GM", "Realm" end
    env.Ambiguate = function(name) return string.match(name, "^[^-]+") end
    env.IsInRaid = function() return true end
    env.IsInGroup = function() return true end
    env.GetNumGroupMembers = function() return 2 end
    env.UnitIsGroupLeader = function() return true end
    env.UnitIsGroupAssistant = function() return false end
    env.InCombatLockdown = function() return false end
    env.SwapRaidSubgroup = function() error("GM already in last subgroup") end
    env.GetRaidRosterInfo = function(index)
        if index == 1 then return "GM", 2, 8, 60, nil, nil, nil, true end
        if index == 40 then return "Winner", 0, 1, 60, nil, nil, nil, options.online ~= false end
    end
    env.RandomRoll = function() client.rolls = client.rolls + 1 end
    env.Enum = {
        RegisterAddonMessagePrefixResult = { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 },
        SendAddonMessageResult = { Success = 0, AddOnMessageLockdown = 11 },
    }
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function()
            if options.registerError then error("registration failed") end
            if options.registration ~= nil then return options.registration end
            return 0
        end,
        InChatMessagingLockdown = function() return client.locked end,
        SendChatMessage = function(message, channel, language, target)
            assert(not client.locked, "chat must not send during lockdown")
            client.chat[#client.chat + 1] = { message = message, channel = channel, target = target }
        end,
        SendAddonMessage = function(prefix, message, channel, target)
            if client.locked then return 11 end
            client.comms[#client.comms + 1] = message
            return 0
        end,
    }
    env.issecretvalue = function(value) return value == client.secret end
    env.CreateFrame = function()
        local frame = { events = {} }
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:SetScript(name, callback) self[name] = callback end
        client.frames[#client.frames + 1] = frame
        return frame
    end
    local function schedule(delay, callback, repeating)
        local timer = { at = client.now + delay, callback = callback, interval = repeating and delay }
        function timer:Cancel() self.cancelled = true end
        client.timers[#client.timers + 1] = timer
        return timer
    end
    env.C_Timer = {
        After = function(delay, callback) schedule(delay, callback) end,
        NewTicker = function(delay, callback) return schedule(delay, callback, true) end,
    }
    function client:advance(seconds)
        local target = self.now + seconds
        for iteration = 1, 1000 do
            local nextTimer
            for _, timer in ipairs(self.timers) do
                if not timer.cancelled and timer.at <= target and (not nextTimer or timer.at < nextTimer.at) then
                    nextTimer = timer
                end
            end
            if not nextTimer then self.now = target; return end
            self.now = nextTimer.at
            if nextTimer.interval then nextTimer.at = nextTimer.at + nextTimer.interval
            else nextTimer.cancelled = true end
            nextTimer.callback()
        end
        error("timer loop did not settle")
    end
    function client:event(event, ...)
        for _, frame in ipairs(self.frames) do
            if frame.events[event] then frame.OnEvent(frame, event, ...) end
        end
    end
    local addon = {}
    for _, path in ipairs(options.classic and { "Compat.lua", "API.lua" }
        or { "Compat.lua", "CompatForever.lua", "API.lua" }) do
        local chunk
        if setfenv then chunk = assert(loadfile(path)); setfenv(chunk, env)
        else chunk = assert(loadfile(path, "t", env)) end
        chunk("MicroGames", addon)
    end
    client.api, client.compat, client.env = addon.API, addon.Compat, env
    return client
end

local tests = {}

function tests.prefix_registration()
    for _, case in ipairs({ {0, true}, {1, true}, {2, false}, {3, false}, {true, true}, {false, false} }) do
        local client = newClient({ registration = case[1] })
        local ok, reason = client.api.BroadcastMonitoringState()
        equal(ok, case[2], "registration " .. tostring(case[1]))
        if not ok then equal(reason, "PREFIX_NOT_REGISTERED") end
    end
    local client = newClient({ registerError = true })
    equal(client.api.BroadcastMonitoringState(), false, "registration exception")
    client.env.C_ChatInfo.RegisterAddonMessagePrefix = nil
    equal(client.compat.RegisterAddonMessagePrefix("MicroGames"), false, "missing registration API")
end

local function startSingle(client)
    equal(client.api.MoveGMToLastSpot(), true)
    equal(client.api.StartRaidNumbering(), 1, "sparse roster count")
    equal(client.api.GetRaidNameByNumber(1), "Winner")
    equal(client.api.StartGameSession(), true)
    equal(client.api.RoundRoll(), true)
    client:advance(2)
    equal(client.rolls, 1)
end

function tests.sparse_winner_both_clients()
    for _, classic in ipairs({ true, false }) do
        local client = newClient({ classic = classic })
        equal(client.compat.IsForever(), not classic)
        startSingle(client)
        client:event("CHAT_MSG_SYSTEM", "GM rolls 1 (1-1)")
        equal(client.api.GetLastWinner().name, "Winner", "online player at raid40")
        equal(client.api.HasPendingRoll(), false)
    end
end

function tests.offline_winner()
    local client = newClient({ online = false })
    startSingle(client)
    client:event("CHAT_MSG_SYSTEM", "GM rolls 1 (1-1)")
    equal(client.api.GetLastWinner(), nil)
    equal(client.api.GetLastInvalidRoll().reason, "OFFLINE")
end

function tests.secret_roll_and_timeout()
    local client = newClient()
    startSingle(client)
    client.secret = "GM rolls 1 (1-1)"
    client:event("CHAT_MSG_SYSTEM", client.secret)
    client:event("CHAT_MSG_SYSTEM", nil)
    client:event("CHAT_MSG_SYSTEM", {})
    equal(client.api.GetLastWinner(), nil)
    equal(client.api.HasPendingRoll(), true)
    client:advance(10)
    equal(client.api.HasPendingRoll(), false)
    equal(client.api.GetLastWinner(), nil)
end

function tests.queue_restriction_transition()
    local client = newClient()
    equal(client.api.MoveGMToLastSpot(), true)
    equal(client.api.StartRaidNumbering(), 1)
    client.locked = true
    equal(client.api.SendNumbers(), true)
    equal(client.api.GetSendQueueView().chat.paused, true)
    -- Activating event: query is temporarily false during dispatch.
    client.locked = false
    client:event("ADDON_RESTRICTION_STATE_CHANGED", 1, 1)
    client.locked = true
    client:advance(0)
    equal(client.api.GetSendQueueView().chat.paused, true, "must stay paused on activation")
    equal(#client.chat, 0)
    client.locked = false
    client:event("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
    client:advance(3)
    equal(#client.chat, 1)
    equal(client.api.GetSendQueueView().chat.pending, 0)
end

function tests.assistant_number_dispatch()
    local client = newClient({ db = { sessionMode = "multi_assistant", multiRaid = {
        acceptedCoordinator = "Coordinator-Realm", sessionId = "MG-test", assistantRaidId = 2,
        assignmentStatus = "received", assignedRoster = { { name = "Winner", number = 9 } },
    } } })
    client:event("CHAT_MSG_ADDON", "MicroGames",
        "mr1|SEND_NUMBERS|MG-test|Coordinator-Realm|GM-Realm|2|1|-|-", "WHISPER", "Coordinator-Realm")
    client:advance(3)
    equal(#client.chat, 1)
    equal(client.chat[1].target, "Winner")
    equal(client.chat[1].message, "Your MG number is: 9")
    equal(client.api.GetMultiRaidView().numberWhisperStatus, "sent")
end

function tests.multi_winner_branches()
    for _, raidId in ipairs({ 1, 2, 0 }) do
        local entry = raidId > 0 and { name = "Winner", raidId = raidId, assistantName = "Assistant" } or nil
        local client = newClient({ db = { sessionMode = "multi_coordinator", multiRaid = {
            sessionId = "MG-test", assignmentsStatus = "assigned", totalAssigned = 1,
            globalNamesByNumber = { [1] = entry }, globalAssignments = {}, assistants = {},
        } } })
        equal(client.api.StartMultiRaidGameSession(), true)
        equal(client.api.MultiRaidRoundRoll(), true)
        client:advance(2)
        client:event("CHAT_MSG_SYSTEM", "GM rolls 1 (1-1)")
        equal(client.api.HasPendingRoll(), false)
        if raidId == 0 then equal(client.api.GetLastInvalidRoll().reason, "NO_GLOBAL_ASSIGNMENT")
        else equal(client.api.GetLastWinner().name, "Winner") end
        if raidId == 2 then equal(client.api.GetMultiRaidView().manualWinnerCheck.raidId, 2) end
    end
end

local count = 0
for name, test in pairs(tests) do
    test()
    count = count + 1
    print("PASS " .. name)
end
print(tostring(count) .. " compatibility regression tests passed")
