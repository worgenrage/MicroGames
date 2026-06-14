# UI

MicroGames uses a movable in-game window opened with `/mg` or `/microgames`.
Closing the window only hides it. It must not reset numbering, rounds, whisper text, or any game state.

## Tabs

- Control: Start numbering, send numbers, round roll, winner actions, reward yells, stop, reset, and reset rounds.
- Roster: Shows the recorded name and number snapshot from `StartRaidNumbering()`.
- Settings: Edits the whisper text, round roll delay, and reward yell templates.

## UX Rules

- All visible UI text should be English.
- Loading the addon should only create UI and register commands.
- Starting numbering should only record the current raid snapshot.
- Sending numbers should be a separate explicit action.
- Round Roll should increment the round, announce `ROUND X`, and then roll after the configured delay.
- After a roll result is detected, the UI should prominently show the winner number and matching player name.
- Reward yell templates should be sent only by explicit button press.
- Reward yell templates are stored in `MicroGamesDB.rewardTemplates`.
- Hiding or closing the UI should preserve all process state.

## Control Bindings

- `Start Numbering` calls `addon.API.StartRaidNumbering()` and records the current raid snapshot.
- `Send Numbers` calls `addon.API.SendNumbers()` and whispers numbers to recorded players.
- `Round Roll` calls `addon.API.RoundRoll()`, announces the next round, then rolls after the configured delay.
- `Say Winner` calls `addon.API.SendWinnerSay()` with `You win ROUND X come closer! :)`.
- `Whisper Winner` calls `addon.API.SendWinnerWhisper()` with `You win ROUND X come closer! :)`.
- Reward buttons call `addon.API.SendRewardYell(index)` for the selected template.
- `Stop` calls `addon.API.StopRaidNumbering()` and keeps recorded data.
- `Reset` calls `addon.API.ResetRaidNumbering()` and clears recorded names, numbers, and rounds.
- `Reset Rounds` calls `addon.API.ResetRounds()` and only clears the round counter.
- The Control tab displays `HasRaidNumbers()`, `CountRaidNumbers()`, `GetCurrentRound()`, `BuildPreviousRoundMessage()`, `BuildRoundMessage()`, and `BuildRollCommand()` output.
- The Control tab displays `BuildLastWinnerText()` and `BuildWinnerMessage()` after a detected roll.
- The Control tab displays reward yell template buttons from `GetRewardTemplates()`.
- During `ROUND 1`, the previous completed round display should be `-`.

## Roster Bindings

- The Roster tab reads `addon.API.GetRaidNumberEntries()`.
- Each visible roster row can call `addon.API.SendNumberWhisperToName(name)` for a single recorded player.
- Roster pagination is UI-only and must not change recorded data.

## Settings Bindings

- The whisper text input calls `addon.API.SetNumberWhisperText(text)`.
- The whisper preview uses `addon.API.BuildNumberWhisperMessage(12)`.
- The delay input calls `addon.API.SetRoundRollDelay(seconds)`.
- The reward input calls `addon.API.AddRewardTemplate(text)`.
- Reward row remove buttons call `addon.API.RemoveRewardTemplate(index)`.
- Added reward templates persist through WoW SavedVariables.
