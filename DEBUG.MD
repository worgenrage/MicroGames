# Debug Notes

> Historical diagnostic note. The current implementation restores active Single and Multi Raid runtime state after `/reload`, cancels send queues during reset/clear operations, and reports Multi start/stop notification failures separately from the completed local state transition.

## Single Raid History Looks Incomplete After Multi Raid Work

Context:

- Live Single Raid test used `START GAME` / `STOP GAME`.
- Event reportedly started around `2026-07-19 18:27` and continued past `19:00`.
- History screenshot showed three completed Single Raid sessions:
  - `#1` started `2026-07-19 16:24:36`, stopped `2026-07-19 18:27:02`, `players 0`, `rounds 0`
  - `#2` started `2026-07-19 18:27:22`, stopped `2026-07-19 18:27:36`, `players 39`, `rounds 0`
  - `#3` started `2026-07-19 18:27:38`, stopped `2026-07-19 18:27:41`, `players 39`, `rounds 0`
- Screenshot also showed `Mode locked` while viewing History.

Current analysis:

- The screenshot shows completed sessions, not currently active sessions.
- Session `#1` looks like an old/stale `MicroGamesDB.activeSession` that was later stopped and appended to history.
- Sessions `#2` and `#3` look like two short START/STOP cycles around event start.
- If RoundRolls worked after `18:27`, then there likely was another active Single Raid session after these completed entries.
- History only receives a session when `API.StopGameSession()` succeeds and appends `MicroGamesDB.activeSession` to `MicroGamesDB.history`.
- Therefore, later round/reward data may still be inside `MicroGamesDB.activeSession` if the real event session was not successfully stopped.
- `Mode locked` after STOP is a clue that either `MicroGamesDB.activeSession` is still active, `pendingRollRound` exists, or `MicroGamesDB.multiRaid.gameStatus == "active"` is stale.

Relevant code paths:

- `API.StartGameSession()` creates `MicroGamesDB.activeSession`.
- `API.StopGameSession()` appends the active session to `MicroGamesDB.history`, then clears active Single Raid runtime state.
- `API.RoundRoll()` records round rows into the active Single Raid session.
- `HandleSystemMessage()` records winner/invalid roll results after parsing the WoW system roll message.
- `API.SendRewardYell()` records rewards into the active session.
- History UI shows only completed sessions from `API.GetGameHistory()`.

Useful in-game checks:

```lua
/dump MicroGamesDB.activeSession
/dump MicroGamesDB.activeSession and MicroGamesDB.activeSession.currentRound
/dump MicroGamesDB.activeSession and MicroGamesDB.activeSession.rounds and #MicroGamesDB.activeSession.rounds
/dump MicroGamesDB.multiRaid and MicroGamesDB.multiRaid.gameStatus
```

If `MicroGamesDB.activeSession` contains the missing rounds, then the data is probably not lost; it has not been moved into History because the active session has not been successfully stopped.

Open questions for later:

- Did `STOP GAME` return an error/status text at the end of the event, such as `ROLL_PENDING`?
- Was there still a pending roll when STOP was pressed?
- Was Multi Raid state left as `gameStatus = "active"` even while using Single Raid?
- Should History UI show the currently active session separately to avoid confusing "missing history" with "not stopped yet"?
- Should `STOP GAME` or mode lock status expose a clearer reason in the UI?
