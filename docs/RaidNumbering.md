# Raid Numbering

MicroGames uses game-specific raid numbers, not live raid roster indexes.
The addon must not count or assign raid numbers while it is loading.
Counting only happens when the game master explicitly starts the numbering flow from the UX.

## Terms

- `raidIndex`: The current WoW raid roster index from `GetRaidRosterInfo(index)` or `UnitInRaid(unit)`.
- `gameNumber`: The stable number assigned by MicroGames when the game starts.
- `subgroup`: The raid group number returned by `GetRaidRosterInfo(index)`, from 1 to 8.

## Rules

- Raid roster indexes are not stable game identifiers.
- If a player leaves, joins, or the roster changes, WoW raid indexes can shift.
- MicroGames assigns stable `gameNumber` values from a snapshot of the raid roster.
- The assignment is created only by an explicit `addon.API.StartRaidNumbering()` call.
- Starting raid numbering never sends whispers automatically.
- After assignment, lookups must use the MicroGames tables, not the live raid index.
- A player leaving the raid does not free or shift their `gameNumber`.
- New players do not receive a number automatically during an active game.
- `addon.API.StopRaidNumbering()` marks the numbering as inactive but keeps the recorded names and numbers.
- Stopped/inactive numbering snapshots can be viewed but cannot be used to send number whispers.
- `addon.API.ResetRaidNumbering()` clears all recorded names and numbers.
- Resetting raid numbering also resets the round counter.

## Current Scope

- The addon is currently intended to run on the game master's client only.
- There is no addon-message synchronization yet.
- If the addon is later used by multiple raid members, the game master should become the host and broadcast the assigned numbers.

## API

```lua
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
local sentCount = addon.API.SendNumbers()
```

`addon.API.SendNumbers()` sends one immediate whisper per recorded player while numbering is active. If chat throttling becomes a problem, this function should be changed to use a queued sender.
The whisper text is stored in `MicroGamesDB.numberWhisperText`.

Compatibility aliases are currently available:

```lua
addon.API.AssignRaidNumbers
addon.API.ClearRaidNumbers
addon.API.GetAssignedRaidCount
addon.API.SendNumberWhispers
```

Round logic is documented in `docs/Rounds.md`.
