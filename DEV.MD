# MicroGames Development Notes

## Project State

MicroGames is a WoW Classic Era / Hardcore 1.15.8 addon.

- TOC interface: `11508`
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
- `MicroGamesDB.rewardTemplates`
- `MicroGamesDB.activeSession`
- `MicroGamesDB.history`

## Raid Numbering

Raid roster indexes are not used as stable game IDs during gameplay.

Workflow:

1. Take a snapshot of the current raid roster.
2. Assign stable MG numbers by snapshot order.
3. Store both number-to-name and name-to-number mappings.
4. Do not shift numbers when players leave.

Main API:

```lua
addon.API.StartRaidNumbering()
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
- Active sessions are stored in `MicroGamesDB.activeSession`.
- Completed sessions are stored in `MicroGamesDB.history`.
- While a game session is active or a roll is pending, setup controls are locked.

Saved session data includes:

- start and stop timestamps
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
```

Rules:

- `RoundRoll()` increments the round counter.
- `RoundRoll()` and `RerollCurrentRound()` require an active game session.
- It announces `ROUND X` in raid chat.
- After the configured delay, it rolls `RandomRoll(1, assignedCount)`.
- If `Roll Countdown Sound` is enabled, `RAID_WARNING` countdown messages are sent during the configured delay so raid members receive the normal raid warning alert.
- The game master may need raid leader or assistant permissions for raid warning countdown messages.
- Roll range is based on the recorded raid snapshot count.
- `RerollCurrentRound()` rolls again for the current round without incrementing the round counter.
- `RoundRoll()` and `RerollCurrentRound()` return `ROLL_PENDING` while a previous delayed roll is still pending.
- Pending roll state is not restored after `/reload` because scheduled roll timers do not survive reload.
- Rerolls are saved under the same round as additional roll entries.
- Roll result detection listens to `CHAT_MSG_SYSTEM`.
- Only the game master's own pending roll is accepted.
- Other players' rolls are ignored.

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
- `Mini` collapses the UI to a small frame without resetting state
- `Open` expands the collapsed frame back to the current tab
- `TRADE_SHOW` automatically collapses the UI when the frame is visible
- `TRADE_CLOSED` expands it again only when trade opening caused the collapse

Tabs:

- `Control`
- `Setup`
- `Rewards`
- `History`
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
- `DEV.MD`: current development state summary
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

- Consider chat throttling for mass whisper sending.
