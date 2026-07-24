# UI

MicroGames uses a movable in-game window opened with `/mg` or `/microgames`.
Closing the window only hides it. It must not reset numbering, rounds, whisper text, or any game state.
The global mode selector defaults to `Single Raid` and is locked while a game session or roll is active.
The `Min` button collapses the window to a small frame without hiding or resetting it.
The `Max` button expands the collapsed frame back to the current tab.
When the WoW trade window opens, MicroGames automatically collapses if it is visible.
When the trade window closes, MicroGames expands again only if the trade opening caused the collapse.

In `Multi Raid - Coordinator` mode, the Setup tab shows assistant invite controls and assistant auth status. In `Multi Raid - Assistant` mode, Setup shows pending Coordinator invites and accept/reject controls.
Coordinator Setup can request accepted Assistant rosters. Assistant Setup can record the local raid, excluding the Assistant character, and send the recorded roster to the Coordinator. If the local raid roster changes after recording, the Assistant roster is marked stale and must be recorded again.
Coordinator Setup can record the main raid, assign global numbers across received rosters, send assignment ranges to Assistants, dispatch number whispers, and start/stop the Multi Raid game session. In Multi Raid Coordinator mode, Control round rolls use the global assigned range only after the Multi Raid game is active, and Assistants automatically relay round and roll result messages into their own raid chat.

## Tabs

- Control: Round roll, winner status, winner actions, reward yells, and compact setup controls.
- Setup: Prepares the live raid layout, shows the recorded name and number snapshot from `StartRaidNumbering()`, and provides setup controls.
- Rewards: Edits reward yell templates and provides a secondary reward view.
- History: Shows completed sessions, session details, round results, winners, and rewards.
- History marks completed sessions as `Single` or `Multi`; Multi sessions include the multi session ID, Coordinator, raid ranges, winner raid IDs, and manual Assistant-check status.
- Monitoring: Shows live addon-message debug state from another MicroGames user in the same party or raid.
- Settings: Edits the whisper text and round roll delay.
- Settings also controls roll countdown raid warning alerts.

## UX Rules

- All visible UI text should be English.
- Loading the addon should only create UI and register commands.
- `Move GM to Last Spot` should scan the live raid layout and swap the GM into the last used subgroup before any Single Raid snapshot is recorded.
- `Record Raid` should stay disabled until the GM move is verified.
- Starting numbering should only record the current raid snapshot after the GM move is ready.
- Sending numbers should be a separate explicit action.
- Sending numbers requires active numbering; stopped snapshots remain visible but cannot be whispered.
- Round Roll should increment the round, announce `ROUND X`, and then roll after the configured delay.
- If the round announcement cannot be sent, the roll must remain cancelled and the Control status must warn the game master.
- Round Roll and reroll require an active game session.
- `Roll again for ROUND X` should be a smaller centered button below `Round Roll`.
- Rerolling must not increment or change the current round.
- After a roll result is detected, the UI should prominently show the winner number and matching player name.
- After a Single Raid roll resolves, the Control status should show the winner, offline reroll requirement, or timeout instead of retaining the earlier pending-roll text.
- Single Raid Control exposes a visible `Auto Announce winner + whisper` checkbox next to the manual winner actions. It defaults to off and persists through `MicroGamesDB.autoAnnounceWinnerEnabled`.
- When enabled, a valid online Single Raid winner queues both the `{rt1}` raid winner announcement and the winner whisper. The Control status reports full success, partial failure, or complete failure.
- The winner name should be visually separated from surrounding status text with a highlighted panel/color.
- `Round Roll` is the primary gameplay button and should be visually separated from setup controls.
- Game controls should expose `START GAME` and `STOP GAME` on the Control tab.
- `START GAME` should be disabled/greyed when a game session is already active.
- `STOP GAME` should be disabled/greyed when no game session is active.
- The Control tab should display a clear text status such as `EVENT STARTED - ROUND X - MEMBERS X`.
- Setup controls such as move GM, record raid, send numbers, and clear raid should live on the Setup tab.
- Setup controls should write to a Setup-local status line, not the Control status line.
- While a game session is active or a roll is pending, setup controls and per-player number sends must be disabled/greyed.
- Multi Raid Setup buttons must also reflect roster, assignment, queue, invite, and game-session readiness instead of relying only on API error responses.
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
- Pressing `Start GM Live` makes the local user the Monitoring broadcaster; otherwise the local user is an observer.
- `Start GM Live` is disabled until a game session is active.
- Stopping the game session stops GM live monitoring.
- Observers lock to the first observed GM sender until `Clear GM` is pressed.

