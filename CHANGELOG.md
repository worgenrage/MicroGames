# Changelog

## 0.2.1

- Fixed Single Raid roster recording so the local player running the addon is excluded from MG number assignment.
- Single Raid roll ranges now use the eligible recorded player count instead of the full raid size.
- Kept winner lookup and offline reroll behavior based on the stable recorded snapshot.

## 0.2.0

- Added completed Multi Raid session history persistence.
- Record Multi Raid rounds, rolls, winner raid IDs, Assistant verification status, invalid offline rolls, and rewards into history.
- Show `Single` vs `Multi` session type in the History session list and details.
- Added Multi Raid session details to History, including session ID, Coordinator, and raid number ranges.
- Keep Single Raid session history behavior unchanged while sharing the same history list.

## 0.1.14

- Added explicit Multi Raid game session start/stop lifecycle for Coordinator and accepted Assistants.
- Added Coordinator `Send Numbers` dispatch for global assignments, with Assistant-side automatic whisper relay for Assistant raid players.
- Locked multi-raid roster and assignment mutation while a multi game is active.
- Required an active Multi Raid session before Coordinator round rolls and rerolls can run.
- Added Assistant status reporting for number whisper success/failure and game start/stop.

## 0.1.13

- Added Multi Raid Coordinator main-raid roster recording.
- Added global number assignment across the Coordinator raid and accepted Assistant rosters.
- Added assignment sync to Assistants with assigned global ranges and per-player global numbers.
- Added automatic Assistant-side RAID relay for Coordinator multi-raid round announcements and roll results.
- Added Multi Raid Coordinator round roll and reroll handling using the global assigned range.

## 0.1.12

- Added Assistant-side local raid roster recording for multi-raid sessions.
- Added Assistant-to-Coordinator roster sync messages with chunked `ROSTER_BEGIN`, `ROSTER_ROW`, and `ROSTER_END` addon-message whispers.
- Added Coordinator roster request handling and assistant roster status tracking.
- Mark Assistant local rosters stale when the local raid roster changes after recording.
- Added Setup controls for `Request Rosters`, `Record Local Raid`, and `Send Roster`.

## 0.1.11

- Treat roll results for offline snapshot players as invalid instead of selecting them as winners.
- Record invalid offline rolls in round history and keep the round open for reroll.
- Block starting a new round while the current round has an invalid offline roll that needs rerolling.
- Added multi-raid winner verification message scaffolding for Coordinator-to-Assistant online checks.

## 0.1.10

- Added initial Multi Raid Coordinator/Assistant authentication flow over addon-message whispers.
- Added Coordinator Setup controls for adding assistant character names and sending session invites.
- Added Assistant Setup controls for accepting or rejecting Coordinator invites.
- Added multi-raid session IDs, assistant status tracking, auth logs, and duplicate message protection.

## 0.1.9

- Added a persisted global session mode selector with `Single Raid` as the default mode.
- Added scaffold options for `Multi Raid - Coordinator` and `Multi Raid - Assistant` without changing the stable Single Raid workflow.
- Locked session mode changes while a game session or roll is active.
- Blocked existing Single Raid roster/session actions when a multi-raid scaffold mode is selected.

## 0.1.8

- Stopped live Monitoring tickers and cleared runtime Monitoring state during `RESET ALL`.
- Hardened roster mutation APIs so raid recording, stopping, and clearing cannot bypass active-session or pending-roll locks.
- Capped reward template and Monitoring payload text to keep addon-message updates within WoW chat payload limits.
- Fixed History default selection so the selected completed session is visible on the current history page.
- Fixed `/mg` and `/microgames` so the first command invocation opens the lazily created UI instead of requiring a second Enter.
- Renamed the collapse control labels to `Min` and `Max`.

## 0.1.7

- Added read-only reward template sync to live Monitoring addon-message updates.
- Sends immediate Monitoring updates when reward templates are added or removed while live monitoring is enabled.
- Clarified Monitoring roles: `Start GM Live` makes the local user the broadcaster, and observers lock to the first observed GM until cleared.
- Restricts `Start GM Live` to active game sessions and stops live monitoring when the game session stops.

## 0.1.6

- Added a Settings `Test Sound` button for roll countdown raid warning alerts.
- Added a `Monitoring` tab with live addon-message debug broadcasts for remote state observation.
- Hardened monitoring addon-message sends behind prefix registration and group-channel checks.

## 0.1.5

- Added a persisted `Roll Countdown Sound` setting.
- Sends guarded `RAID_WARNING` countdown messages before round rolls and rerolls when enabled.
- Documented that raid warning countdowns may require raid leader or assistant permissions.

## 0.1.4

- Hardened game state transitions so round rolls and rerolls require an active game session.
- Prevented pending roll state from persisting through reloads.
- Blocked stopping a game or resetting rounds while a roll is pending.
- Prevented stopped/inactive raid snapshots from sending number whispers.
- Added a `Mini` / `Open` collapse control for the main UI.
- Automatically collapses the UI when trade opens and restores it when trade closes if trade caused the collapse.
- Simplified the Roster tab into a Setup flow with `Record Raid`, `Send Numbers`, and `Clear Raid`.
- Locked Setup controls and per-player number sends while a game session is active or a roll is pending.
- Updated project documentation for English-only roll parsing, Setup behavior, and collapse behavior.

## 0.1.3

- Bumped addon metadata version to `0.1.3`.
- Added stone-silver section separators across the MicroGames UI tabs.
- Renamed and moved the roster bulk number whisper button for clearer setup flow.
- `STOP GAME` now clears the runtime raid snapshot after saving the completed session to history.
- Made History round reward text more explicit with a `Reward:` label.
- Added subtle green highlights to History round winner and reward text.
- Added a `History` tab for completed game sessions.
- Added session selection, session details, and paginated per-round history.
- History now shows round number, roll time, winner number/name, reward text, and reward send time.
- Added a two-step `RESET ALL` control in Settings.
- `RESET ALL` now clears all MicroGames SavedVariables data, including history, active session, roster, rewards, settings, and round data.
- Added a large red destructive-action warning before final reset confirmation.
- Fixed reward pagination labels so Control and Rewards tabs no longer overwrite each other.
- Prevented starting a game session when no raid numbers can be recorded.
- Prevented starting a new roll or reroll while a delayed roll is still pending.
- Locked roster setup while a game session is active or a roll is pending.
- Captured the roll range at button press time so delayed rolls use the intended roster snapshot.
- Updated development and session/round documentation for history, pending rolls, and reset behavior.

## 0.1.0

- Added the core MicroGames WoW Classic Era addon structure.
- Added slash commands `/mg` and `/microgames`.
- Added a movable tabbed UI with Control, Roster, Rewards, and Settings views.
- Added raid roster snapshot numbering.
- Added number whisper templates with `XX` replacement.
- Added round announcements and delayed `/roll` handling through `RandomRoll`.
- Added own-roll detection from English `CHAT_MSG_SYSTEM` roll messages.
- Added winner resolution from the recorded roster snapshot.
- Added winner say and whisper actions.
- Added reward yell templates and persisted custom rewards.
- Added active game session persistence through `MicroGamesDB.activeSession`.
- Added completed session storage through `MicroGamesDB.history`.
- Added documentation for raid numbering, rounds, UI, and sessions.

## Initial

- Created the initial MicroGames addon files and TOC metadata.
