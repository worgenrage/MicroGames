# UI

MicroGames uses a movable in-game window opened with `/mg` or `/microgames`.
Closing the window only hides it. It must not reset numbering, rounds, whisper text, or any game state.
The `Mini` button collapses the window to a small frame without hiding or resetting it.
The `Open` button expands the collapsed frame back to the current tab.
When the WoW trade window opens, MicroGames automatically collapses if it is visible.
When the trade window closes, MicroGames expands again only if the trade opening caused the collapse.

## Tabs

- Control: Round roll, winner status, winner actions, reward yells, and compact setup controls.
- Setup: Shows the recorded name and number snapshot from `StartRaidNumbering()` and setup controls.
- Rewards: Edits reward yell templates and provides a secondary reward view.
- History: Shows completed sessions, session details, round results, winners, and rewards.
- Monitoring: Shows live addon-message debug state from another MicroGames user in the same party or raid.
- Settings: Edits the whisper text and round roll delay.
- Settings also controls roll countdown raid warning alerts.

## UX Rules

- All visible UI text should be English.
- Loading the addon should only create UI and register commands.
- Starting numbering should only record the current raid snapshot.
- Sending numbers should be a separate explicit action.
- Sending numbers requires active numbering; stopped snapshots remain visible but cannot be whispered.
- Round Roll should increment the round, announce `ROUND X`, and then roll after the configured delay.
- Round Roll and reroll require an active game session.
- `Roll again for ROUND X` should be a smaller centered button below `Round Roll`.
- Rerolling must not increment or change the current round.
- After a roll result is detected, the UI should prominently show the winner number and matching player name.
- The winner name should be visually separated from surrounding status text with a highlighted panel/color.
- `Round Roll` is the primary gameplay button and should be visually separated from setup controls.
- Game controls should expose `START GAME` and `STOP GAME` on the Control tab.
- `START GAME` should be disabled/greyed when a game session is already active.
- `STOP GAME` should be disabled/greyed when no game session is active.
- The Control tab should display a clear text status such as `EVENT STARTED - ROUND X - MEMBERS X`.
- Setup controls such as record raid, send numbers, and clear raid should live on the Setup tab.
- Setup controls should write to a Setup-local status line, not the Control status line.
- While a game session is active or a roll is pending, setup controls and per-player number sends must be disabled/greyed.
- Tabs must stay inside the main window bounds, not below or outside the frame.
- The main window should use a high enough frame strata/level to avoid click-through into action bar addons.
- Reward yell templates should be sent only by explicit button press.
- Reward yell templates are stored in `MicroGamesDB.rewardTemplates`.
- Number whisper text is stored in `MicroGamesDB.numberWhisperText`.
- Round roll delay is stored in `MicroGamesDB.roundRollDelay`.
- Roll countdown sound is stored in `MicroGamesDB.rollCountdownSoundEnabled`.
- Hiding or closing the UI should preserve all process state.
- Collapsing and expanding the UI should preserve all process state and the selected tab.
- Monitoring must be read-only for remote state and must not change gameplay state.

## Control Bindings

- `START GAME` calls `addon.API.StartGameSession()`.
- `STOP GAME` calls `addon.API.StopGameSession()`, stores the completed session in history, and clears runtime roster/round/winner state for the next game.
- If an active session exists, `StartGameSession()` returns `ACTIVE_SESSION_EXISTS` and must not start a second session.
- `Record Raid` calls `addon.API.StartRaidNumbering()` and records the current raid snapshot.
- `Send Numbers` calls `addon.API.SendNumbers()` and whispers numbers to recorded players only while numbering is active.
- `Round Roll` calls `addon.API.RoundRoll()`, announces the next round, then rolls after the configured delay.
- `Roll again for ROUND X` calls `addon.API.RerollCurrentRound()`.
- `Say Winner` calls `addon.API.SendWinnerSay()` with `You win ROUND X come closer! :)`.
- `Whisper Winner` calls `addon.API.SendWinnerWhisper()` with `You win ROUND X come closer! :)`.
- Reward buttons call `addon.API.SendRewardYell(index)` from the Control tab during gameplay.
- `Clear Raid` calls `addon.API.ResetRaidNumbering()` and clears recorded names, numbers, and rounds.
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

## Setup Bindings

- The Setup tab reads `addon.API.GetRaidNumberEntries()`.
- Each visible roster row can call `addon.API.SendNumberWhisperToName(name)` for a single recorded player while setup is unlocked.
- Setup buttons call `StartRaidNumbering()`, `SendNumbers()`, and `ResetRaidNumbering()`.
- During an active game session or pending roll, setup buttons must not modify the roster or send number whispers.
- Roster pagination is UI-only and must not change recorded data.

## Settings Bindings

- The whisper text input calls `addon.API.SetNumberWhisperText(text)`.
- The whisper preview uses `addon.API.BuildNumberWhisperMessage(12)`.
- The delay input calls `addon.API.SetRoundRollDelay(seconds)`.
- The `Roll Countdown Sound` checkbox calls `addon.API.SetRollCountdownSoundEnabled(enabled)`.
- The `Test Sound` button calls `addon.API.TestRollCountdownSound()` and sends one raid warning test only when roll countdown sound is enabled.
- Whisper text, round delay, roll countdown sound, and added reward templates persist through WoW SavedVariables.

## Monitoring Bindings

- The Monitoring tab reads `addon.API.GetMonitoringView()`.
- `Start Live` calls `addon.API.StartMonitoringBroadcast()` and sends compact addon-message state updates every 1 second to raid or party.
- `Stop Live` calls `addon.API.StopMonitoringBroadcast()`.
- `Send Update` calls `addon.API.BroadcastMonitoringState()` and sends one compact addon-message state update to raid or party.
- `Clear Log` calls `addon.API.ClearMonitoringLog()`.
- Received monitoring updates show source, event, session state, round, recorded players, pending roll, and winner.
- Monitoring data is runtime-only and is not stored in SavedVariables.
