# Game Sessions

MicroGames keeps the active game session in SavedVariables so reloads and window close/open do not reset gameplay state.
Both Single Raid and Multi Raid restore their current round, winner, invalid-roll state, and recorded session data after `/reload`. Pending scheduled rolls are deliberately cleared.

## SavedVariables

- Active Single Raid session: `MicroGamesDB.activeSession`
- Active Multi Raid session: `MicroGamesDB.multiRaid.activeSession`
- Completed sessions: `MicroGamesDB.history`

## Start Game

`addon.API.StartGameSession()` starts or resumes the active game session.

- If no raid numbers exist yet, Single Raid mode requires the GM move step to be ready before a raid numbering snapshot can be created.
- It stores the roster snapshot, start timestamp, current round, rounds, and rewards.
- If an active session already exists after reload, it restores that session.
- Pending roll state is cleared on reload because scheduled roll timers do not survive reload.
- If the user presses `START GAME` while a session is already active, the API returns `ACTIVE_SESSION_EXISTS` and does not start another session.
- While a session is active, roster setup should be locked so the active snapshot cannot be changed accidentally.
- After a game is stopped, the next Single Raid setup requires a fresh GM move before another `Record Raid`.

## Stop Game

`addon.API.StopGameSession()` stops the active session and appends it to `MicroGamesDB.history`.
After the completed session is saved, the runtime roster snapshot, round state, pending roll state, and last winner state are cleared so the next `START GAME` records a fresh raid snapshot.
Stopping a game is blocked while a roll is pending.

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
Rewards are saved only after an explicit reward button action calls `addon.API.SendRewardYell(index)`; rounds without a selected reward should display an empty reward value in History.

## Multi Raid Sessions

The Coordinator starts and stops Multi Raid games through `StartMultiRaidGameSession()` and `StopMultiRaidGameSession()`.
The active session is stored under `MicroGamesDB.multiRaid.activeSession` and restores its round and winner state after `/reload`.
Assistant start/stop delivery failures are reported as warnings because the Coordinator's local state transition has already completed.
Winners from Assistant raids are stored with `MANUAL_ASSISTANT_CHECK`; presence verification is performed manually by the responsible Assistant.

## History

The `History` tab reads `addon.API.GetGameHistory()` and displays completed sessions.

It shows:

- completed session rows with start time, stopped time, round count, and player count
- selected session details
- final winner
- reward count
- paginated round results for the selected session
- winner and roll timestamp per round
- reward text and reward timestamp per round

The Settings tab includes a two-step `RESET ALL` control that clears `MicroGamesDB`, including active session and completed history.
