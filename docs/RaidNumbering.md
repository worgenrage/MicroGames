# Raid Numbering

MicroGames uses game-specific raid numbers, not live raid roster indexes.
The addon must not count or assign raid numbers while it is loading.
Counting only happens when the game master explicitly starts the numbering flow from the UX.
In Single Raid mode, the game master must first run the GM positioning step from Setup. `Record Raid` stays locked until that move is verified.

## Terms

- `raidIndex`: The current WoW raid roster index from `GetRaidRosterInfo(index)` or `UnitInRaid(unit)`.
- `gameNumber`: The stable number assigned by MicroGames when the game starts.
- `subgroup`: The raid group number returned by `GetRaidRosterInfo(index)`, from 1 to 8.
- `GM move`: A live raid layout preparation step that swaps the game master into the last used raid subgroup before the MicroGames snapshot is recorded.

## Rules

- Raid roster indexes are not stable game identifiers.
- If a player leaves, joins, or the roster changes, WoW raid indexes can shift.
- MicroGames assigns stable `gameNumber` values from a snapshot of the raid roster.
- The snapshot excludes the local player running the addon, so the game master does not receive an MG number.
- In Single Raid mode, the assignment is created only by an explicit `addon.API.StartRaidNumbering()` call after `addon.API.MoveGMToLastSpot()` has reached a ready state.
- Starting raid numbering never sends whispers automatically.
- After assignment, lookups must use the MicroGames tables, not the live raid index.
- A player leaving the raid does not free or shift their `gameNumber`.
- New players do not receive a number automatically during an active game.
- `addon.API.StopRaidNumbering()` marks the numbering as inactive but keeps the recorded names and numbers.
- Stopped/inactive numbering snapshots can be viewed but cannot be used to send number whispers.
- `addon.API.ResetRaidNumbering()` clears all recorded names and numbers.
- Resetting raid numbering also resets the round counter.
- Clearing or stopping a recorded raid marks the GM move as required again before the next Single Raid snapshot.

## GM Positioning

`addon.API.MoveGMToLastSpot()` is a live raid scan and swap operation. It does not create a MicroGames number snapshot.

The operation:

- requires Single Raid mode
- requires a raid group
- is blocked during combat lockdown
- requires raid leader or assistant permissions
- scans the current raid roster with `GetRaidRosterInfo(index)`
- finds the highest used subgroup
- finds the highest raid-index member inside that subgroup
- swaps the GM with that member through `SwapRaidSubgroup()`
- waits for `GROUP_ROSTER_UPDATE` and verifies that the GM is in the target subgroup

The WoW API does not expose a direct "subgroup slot" operation, so MicroGames does not promise an exact visual slot inside the subgroup. The safe guarantee is that the GM is moved into the last used subgroup before `Record Raid` is enabled.

If the live raid roster changes after a verified move and before recording, the GM move is marked required again.

## Current Scope

- Single Raid mode is intended to be driven by the game master's client.
- Multi Raid mode supports a Coordinator plus accepted Assistants using addon-message whispers.
- Multi Raid roster and assignment payloads are chunked and sent through the internal throttled addon-message queue.

## API

```lua
local moveOk, moveReason = addon.API.MoveGMToLastSpot()
local moveView = addon.API.GetGMMoveView()
local canRecord = addon.API.CanRecordRaid()
local count = addon.API.StartRaidNumbering()
local number = addon.API.GetRaidNumberByName("Playername")
local name = addon.API.GetRaidNameByNumber(1)
local active = addon.API.HasRaidNumbers()
local assignedCount = addon.API.CountRaidNumbers()

addon.API.StopRaidNumbering()
addon.API.ResetRaidNumbering()
```

## Number Whispers

The game master can send the assigned number to every recorded raid member by whisper from a separate UX action, for example a `SendNumbers` button.
Starting raid numbering does not send any messages.
In Single Raid mode, the local player running the addon is skipped before MG numbers are assigned.
Whispers use the snapshot created by `addon.API.StartRaidNumbering()`, not the current live raid roster.
Whispers require active numbering. After `addon.API.StopRaidNumbering()`, the recorded snapshot remains visible, but number whispers do not send until numbering is started again.

The default whisper text is:

```text
Your MG number is: XX
```

`XX` is replaced with the player's assigned game number. If the UI saves a custom text without `XX`, the number is appended to the end.

```lua
addon.API.SetNumberWhisperText("Your MG number is: XX")

local text = addon.API.GetNumberWhisperText()
local preview = addon.API.BuildNumberWhisperMessage(12)
local sentToOne = addon.API.SendNumberWhisperToName("Playername")
local ok, queuedCountOrReason = addon.API.SendNumbers()
```

`addon.API.SendNumbers()` queues one whisper per recorded player while numbering is active. The queue sends gradually to avoid WoW chat spam limits, and progress is exposed through `addon.API.GetSendQueueView()`.
The whisper text is stored in `MicroGamesDB.numberWhisperText`.

Compatibility aliases are currently available:

```lua
addon.API.AssignRaidNumbers
addon.API.ClearRaidNumbers
addon.API.GetAssignedRaidCount
addon.API.SendNumberWhispers
```

Round logic is documented in `docs/Rounds.md`.
