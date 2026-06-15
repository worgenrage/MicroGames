# Rounds

MicroGames keeps a separate round counter for the game master's UX.
Rounds do not advance while the addon is loading.

## Rules

- The first round starts from 1.
- `addon.API.RoundRoll()` is the intended handler for a future `Round Roll` UX button.
- Each `RoundRoll` call increments the current round by 1.
- `addon.API.RerollCurrentRound()` rolls again for the current round without incrementing the round counter.
- The UI should show the current round and the previous completed round.
- During `ROUND 1`, there is no previous completed round to show.
- The addon announces the round in raid chat as `ROUND X`.
- After a short delay, the addon rolls from 1 to the number of players recorded by `StartRaidNumbering()`.
- The roll range uses the recorded snapshot count, not the current live raid size.
- Example: if `StartRaidNumbering()` recorded 37 players, `RoundRoll()` rolls 1-37.
- After the roll result is detected, the addon stores the winner number and the matching recorded player name.
- Roll detection should only accept the game master's own roll while a round roll is pending.
- Round announcements and roll results are recorded into the active game session when one exists.
- The winner is resolved from the recorded raid numbering snapshot.
- The winner message is `You win ROUND X come closer! :)`.
- Reward yell templates can be selected manually after a winner is detected.
- Reward yells are never automatic.
- Reward templates are persisted in `MicroGamesDB.rewardTemplates`.
- Round roll delay is persisted in `MicroGamesDB.roundRollDelay`.
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
addon.API.ResetRounds()
addon.API.AddRewardTemplate("20 GOLD!")
addon.API.RemoveRewardTemplate(1)

local ok, roundOrReason = addon.API.RoundRoll()
local rerollOk, rerollRoundOrReason = addon.API.RerollCurrentRound()

addon.API.SendWinnerSay()
addon.API.SendWinnerWhisper()
addon.API.SendRewardYell(1)
```

`addon.API.BuildRollCommand()` returns a display preview such as `/roll 1-37`.
The real roll uses `RandomRoll(1, recordedCount)` instead of executing a slash command string.
The roll result is detected from `CHAT_MSG_SYSTEM` while a round roll is pending, and other players' rolls must be ignored.
Rerolls are stored as additional roll entries under the same round.
Reward yell templates default to `10 GOLD!`, `20 GOLD!`, and `KROLL BLADE BOSS`.
Custom reward templates are saved through WoW SavedVariables.
Session persistence is documented in `docs/Sessions.md`.
