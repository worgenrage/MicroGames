# MicroGames Development Notes

## Project State

MicroGames is a WoW Classic Era / Hardcore 1.15.9 addon.

- TOC interface: `11509`
- Lua target: Blizzard WoW addon sandbox, Lua 5.1 subset
- Language server flavor: `classic_era`
- Supported client language: English only
- Main files:
  - `API.lua`
  - `UI.lua`
  - `MicroGames.lua`

## Load And Commands

- The addon registers:
  - `/mg`
  - `/microgames`
- The UI is created lazily when the slash command is used.
- The UI should not open automatically on load or `/reload`.
- On login it prints:
  `MicroGames loaded. Type /mg or /microgames to open.`

## SavedVariables

The addon uses:

```toc
## SavedVariables: MicroGamesDB
```

Current stored fields:

- `MicroGamesDB.numberWhisperText`
- `MicroGamesDB.roundRollDelay`
- `MicroGamesDB.rollCountdownSoundEnabled`
- `MicroGamesDB.sessionMode`
- `MicroGamesDB.multiRaid`
- `MicroGamesDB.rewardTemplates`
- `MicroGamesDB.activeSession`
- `MicroGamesDB.history`

Monitoring data is runtime-only and is not persisted.

Multi-raid setup and runtime coordination data, including `MicroGamesDB.multiRaid.activeSession`, is stored under `MicroGamesDB.multiRaid`.

## Raid Numbering

Raid roster indexes are not used as stable game IDs during gameplay.

Workflow:

1. Take a snapshot of the current raid roster.
2. Exclude the local player running the addon from the eligible snapshot.
3. Assign stable MG numbers by snapshot order.
4. Store both number-to-name and name-to-number mappings.
5. Do not shift numbers when players leave.

Main API:

```lua
addon.API.StartRaidNumbering()
addon.API.MoveGMToLastSpot()
addon.API.GetGMMoveView()
addon.API.CanRecordRaid()
addon.API.StopRaidNumbering()
addon.API.ResetRaidNumbering()
addon.API.CountRaidNumbers()
addon.API.GetRaidNumberEntries()
addon.API.GetRaidNumberByName(name)
addon.API.GetRaidNameByNumber(number)
addon.API.SendNumbers()
addon.API.SendNumberWhisperToName(name)
```

Number whispers require active numbering. `StopRaidNumbering()` keeps the recorded list visible but disables number whisper sending until numbering is started again.
Bulk number whispers are sent through a throttled queue instead of one frame burst sending.
In Single Raid mode, the local player running the addon is never assigned an MG number.
Before Single Raid recording, `MoveGMToLastSpot()` scans the live raid layout and swaps the GM into the last used raid subgroup. `Record Raid` stays locked until that move is verified.

Default number whisper:

```text
Your MG number is: XX
```

`XX` is replaced with the assigned MG number.

## Game Sessions

Game sessions persist across `/reload`, window close/open, and UI recreation.

Main API:

```lua
addon.API.StartGameSession()
addon.API.StopGameSession()
addon.API.HasActiveGameSession()
addon.API.GetGameSessionSummary()
addon.API.GetGameHistory()
addon.API.ResetAllData()
addon.API.CanModifyRoster()
```

Rules:

- `START GAME` starts a new active session.
- If there is already an active session, `StartGameSession()` returns `ACTIVE_SESSION_EXISTS`.
- `STOP GAME` stops the active session and appends it to `MicroGamesDB.history`.
- After `STOP GAME` saves the completed session, runtime roster, round, pending roll, and winner state are cleared so the next game uses a fresh raid snapshot.
- Active Single Raid sessions are stored in `MicroGamesDB.activeSession`.
- Active Multi Raid sessions are stored in `MicroGamesDB.multiRaid.activeSession`.
- Both session types restore current round, winner, and invalid-roll state after `/reload`; scheduled pending rolls are cleared.
- Completed sessions are stored in `MicroGamesDB.history`.
- While a game session is active or a roll is pending, setup controls are locked.

