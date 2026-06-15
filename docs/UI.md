# UI

MicroGames uses a movable in-game window opened with `/mg` or `/microgames`.
Closing the window only hides it. It must not reset numbering, rounds, whisper text, or any game state.

## Tabs

- Control: Round roll, winner status, winner actions, reward yells, and compact setup controls.
- Roster: Shows the recorded name and number snapshot from `StartRaidNumbering()` and roster setup controls.
- Rewards: Edits reward yell templates and provides a secondary reward view.
- Settings: Edits the whisper text and round roll delay.

## UX Rules

- All visible UI text should be English.
- Loading the addon should only create UI and register commands.
- Starting numbering should only record the current raid snapshot.
- Sending numbers should be a separate explicit action.
- Round Roll should increment the round, announce `ROUND X`, and then roll after the configured delay.
- `Roll again for ROUND X` should be a smaller centered button below `Round Roll`.
- Rerolling must not increment or change the current round.
- After a roll result is detected, the UI should prominently show the winner number and matching player name.
- The winner name should be visually separated from surrounding status text with a highlighted panel/color.
- `Round Roll` is the primary gameplay button and should be visually separated from setup controls.
- Game controls should expose `START GAME` and `STOP GAME` on the Control tab.
- `START GAME` should be disabled/greyed when a game session is already active.
- `STOP GAME` should be disabled/greyed when no game session is active.
- The Control tab should display a clear text status such as `EVENT STARTED - ROUND X - MEMBERS X`.
- Roster setup controls such as start numbering, send numbers, stop numbering, reset, and reset rounds should live on the Roster tab.
- Roster setup controls should write to a Roster-local status line, not the Control status line.
- While a game session is active, roster setup controls must be disabled/greyed except `Rounds 0`.
- Tabs must stay inside the main window bounds, not below or outside the frame.
- The main window should use a high enough frame strata/level to avoid click-through into action bar addons.
- Reward yell templates should be sent only by explicit button press.
- Reward yell templates are stored in `MicroGamesDB.rewardTemplates`.
- Number whisper text is stored in `MicroGamesDB.numberWhisperText`.
- Round roll delay is stored in `MicroGamesDB.roundRollDelay`.
- Hiding or closing the UI should preserve all process state.

## Control Bindings

- `START GAME` calls `addon.API.StartGameSession()`.
- `STOP GAME` calls `addon.API.StopGameSession()` and stores the completed session in history.
- If an active session exists, `StartGameSession()` returns `ACTIVE_SESSION_EXISTS` and must not start a second session.
- `Start Numbering` calls `addon.API.StartRaidNumbering()` and records the current raid snapshot.
- `Send Numbers` calls `addon.API.SendNumbers()` and whispers numbers to recorded players.
- `Round Roll` calls `addon.API.RoundRoll()`, announces the next round, then rolls after the configured delay.
- `Roll again for ROUND X` calls `addon.API.RerollCurrentRound()`.
- `Say Winner` calls `addon.API.SendWinnerSay()` with `You win ROUND X come closer! :)`.
- `Whisper Winner` calls `addon.API.SendWinnerWhisper()` with `You win ROUND X come closer! :)`.
- Reward buttons call `addon.API.SendRewardYell(index)` from the Control tab during gameplay.
- `Stop` calls `addon.API.StopRaidNumbering()` and keeps recorded data.
- `Reset` calls `addon.API.ResetRaidNumbering()` and clears recorded names, numbers, and rounds.
- `Reset Rounds` calls `addon.API.ResetRounds()` and only clears the round counter.
- The Control tab displays `HasRaidNumbers()`, `CountRaidNumbers()`, `GetCurrentRound()`, `BuildPreviousRoundMessage()`, `BuildRoundMessage()`, and `BuildRollCommand()` output.
- The Control tab displays `BuildLastWinnerText()` and `BuildWinnerMessage()` after a detected roll.
- The Control tab displays active game session state from `GetGameSessionSummary()`.
- During `ROUND 1`, the previous completed round display should be `-`.

## Rewards Bindings

- Reward buttons call `addon.API.SendRewardYell(index)` for the selected template.
- Reward yell messages should start with the winner name, formatted as `[WinnerName]: reward text`.
- Reward buttons are shown on the Control tab for gameplay and can also appear on the Rewards tab.
- Reward templates are read from `addon.API.GetRewardTemplates()`.
- The reward input calls `addon.API.AddRewardTemplate(text)`.
- Reward row remove buttons call `addon.API.RemoveRewardTemplate(index)`.

## Roster Bindings

- The Roster tab reads `addon.API.GetRaidNumberEntries()`.
- Each visible roster row can call `addon.API.SendNumberWhisperToName(name)` for a single recorded player.
- Roster setup buttons call `StartRaidNumbering()`, `SendNumbers()`, `StopRaidNumbering()`, `ResetRaidNumbering()`, and `ResetRounds()`.
- During an active game session, roster setup buttons must not modify the roster; `Rounds 0` remains available.
- Roster pagination is UI-only and must not change recorded data.

## Settings Bindings

- The whisper text input calls `addon.API.SetNumberWhisperText(text)`.
- The whisper preview uses `addon.API.BuildNumberWhisperMessage(12)`.
- The delay input calls `addon.API.SetRoundRollDelay(seconds)`.
- Whisper text, round delay, and added reward templates persist through WoW SavedVariables.