## Control Bindings

- `START GAME` calls `addon.API.StartGameSession()`.
- `STOP GAME` calls `addon.API.StopGameSession()`, stores the completed session in history, and clears runtime roster/round/winner state for the next game.
- If an active session exists, `StartGameSession()` returns `ACTIVE_SESSION_EXISTS` and must not start a second session.
- `Move GM to Last Spot` calls `addon.API.MoveGMToLastSpot()` and prepares the live raid layout without recording a MicroGames snapshot.
- `Record Raid` is enabled only when `addon.API.CanRecordRaid()` is true, then calls `addon.API.StartRaidNumbering()` and records the current raid snapshot.
- `Send Numbers` calls `addon.API.SendNumbers()` and whispers numbers to recorded players only while numbering is active.
- Multi Raid `Send Numbers` calls `addon.API.SendMultiRaidNumbers()`; the Coordinator whispers main-raid players and Assistants automatically whisper their own assigned players.
- Multi Raid `Start Multi` calls `addon.API.StartMultiRaidGameSession()` and enables Coordinator multi round rolls.
- Multi Raid `Stop Multi` calls `addon.API.StopMultiRaidGameSession()` and tells Assistants to mark the multi game stopped.
- Multi Raid start/stop remains a successful local state transition when only an Assistant notification fails; the Setup status shows that delivery problem as a warning.
- `Round Roll` calls `addon.API.RoundRoll()`, announces the next round, then rolls after the configured delay.
- In Multi Raid Coordinator mode, `Round Roll` calls `addon.API.MultiRaidRoundRoll()` and requires an active Multi Raid game session.
- `Roll again for ROUND X` calls `addon.API.RerollCurrentRound()`.
- In Multi Raid Coordinator mode, `Roll again for ROUND X` calls `addon.API.MultiRaidRerollCurrentRound()` and requires an active Multi Raid game session.
- `Say Winner` calls `addon.API.SendWinnerSay()` with `You win ROUND X! Your MG number #N was rolled. Come closer! :)`.
- `Whisper Winner` calls `addon.API.SendWinnerWhisper()` with `You win ROUND X! Your MG number #N was rolled. Come closer! :)`.
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
- Setup buttons call `MoveGMToLastSpot()`, `StartRaidNumbering()`, `SendNumbers()`, and `ResetRaidNumbering()`.
- The Setup status line displays `GetGMMoveView().message` while Single Raid has no recorded numbers.
- During an active game session or pending roll, setup buttons must not modify the roster or send number whispers.
- Roster pagination is UI-only and must not change recorded data.

## Settings Bindings

- The whisper text input calls `addon.API.SetNumberWhisperText(text)`.
- The whisper preview uses `addon.API.BuildNumberWhisperMessage(12)`.
- The delay input calls `addon.API.SetRoundRollDelay(seconds)`.
- The `Roll Countdown Sound` checkbox calls `addon.API.SetRollCountdownSoundEnabled(enabled)`.
- The `Test Sound` button calls `addon.API.TestRollCountdownSound()` and sends one raid warning test only when roll countdown sound is enabled.
- The Single Raid Control checkbox calls `addon.API.SetAutoAnnounceWinnerEnabled(enabled)`.
- Whisper text, round delay, roll countdown sound, automatic winner announce, and added reward templates persist through WoW SavedVariables.

## Monitoring Bindings

- The Monitoring tab reads `addon.API.GetMonitoringView()`.
- `Start GM Live` calls `addon.API.StartMonitoringBroadcast()` and sends compact addon-message state updates every 1 second to raid or party.
- `Stop GM Live` calls `addon.API.StopMonitoringBroadcast()`.
- `Send Update` calls `addon.API.BroadcastMonitoringState()` and sends one compact addon-message state update to raid or party.
- `Clear GM` calls `addon.API.ClearMonitoringLog()` and clears the observed GM lock plus the received log.
- Received monitoring updates show source, event, session state, round, recorded players, pending roll, winner, and visible reward templates.
- Monitoring data is runtime-only and is not stored in SavedVariables.