Saved session data includes:

- start and stop timestamps
- session type (`single` or `multi`)
- roster snapshot
- assigned count
- round count
- roll results
- rerolls
- winners
- rewards

## Rounds And Rolls

Main API:

```lua
addon.API.RoundRoll()
addon.API.RerollCurrentRound()
addon.API.GetCurrentRound()
addon.API.HasPendingRoll()
addon.API.GetPreviousRound()
addon.API.ResetRounds()
addon.API.BuildRoundMessage(roundNumber)
addon.API.BuildPreviousRoundMessage()
addon.API.BuildRollCommand()
addon.API.BuildRerollButtonText()
addon.API.SetRoundRollDelay(seconds)
addon.API.GetRoundRollDelay()
addon.API.SetRollCountdownSoundEnabled(enabled)
addon.API.GetRollCountdownSoundEnabled()
addon.API.TestRollCountdownSound()
addon.API.BroadcastMonitoringState()
addon.API.StartMonitoringBroadcast()
addon.API.StopMonitoringBroadcast()
addon.API.GetMonitoringBroadcastEnabled()
addon.API.GetMonitoringView()
addon.API.ClearMonitoringLog()
```

Rules:

- `RoundRoll()` increments the round counter.
- `RoundRoll()` and `RerollCurrentRound()` require an active game session.
- It announces `ROUND X` in raid chat.
- If the round announcement fails, the action returns `ROUND_ANNOUNCEMENT_FAILED_*`, leaves the round counter unchanged, and does not schedule a roll.
- After the configured delay, it rolls `RandomRoll(1, assignedCount)`.
- If `Roll Countdown Sound` is enabled, `RAID_WARNING` countdown messages are sent during the configured delay so raid members receive the normal raid warning alert.
- `TestRollCountdownSound()` sends a one-off `RAID_WARNING` test message only when `Roll Countdown Sound` is enabled.
- The game master may need raid leader or assistant permissions for raid warning countdown messages.
- Roll range is based on the recorded eligible snapshot count, excluding the local player running the addon.
- `RerollCurrentRound()` rolls again for the current round without incrementing the round counter.
- `RoundRoll()` and `RerollCurrentRound()` return `ROLL_PENDING` while a previous delayed roll is still pending.
- Pending roll state is not restored after `/reload` because scheduled roll timers do not survive reload.
- Rerolls are saved under the same round as additional roll entries.
- Roll result detection listens to `CHAT_MSG_SYSTEM`.
- Only the game master's own pending roll is accepted.
- Other players' rolls are ignored.
- If a roll resolves to an offline recorded snapshot player, the roll is marked invalid and the same round must be rerolled.
- Offline invalid rolls do not change or shift assigned player numbers.

## Monitoring

Monitoring uses WoW addon messages with the `MicroGames` prefix.

Main API:

```lua
addon.API.BroadcastMonitoringState()
addon.API.StartMonitoringBroadcast()
addon.API.StopMonitoringBroadcast()
addon.API.GetMonitoringBroadcastEnabled()
addon.API.GetMonitoringView()
addon.API.ClearMonitoringLog()
```

Rules:

- Broadcasts go to `RAID` when the player is in a raid, otherwise `PARTY` when grouped.
- No broadcast is sent while solo.
- The user who presses `Start GM Live` is the GM broadcaster.
- `Start GM Live` requires an active game session.
- Stopping the game session stops GM live monitoring.
- Clients that do not start GM live stay observers.
- Observers lock to the first observed GM sender and ignore competing Monitoring senders until `Clear GM` is pressed.
- Live monitoring sends compact runtime state updates every 1 second while enabled.
- Broadcast payloads are compact runtime state frames for debugging another user's addon state.
- Monitoring state updates include source, event, session state, round, recorded player count, pending roll, winner, and visible reward templates.
- The Monitoring tab is read-only for remote state and must not modify gameplay state.
- Key gameplay state changes also broadcast immediate updates while live monitoring is enabled.
- Reward template changes broadcast immediate updates while live monitoring is enabled.

