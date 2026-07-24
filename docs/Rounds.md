# Rounds

MicroGames keeps a separate round counter for the game master's UX.
Rounds do not advance while the addon is loading.

## Rules

- The first round starts from 1.
- `addon.API.RoundRoll()` is the handler for the `Round Roll` UX button.
- `addon.API.RoundRoll()` and `addon.API.RerollCurrentRound()` require an active game session.
- Each `RoundRoll` call increments the current round by 1.
- `addon.API.RerollCurrentRound()` rolls again for the current round without incrementing the round counter.
- A new roll or reroll cannot start while a previous delayed roll is pending.
- Round reset cannot run while a delayed roll is pending.
- Pending roll state is not restored after `/reload` because scheduled roll timers do not survive reload.
- The UI should show the current round and the previous completed round.
- During `ROUND 1`, there is no previous completed round to show.
- The addon announces the round in raid chat as `ROUND X`.
- If the `ROUND X` announcement cannot be sent, the round counter does not advance, no roll is scheduled, and the UI warns the game master.
- After a short delay, the addon rolls from 1 to the number of eligible players recorded by `StartRaidNumbering()`.
- In Single Raid mode, `StartRaidNumbering()` excludes the local player running the addon before assigning MG numbers.
- In Multi Raid Coordinator mode, the addon rolls from 1 to the global assigned player count created by `AssignMultiRaidGlobalNumbers()`.
- Multi Raid rolls and rerolls require an active Multi Raid game session started by the Coordinator.
- Winners from an Assistant raid are marked `MANUAL_ASSISTANT_CHECK`; the responsible Assistant verifies presence manually outside the addon protocol.
- If `Roll Countdown Sound` is enabled, `RAID_WARNING` countdown messages are sent during the configured roll delay so raid members receive the normal raid warning alert.
- The game master may need raid leader or assistant permissions for raid warning countdown messages.
- The delayed roll captures the recorded range at button press time.
- The roll range uses the recorded snapshot count, not the current live raid size.
- Example: if `StartRaidNumbering()` recorded 37 players, `RoundRoll()` rolls 1-37.
- After the roll result is detected, the addon stores the winner number and the matching recorded player name.
- Roll detection should only accept the game master's own roll while a round roll is pending.
- Roll detection only supports English client `CHAT_MSG_SYSTEM` roll messages.
- Round announcements and roll results are recorded into the active game session when one exists.
- The winner is resolved from the recorded raid numbering snapshot.
- If the resolved snapshot player is offline in the current live raid roster, the roll is recorded as invalid and the current round must be rerolled.
- Invalid offline rolls do not change assigned player numbers.
- The winner message is `You win ROUND X come closer! :)`.
- Reward yell templates can be selected manually after a winner is detected.
- Reward yells are never automatic.
- Reward history entries are only recorded when `addon.API.SendRewardYell(index)` is called by an explicit reward button action.
- Reward templates are persisted in `MicroGamesDB.rewardTemplates`.
- Round roll delay is persisted in `MicroGamesDB.roundRollDelay`.
- Roll countdown sound is persisted in `MicroGamesDB.rollCountdownSoundEnabled`.
- Resetting raid numbering also resets the round counter.

## API

```lua
local round = addon.API.GetCurrentRound()
local previousRound = addon.API.GetPreviousRound()
local delay = addon.API.GetRoundRollDelay()
local commandPreview = addon.API.BuildRollCommand()
local roundPreview = addon.API.BuildRoundMessage(10)
local previousRoundPreview = addon.API.BuildPreviousRoundMessage()
local rerollButtonText = addon.API.BuildRerollButtonText()
local winner = addon.API.GetLastWinner()
local winnerText = addon.API.BuildLastWinnerText()
local winnerMessage = addon.API.BuildWinnerMessage()
local rewardTemplates = addon.API.GetRewardTemplates()
local rewardYell = addon.API.BuildRewardYellMessage("10 GOLD!")

addon.API.SetRoundRollDelay(2)
addon.API.SetRollCountdownSoundEnabled(true)
addon.API.ResetRounds()
addon.API.AddRewardTemplate("20 GOLD!")
addon.API.RemoveRewardTemplate(1)

local ok, roundOrReason = addon.API.RoundRoll()
local rerollOk, rerollRoundOrReason = addon.API.RerollCurrentRound()
local multiOk, multiRoundOrReason = addon.API.MultiRaidRoundRoll()
local multiRerollOk, multiRerollRoundOrReason = addon.API.MultiRaidRerollCurrentRound()

addon.API.SendWinnerSay()
addon.API.SendWinnerWhisper()
addon.API.SendRewardYell(1)
```

`addon.API.BuildRollCommand()` returns a display preview such as `/roll 1-37`.
The real roll uses `RandomRoll(1, recordedCount)` instead of executing a slash command string.
The roll result is detected from English client `CHAT_MSG_SYSTEM` roll messages while a round roll is pending, and other players' rolls must be ignored.
Rerolls are stored as additional roll entries under the same round.
Offline-player invalid rolls are stored as invalid roll entries under the same round, and a later valid reroll replaces the round winner.
Reward yell templates default to `10 GOLD!`, `20 GOLD!`, and `KROLL BLADE BOSS`.
Custom reward templates are saved through WoW SavedVariables.
Session persistence is documented in `docs/Sessions.md`.
