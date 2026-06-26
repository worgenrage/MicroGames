# Changelog

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