## Winner Actions

Winner data is resolved by matching the roll result number to the recorded roster snapshot.

Main API:

```lua
addon.API.GetLastWinner()
addon.API.BuildLastWinnerText()
addon.API.BuildWinnerMessage()
addon.API.SendWinnerSay()
addon.API.SendWinnerWhisper()
```

Winner message:

```text
You win ROUND X come closer! :)
```

## Rewards

Reward templates are persisted in `MicroGamesDB.rewardTemplates`.

Default reward templates:

- `10 GOLD!`
- `20 GOLD!`
- `KROLL BLADE BOSS`

Main API:

```lua
addon.API.GetRewardTemplates()
addon.API.AddRewardTemplate(text)
addon.API.RemoveRewardTemplate(index)
addon.API.BuildRewardYellMessage(rewardText)
addon.API.SendRewardYell(index)
```

Reward yell format:

```text
[WinnerName]: reward text
```

Reward yells are explicit button actions. They are never automatic after a roll.

## UI

The main UI is movable and uses high enough frame strata/level to avoid click-through into action bar addons:

- `DIALOG` strata
- frame level `100`
- tabs are inside the main frame bounds
- the global mode selector defaults to `Single Raid`
- mode options are `Single Raid`, `Multi Raid - Coordinator`, and `Multi Raid - Assistant`
- mode switching is locked while a game session or roll is active
- `Min` collapses the UI to a small frame without resetting state
- `Max` expands the collapsed frame back to the current tab
- `TRADE_SHOW` automatically collapses the UI when the frame is visible
- `TRADE_CLOSED` expands it again only when trade opening caused the collapse

Tabs:

- `Control`
- `Setup`
- `Rewards`
- `History`
- `Monitoring`
- `Settings`

### Control

Gameplay-focused tab.

Contains:

- round status
- recorded member count
- active game session status
- large `Round Roll` button
- smaller centered `Roll again for ROUND X` button
- highlighted winner panel
- winner say/whisper buttons
- reward yell buttons
- `GAME CONTROL`
  - `START GAME`
  - `STOP GAME`

Session state display:

```text
EVENT STARTED - ROUND X - MEMBERS X
EVENT STOPPED - ROUND X - MEMBERS X
```

`START GAME` and `STOP GAME` visually reflect session state:

- Start disabled while active
- Stop disabled while inactive

### Setup

Raid snapshot and setup tab.

Contains:

- recorded player number/name list
- per-player send button
- roster pagination
- setup buttons:
  - `Record Raid`
  - `Send Numbers`
  - `Clear Raid`
- Setup-local status line

Setup controls, including per-player number sends, are locked while a game session is active or a roll is pending.

In `Multi Raid - Coordinator` mode, Setup shows Coordinator auth controls:

- session ID
- assistant character name input
- assistant invite/status list
- roster request control
- assistant roster status and eligible count
- main-raid roster recording
- global number assignment
- global number whisper dispatch
- multi game start/stop controls
- assistant assignment range/status
- multi-raid auth log and clear control

In `Multi Raid - Assistant` mode, Setup shows Assistant auth controls:

- pending Coordinator invite
- accepted Coordinator/session status
- `Accept` / `Reject` invite controls
- `Record Local Raid`
- `Send Roster`
- local roster status and eligible count
- assigned global range and assignment status
- automatic number whisper relay after Coordinator dispatch
- multi game start/stop status
- multi-raid auth log and clear control

Multi-raid auth uses addon-message whispers through the `MicroGames` prefix. Assistants are manually added by character name; `Name-Realm` is supported when needed. Existing Single Raid gameplay actions are blocked while a multi-raid mode is selected.

