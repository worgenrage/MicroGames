# Game Sessions

MicroGames keeps the active game session in SavedVariables so reloads and window close/open do not reset gameplay state.

## SavedVariables

- Active session: `MicroGamesDB.activeSession`
- Completed sessions: `MicroGamesDB.history`

## Start Game

`addon.API.StartGameSession()` starts or resumes the active game session.

- If no raid numbers exist yet, it creates a raid numbering snapshot first.
- It stores the roster snapshot, start timestamp, current round, rounds, and rewards.
- If an active session already exists after reload, it restores that session.
- If the user presses `START GAME` while a session is already active, the API returns `ACTIVE_SESSION_EXISTS` and does not start another session.
- While a session is active, roster setup should be locked so the active snapshot cannot be changed accidentally.

## Stop Game

`addon.API.StopGameSession()` stops the active session and appends it to `MicroGamesDB.history`.

The saved session includes:

- `startedAt`
- `stoppedAt`
- `assignedCount`
- `roster`
- `totalRounds`
- `rounds`
- `rewards`
- final winner fields when available

Rerolls are saved as additional roll entries inside the same round.

## History

History display is not implemented yet. A future History tab should read `addon.API.GetGameHistory()`.