Multi-raid roster sync is Assistant-owned:

- The Assistant records its current raid snapshot locally.
- The Assistant excludes itself from eligible players.
- The Assistant sends the recorded roster to the Coordinator through chunked addon-message whispers.
- The Coordinator can request rosters, but the request does not remotely create a snapshot.
- If the Assistant raid roster changes after recording, the local roster becomes stale and must be recorded again before sending.
- The Coordinator records its own main raid separately and excludes the Coordinator character.
- The Coordinator assigns global numbers only after its own roster is recorded and accepted Assistant rosters are received.
- Assignments are sent to Assistants as chunked addon-message whispers.
- Roster and assignment receivers reject incomplete, duplicated, out-of-range, and mismatched chunk sequences.
- The Coordinator can dispatch global number whispers after assignment; the Coordinator whispers main-raid players and Assistants whisper their own assigned local players.
- Bulk visible whispers and chunked roster/assignment addon messages are throttled through send queues to avoid WoW chat and addon-message rate limits.
- The Coordinator must start the Multi Raid game session before multi round rolls or rerolls can run.
- Active multi games lock roster recording, roster sending, and global assignment changes.
- Coordinator multi-raid round announcements and roll results are relayed by Assistants into their own raid chat.
- Completed Multi Raid sessions are appended to the same `MicroGamesDB.history` list as Single Raid sessions with `sessionType = "multi"`.
- Multi Raid history stores the Coordinator, multi session ID, global roster assignments, raid ranges, Assistant summaries, round results, winner raid IDs, manual Assistant-check status, invalid local-raid offline rolls, and rewards.
- Winners assigned to an Assistant raid are checked manually by that Assistant; the addon does not send automatic winner verification requests.
- Resetting Single Raid data, clearing Multi Raid state, or using `RESET ALL` cancels pending send queues.

### Rewards

Reward template management and secondary reward view.

Contains:

- reward yell buttons
- add reward template
- remove reward template
- reward template pagination

### History

Completed game session viewer.

Contains:

- completed session list
- history pagination
- selected session details
- paginated round results for the selected session
- winner and roll timestamp per round
- reward text and reward timestamp per round

### Monitoring

Runtime debug tab for observing another MicroGames client in the same party or raid.

Contains:

- live remote state
- local debug state and selected broadcast channel
- remote reward templates
- `Start GM Live` / `Stop GM Live`
- `Send Update`
- `Clear GM`
- received monitoring event log

The tab uses addon messages only through `C_ChatInfo.SendAddonMessage`. It does not send visible raid chat, whispers, yells, rolls, or rewards.

### Settings

Contains:

- number whisper text
- round roll delay
- roll countdown sound
- two-step `RESET ALL` data wipe control

`RESET ALL` clears runtime state and resets `MicroGamesDB`, including active session, completed history, reward templates, round state, roster snapshot, and settings.

Both persist through SavedVariables.

## Documentation Files

- `AGENT.MD`: standing agent/project rules
- `README.md`: public GitHub and CurseForge overview
- `LICENSE`: MIT license and author attribution
- `DEV.MD`: current development state summary
- `docs/ReleasePackage.md`: recommended release ZIP contents
- `docs/RaidNumbering.md`: raid numbering model
- `docs/Rounds.md`: round/roll/reroll/winner model
- `docs/Sessions.md`: active session and history persistence
- `docs/UI.md`: UI layout and control bindings

## Validation Commands

From project root:

```powershell
& 'C:\Users\hamar\AppData\Roaming\JetBrains\Rider2026.1\plugins\wowlua-ls\server\win32-x64\wowlua_ls.exe' check .
git diff --check
```

## Known Next Steps

- Consider embedding ChatThrottleLib later if the internal queues need more adaptive traffic shaping.
- Add repeatable mocked runtime tests for session restore, chunk rejection, queue cancellation, and announcement failure paths.
